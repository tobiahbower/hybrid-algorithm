function [order] = findOrder(noisy)
    % % Read the WAV file
    % [noisy, fs] = audioread(wavFilePath);
    
    % % Convert stereo to mono if necessary
    % if size(noisy, 2) == 2
    %     noisy = mean(noisy, 2);
    % end
    
    % Segment the noisy signal into frames
    frameSize = 256; % Example frame size
    totseg = floor(length(noisy) / frameSize);
    noisyFrames = reshape(noisy(1:totseg*frameSize), frameSize, totseg)';
    
    order = zeros(totseg, 1);
    % We assume maximum order to be 100
    T = 100;

    for i = 1:totseg
        [arcoefs, noisevar, reflection_coefs] = aryule(noisyFrames(i, :), T);
        pacf = -reflection_coefs;
        cpacf = cumsum(abs(pacf));
        % Estimated order = lag at which CPACF is 70% of range of CPACF
        dist = abs(cpacf - 0.7 * (range(cpacf)));
        [~, minIndex] = min(dist);
        order(i) = minIndex;

        % if i == 4 || i == totseg - 1
        %     if i == 4
        %         figure(5);
        %         heading = 'PACF plot for Voiced Frame';
        %     else
        %         figure(6);
        %         heading = 'PACF plot for Silent Frame';
        %     end
        %     title(heading);
        %     subplot(211);
        %     stem(pacf, 'filled', 'MarkerSize', 4);
        %     xlabel('Lag'); ylabel('Partial Autocorrelation coefficients');
        %     xlim([1 T]);
        %     uconf = 1.96 / sqrt(size(noisyFrames, 2));
        %     lconf = -uconf;
        %     hold on;
        %     plot([1 T], [1 1]' * [lconf uconf], 'r');
        %     hold off;
        %     subplot(212);
        %     text = ['Estimated order = ', num2str(order(i))];
        %     stem(cpacf, 'filled', 'MarkerSize', 4); xlabel('Lag'); ylabel('Cumulative PACF'); title(text);
        %     grid on;
        %     hold on;
        %     plot(0.7 * range(cpacf) * ones(1, T), 'r');
        %     hold off;
        %     xlabel('Lags'); ylabel('Cumulative PACF');
        % end
    end

    % saveas(figure(5), [saveToPath, 'PACF_plot_voiced_frame_', type, '_', num2str(dB), 'dB']);
    % saveas(figure(6), [saveToPath, 'PACF_plot_silent_frame_', type, '_', num2str(dB), 'dB']);
end
