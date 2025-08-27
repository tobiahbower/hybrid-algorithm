function score = MOS_PESQ(xPath, yPath)
%CALCULATE_PESQ_SCORE Computes PESQ score between two audio files
%   score = calculate_pesq_score(xPath, yPath)
%   xPath : path to reference audio file
%   yPath : path to degraded audio file

    sr_pesq_req = 16000;  % Required sampling rate for wideband PESQ

    % Load and resample audio
    [X, fsX] = audioread(xPath);
    [Y, fsY] = audioread(yPath);

    if fsX ~= sr_pesq_req
        X = resample(X, sr_pesq_req, fsX);
    end
    if fsY ~= sr_pesq_req
        Y = resample(Y, sr_pesq_req, fsY);
    end

    % Convert to mono if needed
    if size(X, 2) > 1
        X = mean(X, 2);
    end
    if size(Y, 2) > 1
        Y = mean(Y, 2);
    end

    % Convert to int16 format
    X_int16 = int16(X * 32767);
    Y_int16 = int16(Y * 32767);

    % Save temp WAV files
    audiowrite('ref.wav', X_int16, sr_pesq_req, 'BitsPerSample', 16);
    audiowrite('deg.wav', Y_int16, sr_pesq_req, 'BitsPerSample', 16);

    % Call PESQ executable (assumes it's in system path)
    [~, cmdout] = system('pesq +16000 ref.wav deg.wav');

    % Extract score from output
    score = str2double(regexp(cmdout, 'PESQ_MOS\s*=\s*([\d.]+)', 'tokens', 'once'));

    % Clean up temp files
    delete ref.wav deg.wav;
end