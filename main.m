clear all; clc;
addpath(genpath(pwd));

% === Optimization Parameters ===
n_iter = 100;               % Number of hybrid algorithm iterations
l = 128;                     % Window length / FFT length
m = 128;                     % Number of Mel bands
w = hann(l, 'periodic');     % STFT window
alpha = 0.5;                % Momentum convergence parameter
lambda = 0.1;                % Magnitude stability enforcer

%% Load
% [x, fs] = audioread("./samples/billy-inputs/billy_inp.wav");
[x,fs] = audioread('.\..\sre-research\db-noizeus_corpora\NOIZEUS\airport_0dB\wav\sp01_airport_sn0.wav');

x = x(:);
% Find the index of the first non-zero element
firstNonZero = find(x ~= 0, 1, 'first');

% Trim leading zeros
if isempty(firstNonZero)
    x = [];  % All elements are zero
else
    x = x(firstNonZero:end);
end

% PESQ is designed for 8000Hz
x = resample(x, 8000, fs);
fs = 8000;
% figure(100); plot(x); hold on;

%% Plot a VAD
x_norm = x / max(abs(x));
vad.plotVAD(x_norm, fs, @vad.vad1);

%% Reverse hybrid - apply Kalamn denoising first
% kalman = utils.SE_Kalman_Filter(fs);
% x = kalman.enhance(x,1);
% plot(x); hold off;

%% === LPC Order Estimation ===
xorder = utils.LPC_PACF_Order_Estimator(x);
x_order = xorder.estimateOrder();
xorder.plotPACF(2);

%% === One-Sided STFT ===
[X_STFT, f_spectrum_eval, t_overlap_eval] = stft(x, fs, ...
    'Window', w, ...
    'OverlapLength', l/2, ...
    'FFTLength', l*4, ...
    'FrequencyRange', 'onesided');

X_STFT_magnitude = abs(X_STFT);                     % Magnitude spectrum
num_STFT_bins = size(X_STFT_magnitude, 1);          % Should be l/2 + 1 = 257

% === Mel Filter Bank Design ===
X_mel_filter_bank = designAuditoryFilterBank(num_STFT_bins, ...
    'FFTLength', l*4, ...
    'NumBands', m, ...
    'FrequencyScale', 'mel');

% === Mel Spectrogram Computation ===
X_mel_spectrogram = X_mel_filter_bank * X_STFT_magnitude;
X_mel_spectrogram_dB = 10 * log10(X_mel_spectrogram + eps);  % Log compression

% === Initialize STFT State ===
S_in = X_STFT_magnitude .* exp(1i * 2 * pi * rand(size(X_STFT_magnitude)));  % Initial phase
S_prev = S_in;                % Previous iteration state

win = hann(256, 'periodic');
hop = 128;

%% FGLA Implementation
convergence_error = zeros(n_iter, 1);  % Preallocate error vector

% === Hybrid Griffin-Lim + Kalman Enhancement Loop ===
for i = 1:n_iter
    % --- Speech Reconstruction ---
    [Y_recon, y_recon] = utils.SR_FGLA(X_STFT_magnitude, S_in, S_prev, alpha, lambda, win, hop);

    % y_recon = utils.SE_Kalman(real(x_recon), 2, 8000);

    % --- Update STFT State ---
    S_prev = S_in;
    S_in = Y_recon;

    current_magnitude = abs(S_in);
    error = norm(current_magnitude - X_STFT_magnitude, 'fro') / norm(X_STFT_magnitude, 'fro');
    convergence_error(i) = error;

    fprintf('Iter: %d/%d\n', i, n_iter);
end

%% Analysis 
% Spectral convergence
figure(5);
plot(1:n_iter, convergence_error, 'DisplayName', sprintf('\alpha=%d',alpha));
hold on;
xlabel('iteration');
ylabel('residual stft');
title('spectral convergence SR\_FGLA');
grid on;

% === Clean Spike Artifact ===
y_recon(end) = NaN;
y_recon(1) = NaN;

% === Resample y_recon to match x length ===
y_recon_real = real(y_recon);  % Remove imaginary part
y_recon_resampled = resample(y_recon_real, length(x), length(y_recon_real));  % Match length

% order estimator
yorder = utils.LPC_PACF_Order_Estimator(y_recon_resampled);
y_recon_resampled_order = yorder.estimateOrder();
yorder.plotPACF(2);

% VAD in post
% Remove leading and trailing NaNs
firstValid = find(~isnan(y_recon_resampled), 1, 'first');
lastValid  = find(~isnan(y_recon_resampled), 1, 'last');
y_recon_resampled_clean = y_recon_resampled(firstValid:lastValid);
%normalize
y_recon_resampled_norm = y_recon_resampled_clean / max(abs(y_recon_resampled_clean));
% rms_orig = sqrt(mean(y_recon_resampled_clean.^2));
% rms_denoised = sqrt(mean(y_recon_resampled_clean.^2));
% y_recon_resampled_norm = y_recon_resampled_clean * (rms_orig / rms_denoised);
vad.plotVAD(y_recon_resampled_norm, fs, @vad.vad1, 83);

