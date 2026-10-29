function statusReport = cadi_stage2_filter_and_tensors(outBaseDir, sStation, startDT, endDT, opts)
% CADI_STAGE2_FILTER_AND_TENSORS Stage 2 of the CADI pipeline: Scans minute 
% *_ion.mat files within the specified datetime range, applies multi-antenna 
% interference filtering, constructs the 13-layer ion_dat matrix, generates 
% standardized U-Net input tensors (192x96x3 and 192x96x6) with padded 
% frequency/height grids, and appends them to the *_ion.mat files.
%
% Inputs:
%   outBaseDir : Base directory where *_ion.mat files are stored
%   sStation   : 2-character station code (e.g., 'RB', 'CA', 'HA', 'EU', 'PO')
%   startDT    : Start datetime vector [YYYY, MM, DD, hh, mm, ss]
%   endDT      : End datetime vector [YYYY, MM, DD, hh, mm, ss]
%   opts       : Structure with optional filtering and processing parameters:
%                - spike_thresh_dB   (default: 2)
%                - min_extent        (default: 35)
%                - min_count         (default: 10)
%                - dBthr             (default: 3)
%                - required_antennas (default: 3)
%                - overwrite         (default: true)
%
% Output:
%   statusReport : Structure containing execution statistics and processed file list

    if nargin < 6 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'spike_thresh_dB'),   opts.spike_thresh_dB = 2;    end
    if ~isfield(opts, 'min_extent'),        opts.min_extent = 35;        end
    if ~isfield(opts, 'min_count'),         opts.min_count = 10;         end
    if ~isfield(opts, 'dBthr'),             opts.dBthr = 3;              end
    if ~isfield(opts, 'required_antennas'), opts.required_antennas = 3;  end
    if ~isfield(opts, 'overwrite'),         opts.overwrite = true;       end

    tStart = datetime(startDT(1), startDT(2), startDT(3), startDT(4), startDT(5), startDT(6));
    tEnd   = datetime(endDT(1), endDT(2), endDT(3), endDT(4), endDT(5), endDT(6));

    yearsToScan = unique(startDT(1):endDT(1));
    monthLetters = 'ABCDEFGHIJKL';

    % Collect candidate *_ion.mat files across all years in the range
    candidateFiles = [];
    for yIdx = 1:numel(yearsToScan)
        sYear = sprintf('%04d', yearsToScan(yIdx));
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
    fprintf('   CADI STAGE 2: INTERFERENCE FILTERING & TENSOR GENERATION \n');
    fprintf('============================================================\n');
    fprintf('Station          : %s\n', sStation);
    fprintf('Time Range       : %s to %s\n', datestr(tStart), datestr(tEnd));
    fprintf('Output Base Dir  : %s\n', outBaseDir);
    fprintf('Filter Params    : spike=%d dB, extent=%d px, count=%d, thr=%d dB, ants=%d/4\n', ...
        opts.spike_thresh_dB, opts.min_extent, opts.min_count, opts.dBthr, opts.required_antennas);
    fprintf('Found %d total *_ion.mat files in station directory.\n', numel(candidateFiles));

    % Filter files by 10-character base name (minute files only) and datetime range
    validFileList = {};
    for i = 1:numel(candidateFiles)
        fname = candidateFiles(i).name;
        baseName = erase(fname, '_ion.mat');

        % Skip hourly summary files (baseName length == 8, e.g., 'RB9F0820')
        % Only process individual minute sessions (baseName length == 10, e.g., 'RB9F082005')
        if length(baseName) ~= 10
            continue;
        end

        mChar = upper(baseName(4));
        fileMonth = strfind(monthLetters, mChar);
        fileDay   = str2double(baseName(5:6));
        fileHour  = str2double(baseName(7:8));
        fileMin   = str2double(baseName(9:10));

        if isempty(fileMonth) || isnan(fileDay) || isnan(fileHour) || isnan(fileMin)
            continue;
        end

        fileDT = datetime(candidateFiles(i).yearVal, fileMonth, fileDay, fileHour, fileMin, 0);
        if fileDT >= tStart && fileDT <= tEnd
            validFileList{end+1} = fullfile(candidateFiles(i).folder, fname); %#ok<AGROW>
        end
    end

    numValid = numel(validFileList);
    fprintf('Selected %d minute sessions matching the requested time range.\n', numValid);

    % Station configuration structure
    siteStruct = CADI_site_mtrx(sStation);

    processedCount = 0;
    skippedCount   = 0;
    errorCount     = 0;
    processedFiles = {};
    stageTimer     = tic;

    for i = 1:numValid
        currentFullPath = validFileList{i};
        [~, fnameOnly, ext] = fileparts(currentFullPath);

        try
            % Check if already processed when overwrite is disabled
            if ~opts.overwrite
                fileVars = whos('-file', currentFullPath);
                varNames = {fileVars.name};
                if ismember('ion_dat', varNames) && ismember('X_tensor_6ch', varNames)
                    skippedCount = skippedCount + 1;
                    continue;
                end
            end

            % Load raw variables extracted in Stage 1
            raw = load(currentFullPath, 'ionoIQ', 'headerStruct', 'DT');
            if ~isfield(raw, 'ionoIQ') || ~isfield(raw, 'headerStruct')
                fprintf('  Warning: Missing ionoIQ or headerStruct in %s%s. Skipping.\n', fnameOnly, ext);
                errorCount = errorCount + 1;
                continue;
            end

            ionoIQ       = raw.ionoIQ;
            headerStruct = raw.headerStruct;

            % Extract frequency, height, and antenna polarity mapping
            F        = double(headerStruct.datablock.FreqS);
            h        = double(headerStruct.datablock.heights);
            antOrder = headerStruct.datablock.antOrder;
            antPol   = siteStruct.polarity;
            Ch2Pol   = antPol(antOrder + 1);

            % Calculate raw ionogram matrices in dB
            ion1 = squeeze(20 * log10(abs(ionoIQ(1, :, :))));
            ion2 = squeeze(20 * log10(abs(ionoIQ(2, :, :))));
            ion3 = squeeze(20 * log10(abs(ionoIQ(3, :, :))));
            ion4 = squeeze(20 * log10(abs(ionoIQ(4, :, :))));
            iona = squeeze(20 * log10(mean(abs(ionoIQ(:, :, :)), 1)));

            % Calculate phase angles in radians taking into account individual antenna polarity
            Ph1 = squeeze(angle(ionoIQ(1, :, :))) * Ch2Pol(1);
            Ph2 = squeeze(angle(ionoIQ(2, :, :))) * Ch2Pol(2);
            Ph3 = squeeze(angle(ionoIQ(3, :, :))) * Ch2Pol(3);
            Ph4 = squeeze(angle(ionoIQ(4, :, :))) * Ch2Pol(4);

            % Apply vertical interference removal filter
            ion1_clean = remove_cadi_interference_v2(ion1, opts.spike_thresh_dB, opts.min_extent, opts.min_count, opts.dBthr);
            ion2_clean = remove_cadi_interference_v2(ion2, opts.spike_thresh_dB, opts.min_extent, opts.min_count, opts.dBthr);
            ion3_clean = remove_cadi_interference_v2(ion3, opts.spike_thresh_dB, opts.min_extent, opts.min_count, opts.dBthr);
            ion4_clean = remove_cadi_interference_v2(ion4, opts.spike_thresh_dB, opts.min_extent, opts.min_count, opts.dBthr);
            iona_clean = remove_cadi_interference_v2(iona, opts.spike_thresh_dB, opts.min_extent, opts.min_count, opts.dBthr);

            % Removal of weak signals below dBthr in original matrices
            if opts.dBthr > 0
                ion1(ion1 < opts.dBthr) = NaN;
                ion2(ion2 < opts.dBthr) = NaN;
                ion3(ion3 < opts.dBthr) = NaN;
                ion4(ion4 < opts.dBthr) = NaN;
                iona(iona < opts.dBthr) = NaN;
            end

            % Multi-antenna coincidence voting (M out of 4 antennas)
            votes = ~isnan(ion1_clean) + ~isnan(ion2_clean) + ~isnan(ion3_clean) + ~isnan(ion4_clean);
            mask  = double(votes >= opts.required_antennas);
            mask(mask == 0) = NaN;

            % Apply multi-antenna mask to cleaned amplitude channels
            ion1_clean = ion1_clean .* mask;
            ion2_clean = ion2_clean .* mask;
            ion3_clean = ion3_clean .* mask;
            ion4_clean = ion4_clean .* mask;
            iona_clean = iona_clean .* mask; %#ok<NASGU>

            % Calculate original phase differences
            dPh12 = wrapToPi(Ph2 - Ph1);
            dPh23 = wrapToPi(Ph3 - Ph2);
            dPh34 = wrapToPi(Ph4 - Ph3);
            dPh41 = wrapToPi(Ph1 - Ph4);
            dPh13 = wrapToPi(Ph3 - Ph1);
            dPh24 = wrapToPi(Ph4 - Ph2);

            % Calculate filtered phases and phase differences
            Ph1f = Ph1 .* mask;
            Ph2f = Ph2 .* mask;
            Ph3f = Ph3 .* mask;
            Ph4f = Ph4 .* mask;

            dPh23f = wrapToPi(Ph3f - Ph2f);
            dPh41f = wrapToPi(Ph1f - Ph4f);

            % Replace exact zeros with NaN in original phase differences for white background
            dPh12(dPh12 == 0) = NaN; %#ok<NASGU>
            dPh23(dPh23 == 0) = NaN;
            dPh34(dPh34 == 0) = NaN; %#ok<NASGU>
            dPh41(dPh41 == 0) = NaN;
            dPh13(dPh13 == 0) = NaN; %#ok<NASGU>
            dPh24(dPh24 == 0) = NaN; %#ok<NASGU>

            % Assemble the 13-layer ion_dat matrix
            [H_orig, W_orig] = size(ion1);
            ion_dat = zeros(13, H_orig, W_orig);
            ion_dat(1, :, :)  = ion1;
            ion_dat(2, :, :)  = ion2;
            ion_dat(3, :, :)  = ion3;
            ion_dat(4, :, :)  = ion4;
            ion_dat(5, :, :)  = ion1_clean;
            ion_dat(6, :, :)  = ion2_clean;
            ion_dat(7, :, :)  = ion3_clean;
            ion_dat(8, :, :)  = ion4_clean;
            ion_dat(9, :, :)  = dPh23;
            ion_dat(10, :, :) = dPh41;
            ion_dat(11, :, :) = dPh23f;
            ion_dat(12, :, :) = dPh41f;
            ion_dat(13, :, :) = mask;

            % Build standardized U-Net tensors (192x96x3 and 192x96x6) and padded grids
            f_grid_orig = F(:)' / 1e6; % [1 x W_orig] in MHz
            h_grid_orig = h(:);        % [H_orig x 1] in km

            [X_tensor_filt, f_grid, h_grid] = build_cadi_3ch_tensor(ion_dat, f_grid_orig, h_grid_orig, true);
            [X_tensor_orig, ~, ~]           = build_cadi_3ch_tensor(ion_dat, f_grid_orig, h_grid_orig, false);
            X_tensor_6ch                    = cat(3, X_tensor_filt, X_tensor_orig);

            % Append all computed matrices and tensors back to the *_ion.mat file
            save(currentFullPath, 'ion_dat', 'siteStruct', ...
                 'X_tensor_filt', 'X_tensor_orig', 'X_tensor_6ch', ...
                 'f_grid', 'h_grid', 'H_orig', 'W_orig', '-append');

            processedCount = processedCount + 1;
            processedFiles{end+1} = [fnameOnly, ext]; %#ok<AGROW>

            if mod(processedCount, 50) == 0 || i == numValid
                fprintf('  Processed %d / %d sessions (%.1f s)\n', processedCount, numValid, toc(stageTimer));
            end

        catch ME
            fprintf('  ERROR processing %s%s: %s\n', fnameOnly, ext, ME.message);
            errorCount = errorCount + 1;
        end
    end

    statusReport = struct();
    statusReport.station        = sStation;
    statusReport.totalSelected  = numValid;
    statusReport.processedCount = processedCount;
    statusReport.skippedCount   = skippedCount;
    statusReport.errorCount     = errorCount;
    statusReport.processedFiles = processedFiles;
    statusReport.elapsedTimeSec = toc(stageTimer);

    fprintf('\n============================================================\n');
    fprintf('   STAGE 2 COMPLETED SUCCESSFULLY                           \n');
    fprintf('   Processed Files : %d / %d (Skipped: %d, Errors: %d)      \n', ...
        processedCount, numValid, skippedCount, errorCount);
    fprintf('   Elapsed Time    : %.2f seconds                           \n', statusReport.elapsedTimeSec);
    fprintf('============================================================\n');
end

% =========================================================================
% HELPER: BUILD STANDARDIZED 3-CHANNEL TENSOR (192 x 96 x 3)
% =========================================================================
function [X_tensor, f_grid_padded, h_grid_padded] = build_cadi_3ch_tensor(ion_dat, f_grid_orig, h_grid_orig, use_filtered)
% BUILD_CADI_3CH_TENSOR Extracts amplitude and O/X polarization channels 
% from ion_dat and pads them to 192x96x3 following process_cadi_pair logic.

    H_pad = 192;
    W_pad = 96;
    X_tensor = zeros(H_pad, W_pad, 3, 'single');

    [~, H_orig, W_orig] = size(ion_dat);
    f_grid_padded = zeros(1, W_pad);
    h_grid_padded = zeros(H_pad, 1);

    % 1. Extend height grid from H_orig to H_pad (192) with 3.0 km step
    h_step = 3.0;
    if H_orig < H_pad
        h_grid_padded(1:H_orig) = h_grid_orig;
        for k = (H_orig + 1):H_pad
            h_grid_padded(k) = h_grid_padded(k - 1) + h_step;
        end
    else
        h_grid_padded = h_grid_orig(1:H_pad);
    end

    % 2. Extend frequency grid from W_orig to W_pad (96) using log-step extrapolation
    if W_orig < W_pad
        f_grid_padded(1:W_orig) = f_grid_orig;
        log_diffs = diff(log(f_grid_orig(end-5:end)));
        avg_log_step = mean(log_diffs);
        for k = (W_orig + 1):W_pad
            f_grid_padded(k) = f_grid_padded(k - 1) * exp(avg_log_step);
        end
    else
        f_grid_padded = f_grid_orig(1:W_pad);
    end

    % 3. Select slices based on filtered vs. original flag
    if logical(use_filtered)
        amp_slices = 5:8;
        ph_ne_idx  = 11;
        ph_sw_idx  = 12;
    else
        amp_slices = 1:4;
        ph_ne_idx  = 9;
        ph_sw_idx  = 10;
    end

    % 4. Channel 1: Normalized mean amplitude in dB (suppressing ground clutter < 85 km)
    M_4ch = ion_dat(amp_slices, :, :);
    M_mean = squeeze(mean(M_4ch, 1, 'omitnan'));
    M_mean(isnan(M_mean)) = 0;
    M_mean(h_grid_orig < 85, :) = 0;

    max_dB = 50.0;
    Ch1_raw = min(max(M_mean, 0), max_dB) / max_dB;

    % 5. Channels 2 & 3: O-mode and X-mode weighted polarization channels
    dPh23 = squeeze(ion_dat(ph_ne_idx, :, :));
    dPh41 = squeeze(ion_dat(ph_sw_idx, :, :));

    X_weight_23 = max(0, -sin(dPh23)); X_weight_23(isnan(X_weight_23)) = 0;
    X_weight_41 = max(0, -sin(dPh41)); X_weight_41(isnan(X_weight_41)) = 0;
    O_weight_23 = max(0, +sin(dPh23)); O_weight_23(isnan(O_weight_23)) = 0;
    O_weight_41 = max(0, +sin(dPh41)); O_weight_41(isnan(O_weight_41)) = 0;

    Ch2_raw = Ch1_raw .* (0.5 * (O_weight_23 + O_weight_41));
    Ch3_raw = Ch1_raw .* (0.5 * (X_weight_23 + X_weight_41));

    % 6. Assemble into padded 192 x 96 x 3 single-precision tensor
    copy_H = min(H_orig, H_pad);
    copy_W = min(W_orig, W_pad);

    X_tensor(1:copy_H, 1:copy_W, 1) = single(Ch1_raw(1:copy_H, 1:copy_W));
    X_tensor(1:copy_H, 1:copy_W, 2) = single(Ch2_raw(1:copy_H, 1:copy_W));
    X_tensor(1:copy_H, 1:copy_W, 3) = single(Ch3_raw(1:copy_H, 1:copy_W));
end