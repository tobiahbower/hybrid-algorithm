function [S_out, y_out] = SR_FGLA(magnitude, S_in, prevS, alpha, lambda, win, hop)
%SR_FGLA_STEP Performs one iteration of Griffin-Lim with momentum and smoothing
%   [S_out, y_out] = SR_FGLA_step(magnitude, S_in, prevS, alpha, lambda)
%   magnitude : input magnitude spectrogram
%   S_in      : current complex spectrogram estimate
%   prevS     : previous spectrogram (for momentum)
%   alpha     : momentum factor (e.g., 0.99)
%   lambda    : smoothing factor (e.g., 0.1)
%   S_out     : updated spectrogram after one iteration
%   y_out     : reconstructed time-domain signal

    FFT_len = length(win);

    % Check Hermitian symmetry
    isSymmetric = norm(S_in - flipud(conj(S_in))) < 1e-10;

    % Enforce symmetry
    % S_in = enforceHermitian(S_in);
    
    y_out = istft(S_in, 'Window', win, 'OverlapLength', hop, 'FFTLength', FFT_len);
    S_new = stft(y_out, 'Window', win, 'OverlapLength', hop, 'FFTLength', FFT_len);
    
    % Inspect imaginary energy ratio
    imagEnergyRatio = norm(imag(y_out)) / norm(y_out);

    phase = exp(1i * angle(S_new));
    if size(phase, 1) == 256
        phase = [phase; zeros(1, size(phase, 2))];
    end
    S_est = magnitude .* phase;

    S_momentum = alpha * prevS + (1 - alpha) * S_est;

    S_out = (1 / (1 + lambda)) * (S_momentum + (lambda / (1 + lambda)) * magnitude .* phase);
end

% function S_sym = enforceHermitian(S)
%     % Assumes S is one-sided (e.g., 0 to N/2)
%     N = size(S, 1);
%     S_sym = [S; conj(flipud(S(2:end-1, :)))]; % Reconstruct full spectrum
% end