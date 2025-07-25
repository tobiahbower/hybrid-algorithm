function [cleanSpeech] = kalman_speech_varQ(x, in, fs)
% Kalman filter-based speech enhancement with tunable process noise
% Inputs:
%   x  - Noisy speech signal
%   in - Index for process noise tuning (0–5)
%   fs - Sampling rate
% Output:
%   cleanSpeech - Enhanced speech signal

% Define tuning offsets for process noise (Q)
Q_pos = [-3, -0.7, 0, 1, 3];

% LPC order (number of coefficients)
p = 15;
y = x(:)';  % Ensure row vector

% Frame parameters: 80ms frames with 10ms overlap
frameLen = round(0.08 * fs);
overlap = round(0.01 * fs);
step = frameLen - overlap;
numFrames = ceil(length(y) / step);
segments = zeros(numFrames, frameLen);

% Segment the signal into overlapping frames
start = 1;
for i = 1:numFrames
    stop = min(start + frameLen - 1, length(y));
    segments(i, 1:(stop - start + 1)) = y(start:stop);
    start = start + step;
end

% Kalman filter setup
H = [zeros(1, p - 1), 1];  % Observation matrix
G = H';                   % Process noise input matrix
R = measurementNoiseNew(segments, fs);  % Estimate measurement noise
cleanSpeech = zeros(1, length(y));      % Output buffer
cleanspeech = zeros(numFrames, frameLen);  % Frame-wise output
Q_arr = zeros(1, numFrames);            % Store Q values for analysis

% Initial state estimate from first p samples
X = y(1:p)';
P = zeros(frameLen, p, p);
P(1, :, :) = R * eye(p);  % Initial error covariance
temp = eye(p);            % Identity matrix for reuse

for i = 1:numFrames
    % LPC analysis on current noisy frame
    [A, Q1] = lpc(segments(i, :), p);
    PHI = [temp(2:p, :); -fliplr(A(2:end))];  % State transition matrix
    % --- Adaptive tuning of process noise Q ---
    if i > 1 && in ~= 0
        q = 1;
        for n = -5:4
            Q0 = (10^n) * Q1;
            P0 = squeeze(P(1, :, :));
            Ak = H * (PHI * P0 * PHI') * H';  % Prediction error
            Bk = H * Q0 * H';                % Process noise contribution
            J1(q) = R / (Ak + Bk + R);       % Sensitivity to measurement noise
            J2(q) = Bk / (Ak + Bk);          % Sensitivity to process noise
            nq(q) = log10(Bk);               % Log-scale for plotting
            q = q + 1;
        end
        [nq_nom, ~] = intersections(nq, J1, nq, J2);  % Find optimal Q

        % Adjust Q based on tuning index
        if ~isempty(nq_nom)
            Q = 10^(nq_nom + Q_pos(in));
        else
            Q = Q1;
        end
    else
        Q = Q1;
    end
    Q_arr(i) = Q;

    % --- First Kalman filter pass (noisy input) ---
    for j = 1:frameLen
        X_ = PHI * X;  % Predict state
        P0 = squeeze(P(j, :, :));
        P_ = PHI * P0 * PHI' + G * Q * G';  % Predict error covariance
        K = P_ * H' / (H * P_ * H' + R);    % Kalman gain
        P(j + 1, :, :) = (eye(p) - K * H) * P_;  % Update error covariance
        e = segments(i, j) - H * X_;       % Innovation
        X = X_ + K * e;                    % Update state
        cleanspeech(i, j) = X(end);        % Output last state as speech
    end
    P(1, :, :) = P(frameLen, :, :);  % Carry over final covariance

    % --- Second Kalman pass (cleaned input) ---
    [A, Q] = lpc(cleanspeech(i, :), p);
    PHI = [temp(2:p, :); -fliplr(A(2:end))];
    if i == 1
        X = cleanspeech(i, 1:p)';
        P0 = temp * R;
    end
    for j = 1:frameLen
        X_ = PHI * X;
               K = P_ * H' / (H * P_ * H' + R);
        P0 = (eye(p) - K * H) * P_;
        e = segments(i, j) - H * X_;
        X = X_ + K * e;
        cleanspeech(i, j) = X(end);
    end
end

% --- Overlap-add reconstruction ---
cleanSpeech(1:frameLen) = cleanspeech(1, :);
start = frameLen + 1;
for i = 2:numFrames - 1
    cleanSpeech(start:start + step) = cleanspeech(i, overlap + 1:end);
    start = start + step;
end
cleanSpeech(start:end) = cleanspeech(numFrames, 1:(length(y) - start + 1));
clean(1:length(y));  % Trim to original length

end
