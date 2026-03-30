%% Πείραμα 1 – Bitrate Ladder & Διαφάνεια (με FFmpeg)
% Θ. Σπάθης – Διπλωματική (MATLAB R2025b)
% Απαιτεί να λειτουργεί το ffmpeg.exe (δοκιμάστηκε με system("ffmpeg -version"))

clear; clc;

%% Ρυθμίσεις Χρήστη
dataFolder   = "C:\Users\teosp\OneDrive\Desktop\ergasies\Διπλωματική Εργασία 2024\experiment\audio_dataset";          % φάκελος με αρχεία .wav
outFolder    = fullfile(dataFolder,"encoded");
ffmpegPath   = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";  % path του ffmpeg.exe
bitrates_kbps = [64 96 128 160 192];         % bitrates για δοκιμή
codec = "libmp3lame";                        % μπορείς να χρησιμοποιήσεις aac ή libopus αν θέλεις
targetFs = 44100;                            % ρυθμός δειγματοληψίας
makePlots = true;

if ~exist(outFolder,"dir"), mkdir(outFolder); end
wavFiles = dir(fullfile(dataFolder,"*.wav"));
assert(~isempty(wavFiles),"Δεν βρέθηκαν αρχεία .wav στο % s",dataFolder);

%% Πίνακας Αποτελεσμάτων
results = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), ...
    'VariableNames',{'File','Bitrate_kbps','CR','SNR_dB','PESQ','STOI'});

%% Κύριος Βρόχος
for f = 1:numel(wavFiles)
    inPath = fullfile(wavFiles(f).folder,wavFiles(f).name);
    [x,fs] = audioread(inPath);
    x = mean(x,2);
    if fs~=targetFs
        x = resample(x,targetFs,fs);
        fs = targetFs;
    end
    x = x./max(abs(x));
    originalBytes = dir(inPath).bytes;

    for bk = bitrates_kbps
        outFile = sprintf("%s_%dkbps.mp3",erase(wavFiles(f).name,".wav"),bk);
        outPath = fullfile(outFolder,outFile);
        bitrateStr = sprintf("%dk",bk);

        % --- Κωδικοποίηση με ffmpeg ---
        cmd = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %s -acodec %s "%s"', ...
            ffmpegPath, inPath, bitrateStr, codec, outPath);
        status = system(cmd);
        if status~=0
            warning("Αποτυχία στο bitrate %d για %s",bk,wavFiles(f).name);
            continue;
        end

        % --- Ανάγνωση (αποσυμπίεση) ---
        [y,fs_y] = audioread(outPath);
        if fs_y~=fs, y = resample(y,fs,fs_y); end
        y = mean(y,2);
        N = min(numel(x),numel(y));  x=x(1:N);  y=y(1:N);

        % --- Μετρικές ---
        CR = originalBytes / dir(outPath).bytes;
        SNR_dB = 10*log10(sum(x.^2)/max(1e-12,sum((x-y).^2)));
        [pesq_val,stoi_val] = tryPESQ_STOI(x,y,fs);

        results = [results; {string(wavFiles(f).name),bk,CR,SNR_dB,pesq_val,stoi_val}]; %#ok<AGROW>
        fprintf("OK | %s @ %dkbps → CR=%.2f SNR=%.2f dB\n",wavFiles(f).name,bk,CR,SNR_dB);
    end
end

%% Αποθήκευση
outCSV = fullfile(outFolder,"results_exp1_ffmpeg.csv");
writetable(results,outCSV);
fprintf("\nΑποθηκεύτηκαν τα αποτελέσματα στο:\n%s\n",outCSV);

%% Γραφήματα
if makePlots && ~isempty(results)
    gb = groupsummary(results,"Bitrate_kbps","mean",["CR","SNR_dB","PESQ","STOI"]);
    figure; plot(gb.Bitrate_kbps,gb.mean_SNR_dB,'-o','LineWidth',1.5);
    xlabel("Bitrate (kbps)"); ylabel("SNR (dB)");
    title("SNR vs Bitrate (MP3 via FFmpeg)"); grid on;

    figure; plot(gb.Bitrate_kbps,gb.mean_CR,'-o','LineWidth',1.5);
    xlabel("Bitrate (kbps)"); ylabel("Compression Ratio");
    title("Compression Ratio vs Bitrate (MP3 via FFmpeg)"); grid on;
end

%% Helper
function [pesq_val,stoi_val]=tryPESQ_STOI(x,y,fs)
pesq_val=NaN; stoi_val=NaN;
try, pesq_val=pesq(x,y,fs); end
try, stoi_val=stoi(x,y,fs); end
end
