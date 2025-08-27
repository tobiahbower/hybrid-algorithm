function plotVAD(x, fs, vadFuncHandle, figNum)
% plotVAD Visualizes a signal and its VAD output
%
% Inputs:
%   x             - Input signal vector
%   fs            - Sampling frequency (Hz)
%   vadFuncHandle - Function handle to VAD function, e.g., @vad.vad1
%   figNum        - (Optional) Figure number to use (default: 82)
%
% Example:
%   plotVAD(x, fs, @vad.vad1);

    if nargin < 4
        figNum = 82;
    end

    x_len = length(x);
    t = (1:x_len) ./ fs;

    % Run VAD
    result = vadFuncHandle(x, fs, x_len);

    % Plot
    figure(figNum); clf;
    p1 = plot(t, x, 'Color', [0 .4 .7]); % Light blue signal
    hold on;
    p2 = plot(t, result * 0.3, 'r-', 'LineWidth', 1.2); % VAD overlay

    % Styling
    set(gca, 'Color', 'k');
    ylim([-0.3 1]);
    xlim([0 t(end)]);
    title('Signal with VAD Overlay');
    xlabel('Time (s)');
    legend({'Signal', 'VAD'}, 'TextColor', 'w');
end