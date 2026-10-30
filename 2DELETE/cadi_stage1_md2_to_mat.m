function statusReport = cadi_stage1_md2_to_mat(inBaseDir, outBaseDir, sStation, startDT, endDT, opts)
% CADI_STAGE1_MD2_TO_MAT Stage 1 of the CADI pipeline: Scans, unzips (.gz to .md2 
% without deleting), filters by datetime range, and extracts raw ionogram matrices 
% into *_ion.mat files using CADI_data_iono_reader_mtrx.

    if nargin < 6 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'sFileType'), opts.sFileType = 'md2'; end 
    if ~isfield(opts, 'minuteStep'), opts.minuteStep = 5; end 
    if ~isfield(opts, 'OutYN'), opts.OutYN = 0; end 

    tStart = datetime(startDT(1), startDT(2), startDT(3), startDT(4), startDT(5), startDT(6));
    tEnd   = datetime(endDT(1), endDT(2), endDT(3), endDT(4), endDT(5), endDT(6));

    yearVal = startDT(1);
    sYear = sprintf('%04d', yearVal);

    targetOutDir = fullfile(outBaseDir, sStation, sYear);
    if ~isfolder(targetOutDir)
        mkdir(targetOutDir);
    end

    sourceDir = fullfile(inBaseDir, sStation, sYear);
    if ~isfolder(sourceDir)
        error('Source directory does not exist: %s', sourceDir);
    end

    gzFiles  = dir(fullfile(sourceDir, '**', '*.md2.gz'));
    rawFiles = dir(fullfile(sourceDir, '**', '*.md2'));
    allFiles = [gzFiles; rawFiles];

    fprintf('============================================================\n');
    fprintf('   CADI STAGE 1: MD2 UNZIP & RAW DATA EXTRACTION            \n');
    fprintf('============================================================\n');
    fprintf('Station    : %s\n', sStation);
    fprintf('Time Range : %s to %s\n', datestr(tStart), datestr(tEnd));
    fprintf('Source Dir : %s\n', sourceDir);
    fprintf('Output Dir : %s\n', targetOutDir);
    fprintf('Found %d total CADI container files.\n', numel(allFiles));

    monthLetters = 'ABCDEFGHIJKL';
    processedHours = 0;
    processedFilesCount = 0;
    fileListProcessed = {};

    for i = 1:numel(allFiles)
        fname = allFiles(i).name;
        fpath = allFiles(i).folder;

        if length(fname) < 10
            continue;
        end

        try
            yDigit = str2double(fname(1));
            fileYear = 2000 + yDigit;
            
            mChar = upper(fname(2));
            fileMonth = strfind(monthLetters, mChar);
            fileDay = str2double(fname(3:4));
            fileHour = str2double(fname(5:6));

            if isempty(fileMonth) || isnan(fileDay) || isnan(fileHour)
                continue;
            end

            fileDTStart = datetime(fileYear, fileMonth, fileDay, fileHour, 0, 0);
            fileDTEnd   = fileDTStart + hours(1) - seconds(1);

            if fileDTEnd < tStart || fileDTStart > tEnd
                continue;
            end

            fprintf('\nProcessing container file: %s\n', fname);

            fullSourcePath = fullfile(fpath, fname);
            if endsWith(fname, '.gz', 'IgnoreCase', true)
                md2Name = regexprep(fname, '\.gz$', '', 'ignorecase');
                targetMd2Path = fullfile(targetOutDir, md2Name);

                if ~isfile(targetMd2Path)
                    fprintf('  Unzipping %s to %s ...\n', fname, targetOutDir);
                    gunzip(fullSourcePath, targetOutDir);
                else
                    fprintf('  Unzipped .md2 file already exists in target directory.\n');
                end
            else
                targetMd2Path = fullfile(targetOutDir, fname);
                if ~isfile(targetMd2Path)
                    copyfile(fullSourcePath, targetMd2Path);
                end
            end

            possibleMinutes = 0:opts.minuteStep:(60 - opts.minuteStep);
            minuteDTs = fileDTStart + minutes(possibleMinutes);
            validMinutes = possibleMinutes(minuteDTs >= tStart & minuteDTs <= tEnd);

            if isempty(validMinutes)
                fprintf('  No minutes match the requested time range in hour %02d. Skipping reader.\n', fileHour);
                continue;
            end

            parentDataPath = fileparts(fileparts(targetOutDir));
            if ~endsWith(parentDataPath, filesep)
                parentDataPath = [parentDataPath, filesep];
            end

            OutYN = 1; 
            if opts.OutYN==0
                fprintf('  Extracting %d minute ionograms for %04d-%02d-%02d %02d:00 ...\n', ...                   
                numel(validMinutes), fileYear, fileMonth, fileDay, fileHour);
            else
                opts.OutYN = 1;
                fprintf('  Extracting Hourly and %d minute ionograms for %04d-%02d-%02d %02d:00 ...\n', ...                   
                numel(validMinutes), fileYear, fileMonth, fileDay, fileHour);
            end

            CADI_data_iono_reader_mtrx(parentDataPath, sStation, fileYear, fileMonth, fileDay, fileHour, opts.sFileType, opts.OutYN, validMinutes);

            processedHours = processedHours + 1;
            processedFilesCount = processedFilesCount + numel(validMinutes);
            fileListProcessed{end+1} = fname; %#ok<AGROW>

        catch ME
            fprintf('  ERROR processing file %s: %s\n', fname, ME.message);
        end
    end

    statusReport = struct();
    statusReport.station = sStation;
    statusReport.year = yearVal;
    statusReport.processedHours = processedHours;
    statusReport.processedFilesCount = processedFilesCount;
    statusReport.processedFiles = fileListProcessed;

    fprintf('\n============================================================\n');
    fprintf('   STAGE 1 COMPLETED SUCCESSFULLY                           \n');
    fprintf('   Processed Hours : %d                                     \n', processedHours);
    fprintf('   Extracted Files : %d minute datasets                     \n', processedFilesCount);
    fprintf('============================================================\n');
end