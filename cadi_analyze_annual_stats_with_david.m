function cadi_analyze_annual_stats_with_david(outBaseDir, davidDir, sStation, targetYear, opts)
% CADI_ANALYZE_ANNUAL_STATS_WITH_DAVID 
% Loads pre-calculated NN summaries and compares them directly against 
% David's manually scaled ground-truth (*_pol.mat) profiles.
% Generates: Classification Bar Chart, ErrorHist, Scatter, and Hybrid Diurnals.

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'forceRebuild'), opts.forceRebuild = false; end
    if ~isfield(opts, 'tecScaleFactor'), opts.tecScaleFactor = 1.0; end
    if ~isfield(opts, 'models')
        opts.models(1).label = '6ch-combined';
    end

    numModels = length(opts.models);
    sYear     = sprintf('%04d', targetYear);

    % =====================================================================
    % STEP 1: LOAD OR BUILD DAVID'S CACHE
    % =====================================================================
    davidCacheFile = fullfile(outBaseDir, sprintf('CADI_Summary_%s_%s_David.mat', sStation, sYear));
    
    if isfile(davidCacheFile) && ~opts.forceRebuild
        fprintf('Loading existing David reference cache: %s\n', davidCacheFile);
        load(davidCacheFile, 'davidData');
    else
        fprintf('Scanning directory for David''s *_pol.mat files: %s\n', davidDir);
        dFiles = dir(fullfile(davidDir, '*_pol.mat'));
        Nd = numel(dFiles);
        
        if Nd == 0
            error('No *_pol.mat files found in the specified David directory!');
        end
        
        fprintf('Found %d reference files. Extracting data...\n', Nd);
        
        d_dtNums = nan(Nd, 1);
        d_foF2   = nan(Nd, 1);
        d_hmF2   = nan(Nd, 1);
        d_SlabT  = nan(Nd, 1);
        d_TEC    = nan(Nd, 1);
        
        for i = 1:Nd
            fPath = fullfile(dFiles(i).folder, dFiles(i).name);
            try
                d = load(fPath, 'records');
                if isfield(d, 'records')
                    rec = d.records;
                    d_dtNums(i) = datenum(double(rec.DT(1:6)));
                    
                    if isfield(rec, 'Peak')
                        pk = rec.Peak;
                        if isfield(pk, 'foF2'),  d_foF2(i)  = double(pk.foF2); end
                        if isfield(pk, 'hmF2'),  d_hmF2(i)  = double(pk.hmF2); end
                        if isfield(pk, 'SlabT'), d_SlabT(i) = double(pk.SlabT); end
                        
                        % Physical Sub-peak Electron Content (pseudo-TEC) Formula
                        % Scaled dynamically using opts.tecScaleFactor
                        if ~isnan(d_SlabT(i)) && ~isnan(d_foF2(i))
                            d_TEC(i) = opts.tecScaleFactor * 0.00124 * d_SlabT(i) * (d_foF2(i)^2);
                        end
                    end
                end
            catch
                fprintf('Error parsing %s\n', dFiles(i).name);
            end
        end
        
        davidData = struct();
        davidData.station = sStation;
        davidData.year    = targetYear;
        davidData.dt      = datetime(d_dtNums, 'ConvertFrom', 'datenum');
        davidData.foF2    = d_foF2;
        davidData.hmF2    = d_hmF2;
        davidData.SlabT   = d_SlabT;
        davidData.TEC     = d_TEC;
        
        save(davidCacheFile, 'davidData', '-v7.3');
        fprintf('Saved David reference cache to: %s\n', davidCacheFile);
    end

    % Shift datetime to minute start for robust synchronization (ignores seconds mismatch)
    dt_David_sync = dateshift(davidData.dt, 'start', 'minute');

    % =====================================================================
    % STEP 2: LOOP THROUGH NEURAL NETWORKS AND COMPARE WITH DAVID
    % =====================================================================
    paramsToPlot = {
        'foF2',  'foF2 [MHz]';
        'hmF2',  'hmF2 [km]';
        'TEC',   'TEC [TECU]';
        'SlabT', 'Slab Thickness [km]'
    };

    catNamesShort = {'C1 (Good)', 'C2 (E/Es)', 'C3 (Jagged)', 'C4 (Es Block)', 'C5 (Weak)', 'C6 (Missed)'};

    for m = 1:numModels
        modelLabel = opts.models(m).label;
        safeLabel  = strrep(strrep(modelLabel, '-', '_'), ' ', '_');
        
        nnSummaryFile = fullfile(outBaseDir, sprintf('CADI_Summary_%s_%s_%s.mat', sStation, sYear, safeLabel));
        if ~isfile(nnSummaryFile)
            fprintf('WARNING: NN Summary file not found: %s. Skipping model.\n', nnSummaryFile);
            continue;
        end
        
        tmp = load(nnSummaryFile, 'summaryData');
        nnData = tmp.summaryData;
        
        % Sync dates maintaining original chronological order ('stable')
        dt_NN_sync = dateshift(nnData.dt, 'start', 'minute');
        [~, idx_D, idx_NN] = intersect(dt_David_sync, dt_NN_sync, 'stable');
        
        matchedCount = length(idx_D);
        fprintf('\n====================================================================\n');
        fprintf('Comparing David Ground Truth vs NN Model: %s\n', modelLabel);
        fprintf('Found %d matching sessions (by minute).\n', matchedCount);
        
        if matchedCount == 0, continue; end
        
        % --- 2.1 Category Classification Bar Chart (replaces Heatmap) ---
        matched_nn_cats = nnData.qualityCategory(idx_NN);
        cat_counts = histcounts(matched_nn_cats, 0.5:6.5);
        
        hFigBar = figure('Visible', 'off', 'Position', [100, 100, 1000, 600], 'Color', 'w');
        b = bar(1:6, cat_counts, 'FaceColor', [0.2 0.5 0.8]);
        
        % Add text labels on top of bars
        for i = 1:6
            pct = 100 * cat_counts(i) / matchedCount;
            if cat_counts(i) > 0
                text(i, cat_counts(i), sprintf('%d\n(%.1f%%)', cat_counts(i), pct), ...
                    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                    'FontWeight', 'bold', 'FontSize', 11);
            end
        end
        
        set(gca, 'XTick', 1:6, 'XTickLabel', catNamesShort, 'FontSize', 11);
        ylim([0, max(cat_counts)*1.15]);
        ylabel('Number of Sessions', 'FontSize', 12, 'FontWeight', 'bold');
        title(sprintf('How NN "%s" Classified David''s %d Reference Ionograms', modelLabel, matchedCount), ...
            'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
        grid on;
        
        outBar = fullfile(outBaseDir, sprintf('David_vs_%s_CategoryBar.png', safeLabel));
        exportgraphics(hFigBar, outBar, 'Resolution', 150);
        close(hFigBar);

        % --- Filter strictly for Category 1 matches for ErrorHist and Scatter ---
        valid_C1_mask = (matched_nn_cats == 1);
        idx_D_C1 = idx_D(valid_C1_mask);
        idx_NN_C1 = idx_NN(valid_C1_mask);
        
        fprintf('  Of those matches, %d were classified as Category 1 (Good F2) by NN.\n', length(idx_D_C1));
        
        % --- 2.2 ErrorHist (NN Prediction - David Reference) ---
        hFigEH = figure('Visible', 'off', 'Position', [100, 100, 1400, 1200], 'Color', 'w');
        sgtitle(sprintf('Error Distribution (NN Prediction - David Ref): %s', modelLabel), ...
            'FontSize', 18, 'FontWeight', 'bold', 'Interpreter', 'none');
        
        for pIdx = 1:size(paramsToPlot, 1)
            pField = paramsToPlot{pIdx, 1};
            pLabel = paramsToPlot{pIdx, 2};
            
            val_David = davidData.(pField)(idx_D_C1);
            val_NN    = nnData.(pField)(idx_NN_C1);
            
            valid_pts = isfinite(val_David) & isfinite(val_NN);
            delta = val_NN(valid_pts) - val_David(valid_pts); % Prediction - Truth
            
            subplot(2, 2, pIdx);
            if ~isempty(delta)
                histogram(delta, 80, 'FaceColor', [0.8 0.3 0.3], 'EdgeColor', 'none');
                hold on; xline(0, 'k-', 'LineWidth', 1.5); xline(mean(delta), 'b--', 'LineWidth', 2.0); hold off;
                title(sprintf('\\Delta %s (Bias=%+.2f, MAE=%.2f)', pField, mean(delta), mean(abs(delta))), 'FontSize', 14);
            end
            xlabel(sprintf('%s - David %s', modelLabel, pLabel), 'FontSize', 12, 'Interpreter', 'none');
            ylabel('Count', 'FontSize', 12);
            grid on;
        end
        outEH = fullfile(outBaseDir, sprintf('David_vs_%s_ErrorHist.png', safeLabel));
        exportgraphics(hFigEH, outEH, 'Resolution', 150);
        close(hFigEH);

        % --- 2.3 Scatter (Regression) ---
        hFigScat = figure('Visible', 'off', 'Position', [100, 100, 1400, 1200], 'Color', 'w');
        sgtitle(sprintf('Regression Analysis: David Reference vs NN %s', modelLabel), ...
            'FontSize', 18, 'FontWeight', 'bold', 'Interpreter', 'none');
            
        for pIdx = 1:size(paramsToPlot, 1)
            pField = paramsToPlot{pIdx, 1};
            pLabel = paramsToPlot{pIdx, 2};
            
            X_Truth = davidData.(pField)(idx_D_C1);
            Y_Pred  = nnData.(pField)(idx_NN_C1);
            
            valid_pts = isfinite(X_Truth) & isfinite(Y_Pred);
            X = X_Truth(valid_pts); Y = Y_Pred(valid_pts);
            
            ax = subplot(2, 2, pIdx);
            % Need at least 2 points to calculate correlation and regression
            if numel(X) >= 2
                scatter(X, Y, 15, [0.3 0.3 0.3], 'filled', 'MarkerFaceAlpha', 0.4);
                hold on;
                min_val = min([X; Y]); max_val = max([X; Y]);
                plot([min_val, max_val], [min_val, max_val], '--k', 'LineWidth', 1.5);
                
                p_fit = polyfit(X, Y, 1);
                x_fit = linspace(min_val, max_val, 100);
                plot(x_fit, polyval(p_fit, x_fit), '-b', 'LineWidth', 2.0);
                
                r_val = corr(X, Y); rmse_val = sqrt(mean((Y - X).^2));
                title(sprintf('%s (R=%.3f, RMSE=%.2f)', pField, r_val, rmse_val), 'FontSize', 14);
                xlim([min_val, max_val]); ylim([min_val, max_val]);
                axis equal; hold off;
            else
                title(sprintf('%s (Insufficient Data)', pField), 'FontSize', 14);
            end
            xlabel(sprintf('David Reference %s', pLabel), 'FontSize', 12, 'Interpreter', 'none');
            ylabel(sprintf('NN %s %s', modelLabel, pLabel), 'FontSize', 12, 'Interpreter', 'none');
            grid on;
        end
        outScat = fullfile(outBaseDir, sprintf('David_vs_%s_Scatter.png', safeLabel));
        exportgraphics(hFigScat, outScat, 'Resolution', 150);
        close(hFigScat);

        % --- 2.4 Hybrid Pairwise Diurnal Plots ---
        % NN (Blue): ALL Category 1 data (IQR Shading + Median)
        % David (Red): ALL valid David data (Small Scatter points + 1-hour IQR & Median)
        
        mVec_NN = month(nnData.dt);
        utH_NN  = hour(nnData.dt) + minute(nnData.dt)/60;
        
        mVec_D  = month(davidData.dt);
        utH_D   = hour(davidData.dt) + minute(davidData.dt)/60;
        
        % NN bins (15 min)
        binStep   = 0.25; 
        t_edges   = 0 : binStep : 24;
        t_centers = t_edges(1:end-1) + binStep/2;
        
        % David bins (1 hour) for accumulating enough points for IQR
        binStep_D   = 1.0; 
        t_edges_D   = 0 : binStep_D : 24;
        t_centers_D = t_edges_D(1:end-1) + binStep_D/2;

        monthNames = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
        
        for pIdx = 1:size(paramsToPlot, 1)
            pField = paramsToPlot{pIdx, 1};
            pLabel = paramsToPlot{pIdx, 2};
            
            hFigPD = figure('Visible', 'off', 'Position', [50, 50, 2000, 1200], 'Color', 'w');
            sgtitle(sprintf('Diurnal %s: David Ground Truth (Red) vs NN %s (Blue)', pField, modelLabel), ...
                'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');
                
            for mo = 1:12
                ax = subplot(3, 4, mo, 'Parent', hFigPD);
                hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
                title(ax, monthNames{mo});
                
                all_y_month = [];
                
                % 1. Process NN Data (All C1 for this month)
                idx_mo_NN = (mVec_NN == mo) & (nnData.qualityCategory == 1);
                t_NN = utH_NN(idx_mo_NN);
                y_NN = nnData.(pField)(idx_mo_NN);
                
                if ~isempty(t_NN)
                    [~, bins_NN] = histc(t_NN, t_edges);
                    p25 = nan(1, length(t_centers)); p50 = nan(1, length(t_centers)); p75 = nan(1, length(t_centers));
                    for b = 1:length(t_centers)
                        yb = y_NN(bins_NN == b);
                        if ~isempty(yb)
                            p25(b) = prctile(yb, 25); p50(b) = median(yb); p75(b) = prctile(yb, 75);
                        end
                    end
                    v_nn = ~isnan(p50);
                    if any(v_nn)
                        tc = t_centers(v_nn);
                        patch(ax, [tc, fliplr(tc)], [p25(v_nn), fliplr(p75(v_nn))], [0.15 0.35 0.85], ...
                            'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                        plot(ax, tc, p50(v_nn), 'Color', [0.15 0.35 0.85], 'LineWidth', 2.0, 'DisplayName', sprintf('NN %s (Median)', modelLabel));
                        all_y_month = [all_y_month; p25(v_nn)'; p75(v_nn)']; %#ok<AGROW>
                    end
                end
                
                % 2. Process David Data (All valid points for this month)
                idx_mo_D = (mVec_D == mo);
                t_D = utH_D(idx_mo_D);
                y_D = davidData.(pField)(idx_mo_D);
                
                valid_D = isfinite(y_D);
                t_D = t_D(valid_D); y_D = y_D(valid_D);
                
                if ~isempty(t_D)
                    % Reduced scatter size to 8 and alpha to 0.3 to prevent cluttering the IQR corridors
                    scatter(ax, t_D, y_D, 8, 'r', 'filled', 'MarkerFaceAlpha', 0.3, 'DisplayName', 'David Ref (Raw)');
                    all_y_month = [all_y_month; y_D]; %#ok<AGROW>
                    
                    % Compute wide-bin median and IQR for David (No spline interpolation)
                    [~, bins_D] = histc(t_D, t_edges_D);
                    p25_D = nan(1, length(t_centers_D));
                    p50_D = nan(1, length(t_centers_D));
                    p75_D = nan(1, length(t_centers_D));
                    
                    for b = 1:length(t_centers_D)
                        yb = y_D(bins_D == b);
                        if numel(yb) >= 3 % Need at least 3 points for meaningful IQR
                            p25_D(b) = prctile(yb, 25);
                            p50_D(b) = median(yb);
                            p75_D(b) = prctile(yb, 75);
                        elseif numel(yb) >= 1 % 1-2 points: just use median, no IQR bounds
                            p50_D(b) = median(yb);
                        end
                    end
                    
                    v_d = ~isnan(p50_D);
                    if any(v_d)
                        tc_d = t_centers_D(v_d);
                        
                        % Draw Red IQR Patch only where 25th and 75th percentiles exist
                        v_patch = ~isnan(p25_D) & ~isnan(p75_D);
                        if any(v_patch)
                            tc_patch = t_centers_D(v_patch);
                            patch(ax, [tc_patch, fliplr(tc_patch)], [p25_D(v_patch), fliplr(p75_D(v_patch))], 'r', ...
                                'FaceAlpha', 0.20, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                        end
                        
                        % Draw Red Median Line (naturally breaks where data is missing, no pchip)
                        plot(ax, tc_d, p50_D(v_d), 'Color', 'r', 'LineWidth', 2.0, 'DisplayName', 'David Ref (Median)');
                    end
                end
                
                % 3. Dynamic Axis Limits
                if numel(all_y_month) >= 2
                    y_min = prctile(all_y_month, 2);
                    y_max = prctile(all_y_month, 98);
                    yspan = max(1, y_max - y_min);
                    yl_min = y_min - yspan * 0.10;
                    yl_max = y_max + yspan * 0.15;
                    
                    if strcmp(pField, 'hmF2') || strcmp(pField, 'SlabT')
                        ylim(ax, [yl_min, yl_max]);
                    else
                        ylim(ax, [max(0, yl_min), yl_max]);
                    end
                else
                    ylim(ax, [0, 1]);
                end
                
                xlim(ax, [0, 24]);
                xticks(ax, 0:2:24); % Fixed 2-hour step for X-axis
                if mo == 1 || mo == 5 || mo == 9, ylabel(ax, pLabel, 'Interpreter', 'none'); end
                if mo > 8, xlabel(ax, 'Time (UT, hours)'); end
            end
            
            subplot(3,4,1); legend('Location', 'best');
            outPD = fullfile(outBaseDir, sprintf('David_vs_%s_Diurnal_%s.png', safeLabel, pField));
            exportgraphics(hFigPD, outPD, 'Resolution', 150);
            close(hFigPD);
        end
    end
    fprintf('All David comparison plots saved successfully.\n');
end