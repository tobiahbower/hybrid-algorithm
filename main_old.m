fs = 16000;

%% Load in NOIZEUS input speech files and calculate their PACF speech order
% noizeusDir = './NOIZEUS/';
% noizeus = dir(noizeusDir);
% noizeus = noizeus(3:end);
% envSnrs = {noizeus.name};
% 
% rawdata = struct();
% 
% for i = 1:length(noizeus)
%     varName = envSnrs{i};
%     speechFiles = dir([noizeusDir, noizeus(i).name, '/gla/']);
%     speechFiles = speechFiles(3:end);
% 
%     for j = 1:length(speechFiles)
%         [speechFile, ~] = audioread([speechFiles(j).folder, '/', speechFiles(j).name]);        
% 
%         % Store in nested structure: e.g. data.airport_0dB.sp01_airport_sn0
%         cleanName = matlab.lang.makeValidName(speechFiles(j).name);
%         cleanParent = matlab.lang.makeValidName(varName);
%         rawdata.(cleanParent).(cleanName).mag = speechFile;
%         rawdata.(cleanParent).(cleanName).pacf = findOrder(speechFile);  % speech order
%     end
% end
% assignin('base', 'rawdata', rawdata);
% 
% clear cleanName cleanParent envSnrs speechFiles i j varName


%% Run GLA over the NOIZEUS
% pyenv('Version', 'C:\Users\Toby\AppData\Local\Programs\Python\Python39\python.exe');
% insert(py.sys.path,int32(0),'C:\Users\Toby\github\phase-preservative-istft\Hybrid-Algorithm-PESQ\pipeline\'); % Show the python scripts
% 
% mod = py.importlib.import_module('griffinLimTune');
% py.importlib.reload(mod);
% audio_np = py.numpy.array(data.airport_0dB.sp01_airport_sn0_wav);
% mod.process(audio_np, int32(fs));

%% Load in GLA processed wav files to run speech enhancement on them
% glaDir = './gla/';
% gla = dir(glaDir);
% gla = gla(3:end);
% glaSnrs = {gla.name};
% 
% gladata = struct();
% 
% for i = 1:length(gla)
%     varName = glaSnrs{i};
%     speechFiles = dir([glaDir, gla(i).name, '/wav/']);
%     speechFiles = speechFiles(3:end);
% 
%     for j = 1:length(speechFiles)
%         [speech, ~] = audioread([speechFiles(j).folder, '\', speechFiles(j).name]);        
% 
%         % Store in nested structure: e.g. data.airport_0dB.sp01_airport_sn0
%         cleanName = matlab.lang.makeValidName(speechFiles(j).name);
%         cleanParent = matlab.lang.makeValidName(varName);
%         gladata.(cleanParent).(cleanName).mag = speech;
%         gladata.(cleanParent).(cleanName).pacf = findOrder(speech);  % speech order
%         gladata.(cleanParent).(cleanName).kalm = kalman_speech_varQ(speech, fs);
%     end
% end
% assignin('base', 'gladata', gladata);
% 
% clear cleanName cleanParent glaSnrs speechFiles i j varName
% Setup directories
glaDir = './gla/';
gla = dir(glaDir);
gla = gla(3:end);  % Skip '.' and '..'

% Loop through each SNR/environment folder
for i = 1:length(gla)
    varName = gla(i).name;
    speechFiles = dir(fullfile(glaDir, varName, 'wav', '*.wav'));

    % Create 'kalm' folder if it doesn't exist
    kalmanSaveDir = fullfile(glaDir, varName, 'kalm');
    if ~exist(kalmanSaveDir, 'dir')
        mkdir(kalmanSaveDir);
    end

    for j = 1:length(speechFiles)
        speechPath = fullfile(speechFiles(j).folder, speechFiles(j).name);
        [speech, fs] = audioread(speechPath);

        % Run Kalman filtering
        kalmResult = kalman_speech_varQ(speech, fs);

        % Clean filename for saving
        [~, cleanName, ext] = fileparts(speechFiles(j).name);
        cleanName = matlab.lang.makeValidName(cleanName);
        wavPath = fullfile(kalmanSaveDir, [cleanName, '_kalm.wav']);
        
        % Save .wav file
        audiowrite(wavPath, kalmResult, fs);

        % Save .mat file
        save(matPath, 'kalmResult');
    end
end

disp('Analysis Complete');