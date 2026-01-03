classdef calc_pesq
    properties
        Binary % Path to the PESQ executable
        PathAudio % Path to the folder containing audio files
        Reference % Reference audio file
        Degraded % Degraded audio file
        SamplingFrequency % Sampling frequency
        Mode % PESQ mode ('nb' or 'wb')
    end

    methods
        function obj = calc_pesq(binary, pathaudio, reference, degraded, fs, mode)
            % Constructor to initialize properties
            obj.Binary = binary;
            obj.PathAudio = pathaudio;
            obj.Reference = reference;
            obj.Degraded = degraded;
            obj.SamplingFrequency = fs;
            obj.Mode = mode;
        end

        function scores = computeScores(obj)
            % Compute PESQ scores
            referencePath = fullfile(obj.PathAudio, obj.Reference);
            degradedPath = fullfile(obj.PathAudio, obj.Degraded);

            % Prepare the command for system call
            command = sprintf('pushd %%CD%% && cd %s && %s +%i %s %s && popd', ...
                pwd(), obj.Binary, obj.SamplingFrequency, referencePath, degradedPath);

            [status, stdout] = system(command);

            if status ~= 0
                error('The %s binary exited with error code %i:\n%s\n', obj.Binary, status, stdout);
            end

            scores = obj.stdout2scores(stdout);
        end

        function scores = stdout2scores(~, stdout)
            % Extract scores from the stdout output
            tag = 'Prediction : PESQ_MOS = ';
            idx = strfind(stdout, tag);

            if isempty(idx) || length(idx) ~= 1
                scores = [NaN, NaN]; % Default values
                return;
            end

            stdout = stdout(idx + length(tag):end);
            scores = sscanf(stdout, '%f', [1, 2]);

            if isempty(scores)
                scores = [NaN, NaN]; % Default values
            end
        end
    end
end
