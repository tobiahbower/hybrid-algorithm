classdef SE_Kalman_Filter
    properties
        fs              % Sampling rate
        p               % LPC order
        frameDur = 0.64 % Frame duration in seconds
        overlapDur = 0.32 % Overlap duration in seconds
        Q_pos = [-10 -7 -5 -3, -2, -1, 0, 1, 2, 3, 5, 7, 10];  % Add more aggressive options
        enableSecondPass = true     % Toggle for second Kalman pass
        diagnostics = struct()      % Stores Q evolution, silent frames, etc.
    end

    methods
        function obj = SE_Kalman_Filter(fs, estOrder)
            obj.fs = fs;
            obj.p = estOrder;
        end

        function [enhanced] = enhance(obj, x, in)
            [segments, hopLen] = obj.segmentSignal(x);
            numFrames = size(segments, 1);

            [R, silentMask] = obj.measurementNoise(segments);
            obj.diagnostics.silentFrames = silentMask;

            H = [zeros(1, obj.p - 1), 1];
            G = H';
            cleaned = zeros(size(segments));
            Q_arr = zeros(1, numFrames);

            X = segments(1, 1:obj.p)';
            P0 = R * eye(obj.p);

            for i = 1:numFrames
                frame = segments(i, :);
                [A, Q1] = lpc(frame, obj.p);
                PHI = [eye(obj.p - 1), zeros(obj.p - 1, 1); -fliplr(A(2:end))];

                if i > 1 && in ~= 0
                    Q = obj.tuneQ(P0, PHI, H, Q1, R, obj.Q_pos(in));
                else
                    Q = Q1;
                end
                Q_arr(i) = Q;

                [cleanedFrame, P_last] = obj.kalmanFilter(frame, X, P0, PHI, H, G, Q, R);
                cleaned(i, :) = cleanedFrame;

                if obj.enableSecondPass
                    [A2, Q2] = lpc(cleanedFrame, obj.p);
                    PHI2 = [eye(obj.p - 1), zeros(obj.p - 1, 1); -fliplr(A2(2:end))];
                    [cleanedFrame2, ~] = obj.kalmanFilter(frame, cleanedFrame(1:obj.p)', P0, PHI2, H, G, Q2, R);
                    cleaned(i, :) = cleanedFrame2;
                    X = cleanedFrame2(1:obj.p)';
                else
                    X = cleanedFrame(1:obj.p)';
                end

                P0 = P_last;
            end

            enhanced = obj.overlapAdd(cleaned, hopLen);
            enhanced = enhanced(1:length(x));
            obj.diagnostics.Q_arr = Q_arr;
        end

        function [segments, hopLen] = segmentSignal(obj, x)
            frameLen = round(obj.frameDur * obj.fs);
            overlapLen = round(obj.overlapDur * obj.fs);
            hopLen = frameLen - overlapLen;
            numFrames = ceil((length(x) - overlapLen) / hopLen);
            segments = zeros(numFrames, frameLen);
            for i = 1:numFrames
                startIdx = (i - 1) * hopLen + 1;
                endIdx = min(startIdx + frameLen - 1, length(x));
                segments(i, 1:(endIdx - startIdx + 1)) = x(startIdx:endIdx);
            end
        end

        function [R, silentMask] = measurementNoise(obj, xseg)
            numFrame = size(xseg, 1);
            noise_cov = zeros(1, numFrame);
            spectral_flatness = zeros(1, numFrame);
            silentMask = zeros(1, numFrame);

            for k = 1:numFrame
                [c, lag] = xcorr(xseg(k, :), 'coeff');
                zeroIdx = find(lag == 0, 1);
                c = c(zeroIdx:end);
                psd = fftshift(abs(fft(c)));
                psd = psd(round(length(psd)/2):end);
                freq = obj.fs * (0:length(c)-1) / length(c);
                freq_2kHz = find(freq >= 100 & freq <= 2000);
                psd_2kHz = psd(freq_2kHz);
                spectral_flatness(k) = geomean(psd_2kHz) / mean(psd_2kHz);
            end

            norm_flatness = spectral_flatness / max(spectral_flatness);
            for k = 1:numFrame
                if norm_flatness(k) >= 0.707
                    noise_cov(k) = var(xseg(k, :));
                    silentMask(k) = 1;
                end
            end
            R = max(noise_cov);
        end

        function [Q_opt] = tuneQ(obj, P0, PHI, H, Q1, R, offset)
            J1 = zeros(1, 10); J2 = zeros(1, 10); nq = zeros(1, 10);
            for q = 1:10
                n = q - 6;
                Q0 = (10^n) * Q1;
                Ak = H * PHI * P0 * PHI' * H';
                Bk = H * Q0 * H';
                J1(q) = R / (Ak + Bk + R);
                J2(q) = Bk / (Ak + Bk);
                nq(q) = log10(Bk);
            end
            [nq_nom, ~] = utils.intersections(nq, J1, nq, J2);
            if ~isempty(nq_nom)
                Q_opt = 10^(nq_nom + offset);
            else
                Q_opt = Q1;
            end
        end

        function [cleanedFrame, P_last] = kalmanFilter(obj, frame, X, P0, PHI, H, G, Q, R)
            len = length(frame);
            cleanedFrame = zeros(1, len);
            P = P0;
            for j = 1:len
                X_ = PHI * X;
                P_ = PHI * P * PHI' + G * Q * G';
                K = P_ * H' / (H * P_ * H' + R);
                K = min(K, 1); % Clamp gain
                e = frame(j) - H * X_;
                X = X_ + K * e;
                P = (eye(obj.p) - K * H) * P_;
                cleanedFrame(j) = X(end);
            end
            P_last = P;
        end

        function y = overlapAdd(obj, frames, hopLen)
            [numFrames, frameLen] = size(frames);
            totalLen = (numFrames - 1) * hopLen + frameLen;
            y = zeros(1, totalLen);
            windowSum = zeros(1, totalLen);
            win = hann(frameLen)'; % Smooth window

            for i = 1:numFrames
                startIdx = (i - 1) * hopLen + 1;
                y(startIdx:startIdx + frameLen - 1) = y(startIdx:startIdx + frameLen - 1) + frames(i,:) .* win;
                windowSum(startIdx:startIdx + frameLen - 1) = windowSum(startIdx:startIdx + frameLen - 1) + win;
            end
            y = y ./ max(windowSum, 1e-6); % Normalize to avoid flutter
        end
    end
end