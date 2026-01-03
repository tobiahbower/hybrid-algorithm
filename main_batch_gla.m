clear all; clc;
addpath(genpath(pwd));
set(0, 'defaultLegendInterpreter', 'latex');

denoise = false;
plotBool = false;

% === Optimization Parameters ===
n_iter = 50;               % Number of hybrid algorithm iterations
l = 256;                   % Window length / FFT length
m = 128;                   % Number of Mel bands
w = hann(l, 'periodic');   % STFT window
alpha = 0.01;              % Momentum convergence parameter
lambda = 0.001;            % Magnitude stability enforcer

noizeus = '.\..\sre-research\db-noizeus_corpora\NOIZEUS\';
cleanPath = fullfile(noizeus, 'clean_noizeus', 'wav');

% === Collect all noisy files recursively ===
noisyFiles = dir(fullfile(noizeus, '*babble*', 'wav', '*.wav'));
noisyFiles = noisyFiles(~contains({noisyFiles.folder}, 'clean_noizeus')); % filter out clean folder
nFiles = numel(noisyFiles);

fprintf('Found %d noisy files.\n', nFiles);

% === Pre-allocate results ===
fileNames = cell(nFiles,1);
stoi_before = zeros(nFiles,1);
visqol_before = zeros(nFiles,1);
pesq_before = zeros(nFiles,2);
stoi_after = zeros(nFiles,1);
visqol_after = zeros(nFiles,1);
pesq_after = zeros(nFiles,2);

% === Loop over all noisy files ===
for f = 1:nFiles
    noisyfile = fullfile(noisyFiles(f).folder, noisyFiles(f).name);
    [~, baseName, ~] = fileparts(noisyFiles(f).name);
    cleanfile = fullfile(cleanPath, [extractBefore(baseName,'_'), '.wav']);  % match clean reference

    fprintf('\n[%d/%d] Processing %s\n', f, nFiles, noisyfile);
    fileNames{f} = baseName;

    %% --- Load audio ---
    [x, fs] = audioread(noisyfile);
    [ref, ~] = audioread(cleanfile);
    x = x(:);
    firstNonZero = find(x ~= 0, 1, 'first');
    if ~isempty(firstNonZero), x = x(firstNonZero:end); end

    % --- Resample to 8k for MOS ---
    x = resample(x, 8000, fs);
    ref = resample(ref, 8000, fs);
    fs = 8000;

    %% --- MOS Before Enhancement ---
    stoi_before(f)   = stoi(x, ref, fs);
    visqol_before(f) = visqol(x, ref, fs, Mode='speech');
    try
        pesqObj = pesq.calc_pesq('pesq2.exe', noizeus, ...
            fullfile('clean_noizeus','wav',[extractBefore(baseName,'_') '.wav']), ...
            fullfile(noisyFiles(f).folder, noisyFiles(f).name), fs, 'nb');
        pesqScores = pesqObj.computeScores();
        pesq_before(f,:) = pesqScores;
    catch
        pesq_before(f,:) = [NaN NaN];
    end

    %% --- Mel Spectrogram ---
    FFT_len = 512;              % Match inferred FFT length
    hop = FFT_len / 4;          % 75% overlap
    win = hann(FFT_len, 'periodic');

    [X_STFT_magnitude, ~, ~, ~] = utils.Mel_Spectrogram(x, fs, FFT_len, m, win, 2, plotBool);

    % Initialize phase using noisy STFT
    [S_noisy, ~] = stft(x, 'Window', win, 'OverlapLength', hop, 'FFTLength', FFT_len);
    X_STFT_magnitude = abs(S_noisy);
    S_in = X_STFT_magnitude .* exp(1i * angle(S_noisy));
    S_prev = S_in;

    [nFreqBins, nFrames] = size(X_STFT_magnitude);
    expected_Nfft = 2*(nFreqBins - 1);
    fprintf('Magnitude bins: %d   inferred FFTLength: %d\n', nFreqBins, expected_Nfft);

    if length(win) > expected_Nfft
        error('Window length (%d) longer than inferred FFT length (%d).', length(win), expected_Nfft);
    end

    %% --- FGLA Enhancement Loop ---
    for i = 1:n_iter
        [Y_recon, y_recon] = utils.SR_FGLA_full(X_STFT_magnitude, S_in, S_prev, fs, alpha, lambda, win, hop);
        S_prev = S_in;
        S_in = Y_recon;
    end

    %% --- Post-process ---
    y_recon_real = real(y_recon);
    y_recon_real = y_recon_real / max(abs(y_recon_real));  % normalize safely

    % Trim or pad to match original length
    target_len = length(x);
    if length(y_recon_real) > target_len
        y_recon_trimmed = y_recon_real(1:target_len);
    else
        y_recon_trimmed = [y_recon_real; zeros(target_len - length(y_recon_real), 1)];
    end

    % Final cleanup
    y_recon_clean = y_recon_trimmed;
    y_recon_clean(isnan(y_recon_clean)) = 0;

    %% --- MOS After Enhancement ---
    stoi_after(f)   = stoi(y_recon_clean, ref(1:length(y_recon_clean)), fs);
    visqol_after(f) = visqol(y_recon_clean, ref(1:length(y_recon_clean)), fs, Mode='speech');

    outFile = fullfile(noizeus, [baseName '_enhanced.wav']);
    audiowrite(outFile, y_recon_clean, fs);

    try
        pesqObj2 = pesq.calc_pesq('pesq2.exe', noizeus, ...
            fullfile('clean_noizeus','wav',[extractBefore(baseName,'_') '.wav']), ...
            [baseName '_enhanced.wav'], fs, 'nb');
        pesqScores2 = pesqObj2.computeScores();
        pesq_after(f,:) = pesqScores2;
    catch
        pesq_after(f,:) = [NaN NaN];
    end

    %% --- Diagnostics ---
    fprintf('\n--- MOS Summary for %s ---\n', fileNames{f});
    fprintf('STOI   → Before: %.4f   After: %.4f\n', stoi_before(f), stoi_after(f));
    fprintf('PESQ   → Before: %.4f %.4f   After: %.4f %.4f\n', ...
        pesq_before(f,1), pesq_before(f,2), pesq_after(f,1), pesq_after(f,2));
    fprintf('Reconstructed length: %d   Original length: %d\n', length(y_recon_clean), length(x));
    fprintf('Max amplitude: %.4f   Any NaNs? %d\n', max(abs(y_recon_clean)), any(isnan(y_recon_clean)));
    fprintf('----------------------------------------\n');
end

%% === Tabulate Results ===
% Results = table(fileNames, stoi_before, visqol_before, pesq_before, stoi_after, visqol_after, pesq_after);
% disp('========================================');
% disp('   MOS Scores (Before vs After)  ');
% disp('========================================');
% disp(Results);
%
% fprintf('\n========================================\n');
% fprintf('   PESQ & STOI Scores (Before vs After)\n');
% fprintf('========================================\n');
% for f = 1:nFiles
%     fprintf('File: %s\n', fileNames{f});
%     fprintf('  STOI   → Before: %.4f   After: %.4f\n', stoi_before(f), stoi_after(f));
%     fprintf('  PESQ   → Before: %.4f %.4f   After: %.4f %.4f\n', ...
%         pesq_before(f,1), pesq_before(f,2), pesq_after(f,1), pesq_after(f,2));
%     fprintf('----------------------------------------\n');
% end

% Optional: Write to CSV
% writetable(Results, fullfile(noizeus, 'MOS_results.csv'));
% fprintf('Results saved to MOS_results.csv\n');
