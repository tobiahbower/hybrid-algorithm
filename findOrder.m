function [order] = findOrder(noisy)
% Estimate LPC order for each frame of a noisy speech signal using PACF
% Input:
%   noisy     - Noisy speech signal (mono)
% Output:
%   order     - Estimated LPC order per frame
% Optional:
%   plotFlag  - Set to true to enable PACF plots for selected frames

% --- Configuration ---
plotFlag = false;         % Toggle plotting ON/OFF
frameSize = 256;         % Frame size in samples
maxOrder = 100;          % Maximum LPC order to test

% --- Frame segmentation ---
totseg = floor(length(noisy) / frameSize);  % Total number of full frames
noisyFrames = reshape(noisy(1:totseg * frameSize), frameSize, totseg)';  % Frame matrix

order = zeros(totseg, 1);  % Preallocate order array

% --- LPC order estimation loop ---
for i = 1:totseg
    % Estimate LPC coefficients using Yule-Walker method
    [~, ~, reflection_coefs] = aryule(noisyFrames(i, :), maxOrder);
    
    % Compute PACF and cumulative PACF
    pacf = -reflection_coefs;
    cpacf = cumsum(abs(pacf));
    
    % Estimate order: lag where CPACF reaches 70% of its range
    target = 0.7 * range(cpacf);
    [~, minIndex] = min(abs(cpacf - target));
    order(i) = minIndex;

    % --- Optional plotting for selected frames ---
    if plotFlag && (i == 4 || i == totseg - 1)
        figure;
        if i == 4
            heading = 'PACF plot for Voiced Frame';
        else
            heading = 'PACF plot for Silent Frame';
        end
        sgtitle(heading);

        % Plot PACF
        subplot(2,1,1);
        stem(pacf, 'filled', 'MarkerSize', 4);
        xlabel('Lag'); ylabel('PACF Coefficients');
        xlim([1 maxOrder]);
        uconf = 1.96 / sqrt(frameSize);  % Confidence bounds
        hold on;
        plot([1 maxOrder], [1 1]' * [uconf -uconf], 'r');
        hold off;

        % Plot CPACF
        subplot(2,1,2);
        stem(cpacf, 'filled', 'MarkerSize', 4);
        hold on;
        plot(0.7 * range(cpacf) * ones(1, maxOrder), 'r');
        hold off;
        xlabel('Lag'); ylabel('Cumulative PACF');
        title(['Estimated order = ', num2str(order(i))]);
        grid on;
    end
end

end
