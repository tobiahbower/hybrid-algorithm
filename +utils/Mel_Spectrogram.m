function [X_STFT_magnitude, X_mel_spectrogram_dB, time_vector, frequency_vector] = Mel_Spectrogram(inputSpeech, fs, l, m, w, subnum, plotBool)
% computeMelSpectrogram - Computes a Mel-scaled spectrogram from a denoised signal
%
% Inputs:
%   x_denoised : Denoised input signal (vector)
%   fs         : Sampling frequency (Hz)
%   l          : Window length (samples)
%   m          : Number of Mel bands
%   w          : Window function (e.g., hamming(l))
%   plotBool   : (Optional) Boolean to enable visualization (default: false)
%
% Outputs:
%   X_mel_spectrogram_dB : Mel spectrogram in dB scale
%   time_vector           : Time axis for spectrogram
%   frequency_vector      : Frequency axis (Hz)

    if nargin < 6
        plotBool = false;
    end

    %% === One-Sided STFT ===
    [X_STFT, ~, ~] = stft(inputSpeech, fs, ...
        'Window', w, ...
        'OverlapLength', l/2, ...
        'FFTLength', l*4, ...
        'FrequencyRange', 'onesided');

    X_STFT_magnitude = abs(X_STFT);
    num_STFT_bins = size(X_STFT_magnitude, 1);  % Should be l/2 + 1

    %% === Mel Filter Bank Design ===
    X_mel_filter_bank = designAuditoryFilterBank(num_STFT_bins, ...
        'FFTLength', l*4, ...
        'NumBands', m, ...
        'FrequencyScale', 'mel');

    %% === Mel Spectrogram Computation ===
    X_mel_spectrogram = X_mel_filter_bank * X_STFT_magnitude;
    X_mel_spectrogram_dB = 10 * log10(X_mel_spectrogram + eps);  % Log compression

    %% === Time and Frequency Vectors ===
    time_vector = linspace(0, size(X_mel_spectrogram_dB, 2) * (l/2) / fs, size(X_mel_spectrogram_dB, 2));
    frequency_vector = linspace(0, fs/2, num_STFT_bins);

    %% === Visualization ===
    if plotBool
        figure(91);
        ylabel('Frequency (Hz)');
        subplot(3,1,subnum);
        imagesc(time_vector, frequency_vector, X_mel_spectrogram_dB);
        axis xy;
        % colorbar;
        if subnum==3
            xlabel('Time (s)');
        end
        % title('Mel Spectrogram (dB)');
    end
end