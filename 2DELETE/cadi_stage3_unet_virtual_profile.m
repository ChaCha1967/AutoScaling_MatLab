function statusReport = cadi_stage3_unet_virtual_profile(outBaseDir, sStation, startDT, endDT, opts)
% CADI_STAGE3_UNET_VIRTUAL_PROFILE Stage 3 of the CADI pipeline: Loads the 
% trained U-Net model, runs batched inference on *_ion.mat files, extracts 
% virtual height profile ScaleV_unet and foF2_unet, and appends results.

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'model_path') || isempty(opts.model_path)
        opts.model_path = 'N:/cadi_out_test/cadi_unet_6ch_combined.mat';
    end
    if ~isfield(opts, 'threshold'),     opts.threshold = 0.50;       end
    if ~isfield(opts, 'min_blob_size'), opts.min_blob_size = 15;     end
    if ~isfield(opts, 'edge_choice'),   opts.edge_choice = 'center'; end
    if ~isfield(opts, 'batchSize'),     opts.batchSize = 64;         end
    if ~isfield(opts, 'overwrite'),     opts.overwrite = true;       end

    if ~isfile(opts.model_path)
        error('Trained U-Net model file not found: %s', opts.model_path);
    end

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
    fprintf('   CADI STAGE 3: U-NET INFERENCE & VIRTUAL PROFILE EXTRACTION\n');
    fprintf('============================================================\n');
    fprintf('Station        : %s\n', sStation);
    fprintf('Time Range     : %s to %s\n', datestr(tStart), datestr(tEnd));
    fprintf('Model Path     : %s\n', opts.model_path);
    fprintf('Extraction Mode: [%s] | Threshold: %.2f (Min blob: %d px)\n', ...
        opts.edge_choice, opts.threshold, opts.min_blob_size);

    validFileList = {};
    skippedCount  = 0;
    missingStage2 = 0;

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

            if ~ismember('X_tensor_6ch', varNames) && ~ismember('X_tensor_filt', varNames)
                missingStage2 = missingStage2 + 1;
                continue;
            end

            if ~opts.overwrite && ismember('ScaleV_unet', varNames) && ismember('mask_pred', varNames)
                skippedCount = skippedCount + 1;
                continue;
            end

            validFileList{end+1} = fullPath; %#ok<AGROW>
        end
    end

    numValid = numel(validFileList);
    fprintf('Selected %d minute sessions for U-Net inference (Skipped: %d, Missing Stage 2: %d).\n', ...
        numValid, skippedCount, missingStage2);

    if numValid == 0
        statusReport = struct('station', sStation, 'totalSelected', 0, ...
            'processedCount', 0, 'detectedCount', 0, 'skippedCount', skippedCount, ...
            'errorCount', missingStage2, 'processedFiles', {{}}, 'elapsedTimeSec', 0);
        return;
    end

    stageTimer = tic;
    fprintf('Loading U-Net model into memory...\n');
    modelData  = load(opts.model_path);
    trainedNet = modelData.trainedNet;

    strategy = '6ch_combined';
    if isfield(modelData, 'trainInfo') && isfield(modelData.trainInfo, 'strategy')
        strategy = modelData.trainInfo.strategy;
    end
    is_6ch = contains(lower(strategy), '6ch');
    inChannels = 3;
    if is_6ch, inChannels = 6; end

    useGPU = canUseGPU();
    if useGPU
        fprintf('GPU acceleration enabled for U-Net inference.\n');
    else
        fprintf('Running U-Net inference on CPU.\n');
    end

    default_f_grid = logspace(log10(1.5), log10(18.0), 96);
    default_h_grid = (0:3:(191*3))';

    batchSize      = opts.batchSize;
    numBatches     = ceil(numValid / batchSize);
    processedCount = 0;
    detectedCount  = 0;
    errorCount     = missingStage2;
    processedFiles = {};

    unetOpts = struct('model_path', opts.model_path, 'strategy', strategy, ...
                      'threshold', opts.threshold, 'min_blob_size', opts.min_blob_size, ...
                      'edge_choice', opts.edge_choice);

    for b = 1:numBatches
        idxStart = (b - 1) * batchSize + 1;
        idxEnd   = min(b * batchSize, numValid);
        curBatchSize = idxEnd - idxStart + 1;

        X_batch    = zeros(192, 96, inChannels, curBatchSize, 'single');
        f_grids    = cell(curBatchSize, 1);
        h_grids    = cell(curBatchSize, 1);
        batchValid = true(curBatchSize, 1);

        for k = 1:curBatchSize
            fileIdx = idxStart + k - 1;
            fPath   = validFileList{fileIdx};
            try
                if is_6ch
                    d = load(fPath, 'X_tensor_6ch', 'X_tensor_filt', 'X_tensor_orig', 'f_grid', 'h_grid');
                    if isfield(d, 'X_tensor_6ch')
                        X_batch(:, :, :, k) = single(d.X_tensor_6ch);
                    else
                        X_batch(:, :, :, k) = cat(3, single(d.X_tensor_filt), single(d.X_tensor_orig));
                    end
                else
                    if contains(lower(strategy), 'filt')
                        d = load(fPath, 'X_tensor_filt', 'f_grid', 'h_grid');
                        X_batch(:, :, :, k) = single(d.X_tensor_filt);
                    else
                        d = load(fPath, 'X_tensor_orig', 'f_grid', 'h_grid');
                        X_batch(:, :, :, k) = single(d.X_tensor_orig);
                    end
                end

                if isfield(d, 'f_grid') && ~isempty(d.f_grid)
                    f_grids{k} = double(d.f_grid(:)');
                else
                    f_grids{k} = default_f_grid;
                end

                if isfield(d, 'h_grid') && ~isempty(d.h_grid)
                    h_grids{k} = double(d.h_grid(:));
                else
                    h_grids{k} = default_h_grid;
                end
            catch ME
                fprintf('  ERROR loading tensor from %s: %s\n', fPath, ME.message);
                batchValid(k) = false;
                errorCount = errorCount + 1;
            end
        end

        dlX = dlarray(X_batch, 'SSCB');
        if useGPU
            dlX = gpuArray(dlX);
        end
        dlY_pred   = predict(trainedNet, dlX);
        probsBatch = gather(extractdata(dlY_pred));

        for k = 1:curBatchSize
            if ~batchValid(k)
                continue;
            end

            fileIdx = idxStart + k - 1;
            fPath   = validFileList{fileIdx};
            [~, fnameOnly, ext] = fileparts(fPath);

            try
                prob_map = probsBatch(:, :, 1, k);
                mask_raw = prob_map >= opts.threshold;

                mask_clean = bwareaopen(mask_raw, opts.min_blob_size);
                mask_pred = filter_significant_trace_blobs(mask_clean);

                [f_virt, h_virt, foF2_unet] = extract_virtual_profile_and_fof2( ...
                    mask_pred, f_grids{k}, h_grids{k}, opts.edge_choice);

                if ~isempty(f_virt)
                    ScaleV_unet = [f_virt(:), h_virt(:)];
                    detectedCount = detectedCount + 1;
                else
                    ScaleV_unet = zeros(0, 2);
                end

                save(fPath, 'mask_pred', 'ScaleV_unet', 'foF2_unet', 'unetOpts', '-append');

                processedCount = processedCount + 1;
                processedFiles{end+1} = [fnameOnly, ext]; %#ok<AGROW>
            catch ME
                fprintf('  ERROR saving U-Net profile to %s%s: %s\n', fnameOnly, ext, ME.message);
                errorCount = errorCount + 1;
            end
        end

        % fprintf('  Processed %d / %d sessions (%.1f s)\n', idxEnd, numValid, toc(stageTimer));
        elapsedSec = toc(stageTimer);
        filesPerSec = idxEnd / max(elapsedSec, 0.001);
        remainingFiles = numValid - idxEnd;
        etaSec = remainingFiles / max(filesPerSec, 0.001);

        fprintf('  Progress: %d / %d sessions (Batch %d / %d) | Elapsed: %.1f s | ETA: %.1f s\n', ...
            idxEnd, numValid, b, numBatches, elapsedSec, etaSec);

    end

    statusReport = struct();
    statusReport.station        = sStation;
    statusReport.totalSelected  = numValid;
    statusReport.processedCount = processedCount;
    statusReport.detectedCount  = detectedCount;
    statusReport.skippedCount   = skippedCount;
    statusReport.errorCount     = errorCount;
    statusReport.processedFiles = processedFiles;
    statusReport.elapsedTimeSec = toc(stageTimer);

    fprintf('\n============================================================\n');
    fprintf('   STAGE 3 COMPLETED SUCCESSFULLY                           \n');
    fprintf('   Processed Files  : %d / %d (Traces Detected: %d)         \n', ...
        processedCount, numValid, detectedCount);
    fprintf('   Elapsed Time     : %.2f seconds                          \n', statusReport.elapsedTimeSec);
    fprintf('============================================================\n');
end

function mask_filtered = filter_significant_trace_blobs(mask_clean)
    mask_filtered = false(size(mask_clean));
    if ~any(mask_clean(:))
        return;
    end

    cc = bwconncomp(mask_clean);
    if cc.NumObjects == 0
        return;
    end

    numPixels = cellfun(@numel, cc.PixelIdxList);
    maxArea   = max(numPixels);

    keepMask = (numPixels >= 0.15 * maxArea) | (numPixels >= 25);
    validIdx = find(keepMask);

    for i = 1:numel(validIdx)
        mask_filtered(cc.PixelIdxList{validIdx(i)}) = true;
    end
end

function [f_virt, h_virt, foF2_val] = extract_virtual_profile_and_fof2(mask, f_grid, h_grid, edge_choice)
    cols_with_trace = find(any(mask, 1));
    if isempty(cols_with_trace)
        f_virt   = [];
        h_virt   = [];
        foF2_val = NaN;
        return;
    end

    num_pts = numel(cols_with_trace);
    f_virt  = zeros(num_pts, 1);
    h_virt  = zeros(num_pts, 1);

    for idx = 1:num_pts
        c = cols_with_trace(idx);
        rows_in_col = find(mask(:, c));

        switch lower(edge_choice)
            case 'top'
                target_row = max(rows_in_col);
                h_virt(idx) = h_grid(target_row);
            case 'bottom'
                target_row = min(rows_in_col);
                h_virt(idx) = h_grid(target_row);
            case 'center'
                mean_row = mean(rows_in_col);
                r_low    = floor(mean_row);
                r_high   = ceil(mean_row);
                if r_low == r_high
                    h_virt(idx) = h_grid(r_low);
                else
                    w = mean_row - r_low;
                    h_virt(idx) = (1 - w) * h_grid(r_low) + w * h_grid(r_high);
                end
            otherwise
                target_row = round(mean(rows_in_col));
                h_virt(idx) = h_grid(target_row);
        end

        f_virt(idx) = f_grid(c);
    end

    foF2_val = max(f_virt);
end