function score = MOS_STOI(xPath, yPath)
%CALCULATE_STOI_SCORE Computes STOI score between two audio files
%   score = calculate_stoi_score(xPath, yPath)
%   xPath : path to reference audio file
%   yPath : path to degraded audio file

    sr_stoi_req = 10000;  % STOI standard sampling rate

    % Load and resample audio
    [X, fsX] = audioread(xPath);
    [Y, fsY] = audioread(yPath);

    if fsX ~= sr_stoi_req
        X = resample(X, sr_stoi_req, fsX);
    end
    if fsY ~= sr_stoi_req
        Y = resample(Y, sr_stoi_req, fsY);
    end

    % Convert to mono if needed
    if size(X, 2) > 1
        X = mean(X, 2);
    end
    if size(Y, 2) > 1
        Y = mean(Y, 2);
    end

    % Truncate to match lengths
    minLen = min(length(X), length(Y));
    X = X(1:minLen);
    Y = Y(1:minLen);

    % Compute STOI score
    score = stoi(X, Y, sr_stoi_req);
end