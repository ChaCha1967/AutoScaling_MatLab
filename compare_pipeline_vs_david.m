function compare_pipeline_vs_david(outBaseDir, sStation, targetYear, PolDir, opts)
% COMPARE_PIPELINE_VS_DAVID Compares pipeline processing results against David's 
% manual scaling reference data across 4 monthly diurnal multi-panel figures 
% (foF2, hmF2, SlabT, and calculated TEC).
%
% SYNTAX:
%   compare_pipeline_vs_david(outBaseDir, sStation, targetYear, PolDir, opts)
%
% INPUTS:
%   - outBaseDir : Root directory containing station subfolders and summary MAT files
%   - sStation   : Two-letter station code string (e.g., 'RB')
%   - targetYear : Numeric target year (e.g., 2008)
%   - PolDir     : Directory containing David's manual *_pol.mat reference files
%   - opts       : (Optional) Structure of options passed to cadi_analyze_annual_stats (forceRebuild, etc.)

    if nargin < 5 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'forceRebuild')
        opts.forceRebuild = false;
    end

    sYear = sprintf('%04d', targetYear);
    summaryMatPath = fullfile(outBaseDir, sprintf('CADI_Summary_%s_%s.mat', sStation, sYear));

    % =====================================================================
    % STEP 1: LOAD OR GENERATE PIPELINE SUMMARY DATA
    % =====================================================================
    if isfile(summaryMatPath) && ~opts.forceRebuild
        fprintf('Loading existing pipeline annual summary from: %s\n', summaryMatPath);
        load(summaryMatPath, 'summaryData');
    else
        fprintf('Summary file not found or forceRebuild requested. Running cadi_analyze_annual_stats...\n');
        summaryData = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts);
    end

    % Extract valid pipeline data (filtering by category 1 - Good profiles if available)
    if isfield(summaryData, 'qualityCategory')
        pipeValid = (summaryData.qualityCategory == 1) & ~isnan(summaryData.foF2);
    else
        pipeValid = ~isnan(summaryData.foF2);
    end

    pipe_dt    = summaryData.dt(pipeValid);
    pipe_foF2  = summaryData.foF2(pipeValid);
    pipe_hmF2  = summaryData.hmF2(pipeValid);
    pipe_SlabT = summaryData.SlabT(pipeValid);
    pipe_TEC   = summaryData.TEC(pipeValid);

    % =====================================================================
    % STEP 2: LOAD DAVID'S MANUAL SCALING REFERENCE DATA FROM PolDir
    % =====================================================================
    if ~isfolder(PolDir)
        error('David reference directory does not exist: %s', PolDir);
    end

    matFiles = dir(fullfile(PolDir, '*_pol.mat'));
    N_pol = numel(matFiles);
    if N_pol == 0
        warning('No *_pol.mat reference files found in: %s', PolDir);
        return;
    end

    fprintf('Found %d David reference files in %s. Extracting parameters...\n', N_pol, PolDir);

    dtNums_d    = nan(N_pol, 1);
    foF2_d_arr  = nan(N_pol, 1);
    hmF2_d_arr  = nan(N_pol, 1);
    SlabT_d_arr = nan(N_pol, 1);

    for i = 1:N_pol
        filePath = fullfile(matFiles(i).folder, matFiles(i).name);
        try
            d = load(filePath, 'records');
            if isfield(d, 'records') && isfield(d.records, 'DT') && numel(d.records.DT) >= 6
                dtNums_d(i) = datenum(double(d.records.DT(1:6)));
            end
            if isfield(d, 'records') && isfield(d.records, 'Peak') && ~isempty(d.records.Peak)
                p = d.records.Peak;
                if isfield(p, 'foF2') && ~isempty(p.foF2),   foF2_d_arr(i)  = double(p.foF2);   end
                if isfield(p, 'hmF2') && ~isempty(p.hmF2),   hmF2_d_arr(i)  = double(p.hmF2);   end
                if isfield(p, 'SlabT') && ~isempty(p.SlabT), SlabT_d_arr(i) = double(p.SlabT); end
            end
        catch
            % Skip unreadable files quietly
        end
    end

    davidValid = ~isnan(dtNums_d) & ~isnan(foF2_d_arr) & ~isnan(hmF2_d_arr);
    david_dt   = datetime(dtNums_d(davidValid), 'ConvertFrom', 'datenum');
    david_foF2 = foF2_d_arr(davidValid);
    david_hmF2 = hmF2_d_arr(davidValid);
    david_SlabT= SlabT_d_arr(davidValid);
    % Calculate TEC for David data consistent with pipeline formula, scaled to [0, 50] TECU
    david_TEC  = (david_SlabT .* (david_foF2 .^ 2) * 0.124) / 10.0;

    % =====================================================================
    % STEP 3: PREPARE TIME VECTORS & PLOTTING CONFIGURATION
    % =====================================================================
    pipe_mVec   = month(pipe_dt);
    pipe_utHrs  = hour(pipe_dt) + minute(pipe_dt)/60 + second(pipe_dt)/3600;

    david_mVec  = month(david_dt);
    david_utHrs = hour(david_dt) + minute(david_dt)/60 + second(david_dt)/3600;

    monthNames = {'January','February','March','April','May','June', ...
                  'July','August','September','October','November','December'};

    params = {
        pipe_foF2,  david_foF2,  'foF2 (MHz)',                [0, 10],   'foF2';
        pipe_hmF2,  david_hmF2,  'hmF2 (km)',                 [150, 500], 'hmF2';
        pipe_SlabT, david_SlabT, 'Slab Thickness (km)',       [0, 450],   'SlabT';
        pipe_TEC,   david_TEC,   'TEC (TECU, 10^{16} m^{-2})',[0, 50],   'TEC'
    };

    binStep    = 0.25; % 15-minute bins
    binCenters = (0 : binStep : (24 - binStep)) + binStep/2;

    % =====================================================================
    % STEP 4: GENERATE 4 MULTI-PANEL COMPARISON FIGURES
    % =====================================================================
    for pIdx = 1:size(params, 1)
        pipeDataAll  = params{pIdx, 1};
        davidDataAll = params{pIdx, 2};
        pLabel       = params{pIdx, 3};
        pYLim        = params{pIdx, 4};
        pName        = params{pIdx, 5};

        hFig = figure('Visible', 'off', 'Position', [50, 50, 2400, 1300], 'Color', 'w');
        sgtitle(sprintf('Comparison: Pipeline (Black/Gray) vs David Reference (Red/Blue) - %s (%s %s)', ...
            pLabel, sStation, sYear), 'FontSize', 15, 'FontWeight', 'bold');

        for m = 1:12
            ax = subplot(3, 4, m, 'Parent', hFig);
            hold(ax, 'on');

            % --- 1. Plot Pipeline Data (Gray points + Black median line) ---
            idxPipeM = (pipe_mVec == m) & ~isnan(pipeDataAll);
            tPipeM   = pipe_utHrs(idxPipeM);
            yPipeM   = pipeDataAll(idxPipeM);

            if ~isempty(tPipeM)
                scatter(ax, tPipeM, yPipeM, 7, [0.7 0.7 0.7], 'filled', ...
                    'MarkerFaceAlpha', 0.2, 'MarkerEdgeAlpha', 0.2, 'HandleVisibility', 'off');

                pipeMed = compute_median_curve(tPipeM, yPipeM, binCenters, binStep);
                hPipeLine = plot(ax, binCenters, pipeMed, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Pipeline Median');
            else
                hPipeLine = plot(ax, nan, nan, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Pipeline Median');
            end

            % --- 2. Plot David Reference Data (Bright Blue points + Red median line) ---
            idxDavM = (david_mVec == m) & ~isnan(davidDataAll);
            tDavM   = david_utHrs(idxDavM);
            yDavM   = davidDataAll(idxDavM);

            if ~isempty(tDavM)
                % Увеличена яркость и размер точек Дэвида (MarkerFaceAlpha = 0.6, размер = 10)
                scatter(ax, tDavM, yDavM, 10, [0.1 0.3 0.9], 'filled', ...
                    'MarkerFaceAlpha', 0.6, 'MarkerEdgeAlpha', 0.6, 'HandleVisibility', 'off');

                davMed = compute_median_curve(tDavM, yDavM, binCenters, binStep);
                hDavLine = plot(ax, binCenters, davMed, 'r-', 'LineWidth', 2.0, 'DisplayName', 'David Median');
            else
                hDavLine = plot(ax, nan, nan, 'r-', 'LineWidth', 2.0, 'DisplayName', 'David Median');
            end

            if m == 1
                legend(ax, [hPipeLine, hDavLine], {'Pipeline (Median)', 'David Ref (Median)'}, ...
                    'Location', 'northwest', 'FontSize', 8.5);
            end

            hold(ax, 'off');
            xlim(ax, [0, 24]);
            xticks(ax, 0:4:24);
            ylim(ax, pYLim);
            grid(ax, 'on');

            title(ax, sprintf('%s (Pipe N=%d, Dav N=%d)', monthNames{m}, nnz(idxPipeM), nnz(idxDavM)), 'FontSize', 10);
            xlabel(ax, 'Time (UT, hours)');
            ylabel(ax, pLabel);
        end

        outPlotPath = fullfile(outBaseDir, sprintf('Compare_Pipeline_vs_David_%s_%s_%s.png', sStation, sYear, pName));
        exportgraphics(hFig, outPlotPath, 'Resolution', 150);
        close(hFig);
        fprintf('Saved comparison plot for %s -> %s\n', pName, outPlotPath);
    end
    fprintf('All comparison diurnal figures generated successfully!\n');
end

% =========================================================================
% HELPER FUNCTION: COMPUTE SMOOTHED MEDIAN CURVE OVER BINS
% =========================================================================
function medCurve = compute_median_curve(tVec, yVec, binCenters, binStep)
    medCurve = nan(size(binCenters));
    for b = 1:numel(binCenters)
        bLow  = (b - 1) * binStep;
        bHigh = b * binStep;
        inBin = (tVec >= bLow) & (tVec < bHigh);
        if nnz(inBin) >= 3
            medCurve(b) = median(yVec(inBin), 'omitnan');
        end
    end
    medCurve = movmean(medCurve, 3, 'omitnan');
end