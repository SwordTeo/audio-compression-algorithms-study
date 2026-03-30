%% Πείραμα 5 – Ανθεκτικότητα σε Θόρυβο (Noise Robustness)
% Θ. Σπάθης – Διπλωματική (MATLAB R2025b)
% Μετρά επιδείνωση SNR μετά από προσθήκη θορύβου και συμπίεση με FFmpeg.

clear; clc;

%% Ρυθμίσεις
dataFolder   = "C:\Users\teosp\OneDrive\Desktop\ergasies\Διπλωματική Εργασία 2024\experiment\audio_dataset";      
outFolder    = fullfile(dataFolder,"encoded_noise");
ffmpegPath   = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";
codec        = "libmp3lame";       
bitrate      = 128;                    % σταθερό bitrate
noiseLevels  = [10 20 30];             % SNR του προστιθέμενου θορύβου (dB)
targetFs     = 44100;
makePlots    = true;

if ~exist(outFolder,"dir"), mkdir(outFolder); end
wavFiles = dir(fullfile(dataFolder,"*.wav"));
assert(~isempty(wavFiles),"Δεν βρέθηκαν .wav αρχεία στο %s",dataFolder);

%% Πίνακας αποτελεσμάτων
results = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'File','InputSNR_dB','OutputSNR_dB','DeltaSNR_dB','CR'});

%% Κύριος βρόχος
for f = 1:numel(wavFiles)
    inPath = fullfile(wavFiles(f).folder,wavFiles(f).name);
    [x,fs] = audioread(inPath);
    x = mean(x,2);
    if fs~=targetFs, x = resample(x,targetFs,fs); fs=targetFs; end
    x = x ./ max(abs(x));

    origBytes = dir(inPath).bytes;

    for nl = noiseLevels
        % --- Πρόσθεσε Gaussian θόρυβο για επιθυμητό SNR (πριν τη συμπίεση)
        noisy = awgn(x, nl, 'measured');

        % --- Υπολόγισε SNR εισόδου
        inputSNR = 10*log10(sum(x.^2)/sum((x-noisy).^2));

        % --- Γράψε προσωρινό αρχείο με θόρυβο
        noisyWav = fullfile(outFolder, sprintf("tmp_%s_noise%ddB.wav", erase(wavFiles(f).name,".wav"), nl));
        audiowrite(noisyWav, noisy, fs);

        % --- Κωδικοποίηση με FFmpeg
        outFile = fullfile(outFolder, sprintf("%s_noise%ddB_%dkbps.mp3", ...
                     erase(wavFiles(f).name,".wav"), nl, bitrate));
        cmd = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %dk -acodec %s "%s"', ...
                      ffmpegPath, noisyWav, bitrate, codec, outFile);
        system(cmd);

        % --- Ανάγνωση & SNR εξόδου
        [y,fs_y] = audioread(outFile);
        if fs_y~=fs, y = resample(y,fs,fs_y); end
        y = mean(y,2);
        N = min(numel(x),numel(y)); xA = x(1:N); yA = y(1:N);

        outputSNR = 10*log10(sum(xA.^2)/sum((xA-yA).^2));
        deltaSNR  = outputSNR - inputSNR;
        CR = origBytes / dir(outFile).bytes;

        results = [results; {string(wavFiles(f).name), inputSNR, outputSNR, deltaSNR, CR}]; %#ok<AGROW>
        fprintf("OK | noise=%2ddB -> In=%.2f Out=%.2f Δ=%.2f dB | CR=%.2f\n", ...
            nl, inputSNR, outputSNR, deltaSNR, CR);

        delete(noisyWav); % καθάρισε προσωρινό αρχείο
    end
end

%% Αποθήκευση
outCSV = fullfile(outFolder,"results_exp5_noise.csv");
writetable(results,outCSV);
fprintf("\nΑποθήκευση: %s\n", outCSV);

%% Γραφήματα
if makePlots && ~isempty(results)
    figure; plot(results.InputSNR_dB, results.OutputSNR_dB, '-o');
    xlabel('Input SNR (dB)'); ylabel('Output SNR (dB)');
    title('Επίδραση θορύβου στην ποιότητα μετά τη συμπίεση');
    grid on;

    figure; plot(results.InputSNR_dB, results.DeltaSNR_dB, '-o');
    xlabel('Input SNR (dB)'); ylabel('Απώλεια SNR (Δ dB)');
    title('Απώλεια SNR λόγω συμπίεσης'); grid on;
end
