classdef LPC_PACF_Order_Estimator
    properties
        frameSize = 256;     % Frame size in samples
        maxOrder = 100;      % Maximum LPC order to test
        noisySignal          % Input noisy speech signal
        noisyFrames          % Segmented frames
    end

    methods
        function obj = LPC_PACF_Order_Estimator(noisy)
            % Constructor: accepts noisy signal
            obj.noisySignal = noisy(:);  % Ensure column vector
            totseg = floor(length(obj.noisySignal) / obj.frameSize);
            obj.noisyFrames = reshape(obj.noisySignal(1:totseg * obj.frameSize), obj.frameSize, totseg)';
        end

        function order = estimateOrder(obj)
            numFrames = size(obj.noisyFrames, 1);
            order = zeros(numFrames, 1);

            for i = 1:numFrames
                frame = obj.noisyFrames(i, :);

                % Skip frames with non-finite values
                if any(~isfinite(frame))
                    order(i) = NaN;  % Or set to 0 or -1 depending on your logic
                    continue;
                end

                [~, ~, reflection_coefs] = aryule(frame, obj.maxOrder);
                pacf = -reflection_coefs;
                cpacf = cumsum(abs(pacf));
                target = 0.7 * range(cpacf);
                [~, minIndex] = min(abs(cpacf - target));
                order(i) = minIndex;
            end
        end

        function plotPACF(obj, frameIndex)
            % Plot PACF and CPACF for a selected frame
            if frameIndex < 1 || frameIndex > size(obj.noisyFrames, 1)
                error('Frame index out of bounds.');
            end

            [~, ~, reflection_coefs] = aryule(obj.noisyFrames(frameIndex, :), obj.maxOrder);
            pacf = -reflection_coefs;
            cpacf = cumsum(abs(pacf));
            estOrder = find(abs(cpacf - 0.7 * range(cpacf)) == min(abs(cpacf - 0.7 * range(cpacf))), 1);

            figure;
            sgtitle(['PACF Analysis for Frame ', num2str(frameIndex)]);

            % PACF plot
            subplot(2,1,1);
            stem(pacf, 'filled', 'MarkerSize', 4);
            xlabel('Lag'); ylabel('PACF Coefficients');
            xlim([1 obj.maxOrder]);
            uconf = 1.96 / sqrt(obj.frameSize);
            hold on;
            plot([1 obj.maxOrder], [1 1]' * [uconf -uconf], 'r');
            hold off;

            % CPACF plot
            subplot(2,1,2);
            stem(cpacf, 'filled', 'MarkerSize', 4);
            hold on;
            plot(0.7 * range(cpacf) * ones(1, obj.maxOrder), 'r');
            hold off;
            xlabel('Lag'); ylabel('Cumulative PACF');
            title(['Estimated order = ', num2str(estOrder)]);
            grid on;
        end
    end
end