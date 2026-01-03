function score = calculate_pesq(referenceAudio, degradedAudio, fs, mode)
%CALCULATE_PESQ Computes PESQ score between two audio signals
%   score = calculate_pesq(referenceAudio, degradedAudio, fs, mode)
%   referenceAudio : reference audio signal (vector)
%   degradedAudio : degraded audio signal (vector)
%   fs : integer, sampling rate (e.g., 16000)
%   mode : 'wb' for wide-band or 'nb' for narrow-band

    if nargin < 4
        mode = 'wb'; % Default to wide-band
    end

    % Normalize audio signals
    max_val = max(max(abs(referenceAudio)), max(abs(degradedAudio)));
    referenceAudio = referenceAudio / max_val; % Normalize
    degradedAudio = degradedAudio / max_val; % Normalize

    % Convert to int16 format for PESQ calculation
    referenceAudio_int16 = int16(referenceAudio * 32767);
    degradedAudio_int16 = int16(degradedAudio * 32767);

    % Call PESQ function directly if available in your MATLAB environment
    if strcmp(mode, 'wb')
        score = utils.pesq(fs, referenceAudio_int16, degradedAudio_int16, 'wb');
    else
        score = utils.pesq(fs, referenceAudio_int16, degradedAudio_int16, 'nb');
    end
end
