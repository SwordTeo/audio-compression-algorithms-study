%% Πείραμα 4 – Δειγματοληψία & Κβαντοποίηση (Sampling & Bit Depth)
% Θ. Σπάθης – Διπλωματική (MATLAB R2025b)
% Μετρά SNR & CR σε MP3 (FFmpeg) όταν αλλάζουμε fs και bit depth.

clear; clc;

%% Ρυθμίσεις
dataFolder    = "C:\Users\teosp\OneDrive\Desktop\ergasies\Διπλωματική Εργασία 2024\experiment\audio_dataset";                   % φάκελος με .wav
outFolder     = fullfile(dataFolder,"encoded_fs_bits");
ffmpegPath    = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";
codec         = "libmp3lame";                          % MP3
bitrates_kbps = [128];                                  % σταθερό bitrate για δίκαιη σύγκριση
fs_set        = [22050 44100 48000];                    % δοκιμαστικά fs
bits_set      = [16 24];                                % δοκιμαστικά bit depths
baseFs        = 44100;                                  % στόχος ενοποίησης πριν τις συγκρίσεις
makePlots     = true;

if ~exist(outFolder,"dir"), mkdir(outFolder); end
wavFiles = dir(fullfile(dataFolder,"*.wav"));
assert(~isempty(wavFiles),"Δεν βρέθηκαν .wav αρχεία στο %s",dataFolder);

%% Πίνακας αποτελεσμάτων
results = table(strings(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    zeros(0,1), zeros(0,1), ...
    'VariableNames', {'File','fs_Hz','Bits','Bitrate_kbps','CR','SNR_dB'});

%% Βρόχος αρχείων
for f = 1:numel(wavFiles)
    inPath = fullfile(wavFiles(f).folder,wavFiles(f).name);
    [x,fs0] = audioread(inPath);
    x = mean(x,2);                 % mono για απλές συγκρίσεις

    % Κανονικοποίηση (ασφαλής)
    x = x ./ max(1e-12, max(abs(x)));

    for fs = fs_set
        % resample με αντι-αναδιπλωτικό φίλτρο
        if fs ~= fs0
            x_fs = resample(x, fs, fs0);
        else
            x_fs = x;
        end

        for b = bits_set
            % Γράψε προσωρινό WAV με συγκεκριμένο bit depth (PCM quantization)
            tmpWav = fullfile(outFolder, sprintf("tmp_%s_%dkHz_%dbit.wav", ...
                erase(wavFiles(f).name,".wav"), round(fs/1000), b));
            audiowrite(tmpWav, x_fs, fs, 'BitsPerSample', b);

            % Μέγεθος "εισόδου" για CR (εξαρτάται από fs & bits)
            inBytes = dir(tmpWav).bytes;

            % Κωδικοποίηση σε MP3 @ σταθερό bitrate
            for bk = bitrates_kbps
                outMP3 = fullfile(outFolder, ...
                    sprintf("%s_fs%dk_B%d_%dkbps.mp3", erase(wavFiles(f).name,".wav"), round(fs/1000), b, bk));
                cmd = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %dk -acodec %s "%s"', ...
                    ffmpegPath, tmpWav, bk, codec, outMP3);
                status = system(cmd);
                if status ~= 0
                    warning("Αποτυχία FFmpeg για %s", outMP3);
                    continue;
                end

                % Ανάγνωση συμπιεσμένου (decode) για SNR
                [y,fs_y] = audioread(outMP3);
                if fs_y ~= fs, y = resample(y, fs, fs_y); end
                y = mean(y,2);

                % Ευθυγράμμιση μήκους
                N = min(numel(x_fs), numel(y));
                xA = x_fs(1:N);  yA = y(1:N);

                % Μετρικές
                encBytes = dir(outMP3).bytes;
                CR = inBytes / encBytes;
                SNR_dB = 10*log10(sum(xA.^2) / max(1e-12, sum((xA - yA).^2)));

                % Καταγραφή
                results = [results; {string(wavFiles(f).name), fs, b, bk, CR, SNR_dB}]; %#ok<AGROW>
                fprintf("OK | %-18s | fs=%5d Hz, %2d-bit @%3dkbps -> CR=%.2f SNR=%.2f dB\n", ...
                    wavFiles(f).name, fs, b, bk, CR, SNR_dB);
            end

            % Καθάρισε το προσωρινό WAV
            if exist(tmpWav,"file"), delete(tmpWav); end
        end
    end
end

%% Αποθήκευση αποτελεσμάτων
outCSV = fullfile(outFolder,"results_exp4_fs_bits.csv");
writetable(results, outCSV);
fprintf("\nΑποθήκευση: %s\n", outCSV);

%% Γραφήματα
if makePlots && ~isempty(results)
    % 1) SNR vs fs (γραμμές ανά bit depth)
    figure; hold on; grid on;
    for b = bits_set
        sel = results.Bits == b;
        % Μέσος όρος ανά fs (σε περίπτωση πολλών αρχείων)
        fs_vals = unique(results.fs_Hz(sel));
        snr_mean = arrayfun(@(v) mean(results.SNR_dB(sel & results.fs_Hz==v)), fs_vals);
        plot(fs_vals/1000, snr_mean, '-o', 'DisplayName', sprintf('%d-bit', b));
    end
    xlabel('Sampling rate (kHz)'); ylabel('SNR (dB)');
    title('SNR vs Sampling rate (ανά bit depth)'); legend('Location','best');

    % 2) Compression Ratio vs fs (γραμμές ανά bit depth)
    figure; hold on; grid on;
    for b = bits_set
        sel = results.Bits == b;
        fs_vals = unique(results.fs_Hz(sel));
        cr_mean = arrayfun(@(v) mean(results.CR(sel & results.fs_Hz==v)), fs_vals);
        plot(fs_vals/1000, cr_mean, '-o', 'DisplayName', sprintf('%d-bit', b));
    end
    xlabel('Sampling rate (kHz)'); ylabel('Compression Ratio');
    title('Compression Ratio vs Sampling rate (ανά bit depth)'); legend('Location','best');

    % 3) Heatmap SNR (fs × bits)
    figure; 
    fs_vals = fs_set(:);
    B_vals  = bits_set(:);
    M = zeros(numel(fs_vals), numel(B_vals));
    for i=1:numel(fs_vals)
        for j=1:numel(B_vals)
            sel = results.fs_Hz==fs_vals(i) & results.Bits==B_vals(j);
            M(i,j) = mean(results.SNR_dB(sel));
        end
    end
    imagesc(B_vals, fs_vals/1000, M);
    colorbar; xlabel('Bit depth'); ylabel('Sampling rate (kHz)');
    title('SNR heatmap (μέσος όρος)');
    set(gca,'YDir','normal');
end
