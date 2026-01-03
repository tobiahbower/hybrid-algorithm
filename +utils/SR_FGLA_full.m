function [S_out, y_out] = SR_FGLA_full(magnitude, S_in, prevS, fs, alpha, lambda, win, hop)
% SR_FGLA_full  One iteration of Griffin-Lim variant that keeps shapes consistent.
%   magnitude : (F x T) magnitude spectrogram (F = Nfft/2 + 1)
%   S_in      : (F x T) complex spectrogram estimate (same size as magnitude)
%   prevS     : previous complex spectrogram (same size)
%   win, hop  : window and hop (win length must be <= Nfft)
%
% Returns S_out (F x T) and y_out (time-domain reconstruction)

% ---- derive FFT length from magnitude shape ----
[F_bins, ~] = size(magnitude);
Nfft = 2*(F_bins - 1);             % invert bins -> FFT length
FFT_len = Nfft;

% ---- sanity checks ----
assert(all(size(S_in) == size(magnitude)), 'S_in and magnitude must share shape');
if length(win) > FFT_len
    error('Window length (%d) must be <= inferred FFT length (%d).', length(win), FFT_len);
end

% ---- reconstruct time-domain signal using explicit FFT length ----
y_out = istft(S_in, 'Window', win, 'OverlapLength', hop, 'FFTLength', FFT_len);

% ---- recompute STFT with exact same FFT length ----
S_new = stft(y_out, 'Window', win, 'OverlapLength', hop, 'FFTLength', FFT_len);

% ---- compute phase from S_new and enforce same size ----
phase = exp(1i * angle(S_new));   % (F_bins x T), because FFTLength used above

% ---- construct estimated full-band spectrogram (magnitude with updated phase) ----
% Safe magnitude-phase fusion
% Ensure phase and magnitude have same shape
[F_mag, T_mag] = size(magnitude);
[F_phase, T_phase] = size(phase);

% Trim or pad phase to match magnitude
if F_phase > F_mag
    phase = phase(1:F_mag, :);
elseif F_phase < F_mag
    phase = [phase; ones(F_mag - F_phase, T_phase)];
end

if T_phase > T_mag
    phase = phase(:, 1:T_mag);
elseif T_phase < T_mag
    phase = [phase, ones(F_mag, T_mag - T_phase)];
end

S_est_fullband = magnitude .* phase;


% ---- momentum update (Fast GLA style): momentum on the difference ----
% residual = (S_est - prevS);  then add alpha * residual to S_est
residual = S_est_fullband - prevS;
S_momentum = S_est_fullband + alpha * residual;

% ---- optional smoothing on magnitude only (do NOT smash phase) ----
% Example conservative smoothing: mix magnitudes, keep phase from S_momentum
if nargin >= 6 && lambda > 0
    mag_smoothed = (abs(S_momentum) + lambda * magnitude) ./ (1 + lambda);
    S_out = mag_smoothed .* exp(1i * angle(S_momentum));
else
    S_out = S_momentum;
end

% ---- enforce Hermitian symmetry (so iSTFT yields real signal) ----
S_out = enforceHermitian_full(S_out);

end

function S = enforceHermitian_full(S)
% S is F x T where F = Nfft/2 + 1
% Keep DC and Nyquist untouched, symmetrize the rest
F = size(S,1);
if F < 3
    return;
end
% indices 2:(F-1) are mirrored with (F-1):-1:2
mid = 2:F-1;
S(mid, :) = 0.5*(S(mid,:) + flipud(conj(S(mid,:))));
end
