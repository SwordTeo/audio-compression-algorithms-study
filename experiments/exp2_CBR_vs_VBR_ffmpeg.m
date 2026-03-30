%% Πείραμα 2 – Σύγκριση CBR και VBR (MP3 μέσω FFmpeg)
% Θ. Σπάθης – Διπλωματική (MATLAB R2025b)
% Απαιτεί ffmpeg.exe να είναι λειτουργικό (έλεγχος: system("ffmpeg -version"))

clear; clc;

%% Ρυθμίσεις
dataFolder   = "C:\Users\teosp\OneDrive\Desktop\ergasies\Διπλωματική Εργασία 2024\experiment\audio_dataset";     
outFolder    = fullfile(dataFolder,"encoded_CBR_VBR");
ffmpegPath   = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";
codec        = "libmp3lame";      
bitrates_kbps = [96 128 160];     % bitrate δοκιμών
targetFs     = 44100;
makePlots    = true;

if ~exist(outFolder,"dir"), mkdir(outFolder); end
wavFiles = dir(fullfile(dataFolder,"*.wav"));
assert(~isempty(wavFiles),"Δεν βρέθηκαν .wav αρχεία στο %s",dataFolder);

%% Πίνακας αποτελεσμάτων
results = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), 'VariableNames', ...
    {'File','Mode','Bitrate_kbps','CR','SNR_dB','PESQ','STOI'});

%% Βρόχος ανά αρχείο
for f = 1:numel(wavFiles)
    inPath = fullfile(wavFiles(f).folder,wavFiles(f).name);
    [x,fs] = audioread(inPath);
    x = mean(x,2);
    if fs~=targetFs, x = resample(x,targetFs,fs); fs=targetFs; end
    x = x./max(abs(x));
    origBytes = dir(inPath).bytes;

    for bk = bitrates_kbps
        % ----- CBR -----
        outCBR = fullfile(outFolder,sprintf("%s_CBR_%dkbps.mp3",erase(wavFiles(f).name,".wav"),bk));
        cmdCBR = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %dk -acodec %s "%s"', ...
            ffmpegPath, inPath, bk, codec, outCBR);
        system(cmdCBR);

        % ----- VBR -----
        outVBR = fullfile(outFolder,sprintf("%s_VBR_q2_%dkbps.mp3",erase(wavFiles(f).name,".wav"),bk));
        cmdVBR = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -qscale:a 2 -acodec %s "%s"', ...
            ffmpegPath, inPath, codec, outVBR);
        system(cmdVBR);

        % Ανάγνωση και μετρήσεις
        for mode = ["CBR","VBR"]
            if mode=="CBR", fpath=outCBR; else, fpath=outVBR; end
            [y,fs_y]=audioread(fpath);
            if fs_y~=fs, y=resample(y,fs,fs_y); end
            y=mean(y,2);
            N=min(numel(x),numel(y)); xA=x(1:N); yA=y(1:N);

            CR = origBytes / dir(fpath).bytes;
            SNR_dB = 10*log10(sum(xA.^2)/max(1e-12,sum((xA-yA).^2)));
            [pesq_val,stoi_val]=tryPESQ_STOI(xA,yA,fs);

            results = [results; {string(wavFiles(f).name), mode, bk, CR, SNR_dB, pesq_val, stoi_val}]; %#ok<AGROW>
            fprintf("OK: %-20s | %s @ %3dkbps | CR=%.2f SNR=%.2f\n", ...
                wavFiles(f).name, mode, bk, CR, SNR_dB);
        end
    end
end

%% Αποθήκευση
outCSV = fullfile(outFolder,"results_exp2_CBR_VBR.csv");
writetable(results,outCSV);
fprintf("\nΑποτελέσματα αποθηκεύτηκαν στο %s\n",outCSV);

%% Γραφήματα
if makePlots
    figure;
    hold on;
    for mode = ["CBR","VBR"]
        sel = strcmp(results.Mode,mode);
        plot(results.Bitrate_kbps(sel),results.SNR_dB(sel),'-o','DisplayName',mode);
    end
    xlabel('Bitrate (kbps)'); ylabel('SNR (dB)');
    title('SNR για CBR και VBR (MP3 μέσω FFmpeg)'); grid on; legend;

    figure;
    hold on;
    for mode = ["CBR","VBR"]
        sel = strcmp(results.Mode,mode);
        plot(results.Bitrate_kbps(sel),results.CR(sel),'-o','DisplayName',mode);
    end
    xlabel('Bitrate (kbps)'); ylabel('Compression Ratio');
    title('Compression Ratio για CBR και VBR (MP3 μέσω FFmpeg)'); grid on; legend;
end

%% Helper
function [pesq_val,stoi_val]=tryPESQ_STOI(x,y,fs)
pesq_val=NaN; stoi_val=NaN;
try, pesq_val=pesq(x,y,fs); end
try, stoi_val=stoi(x,y,fs); end
end
