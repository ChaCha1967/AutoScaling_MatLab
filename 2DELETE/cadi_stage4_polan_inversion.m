function statusReport = cadi_stage4_polan_inversion(outBaseDir, sStation, startDT, endDT, opts)
% CADI_STAGE4_POLAN_INVERSION Stage 4 of the CADI pipeline: Loads the U-Net 
% extracted virtual height profile ScaleV_unet, runs Titheridge's POLAN real-height 
% inversion, and appends ScaleR_polan and polanRes.

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'start_val'), opts.start_val = 0.0;  end
    if ~isfield(opts, 'amode'),     opts.amode     = 0.0;  end
    if ~isfield(opts, 'valley'),    opts.valley    = 10.0; end
    if ~isfield(opts, 'list_flag'), opts.list_flag = -10;  end 
    if ~isfield(opts, 'min_pts'),   opts.min_pts   = 3;    end
    if ~isfield(opts, 'overwrite'), opts.overwrite = true; end

    defaultSite = CADI_site_mtrx(sStation);

    tStart = datetime(startDT(1), startDT(2), startDT(3), startDT(4), startDT(5), startDT(6));
    tEnd   = datetime(endDT(1), endDT(2), endDT(3), endDT(4), endDT(5), endDT(6));

    yearsToScan  = unique(startDT(1):endDT(1));
    monthLetters = 'ABCDEFGHIJKL';

    candidateFiles = [];
    for yIdx = 1:numel(yearsToScan)
        sYear   = sprintf('%04d', yearsToScan(yIdx));
        yearDir = fullfile(outBaseDir, sStation, sYear);
        if isfolder(yearDir)
            dirFiles = dir(fullfile(yearDir, '*_ion.mat'));
            for k = 1:numel(dirFiles)
                dirFiles(k).yearVal = yearsToScan(yIdx);
            end
            candidateFiles = [candidateFiles; dirFiles]; %#ok<AGROW>
        end
    end

    fprintf('============================================================\n');
    fprintf('   CADI STAGE 4: POLAN REAL-HEIGHT PROFILE INVERSION        \n');
    fprintf('============================================================\n');
    fprintf('Station        : %s (Default Gyro: %.3f MHz, Dip: %.2f deg)\n', ...
        sStation, defaultSite.gyrofreq, defaultSite.magdip);
    fprintf('Time Range     : %s to %s\n', datestr(tStart), datestr(tEnd));
    fprintf('POLAN Settings : Start=%.1f, Amode=%.1f, Valley=%.1f, MinPts=%d\n', ...
        opts.start_val, opts.amode, opts.valley, opts.min_pts);

    validFileList = {};
    skippedCount  = 0;
    missingStage3 = 0;

    for i = 1:numel(candidateFiles)
        fname    = candidateFiles(i).name;
        baseName = erase(fname, '_ion.mat');

        if length(baseName) ~= 10
            continue;
        end

        mChar     = upper(baseName(4));
        fileMonth = strfind(monthLetters, mChar);
        fileDay   = str2double(baseName(5:6));
        fileHour  = str2double(baseName(7:8));
        fileMin   = str2double(baseName(9:10));

        if isempty(fileMonth) || isnan(fileDay) || isnan(fileHour) || isnan(fileMin)
            continue;
        end

        fileDT = datetime(candidateFiles(i).yearVal, fileMonth, fileDay, fileHour, fileMin, 0);
        if fileDT >= tStart && fileDT <= tEnd
            fullPath = fullfile(candidateFiles(i).folder, fname);
            fileVars = whos('-file', fullPath);
            varNames = {fileVars.name};

            if ~ismember('ScaleV_unet', varNames)
                missingStage3 = missingStage3 + 1;
                continue;
            end

            if ~opts.overwrite && ismember('ScaleR_polan', varNames) && ismember('polanRes', varNames)
                skippedCount = skippedCount + 1;
                continue;
            end

            validFileList{end+1} = fullPath; %#ok<AGROW>
        end
    end

    numValid = numel(validFileList);
    fprintf('Selected %d minute sessions for POLAN inversion (Skipped: %d, Missing Stage 3: %d).\n', ...
        numValid, skippedCount, missingStage3);

    if numValid == 0
        statusReport = struct('station', sStation, 'totalSelected', 0, ...
            'processedCount', 0, 'successCount', 0, 'emptyOrShortCount', 0, ...
            'skippedCount', skippedCount, 'errorCount', missingStage3, ...
            'processedFiles', {{}}, 'elapsedTimeSec', 0);
        return;
    end

    stageTimer        = tic;
    processedCount    = 0;
    successCount      = 0;
    emptyOrShortCount = 0;
    errorCount        = missingStage3;
    processedFiles    = {};

    for i = 1:numValid
        fPath = validFileList{i};
        [~, fnameOnly, ext] = fileparts(fPath);

        try
            d = load(fPath, 'ScaleV_unet', 'siteStruct');
            ScaleV = d.ScaleV_unet;

            if isfield(opts, 'fb') && ~isempty(opts.fb)
                fb_val = double(opts.fb);
            elseif isfield(d, 'siteStruct') && isfield(d.siteStruct, 'gyrofreq')
                fb_val = double(d.siteStruct.gyrofreq);
            else
                fb_val = double(defaultSite.gyrofreq);
            end

            if isfield(opts, 'dip') && ~isempty(opts.dip)
                dip_val = double(opts.dip);
            elseif isfield(d, 'siteStruct') && isfield(d.siteStruct, 'magdip')
                dip_val = double(d.siteStruct.magdip);
            else
                dip_val = double(defaultSite.magdip);
            end

            polanOpts = struct('fb', fb_val, 'dip', dip_val, ...
                               'start_val', opts.start_val, 'amode', opts.amode, ...
                               'valley', opts.valley);

            if isempty(ScaleV) || size(ScaleV, 1) < opts.min_pts
                ScaleR_polan = zeros(0, 2);
                polanRes     = create_empty_polan_struct('INSUFFICIENT_VIRTUAL_PTS');
                emptyOrShortCount = emptyOrShortCount + 1;
            else
                f_in = double(ScaleV(:, 1));
                h_in = double(ScaleV(:, 2));
                validMask = ~isnan(f_in) & ~isnan(h_in) & (f_in > 0) & (h_in > 0);
                f_in = f_in(validMask);
                h_in = h_in(validMask);

                [f_in, uniqIdx] = unique(f_in, 'stable');
                h_in = h_in(uniqIdx);

                if numel(f_in) < opts.min_pts
                    ScaleR_polan = zeros(0, 2);
                    polanRes     = create_empty_polan_struct('INSUFFICIENT_UNIQUE_FREQS');
                    emptyOrShortCount = emptyOrShortCount + 1;
                else
                    [polanRes, ~, ~, ~, ~] = polan_fortran_exact( ...
                        f_in, h_in, fb_val, dip_val, ...
                        opts.start_val, opts.amode, opts.valley, opts.list_flag);

                    if isfield(polanRes, 'foF2') && polanRes.foF2 > 0 && isfield(polanRes, 'TEC')
                        tcont_val = polanRes.TEC / 0.124;
                        polanRes.SlabT = tcont_val / (polanRes.foF2 ^ 2);
                    else
                        polanRes.SlabT = NaN;
                    end

                    if ~isempty(polanRes.f_real_all) && ~isempty(polanRes.h_real_all)
                        ScaleR_polan = [polanRes.f_real_all(:), polanRes.h_real_all(:)];
                        if strcmp(polanRes.status, 'OK')
                            successCount = successCount + 1;
                        end
                    else
                        ScaleR_polan = zeros(0, 2);
                    end
                end
            end

            save(fPath, 'ScaleR_polan', 'polanRes', 'polanOpts', '-append');

            processedCount = processedCount + 1;
            processedFiles{end+1} = [fnameOnly, ext]; %#ok<AGROW>

            if mod(processedCount, 50) == 0 || i == numValid
                fprintf('  Processed %d / %d sessions (Valid inversions: %d | %.1f s)\n', ...
                    processedCount, numValid, successCount, toc(stageTimer));
            end

        catch ME
            fprintf('  ERROR running POLAN on %s%s: %s\n', fnameOnly, ext, ME.message);
            errorCount = errorCount + 1;
        end
    end

    statusReport = struct();
    statusReport.station           = sStation;
    statusReport.totalSelected     = numValid;
    statusReport.processedCount    = processedCount;
    statusReport.successCount      = successCount;
    statusReport.emptyOrShortCount = emptyOrShortCount;
    statusReport.skippedCount      = skippedCount;
    statusReport.errorCount        = errorCount;
    statusReport.processedFiles    = processedFiles;
    statusReport.elapsedTimeSec    = toc(stageTimer);

    fprintf('\n============================================================\n');
    fprintf('   STAGE 4 COMPLETED SUCCESSFULLY                           \n');
    fprintf('   Processed Files  : %d / %d                               \n', processedCount, numValid);
    fprintf('   Successful POLAN : %d (Empty/Short: %d, Errors: %d)      \n', ...
        successCount, emptyOrShortCount, errorCount);
    fprintf('   Elapsed Time     : %.2f seconds                          \n', statusReport.elapsedTimeSec);
    fprintf('============================================================\n');
end

function out = create_empty_polan_struct(statusStr)
    out = struct();
    out.N_out      = 0;
    out.QQ         = zeros(50, 1);
    out.f_virt     = [];
    out.h_virt     = [];
    out.f_real     = [];
    out.h_real     = [];
    out.foF2       = NaN;
    out.hmF2       = NaN;
    out.f_topside  = [];
    out.h_topside  = [];
    out.dev_f      = NaN;
    out.dev_h      = NaN;
    out.TEC        = NaN;
    out.H_scale    = NaN;
    out.SlabT      = NaN;
    out.status     = statusStr;
    out.f_real_all = [];
    out.h_real_all = [];
    out.Ne_cm3     = [];
end