function AudioCompressionGUI
    % Θ. Σπάθης – Διπλωματική 2025
    % Μικρό GUI για συμπίεση ήχου και ανάλυση SNR & CR (MP3/AAC)

    % === Βασικό Παράθυρο ===
    fig = uifigure('Name','Audio Compression Analyzer','Position',[500 300 480 360]);

    % === Τίτλος ===
    uilabel(fig,'Text','Audio Compression Analyzer','FontSize',18,...
        'FontWeight','bold','Position',[100 310 300 30]);

    % === Επιλογή αρχείου ===
    uilabel(fig,'Text','1. Επιλογή αρχείου WAV:','Position',[40 260 180 25],'FontWeight','bold');
    btnFile = uibutton(fig,'Text','Browse...','Position',[250 260 100 25],...
        'ButtonPushedFcn',@(btn,event)selectFile(btn,fig));

    % === Επιλογή codec ===
    uilabel(fig,'Text','2. Codec:','Position',[40 210 120 25],'FontWeight','bold');
    codecDrop = uidropdown(fig,'Items',{'MP3 (libmp3lame)','AAC (aac)'},...
        'Position',[150 210 200 25]);

    % === Επιλογή bitrate ===
    uilabel(fig,'Text','3. Bitrate (kbps):','Position',[40 170 150 25],'FontWeight','bold');
    bitrateDrop = uidropdown(fig,'Items',{'96','128','160','192'},...
        'Position',[200 170 100 25],'Value','128');

    % === Κουμπί Ανάλυσης ===
    btnAnalyze = uibutton(fig,'Text','Ανάλυση','FontWeight','bold',...
        'Position',[180 120 100 30],...
        'ButtonPushedFcn',@(btn,event)analyzeAudio(btn,fig,codecDrop,bitrateDrop));

    % === Πεδίο αποτελεσμάτων ===
    uilabel(fig,'Text','Αποτελέσματα:','Position',[40 80 120 25],'FontWeight','bold');
    txtResults = uitextarea(fig,'Position',[40 30 400 50],'Editable','off','FontName','Consolas');
    
    % Αποθήκευση handles για πρόσβαση
    fig.UserData.txtResults = txtResults;
end


function selectFile(btn,fig)
    [file,path] = uigetfile({'*.wav','Αρχεία Ήχου (*.wav)'});
    if isequal(file,0)
        uialert(fig,'Δεν επιλέχθηκε αρχείο.','Προσοχή');
        return;
    end
    fullpath = fullfile(path,file);
    fig.UserData.inputFile = fullpath;
    uialert(fig,['Επιλέχθηκε: ' file],'Επιβεβαίωση');
end


function analyzeAudio(~,fig,codecDrop,bitrateDrop)
    % Έλεγχος αν έχει δοθεί αρχείο
    if ~isfield(fig.UserData,'inputFile')
        uialert(fig,'Παρακαλώ επιλέξτε αρχείο πρώτα.','Προσοχή');
        return;
    end

    ffmpegPath = "C:\Users\teosp\OneDrive\Desktop\ffmpeg\bin\ffmpeg.exe";
    inPath = fig.UserData.inputFile;
    [x,fs] = audioread(inPath);
    x = mean(x,2);
    x = x ./ max(abs(x)+1e-12);
    origBytes = dir(inPath).bytes;

    % Επιλογές
    codec = codecDrop.Value;
    bitrate = str2double(bitrateDrop.Value);
    codecFlag = "libmp3lame"; ext=".mp3";
    if contains(codec,"AAC"), codecFlag="aac"; ext=".m4a"; end

    % Προσωρινός φάκελος εξόδου
    [~,name] = fileparts(inPath);
    outPath = fullfile(tempdir, sprintf("%s_%s_%dkbps%s",name,codecFlag,bitrate,ext));

    % Εκτέλεση FFmpeg
    cmd = sprintf('"%s" -y -hide_banner -loglevel error -i "%s" -b:a %dk -acodec %s "%s"', ...
                  ffmpegPath, inPath, bitrate, codecFlag, outPath);
    status = system(cmd);

    if status ~= 0
        uialert(fig,'Σφάλμα κατά τη συμπίεση.','Σφάλμα');
        return;
    end

    % Ανάλυση
    [y,fs_y] = audioread(outPath);
    if fs_y~=fs, y = resample(y,fs,fs_y); end
    y = mean(y,2);
    N = min(numel(x),numel(y)); xA=x(1:N); yA=y(1:N);

    SNR_dB = 10*log10(sum(xA.^2)/sum((xA-yA).^2));
    CR = origBytes / dir(outPath).bytes;

    % Εμφάνιση
    txt = sprintf("Codec: %s\nBitrate: %d kbps\nSNR: %.2f dB\nCR: %.2f×", ...
        upper(codecFlag), bitrate, SNR_dB, CR);
    fig.UserData.txtResults.Value = txt;

    % Προαιρετικά: γράφημα (SNR Bar)
    figure('Name','Ανάλυση Ποιότητας');
    bar([SNR_dB CR]); set(gca,'XTickLabel',{'SNR (dB)','CR'});
    title('Ανάλυση Ποιότητας & Συμπίεσης');
    grid on;
end
