%% Πείραμα 6 – Συγκριτική Ανάλυση MP3 vs AAC
% Θ. Σπάθης – Διπλωματική (MATLAB R2025b)
% Συγκρίνει SNR και CR για MP3 (libmp3lame) και AAC (aac) στα ίδια bitrates

clear; clc;

%% Ρυθμίσεις
dataFolder   = "C:\Users\teosp\OneDrive\Desktop\ergasies\Διπλωματική Εργασία 2024\experiment\audio_dataset";      
outFolder    = fullfile(dataFolder,"encoded_mp3_aac");
ffmpegPath   = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";
codecs       = ["libmp3lame","aac"];
bitrates     = [96 128 160];
targetFs     = 44100;

if ~exist(outFolder,"dir"), mkdir(outFolder); end
wavFiles = dir(fullfile(dataFolder,"*.wav"));
assert(~isempty(wavFiles),"Δεν βρέθηκαν .wav αρχεία στο %s",dataFolder);

%% Πίνακας Αποτελεσμάτων
results = table(strings(0,1), strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    'VariableNames', {'File','Codec','Bitrate_kbps','CR','SNR_dB'});

%% Κύριος βρόχος
for f = 1:numel(wavFiles)
    inPath = fullfile(wavFiles(f).folder, wavFiles(f).name);
    [x,fs] = audioread(inPath);
    x = mean(x,2);
    if fs~=targetFs
        x = resample(x,targetFs,fs);
        fs = targetFs;
    end
    x = x ./ max(abs(x));
    origBytes = dir(inPath).bytes;

    for c = 1:numel(codecs)
        codec = codecs(c);
        for bk = bitrates
            bitrateStr = sprintf("%dk",bk);
            ext = ".mp3"; if codec=="aac", ext = ".m4a"; end
            outFile = fullfile(outFolder, sprintf("%s_%s_%dkbps%s", ...
                erase(wavFiles(f).name,".wav"), codec, bk, ext));

            % --- Κωδικοποίηση
            cmd = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %s -acodec %s "%s"', ...
                ffmpegPath, inPath, bitrateStr, codec, outFile);
            status = system(cmd);
            if status~=0
                warning("Σφάλμα στο %s", outFile);
                continue;
            end

            % --- Αποσυμπίεση και υπολογισμός μετρικών
            [y,fs_y] = audioread(outFile);
            if fs_y~=fs, y=resample(y,fs,fs_y); end
            y = mean(y,2);
            N = min(numel(x),numel(y)); xA=x(1:N); yA=y(1:N);

            CR = origBytes / dir(outFile).bytes;
            SNR_dB = 10*log10(sum(xA.^2)/max(1e-12,sum((xA-yA).^2)));

            results = [results; {string(wavFiles(f).name), upper(string(codec)), bk, CR, SNR_dB}]; %#ok<AGROW>
            fprintf("OK | %-18s | %s @ %3dkbps | CR=%.2f | SNR=%.2f dB\n", ...
                wavFiles(f).name, codec, bk, CR, SNR_dB);
        end
    end
end

%% Αποθήκευση
outCSV = fullfile(outFolder,"results_exp6_mp3_aac.csv");
writetable(results,outCSV);
fprintf("\nΑποτελέσματα στο: %s\n", outCSV);

%% Γραφήματα
figure;
hold on; grid on;
for c = ["LIBMP3LAME","AAC"]
    sel = results.Codec==c;
    plot(results.Bitrate_kbps(sel),results.SNR_dB(sel),'-o','DisplayName',c);
end
xlabel('Bitrate (kbps)'); ylabel('SNR (dB)');
title('Σύγκριση MP3 vs AAC – SNR vs Bitrate');
legend('Location','best');

figure;
hold on; grid on;
for c = ["LIBMP3LAME","AAC"]
    sel = results.Codec==c;
    plot(results.Bitrate_kbps(sel),results.CR(sel),'-o','DisplayName',c);
end
xlabel('Bitrate (kbps)'); ylabel('Compression Ratio');
title('Σύγκριση MP3 vs AAC – CR vs Bitrate');
legend('Location','best');
