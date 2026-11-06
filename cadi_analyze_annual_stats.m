function summaryData = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts)
% CADI_ANALYZE_ANNUAL_STATS Scans all processed *_ion.mat files for a full year,
% compiles a fast summary table, computes pipeline & quality classification 
% statistics, and exports monthly diurnal variation and comparison plots.
%
% SYNTAX:
%   summaryData = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts)
%
% INPUTS:
%   - outBaseDir : Root directory containing station subfolders (e.g., 'N:/cadi_out_test/')
%   - sStation   : Two-letter station code string defining the station subfolder (e.g., 'RB')
%   - targetYear : Numeric target year to be processed (e.g., 2008)
%   - opts       : (Optional) Structure containing advanced configuration fields:
%                  * opts.forceRebuild   : Logical flag. When set to true, forces 
%                                          re-scanning of all *_ion.mat files and 
%                                          rebuilds the annual summary MAT file from 
%                                          scratch, ignoring any existing cached summary. 
%                                          When false (default), loads the pre-existing 
%                                          summary file if available to save processing time.
%                  * opts.tecScaleFactor : Numeric multiplier applied to raw POLAN TEC 
%                                          values (default: 10.0). Used to adjust 
%                                          total electron content units so that data 
%                                          properly scales and fits standard plotting 
%                                          ranges (e.g., [0, 50] TECU).
%
% OUTPUTS:
%   - summaryData: Structure containing compiled annual parameters, session timestamps, 
%                  pipeline coverage statistics, U-Net metrics, and automatic 
%                  6-category quality classification IDs for every record.

    if nargin < 4 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'forceRebuild'), opts.forceRebuild = false; end
    if ~isfield(opts, 'tecScaleFactor'), opts.tecScaleFactor = 10.0; end % Multiply raw polanRes.TEC by 10 if needed

    sYear = sprintf('%04d', targetYear);
    yearDir = fullfile(outBaseDir, sStation, sYear);
    summaryMatPath = fullfile(outBaseDir, sprintf('CADI_Summary_%s_%s.mat', sStation, sYear));

    % =====================================================================
    % STEP 1: LOAD OR BUILD FAST ANNUAL SUMMARY TABLE
    % =====================================================================
    if isfile(summaryMatPath) && ~opts.forceRebuild
        fprintf('Loading existing annual summary from: %s\n', summaryMatPath);
        load(summaryMatPath, 'summaryData');
        
        % Normalize TEC scale if loaded from an older summary file so it fits [0, 50] TECU
        medTEC = median(summaryData.TEC(summaryData.TEC > 0), 'omitnan');
        if ~isnan(medTEC)
            if medTEC < 1.5
                fprintf('Scaling loaded summaryData.TEC by x10 (median was %.2f)...\n', medTEC);
                summaryData.TEC = summaryData.TEC * 10.0;
                save(summaryMatPath, 'summaryData', '-v7.3');
            elseif medTEC > 50.0
                fprintf('Scaling loaded summaryData.TEC by /10 to fit [0, 50] TECU (median was %.2f)...\n', medTEC);
                summaryData.TEC = summaryData.TEC / 10.0;
                save(summaryMatPath, 'summaryData', '-v7.3');
            end
        end
    else
        fprintf('Scanning directory: %s ...\n', yearDir);
        allFiles = dir(fullfile(yearDir, '*_ion.mat'));
        
        % Keep only 10-character minute session files (exclude 8-char hourly files)
        baseNames = erase({allFiles.name}, '_ion.mat');
        isMinuteFile = cellfun(@(s) length(s) == 10, baseNames);
        matFiles = allFiles(isMinuteFile);
        N = numel(matFiles);

        fprintf('Found %d minute *_ion.mat files. Extracting metrics...\n', N);

        % Preallocate arrays for speed
        fNames       = {matFiles.name}';
        dtNums       = nan(N, 1);
        nPtsV        = zeros(N, 1);
        nPtsR        = zeros(N, 1);
        foF2_unet    = nan(N, 1);
        foF2_pol     = nan(N, 1);
        hmF2_pol     = nan(N, 1);
        TEC_pol      = nan(N, 1);
        Hscale_pol   = nan(N, 1);
        SlabT_pol    = nan(N, 1);
        devH_pol     = nan(N, 1);
        polStatus    = strings(N, 1);

        % Feature arrays for Task 4 automatic classification
        v_hMin       = nan(N, 1);
        v_hMax       = nan(N, 1);
        v_hMean      = nan(N, 1);
        v_maxJumpUp  = nan(N, 1);
        v_maxJumpDn  = nan(N, 1);
        v_roughness  = nan(N, 1);
        eRegionPx    = zeros(N, 1);
        fRegionPx    = zeros(N, 1);
        eMaxFreqMHz  = nan(N, 1);

        tTimer = tic;
        for i = 1:N
            fPath = fullfile(matFiles(i).folder, matFiles(i).name);
            try
                w = warning('off', 'MATLAB:load:variableNotFound');
                d = load(fPath, 'DT', 'ScaleV_unet', 'ScaleR_polan', 'foF2_unet', ...
                                'polanRes', 'X_tensor_filt', 'f_grid', 'h_grid');
                warning(w);

                if isfield(d, 'DT') && numel(d.DT) >= 6
                    dtNums(i) = datenum(double(d.DT(1:6)));
                end

                % Virtual profile metrics
                if isfield(d, 'ScaleV_unet') && ~isempty(d.ScaleV_unet)
                    sv = double(d.ScaleV_unet);
                    nPtsV(i)   = size(sv, 1);
                    v_hMin(i)  = min(sv(:, 2));
                    v_hMax(i)  = max(sv(:, 2));
                    v_hMean(i) = mean(sv(:, 2));
                    if size(sv, 1) >= 2
                        dh = diff(sv(:, 2));
                        v_maxJumpUp(i) = max(dh);
                        v_maxJumpDn(i) = min(dh);
                        v_roughness(i) = sum(abs(dh(dh < 0)));
                    else
                        v_maxJumpUp(i) = 0; v_maxJumpDn(i) = 0; v_roughness(i) = 0;
                    end
                end

                if isfield(d, 'foF2_unet') && ~isempty(d.foF2_unet)
                    foF2_unet(i) = double(d.foF2_unet);
                end

                % Real profile & POLAN parameters
                if isfield(d, 'ScaleR_polan') && ~isempty(d.ScaleR_polan)
                    nPtsR(i) = size(d.ScaleR_polan, 1);
                end

                if isfield(d, 'polanRes') && isstruct(d.polanRes)
                    pr = d.polanRes;
                    if isfield(pr, 'foF2') && ~isempty(pr.foF2),       foF2_pol(i)   = double(pr.foF2);    end
                    if isfield(pr, 'hmF2') && ~isempty(pr.hmF2),       hmF2_pol(i)   = double(pr.hmF2);    end
                    if isfield(pr, 'TEC') && ~isempty(pr.TEC),         TEC_pol(i)    = double(pr.TEC) * opts.tecScaleFactor; end
                    if isfield(pr, 'H_scale') && ~isempty(pr.H_scale), Hscale_pol(i) = double(pr.H_scale); end
                    if isfield(pr, 'SlabT') && ~isempty(pr.SlabT),     SlabT_pol(i)  = double(pr.SlabT);   end
                    if isfield(pr, 'dev_h') && ~isempty(pr.dev_h),     devH_pol(i)   = double(pr.dev_h);   end
                    if isfield(pr, 'status') && ~isempty(pr.status),   polStatus(i)  = string(pr.status);  end
                end

                % Tensor energy features for E/Es vs F region
                if isfield(d, 'X_tensor_filt') && ~isempty(d.X_tensor_filt)
                    ampFilt = double(d.X_tensor_filt(1:171, 1:92, 1));
                    eRows = 30:49;
                    fRows = 60:160;
                    eMask = ampFilt(eRows, :) > 0.15;
                    fMask = ampFilt(fRows, :) > 0.12;
                    eRegionPx(i) = nnz(eMask);
                    fRegionPx(i) = nnz(fMask);
                    if any(eMask(:)) && isfield(d, 'f_grid') && numel(d.f_grid) >= 92
                        colsE = find(any(eMask, 1));
                        eMaxFreqMHz(i) = double(d.f_grid(max(colsE)));
                    end
                end

            catch
                % Keep NaNs if file is corrupted
            end

            if mod(i, 5000) == 0 || i == N
                el = toc(tTimer);
                eta = (N - i) / (i / el);
                fprintf('  Scanned %d / %d files (%.1f%%) | Elapsed: %.1f s | ETA: %.1f s\n', ...
                    i, N, 100*i/N, el, eta);
            end
        end

        % Auto-check TEC magnitude so majority of points lie within [0, 50] TECU
        medTEC = median(TEC_pol(TEC_pol > 0), 'omitnan');
        if ~isnan(medTEC) && medTEC > 50.0
            while median(TEC_pol(TEC_pol > 0), 'omitnan') > 50.0
                TEC_pol = TEC_pol / 10.0;
            end
        elseif ~isnan(medTEC) && medTEC < 1.5
            TEC_pol = TEC_pol * 10.0;
        end

        % Assemble into summary structure
        summaryData = struct();
        summaryData.station     = sStation;
        summaryData.year        = targetYear;
        summaryData.fNames      = fNames;
        summaryData.dt          = datetime(dtNums, 'ConvertFrom', 'datenum');
        summaryData.nPtsV       = nPtsV;
        summaryData.nPtsR       = nPtsR;
        summaryData.foF2_unet   = foF2_unet;
        summaryData.foF2        = foF2_pol;
        summaryData.hmF2        = hmF2_pol;
        summaryData.TEC         = TEC_pol;
        summaryData.H_scale     = Hscale_pol;
        summaryData.SlabT       = SlabT_pol;
        summaryData.devH        = devH_pol;
        summaryData.polStatus   = polStatus;
        summaryData.v_hMin      = v_hMin;
        summaryData.v_hMax      = v_hMax;
        summaryData.v_hMean     = v_hMean;
        summaryData.v_maxJumpUp = v_maxJumpUp;
        summaryData.v_maxJumpDn = v_maxJumpDn;
        summaryData.v_roughness = v_roughness;
        summaryData.eRegionPx   = eRegionPx;
        summaryData.fRegionPx   = fRegionPx;
        summaryData.eMaxFreqMHz = eMaxFreqMHz;

    end

    % =====================================================================
    % STEP 2: TASK 1 - PIPELINE COVERAGE STATISTICS
    % =====================================================================
    N_total = numel(summaryData.nPtsV);
    hasV    = summaryData.nPtsV > 0;
    hasR    = summaryData.nPtsR > 0;
    vNoR    = hasV & ~hasR;

    fprintf('\n====================================================================\n');
    fprintf('   TASK 1: CADI %s %d ANNUAL PIPELINE STATISTICS\n', sStation, targetYear);
    fprintf('====================================================================\n');
    fprintf('1. Total Processed Sessions (*.mat)       : %7d (100.00%%)\n', N_total);
    fprintf('2. Virtual Profile Extracted (ScaleV > 0) : %7d (%6.2f%%)\n', nnz(hasV), 100*nnz(hasV)/N_total);
    fprintf('3. Real Profile Inverted (ScaleR > 0)     : %7d (%6.2f%%)\n', nnz(hasR), 100*nnz(hasR)/N_total);
    fprintf('4. ScaleV Defined, but ScaleR Empty       : %7d (%6.2f%% of total | %5.2f%% of ScaleV)\n', ...
        nnz(vNoR), 100*nnz(vNoR)/N_total, 100*nnz(vNoR)/max(1, nnz(hasV)));

    if any(vNoR)
        fprintf('   Breakdown of ScaleV -> ScaleR drops:\n');
        fprintf('     - Very short trace (1-2 pts < min_pts) : %d\n', nnz(vNoR & summaryData.nPtsV < 3));
        fprintf('     - Duplicate/non-unique freqs (<3 uniq) : %d\n', nnz(vNoR & summaryData.nPtsV >= 3 & summaryData.polStatus == "INSUFFICIENT_UNIQUE_FREQS"));
        fprintf('     - POLAN convergence / inversion failure: %d\n', nnz(vNoR & summaryData.nPtsV >= 3 & summaryData.polStatus ~= "INSUFFICIENT_UNIQUE_FREQS"));
    end

    % =====================================================================
    % STEP 3: TASK 4 - AUTOMATIC 6-CATEGORY QUALITY CLASSIFICATION
    % =====================================================================
    catID = zeros(N_total, 1);

    % --- A. Sessions WITHOUT a Virtual Profile (~hasV) ---
    isNoV = ~hasV;
    isBlanketedEs = isNoV & (summaryData.eRegionPx >= 18 | summaryData.eMaxFreqMHz >= 3.2) & (summaryData.fRegionPx < 35);
    isMissedF2    = isNoV & (summaryData.fRegionPx >= 35);
    isWeakIono    = isNoV & ~isBlanketedEs & ~isMissedF2;

    catID(isBlanketedEs) = 4;
    catID(isWeakIono)    = 5;
    catID(isMissedF2)    = 6;

    % --- B. Sessions WITH a Virtual Profile (hasV) ---
    isE_as_F2 = hasV & ((summaryData.hmF2 < 165) | (summaryData.v_hMean < 160 & (summaryData.v_hMax - summaryData.v_hMin) < 30));
    
    isJaggedOrBad = hasV & ~isE_as_F2 & ( ...
        ~hasR | ...
        summaryData.v_maxJumpUp > 45 | ...
        summaryData.v_maxJumpDn < -18 | ...
        summaryData.v_roughness > 30 | ...
        summaryData.hmF2 > 520 | ...
        summaryData.H_scale < 5 | summaryData.H_scale > 120 | ...
        summaryData.SlabT < 10  | summaryData.SlabT > 600);

    isGoodF2 = hasV & ~isE_as_F2 & ~isJaggedOrBad;

    catID(isGoodF2)      = 1;
    catID(isE_as_F2)     = 2;
    catID(isJaggedOrBad) = 3;

    summaryData.qualityCategory = catID;

    catNames = {
        '1. Realistic F2 Profile (Good)', ...
        '2. E / Es Misidentified as F2', ...
        '3. Jagged / Unrealistic Profile', ...
        '4. No Profile: Blanketing Es', ...
        '5. No Profile: Weak Ionosphere / Blackout', ...
        '6. No Profile: Missed Valid F-Region Trace'
    };

    fprintf('\n====================================================================\n');
    fprintf('   TASK 4: AUTOMATIC IONOGRAM & PROFILE CLASSIFICATION\n');
    fprintf('====================================================================\n');
    for c = 1:6
        cnt = nnz(catID == c);
        fprintf('  %-44s : %7d (%6.2f%%)\n', catNames{c}, cnt, 100*cnt/N_total);
    end
    fprintf('====================================================================\n');

    % =====================================================================
    % STEP 4: TASK 2 - MONTHLY DIURNAL PLOTS (6 INDIVIDUAL PARAMETERS)
    %         Points + Mean (Solid Black) + Median (Solid Red)
    % =====================================================================
    validMask = (catID == 1); 

    paramsToPlot = {
        'foF2',      'foF2 (MHz)',                [0, 10];
        'foF2_unet', 'foF2\_unet (MHz)',          [0, 10];
        'hmF2',      'hmF2 (km)',                 [150, 500];
        'TEC',       'TEC (TECU, 10^{16} m^{-2})',[0, 50];
        'H_scale',   'Scale Height H (km)',       [10, 100];
        'SlabT',     'Slab Thickness (km)',       [50, 450]
    };

    monthNames = {'January','February','March','April','May','June', ...
                  'July','August','September','October','November','December'};

    dtValid    = summaryData.dt(validMask);
    mVec       = month(dtValid);
    utHours    = hour(dtValid) + minute(dtValid)/60 + second(dtValid)/3600;

    binStep    = 0.25; 
    binCenters = (0 : binStep : (24 - binStep)) + binStep/2;

    for pIdx = 1:size(paramsToPlot, 1)
        pField = paramsToPlot{pIdx, 1};
        pLabel = paramsToPlot{pIdx, 2};
        pYLim  = paramsToPlot{pIdx, 3};

        yDataAll = summaryData.(pField)(validMask);

        hFig = figure('Visible', 'off', 'Position', [50, 50, 2400, 1300], 'Color', 'w');
        sgtitle(sprintf('CADI %s %d - Monthly Diurnal Variation of %s (Black: Mean, Red: Median)', ...
            sStation, targetYear, pLabel), 'FontSize', 16, 'FontWeight', 'bold');

        for m = 1:12
            ax = subplot(3, 4, m, 'Parent', hFig);
            hold(ax, 'on');

            idxM = (mVec == m) & ~isnan(yDataAll);
            tM   = utHours(idxM);
            yM   = yDataAll(idxM);

            if ~isempty(tM)
                scatter(ax, tM, yM, 8, [0.55 0.68 0.85], 'filled', ...
                    'MarkerFaceAlpha', 0.25, 'MarkerEdgeAlpha', 0.25, 'HandleVisibility', 'off');

                meanCurve   = nan(size(binCenters));
                medianCurve = nan(size(binCenters));
                for b = 1:numel(binCenters)
                    bLow  = (b - 1) * binStep;
                    bHigh = b * binStep;
                    inBin = (tM >= bLow) & (tM < bHigh);
                    if nnz(inBin) >= 3
                        meanCurve(b)   = mean(yM(inBin), 'omitnan');
                        medianCurve(b) = median(yM(inBin), 'omitnan');
                    end
                end

                meanSmooth   = movmean(meanCurve, 3, 'omitnan');
                medianSmooth = movmean(medianCurve, 3, 'omitnan');

                hMean = plot(ax, binCenters, meanSmooth, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Mean');
                hMed  = plot(ax, binCenters, medianSmooth, 'r-', 'LineWidth', 2.0, 'DisplayName', 'Median');

                if m == 1
                    legend(ax, [hMean, hMed], {'Mean', 'Median'}, 'Location', 'northwest', 'FontSize', 9);
                end
            end

            hold(ax, 'off');
            xlim(ax, [0, 24]);
            xticks(ax, 0:4:24);
            ylim(ax, pYLim);
            grid(ax, 'on');
            title(ax, sprintf('%s (N = %d)', monthNames{m}, nnz(idxM)), 'FontSize', 11);
            xlabel(ax, 'Time (UT, hours)');
            ylabel(ax, pLabel);
        end

        outPlotPath = fullfile(outBaseDir, sprintf('CADI_%s_%d_Diurnal_%s.png', sStation, targetYear, pField));
        exportgraphics(hFig, outPlotPath, 'Resolution', 150);
        close(hFig);
        fprintf('Saved diurnal plot: %s\n', outPlotPath);
    end

    % =====================================================================
    % STEP 5: FIGURE 7 - COMPARISON OF foF2 (POLAN) VS foF2_unet
    % =====================================================================
    foF2_pol_all  = summaryData.foF2(validMask);
    foF2_unet_all = summaryData.foF2_unet(validMask);

    hFigComp = figure('Visible', 'off', 'Position', [50, 50, 2400, 1300], 'Color', 'w');
    sgtitle(sprintf('CADI %s %d - Monthly Diurnal Comparison: foF2 (POLAN) vs foF2\\_unet (Mean & Median)', ...
        sStation, targetYear), 'FontSize', 16, 'FontWeight', 'bold');

    for m = 1:12
        ax = subplot(3, 4, m, 'Parent', hFigComp);
        hold(ax, 'on');

        idxM   = (mVec == m) & (~isnan(foF2_pol_all) | ~isnan(foF2_unet_all));
        tM     = utHours(idxM);
        yPolM  = foF2_pol_all(idxM);
        yUnetM = foF2_unet_all(idxM);

        if ~isempty(tM)
            meanPol   = nan(size(binCenters));
            medPol    = nan(size(binCenters));
            meanUnet  = nan(size(binCenters));
            medUnet   = nan(size(binCenters));

            for b = 1:numel(binCenters)
                bLow  = (b - 1) * binStep;
                bHigh = b * binStep;
                inBin = (tM >= bLow) & (tM < bHigh);
                if nnz(inBin) >= 3
                    meanPol(b)  = mean(yPolM(inBin), 'omitnan');
                    medPol(b)   = median(yPolM(inBin), 'omitnan');
                    meanUnet(b) = mean(yUnetM(inBin), 'omitnan');
                    medUnet(b)  = median(yUnetM(inBin), 'omitnan');
                end
            end

            p1 = plot(ax, binCenters, movmean(meanPol, 3, 'omitnan'),  'k-',  'LineWidth', 2.0, 'DisplayName', 'foF2 Mean');
            p2 = plot(ax, binCenters, movmean(meanUnet, 3, 'omitnan'), 'k--', 'LineWidth', 1.8, 'DisplayName', 'foF2\_unet Mean');
            p3 = plot(ax, binCenters, movmean(medPol, 3, 'omitnan'),   'r-',  'LineWidth', 2.0, 'DisplayName', 'foF2 Median');
            p4 = plot(ax, binCenters, movmean(medUnet, 3, 'omitnan'),  'r--', 'LineWidth', 1.8, 'DisplayName', 'foF2\_unet Median');

            if m == 1
                legend(ax, [p1, p2, p3, p4], ...
                    {'foF2 Mean', 'foF2\_unet Mean', 'foF2 Median', 'foF2\_unet Median'}, ...
                    'Location', 'northwest', 'FontSize', 8.5);
            end
        end

        hold(ax, 'off');
        xlim(ax, [0, 24]);
        xticks(ax, 0:4:24);
        ylim(ax, [1, 9]); 
        grid(ax, 'on');
        title(ax, sprintf('%s (N = %d)', monthNames{m}, nnz(idxM)), 'FontSize', 11);
        xlabel(ax, 'Time (UT, hours)');
        ylabel(ax, 'Critical Frequency (MHz)');
    end 

    outCompPath = fullfile(outBaseDir, sprintf('CADI_%s_%d_Diurnal_foF2_Comparison.png', sStation, targetYear));
    exportgraphics(hFigComp, outCompPath, 'Resolution', 150);
    close(hFigComp);
    fprintf('Saved foF2 comparison plot: %s\n', outCompPath);

    % =====================================================================
    % STEP 6: Saved annual summary dataset
    % =====================================================================
    save(summaryMatPath, 'summaryData', '-v7.3');
    fprintf('Saved annual summary dataset to: %s\n', summaryMatPath);

end