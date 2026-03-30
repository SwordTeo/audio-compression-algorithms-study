%% Πείραμα 3 – Πολυπλοκότητα & Πόροι (CPU χρόνος, RTF, CR, SNR)
% Θ. Σπάθης – Διπλωματική (MATLAB R2025b)
% Απαιτεί ffmpeg.exe να λειτουργεί

clear; clc;

%% Ρυθμίσεις
dataFolder    = "C:\Users\teosp\OneDrive\Desktop\ergasies\Διπλωματική Εργασία 2024\experiment\audio_dataset";           % φάκελος με .wav
outFolder     = fullfile(dataFolder,"encoded_complexity");
ffmpegPath    = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";
codecs        = ["libmp3lame","aac"];          % MP3 & AAC
bitrates_kbps = [96 128 160];
targetFs      = 44100;
makePlots     = true;

if ~exist(outFolder,"dir"), mkdir(outFolder); end
wavFiles = dir(fullfile(dataFolder,"*.wav"));
assert(~isempty(wavFiles),"Δεν βρέθηκαν .wav αρχεία στο %s",dataFolder);

%% Αποτελέσματα
results = table(strings(0,1), strings(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'File','Codec','Bitrate_kbps','Duration_s', ...
    'EncodeTime_s','DecodeTime_s','RTF','SNR_dB'});

%% Βρόχος
for f = 1:numel(wavFiles)
    inPath = fullfile(wavFiles(f).folder,wavFiles(f).name);
    [x,fs] = audioread(inPath);
    x = mean(x,2);
    if fs~=targetFs, x = resample(x,targetFs,fs); fs=targetFs; end
    x = x ./ max(abs(x)+1e-12);
    durSec = numel(x)/fs;
    origBytes = dir(inPath).bytes;

    for c = 1:numel(codecs)
        codec = codecs(c);
        for bk = bitrates_kbps
            bitrateStr = sprintf("%dk",bk);
            % επέλεξε κατάληξη
            ext = ".mp3"; if codec=="aac", ext = ".m4a"; end
            outPath = fullfile(outFolder, sprintf("%s_%s_%dkbps%s", ...
                         erase(wavFiles(f).name,".wav"), codec, bk, ext));

            % -------- Encode (FFmpeg) με χρονομέτρηση --------
            tic;
            cmd = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %s -acodec %s "%s"', ...
                          ffmpegPath, inPath, bitrateStr, codec, outPath);
            status = system(cmd);
            encTime = toc;
            if status~=0
                warning("Αποτυχία encode: %s @ %s %dkbps", wavFiles(f).name, codec, bk);
                continue;
            end

            % -------- Decode (audioread) με χρονομέτρηση --------
            tic;
            [y,fs_y] = audioread(outPath);
            decTime = toc;
            if fs_y~=fs, y = resample(y,fs,fs_y); end
            y = mean(y,2);

            % Ευθυγράμμιση
            N = min(numel(x),numel(y)); xA = x(1:N); yA = y(1:N);

            % Μετρικές
            SNR_dB = 10*log10(sum(xA.^2)/max(1e-12,sum((xA-yA).^2)));
            RTF    = durSec / max(encTime, 1e-9);   % >1 => γρηγορότερο από real-time

            % Καταγραφή
            results = [results; {string(wavFiles(f).name), string(codec), bk, durSec, ...
                                 encTime, decTime, RTF, SNR_dB}]; %#ok<AGROW>

            fprintf("OK | %-18s | %-9s @ %3dkbps | Enc=%.3fs  Dec=%.3fs  RTF=%.1f  SNR=%.2f dB\n", ...
                wavFiles(f).name, codec, bk, encTime, decTime, RTF, SNR_dB);
        end
    end
end

%% Αποθήκευση
outCSV = fullfile(outFolder,"results_exp3_complexity.csv");
writetable(results,outCSV);
fprintf("\nΑποτελέσματα αποθηκεύτηκαν στο: %s\n", outCSV);

%% Γραφήματα
if makePlots && ~isempty(results)
    % 1) Encode time vs Bitrate (ανά codec)
    figure; hold on; grid on;
    for c = 1:numel(codecs)
        sel = results.Codec==codecs(c);
        plot(results.Bitrate_kbps(sel), results.EncodeTime_s(sel), '-o', 'DisplayName', upper(codecs(c)));
    end
    xlabel('Bitrate (kbps)'); ylabel('Encode time (s)');
    title('Χρόνος κωδικοποίησης vs Bitrate'); legend('Location','best');

    % 2) RTF vs Bitrate (ανά codec)
    figure; hold on; grid on;
    for c = 1:numel(codecs)
        sel = results.Codec==codecs(c);
        plot(results.Bitrate_kbps(sel), results.RTF(sel), '-o', 'DisplayName', upper(codecs(c)));
    end
    xlabel('Bitrate (kbps)'); ylabel('Real-Time Factor (RTF)');
    title('RTF vs Bitrate (RTF>1 ⇒ ταχύτερο από real-time)'); legend('Location','best');

    % 3) Ποιότητα vs Χρόνος (trade-off)
    figure; grid on;
    gscatter(results.EncodeTime_s, results.SNR_dB, results.Codec);
    xlabel('Encode time (s)'); ylabel('SNR (dB)');
    title('Trade-off: Ποιότητα (SNR) vs Χρόνος κωδικοποίησης');
end
