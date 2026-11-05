function comparisonReport = cadi_compare_with_david(pipelineOutDir, davidPolDir, outBaseDir, opts)
% CADI_COMPARE_WITH_DAVID Performs cross-validation of the CADI automated 
% processing pipeline results against David's reference manual scaling dataset 
% (*_pol.mat files).
%
% Syntax:
%   report = cadi_compare_with_david(pipelineOutDir, davidPolDir, outBaseDir, opts)
%
% Key workflow steps:
%   1. Scanning Reference Files: Scans the reference directory (davidPolDir) 
%      to locate all manual scaling files (*_pol.mat).
%   2. Pair Matching: Matches each David reference file with its corresponding 
%      automated pipeline result file (*_ion.mat) in (pipelineOutDir) folder
%      based on identical base names.
%   3. Safe Data Extraction: Safely extracts reference peak parameters (foF2, 
%      hmF2, ScaleHt, SlabT) using a robust helper function (get_field_safe) 
%      while loading pipeline POLAN inversion outputs (polanRes and ScaleR_polan).
%   4. Success Rate Calculation: Computes the overall success percentage of the 
%      pipeline's real-height profile generation against David's benchmark set.
%   5. Statistical Evaluation: Computes quantitative error metrics for matched 
%      sessions:
%        - Bias (mean error / systematic shift)
%        - MAE (Mean Absolute Error)
%        - RMSE (Root Mean Square Error)
%        - R (Pearson correlation coefficient)
%   6. Visualization: Generates a 2x2 panel of regression scatter plots for 
%      foF2, hmF2, ScaleHt, and SlabT featuring an ideal 1:1 line, a linear fit 
%      line, and computed metrics in the titles, exporting the final figure to a PNG file
%      to (outBaseDir) filder.
%
% Syntax example:
%   report = cadi_compare_with_david('N:/cadi_out_test/RB/2008', ...
%                                    'N:/cadi_synced/RB/2008_p1_m1_p1_m1/', ...
%                                    'N:/cadi_out_test/');

    if nargin < 4 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'plotVisible'), opts.plotVisible = 'off'; end

    fprintf('============================================================\n');
    fprintf('   CADI PIPELINE vs DAVID REFERENCE VALIDATION              \n');
    fprintf('============================================================\n');
    fprintf('Pipeline Dir : %s\n', pipelineOutDir);
    fprintf('David Ref Dir: %s\n', davidPolDir);

    % 1. Find all David's reference files (*_pol.mat)
    davidFiles = dir(fullfile(davidPolDir, '*_pol.mat'));
    N_total = numel(davidFiles);

    if N_total == 0
        error('No *_pol.mat reference files found in: %s', davidPolDir);
    end
    fprintf('Found %d reference files from David.\n', N_total);

    % Preallocate storage for matched parameters
    ref_foF2  = []; pipe_foF2  = [];
    ref_hmF2  = []; pipe_hmF2  = [];
    ref_Hsc   = []; pipe_Hsc   = [];
    ref_SlabT = []; pipe_SlabT = [];

    matchedCount = 0;
    hasProfileCount = 0;

    for i = 1:N_total
        polName = davidFiles(i).name; % e.g., 'RB8a010300_pol.mat'
        baseName = erase(polName, '_pol.mat'); % e.g., 'RB8a010300'
        
        % Construct corresponding pipeline file name
        pipeMatName = [baseName, '_ion.mat'];
        pipeMatPath = fullfile(pipelineOutDir, pipeMatName);

        if ~isfile(pipeMatPath)
            continue; % Pipeline file missing for this session
        end

        matchedCount = matchedCount + 1;

        try
            % Load David's reference peak values (from struct 'records')
            dRef = load(fullfile(davidFiles(i).folder, polName), 'records');
            if ~isfield(dRef, 'records') || ~isfield(dRef.records, 'Peak')
                continue;
            end
            pRef = dRef.records.Peak;

            % Safe extraction with alternative field name checks
            val_foF2  = get_field_safe(pRef, {'foF2', 'foF', 'critical_frequency'});
            val_hmF2  = get_field_safe(pRef, {'hmF2', 'hm', 'height_max'});
            val_scale = get_field_safe(pRef, {'ScaleHt', 'ScaleHeight', 'H_scale', 'Hscale', 'H'});
            val_slab  = get_field_safe(pRef, {'SlabT', 'SlabThickness', 'slab'});

            if isnan(val_foF2) || isnan(val_hmF2)
                continue;
            end

            % Load Pipeline results
            dPipe = load(pipeMatPath, 'polanRes', 'ScaleR_polan');
            if ~isfield(dPipe, 'polanRes') || isempty(dPipe.ScaleR_polan)
                continue; % Pipeline failed or didn't produce a real profile
            end
            pPipe = dPipe.polanRes;

            % Check if pipeline successfully derived physical peak parameters
            if isfield(pPipe, 'foF2') && ~isnan(pPipe.foF2) && pPipe.foF2 > 0 && ...
               isfield(pPipe, 'hmF2') && ~isnan(pPipe.hmF2) && pPipe.hmF2 > 0

                hasProfileCount = hasProfileCount + 1;

                % Collect parameters (ensure H_scale and SlabT are available)
                hScalePipe = NaN;
                if isfield(pPipe, 'H_scale'), hScalePipe = pPipe.H_scale; end
                slabTPipe  = NaN;
                if isfield(pPipe, 'SlabT'),  slabTPipe  = pPipe.SlabT;  end

                ref_foF2(end+1, 1)  = double(val_foF2);
                pipe_foF2(end+1, 1) = double(pPipe.foF2);

                ref_hmF2(end+1, 1)  = double(val_hmF2);
                pipe_hmF2(end+1, 1) = double(pPipe.hmF2);

                ref_Hsc(end+1, 1)   = double(val_scale);
                pipe_Hsc(end+1, 1)  = double(hScalePipe);

                ref_SlabT(end+1, 1) = double(val_slab);
                pipe_SlabT(end+1, 1)= double(slabTPipe);
            end

        catch ME
            fprintf('  Error processing match %s: %s\n', baseName, ME.message);
        end
    end

    % 2. Compute Success Percentages
    successPctOfTotal = (hasProfileCount / N_total) * 100;
    successPctOfMatched = (hasProfileCount / max(1, matchedCount)) * 100;

    fprintf('\n------------------------------------------------------------\n');
    fprintf('   PIPELINE INVERSION SUCCESS RATE AGAINST DAVID''S SET      \n');
    fprintf('------------------------------------------------------------\n');
    fprintf('Total Reference Files (David) : %d\n', N_total);
    fprintf('Matched Pipeline Files        : %d\n', matchedCount);
    fprintf('Successfully Inverted (Pipeline): %d\n', hasProfileCount);
    fprintf('Success Rate (% of Total)     : %.2f%%\n', successPctOfTotal);
    fprintf('Success Rate (% of Matched)   : %.2f%%\n', successPctOfMatched);

    % 3. Calculate Regression & Error Metrics
    metrics = struct();
    metrics.foF2  = calc_metrics(ref_foF2, pipe_foF2);
    metrics.hmF2  = calc_metrics(ref_hmF2, pipe_hmF2);
    metrics.ScaleHt = calc_metrics(ref_Hsc, pipe_Hsc);
    metrics.SlabT = calc_metrics(ref_SlabT, pipe_SlabT);

    print_metric_table(metrics);

    % 4. Generate Regression Scatter Plots
    plot_regression_panel(ref_foF2, pipe_foF2, ref_hmF2, pipe_hmF2, ...
                          ref_Hsc, pipe_Hsc, ref_SlabT, pipe_SlabT, ...
                          outBaseDir, opts.plotVisible);

    comparisonReport = struct();
    comparisonReport.N_total = N_total;
    comparisonReport.hasProfileCount = hasProfileCount;
    comparisonReport.successPct = successPctOfTotal;
    comparisonReport.metrics = metrics;
end

% =========================================================================
% HELPER: CALCULATE METRICS (Bias, RMSE, MAE, R)
% =========================================================================
function m = calc_metrics(ref, pipe)
    valid = ~isnan(ref) & ~isnan(pipe);
    r = ref(valid);
    p = pipe(valid);

    if isempty(r)
        m = struct('Bias', NaN, 'RMSE', NaN, 'MAE', NaN, 'R', NaN, 'N', 0);
        return;
    end

    diffs = p - r;
    m.N    = numel(r);
    m.Bias = mean(diffs);
    m.MAE  = mean(abs(diffs));
    m.RMSE = sqrt(mean(diffs.^2));
    
    corrMat = corrcoef(r, p);
    if size(corrMat, 2) >= 2
        m.R = corrMat(1, 2);
    else
        m.R = NaN;
    end
end

% =========================================================================
% HELPER: PRINT STATISTICAL TABLE TO CONSOLE
% =========================================================================
function print_metric_table(met)
    fprintf('\n------------------------------------------------------------\n');
    fprintf('   STATISTICAL METRICS (Pipeline vs David Reference)        \n');
    fprintf('------------------------------------------------------------\n');
    fprintf('%-10s | %6s | %8s | %8s | %8s | %6s\n', 'Parameter', 'N', 'Bias', 'MAE', 'RMSE', 'Corr (R)');
    fprintf('------------------------------------------------------------\n');
    print_row('foF2 (MHz)', met.foF2);
    print_row('hmF2 (km)', met.hmF2);
    print_row('ScaleHt(km)', met.ScaleHt);
    print_row('SlabT (km)', met.SlabT);
    fprintf('============================================================\n');
end

function print_row(name, m)
    fprintf('%-10s | %6d | %8.3f | %8.3f | %8.3f | %6.3f\n', ...
        name, m.N, m.Bias, m.MAE, m.RMSE, m.R);
end

% =========================================================================
% HELPER: PLOT REGRESSION PANEL (2x2 Scatter Plots)
% =========================================================================
function plot_regression_panel(r1, p1, r2, p2, r3, p3, r4, p4, outDir, visMode)
    hFig = figure('Visible', visMode, 'Position', [100, 100, 1400, 1000], 'Color', 'w');
    sgtitle('CADI Pipeline vs David Reference Manual Scaling', 'FontSize', 16, 'FontWeight', 'bold');

    % 1. foF2
    subplot(2, 2, 1);
    draw_scatter_plot(r1, p1, 'foF2 (MHz)', [0, 10]);

    % 2. hmF2
    subplot(2, 2, 2);
    draw_scatter_plot(r2, p2, 'hmF2 (km)', [150, 450]);

    % 3. ScaleHt
    subplot(2, 2, 3);
    draw_scatter_plot(r3, p3, 'ScaleHt (km)', [10, 100]);

    % 4. SlabT
    subplot(2, 2, 4);
    draw_scatter_plot(r4, p4, 'SlabT (km)', [50, 350]);

    outPath = fullfile(outDir, 'CADI_Validation_Regression_vs_David.png');
    exportgraphics(hFig, outPath, 'Resolution', 150);
    close(hFig);
    fprintf('Saved validation regression plot to: %s\n', outPath);
end

function draw_scatter_plot(ref, pipe, labelName, axisLim)
    valid = ~isnan(ref) & ~isnan(pipe);
    r = ref(valid);
    p = pipe(valid);

    hold on;
    scatter(r, p, 12, [0.1 0.4 0.7], 'filled', 'MarkerFaceAlpha', 0.3, 'HandleVisibility', 'off');
    
    % Ideal 1:1 line
    plot(axisLim, axisLim, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Ideal 1:1');

    if numel(r) > 2
        % Linear fit p = a*r + b
        pFit = polyfit(r, p, 1);
        rFitLine = linspace(axisLim(1), axisLim(2), 100);
        pFitLine = polyval(pFit, rFitLine);
        plot(rFitLine, pFitLine, 'r-', 'LineWidth', 2, 'DisplayName', sprintf('Fit: y = %.2fx + %.2f', pFit(1), pFit(2)));
    end

    hold off;
    xlim(axisLim); ylim(axisLim);
    grid on;
    xlabel(['David Reference: ', labelName]);
    ylabel(['Pipeline Output: ', labelName]);
    
    m = calc_metrics(ref, pipe);
    title(sprintf('%s (N=%d, Bias=%.2f, RMSE=%.2f, R=%.3f)', labelName, m.N, m.Bias, m.RMSE, m.R), 'FontSize', 11);
    legend('Location', 'southeast', 'FontSize', 9);
end

% =========================================================================
% HELPER: SAFELY GET FIELD FROM STRUCT WITH MULTIPLE CANDIDATE NAMES
% =========================================================================
function val = get_field_safe(sObj, candidateNames)
val = NaN;
if isempty(sObj) || ~isstruct(sObj)
    return;
end
for k = 1:numel(candidateNames)
    if isfield(sObj, candidateNames{k})
        val = double(sObj.(candidateNames{k}));
        if ~isempty(val) && ~isnan(val)
            return;
        end
    end
end
end