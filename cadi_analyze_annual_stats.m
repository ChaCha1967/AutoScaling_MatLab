function summaryDataArray = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts)
% CADI_ANALYZE_ANNUAL_STATS Scans all processed *_ion.mat files for a full year,
% compiles fast summary tables for MULTIPLE neural network models simultaneously, 
% computes pipeline & quality classification statistics for each, and exports 
% joint multi-model diurnal variation, correlation plots, and pairwise comparisons.

    if nargin < 4 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'forceRebuild'), opts.forceRebuild = false; end
    if ~isfield(opts, 'tecScaleFactor'), opts.tecScaleFactor = 1.0; end
    if ~isfield(opts, 'models')
        opts.models(1).netID = ''; 
        opts.models(1).label = 'base-model';
    end

    numModels = length(opts.models);
    sYear     = sprintf('%04d', targetYear);
    yearDir   = fullfile(outBaseDir, sStation, sYear);

    summaryDataArray = cell(numModels, 1);
    allSummariesExist = true;
    summaryPaths = cell(numModels, 1);

    for m = 1:numModels
        safeLabel = strrep(opts.models(m).label, '-', '_'); 
        safeLabel = strrep(safeLabel, ' ', '_');
        summaryPaths{m} = fullfile(outBaseDir, sprintf('CADI_Summary_%s_%s_%s.mat', sStation, sYear, safeLabel));
        if ~isfile(summaryPaths{m})
            allSummariesExist = false;
        end
    end

    % =====================================================================
    % STEP 1: LOAD OR BUILD FAST ANNUAL SUMMARY TABLES FOR ALL MODELS
    % =====================================================================
    if allSummariesExist && ~opts.forceRebuild
        fprintf('Loading existing annual summaries for all %d models...\n', numModels);
        for m = 1:numModels
            tmp = load(summaryPaths{m}, 'summaryData');
            summaryDataArray{m} = tmp.summaryData;
        end
    else
        fprintf('Scanning directory: %s for %d models...\n', yearDir, numModels);
        allFiles = dir(fullfile(yearDir, '*_ion.mat'));
        
        baseNames = erase({allFiles.name}, '_ion.mat');
        isMinuteFile = cellfun(@(s) length(s) == 10, baseNames);
        matFiles = allFiles(isMinuteFile);
        N = numel(matFiles);

        fprintf('Found %d minute *_ion.mat files. Extracting metrics...\n', N);

        fNames = {matFiles.name}';
        dtNums = nan(N, 1);
        
        MData = repmat(struct(), numModels, 1);
        for m = 1:numModels
            MData(m).nPtsV       = zeros(N, 1);
            MData(m).nPtsR       = zeros(N, 1);
            MData(m).foF2_unet   = nan(N, 1);
            MData(m).foF2        = nan(N, 1);
            MData(m).hmF2        = nan(N, 1);
            MData(m).TEC         = nan(N, 1);
            MData(m).H_scale     = nan(N, 1);
            MData(m).SlabT       = nan(N, 1);
            MData(m).devH        = nan(N, 1);
            MData(m).polStatus   = strings(N, 1);
            MData(m).v_hMin      = nan(N, 1);
            MData(m).v_hMax      = nan(N, 1);
            MData(m).v_hMean     = nan(N, 1);
            MData(m).v_maxJumpUp = nan(N, 1);
            MData(m).v_maxJumpDn = nan(N, 1);
            MData(m).v_roughness = nan(N, 1);
        end

        eRegionPx   = zeros(N, 1);
        fRegionPx   = zeros(N, 1);
        eMaxFreqMHz = nan(N, 1);

        varsToLoad = {'DT', 'X_tensor_filt', 'f_grid'};
        for m = 1:numModels
            netID = opts.models(m).netID;
            varsToLoad = [varsToLoad, ...
                {['ScaleV_unet', netID], ['ScaleR_polan', netID], ...
                 ['foF2_unet', netID], ['polanRes', netID]}]; %#ok<AGROW>
        end

        tTimer = tic;
        w = warning('off', 'MATLAB:load:variableNotFound');
        
        for i = 1:N
            fPath = fullfile(matFiles(i).folder, matFiles(i).name);
            try
                d = load(fPath, varsToLoad{:});

                if isfield(d, 'DT') && numel(d.DT) >= 6
                    dtNums(i) = datenum(double(d.DT(1:6)));
                end

                if isfield(d, 'X_tensor_filt') && ~isempty(d.X_tensor_filt)
                    ampFilt = double(d.X_tensor_filt(1:171, 1:92, 1));
                    eMask = ampFilt(30:49, :) > 0.15;
                    fMask = ampFilt(60:160, :) > 0.12;
                    eRegionPx(i) = nnz(eMask);
                    fRegionPx(i) = nnz(fMask);
                    if any(eMask(:)) && isfield(d, 'f_grid') && numel(d.f_grid) >= 92
                        colsE = find(any(eMask, 1));
                        eMaxFreqMHz(i) = double(d.f_grid(max(colsE)));
                    end
                end

                for m = 1:numModels
                    netID = opts.models(m).netID;
                    vScaleV = ['ScaleV_unet', netID];
                    vScaleR = ['ScaleR_polan', netID];
                    vfoF2   = ['foF2_unet', netID];
                    vRes    = ['polanRes', netID];

                    if isfield(d, vScaleV) && ~isempty(d.(vScaleV))
                        sv = double(d.(vScaleV));
                        MData(m).nPtsV(i)   = size(sv, 1);
                        MData(m).v_hMin(i)  = min(sv(:, 2));
                        MData(m).v_hMax(i)  = max(sv(:, 2));
                        MData(m).v_hMean(i) = mean(sv(:, 2));
                        if size(sv, 1) >= 2
                            dh = diff(sv(:, 2));
                            MData(m).v_maxJumpUp(i) = max(dh);
                            MData(m).v_maxJumpDn(i) = min(dh);
                            MData(m).v_roughness(i) = sum(abs(dh(dh < 0)));
                        else
                            MData(m).v_maxJumpUp(i) = 0; 
                            MData(m).v_maxJumpDn(i) = 0; 
                            MData(m).v_roughness(i) = 0;
                        end
                    end

                    if isfield(d, vfoF2) && ~isempty(d.(vfoF2))
                        MData(m).foF2_unet(i) = double(d.(vfoF2));
                    end

                    if isfield(d, vScaleR) && ~isempty(d.(vScaleR))
                        MData(m).nPtsR(i) = size(d.(vScaleR), 1);
                    end

                    if isfield(d, vRes) && isstruct(d.(vRes))
                        pr = d.(vRes);
                        if isfield(pr, 'foF2') && ~isempty(pr.foF2),       MData(m).foF2(i)      = double(pr.foF2);    end
                        if isfield(pr, 'hmF2') && ~isempty(pr.hmF2),       MData(m).hmF2(i)      = double(pr.hmF2);    end
                        if isfield(pr, 'H_scale') && ~isempty(pr.H_scale), MData(m).H_scale(i)   = double(pr.H_scale); end
                        if isfield(pr, 'dev_h') && ~isempty(pr.dev_h),     MData(m).devH(i)      = double(pr.dev_h);   end
                        if isfield(pr, 'status') && ~isempty(pr.status),   MData(m).polStatus(i) = string(pr.status);  end
                        
                        % Physically robust TEC recalculation
                        if isfield(pr, 'SlabT') && ~isempty(pr.SlabT)
                            MData(m).SlabT(i) = double(pr.SlabT);
                            if pr.SlabT > 0 && pr.foF2 > 0
                                MData(m).TEC(i) = 0.00124 * double(pr.SlabT) * (double(pr.foF2)^2);
                            end
                        end
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
        warning(w);

        for m = 1:numModels
            summaryData = struct();
            summaryData.station     = sStation;
            summaryData.year        = targetYear;
            summaryData.modelLabel  = opts.models(m).label;
            summaryData.fNames      = fNames;
            summaryData.dt          = datetime(dtNums, 'ConvertFrom', 'datenum');
            summaryData.nPtsV       = MData(m).nPtsV;
            summaryData.nPtsR       = MData(m).nPtsR;
            summaryData.foF2_unet   = MData(m).foF2_unet;
            summaryData.foF2        = MData(m).foF2;
            summaryData.hmF2        = MData(m).hmF2;
            summaryData.TEC         = MData(m).TEC;
            summaryData.H_scale     = MData(m).H_scale;
            summaryData.SlabT       = MData(m).SlabT;
            summaryData.devH        = MData(m).devH;
            summaryData.polStatus   = MData(m).polStatus;
            
            summaryData.eRegionPx   = eRegionPx;
            summaryData.fRegionPx   = fRegionPx;
            summaryData.eMaxFreqMHz = eMaxFreqMHz;
            
            summaryData.v_hMin      = MData(m).v_hMin;
            summaryData.v_hMax      = MData(m).v_hMax;
            summaryData.v_hMean     = MData(m).v_hMean;
            summaryData.v_maxJumpUp = MData(m).v_maxJumpUp;
            summaryData.v_maxJumpDn = MData(m).v_maxJumpDn;
            summaryData.v_roughness = MData(m).v_roughness;

            summaryDataArray{m} = summaryData;
        end
    end

    % Apply user-defined TEC Scale Factor directly
    if opts.tecScaleFactor ~= 1.0
        fprintf('Applying user-defined TEC Scale Factor: %g\n', opts.tecScaleFactor);
        for m = 1:numModels
            sD = summaryDataArray{m};
            sD.TEC = sD.TEC * opts.tecScaleFactor;
            summaryDataArray{m} = sD;
        end
    end

    colors = [
        0.85, 0.15, 0.15; % Model 1: Red
        0.15, 0.35, 0.85; % Model 2: Blue
        0.20, 0.80, 0.20; % Model 3: Green
        0.70, 0.20, 0.70; % Model 4: Magenta
        0.10, 0.80, 0.80  % Model 5: Cyan
    ];

    % =====================================================================
    % STEP 2 & 3: COVERAGE STATISTICS & AUTOMATIC QUALITY CLASSIFICATION
    % =====================================================================
    for m = 1:numModels
        sD = summaryDataArray{m};
        N_total = numel(sD.nPtsV);
        hasV    = sD.nPtsV > 0;
        hasR    = sD.nPtsR > 0;

        fprintf('\n====================================================================\n');
        fprintf('   MODEL: %s | CADI %s %d PIPELINE STATISTICS\n', opts.models(m).label, sStation, targetYear);
        fprintf('====================================================================\n');
        fprintf('1. Total Processed Sessions (*.mat)       : %7d (100.00%%)\n', N_total);
        fprintf('2. Virtual Profile Extracted (ScaleV > 0) : %7d (%6.2f%%)\n', nnz(hasV), 100*nnz(hasV)/N_total);
        fprintf('3. Real Profile Inverted (ScaleR > 0)     : %7d (%6.2f%%)\n', nnz(hasR), 100*nnz(hasR)/N_total);
        
        catID = zeros(N_total, 1);
        isNoV = ~hasV;
        isBlanketedEs = isNoV & (sD.eRegionPx >= 18 | sD.eMaxFreqMHz >= 3.2) & (sD.fRegionPx < 35);
        isMissedF2    = isNoV & (sD.fRegionPx >= 35);
        isWeakIono    = isNoV & ~isBlanketedEs & ~isMissedF2;

        catID(isBlanketedEs) = 4;
        catID(isWeakIono)    = 5;
        catID(isMissedF2)    = 6;

        isE_as_F2 = hasV & ((sD.hmF2 < 165) | (sD.v_hMean < 160 & (sD.v_hMax - sD.v_hMin) < 30));
        isJaggedOrBad = hasV & ~isE_as_F2 & ( ...
            ~hasR | ...
            sD.v_maxJumpUp > 45 | sD.v_maxJumpDn < -18 | sD.v_roughness > 30 | ...
            sD.hmF2 > 520 | sD.H_scale < 5 | sD.H_scale > 120 | ...
            sD.SlabT < 10  | sD.SlabT > 600);

        isGoodF2 = hasV & ~isE_as_F2 & ~isJaggedOrBad;

        catID(isGoodF2)      = 1;
        catID(isE_as_F2)     = 2;
        catID(isJaggedOrBad) = 3;

        summaryDataArray{m}.qualityCategory = catID;

        catNames = {
            '1. Realistic F2 Profile (Good)', ...
            '2. E / Es Misidentified as F2', ...
            '3. Jagged / Unrealistic Profile', ...
            '4. No Profile: Blanketing Es', ...
            '5. No Profile: Weak Ionosphere / Blackout', ...
            '6. No Profile: Missed Valid F-Region Trace'
        };

        fprintf('--- AUTOMATIC CLASSIFICATION ---\n');
        for c = 1:6
            cnt = nnz(catID == c);
            fprintf('  %-44s : %7d (%6.2f%%)\n', catNames{c}, cnt, 100*cnt/N_total);
        end

        summaryData = summaryDataArray{m};
        save(summaryPaths{m}, 'summaryData', '-v7.3');
    end

    % =====================================================================
    % SETUP FOR MULTI-GROUP PLOTTING
    % =====================================================================
    plotGroups = struct();
    plotGroups(1).name = ''; 
    plotGroups(1).allowedCats = 1;
    plotGroups(1).titleStr = '(Filtered: Good F2 Only)';
    
    plotGroups(2).name = '_AllExtracted';
    plotGroups(2).allowedCats = [1, 2, 3];
    plotGroups(2).titleStr = '(Raw: All Extracted Profiles)';

    paramsToPlot = {
        'foF2',      'foF2 (POLAN Real Profile, MHz)';
        'hmF2',      'hmF2 (km)';
        'TEC',       'TEC (TECU, 10^{16} m^{-2})';
        'SlabT',     'Slab Thickness (km)'
    };
    
    monthNames = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
    dtValid    = summaryDataArray{1}.dt; 
    mVec       = month(dtValid);
    utHours    = hour(dtValid) + minute(dtValid)/60 + second(dtValid)/3600;
    
    binStep    = 0.25; 
    t_edges    = 0 : binStep : 24;
    t_centers  = t_edges(1:end-1) + binStep/2;

    % =====================================================================
    % STEP 4: MULTI-MODEL DIURNAL PLOTS (OVERALL COMPARISON)
    % =====================================================================
    for g = 1:length(plotGroups)
        grpName  = plotGroups(g).name;
        grpCats  = plotGroups(g).allowedCats;
        grpTitle = plotGroups(g).titleStr;

        fprintf('\nGenerating Multi-Model Diurnal Plots for Group%s...\n', grpName);

        for pIdx = 1:size(paramsToPlot, 1)
            pField = paramsToPlot{pIdx, 1};
            pLabel = paramsToPlot{pIdx, 2};

            plotData = cell(12, numModels);
            all_y_bounds = [];
            
            for mo = 1:12
                idx_m = (mVec == mo);
                for m = 1:numModels
                    sD = summaryDataArray{m};
                    valid_idx = idx_m & ismember(sD.qualityCategory, grpCats);
                    t_vals = utHours(valid_idx);
                    y_vals = sD.(pField)(valid_idx);
                    
                    if isempty(t_vals), continue; end
                    
                    [~, bins] = histc(t_vals, t_edges);
                    p25 = nan(1, length(t_centers));
                    p50 = nan(1, length(t_centers));
                    p75 = nan(1, length(t_centers));
                    
                    for b = 1:length(t_centers)
                        y_b = y_vals(bins == b);
                        if ~isempty(y_b)
                            p25(b) = prctile(y_b, 25);
                            p50(b) = median(y_b);
                            p75(b) = prctile(y_b, 75);
                        end
                    end
                    
                    valid_b = ~isnan(p50);
                    plotData{mo, m} = struct('tc', t_centers(valid_b), 'p25', p25(valid_b), ...
                                             'p50', p50(valid_b), 'p75', p75(valid_b), 'valid', valid_b);
                                             
                    if any(valid_b)
                        all_y_bounds = [all_y_bounds, p25(valid_b), p75(valid_b)]; %#ok<AGROW>
                    end
                end
            end
            
            if ~isempty(all_y_bounds)
                y_min_bound = prctile(all_y_bounds, 2);  
                y_max_bound = prctile(all_y_bounds, 98); 
                y_span = y_max_bound - y_min_bound;
                if y_span == 0, y_span = 1; end
                
                calc_min = y_min_bound - y_span * 0.10;
                calc_max = y_max_bound + y_span * 0.15;
                
                if strcmp(pField, 'hmF2') || strcmp(pField, 'SlabT')
                    pYLim = [calc_min, calc_max];
                else
                    pYLim = [max(0, calc_min), calc_max]; 
                end
            else
                pYLim = [0, 1]; 
            end

            hFig = figure('Visible', 'off', 'Position', [50, 50, 2000, 1200], 'Color', 'w');
            sgtitle(sprintf('CADI %s %d - Multi-Model Diurnal Variation: %s\n%s', ...
                sStation, targetYear, pLabel, grpTitle), 'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');

            for mo = 1:12
                ax = subplot(3, 4, mo, 'Parent', hFig);
                hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
                title(ax, monthNames{mo}, 'Interpreter', 'none');
                
                for m = 1:numModels
                    if isempty(plotData{mo, m}), continue; end
                    pd = plotData{mo, m};
                    if ~any(pd.valid), continue; end
                    
                    c_idx = mod(m-1, size(colors,1)) + 1;
                    
                    x_patch = [pd.tc, fliplr(pd.tc)];
                    y_patch = [pd.p25, fliplr(pd.p75)];
                    patch(ax, x_patch, y_patch, colors(c_idx,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                    plot(ax, pd.tc, pd.p50, 'Color', colors(c_idx,:), 'LineWidth', 2.0, 'DisplayName', opts.models(m).label);
                end
                
                xlim(ax, [0, 24]);
                xticks(ax, 0:2:24);
                ylim(ax, pYLim);
                if mo == 1 || mo == 5 || mo == 9, ylabel(ax, pLabel, 'Interpreter', 'tex'); end
                if mo > 8, xlabel(ax, 'Time (UT, hours)'); end
            end
            subplot(3,4,1); legend('Location', 'best', 'Interpreter', 'none');

            outPlotPath = fullfile(outBaseDir, sprintf('CADI_%s_%d_MultiModel_Diurnal_%s%s.png', sStation, targetYear, pField, grpName));
            exportgraphics(hFig, outPlotPath, 'Resolution', 150);
            close(hFig);
        end
    end

    % =====================================================================
    % STEP 5: MULTI-MODEL CORRELATION PLOTS (foF2_Unet vs foF2_POLAN)
    % =====================================================================
    fprintf('\nGenerating Multi-Model Correlation Plots (Filtered: Good F2 Only)...\n');
    cols = ceil(sqrt(numModels));
    rows = ceil(numModels / cols);

    hFigCorr = figure('Visible', 'off', 'Position', [100, 100, 1800, 1200], 'Color', 'w');
    sgtitle(sprintf('CADI %s %d - Correlation: foF2 (U-Net) vs foF2 (POLAN)\n(Filtered: Good F2 Only)', sStation, targetYear), ...
        'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');

    for m = 1:numModels
        ax = subplot(rows, cols, m, 'Parent', hFigCorr);
        sD = summaryDataArray{m};
        
        validMask = (sD.qualityCategory == 1) & isfinite(sD.foF2) & isfinite(sD.foF2_unet);
        x_unet = sD.foF2_unet(validMask);
        y_pol  = sD.foF2(validMask);

        if isempty(x_unet), continue; end
        
        r_val    = corr(x_unet, y_pol);
        err_val  = y_pol - x_unet;
        rmse_val = sqrt(mean(err_val.^2));
        bias_val = mean(err_val);

        c_idx = mod(m-1, size(colors,1)) + 1;
        scatter(ax, x_unet, y_pol, 10, colors(c_idx,:), 'filled', 'MarkerFaceAlpha', 0.25);
        hold(ax, 'on');
        
        min_f = min([x_unet; y_pol]);
        max_f = max([x_unet; y_pol]);
        plot(ax, [min_f, max_f], [min_f, max_f], '--k', 'LineWidth', 1.5, 'DisplayName', '1:1 Ideal');

        p_fit      = polyfit(x_unet, y_pol, 1);
        x_fit_line = linspace(min_f, max_f, 100);
        y_fit_line = polyval(p_fit, x_fit_line);
        plot(ax, x_fit_line, y_fit_line, '-k', 'LineWidth', 2.0, 'DisplayName', sprintf('Fit: y = %.2fx + %.2f', p_fit(1), p_fit(2)));

        hold(ax, 'off'); grid(ax, 'on'); axis(ax, 'equal');
        xlim(ax, [min_f, max_f]); ylim(ax, [min_f, max_f]);
        
        xlabel(ax, 'foF2 (U-Net, MHz)', 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
        ylabel(ax, 'foF2 (POLAN, MHz)', 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
        title(ax, sprintf('%s\n(R=%.4f | RMSE=%.3f | Bias=%+.3f)', ...
            opts.models(m).label, r_val, rmse_val, bias_val), 'FontSize', 12, 'Interpreter', 'none');
        legend(ax, 'Location', 'southeast', 'FontSize', 9, 'Interpreter', 'none');
    end

    outCorrPath = fullfile(outBaseDir, sprintf('CADI_%s_%d_MultiModel_Correlation.png', sStation, targetYear));
    exportgraphics(hFigCorr, outCorrPath, 'Resolution', 150);
    close(hFigCorr);

    % =====================================================================
    % STEP 6: PAIRWISE COMPARISONS (BASE MODEL VS ALL OTHER MODELS)
    % Heatmap, ErrorHist, Scatter, and Pairwise Diurnal (IQR Corridors)
    % =====================================================================
    if numModels > 1
        fprintf('\n====================================================================\n');
        fprintf('   STEP 6: PAIRWISE COMPARISONS (Base Model vs Others)\n');
        fprintf('====================================================================\n');
        
        base_sD    = summaryDataArray{1};
        base_label = opts.models(1).label;
        catNamesShort = {'C1 (Good)', 'C2 (E/Es)', 'C3 (Jagged)', 'C4 (Es Block)', 'C5 (Weak)', 'C6 (Missed)', 'TOTAL'};
        
        for m = 2:numModels
            comp_sD    = summaryDataArray{m};
            comp_label = opts.models(m).label;
            fprintf('Processing Pairwise: %s vs %s...\n', base_label, comp_label);
            
            % --- 6.1 Heatmap (Quality Category Matrix) ---
            cat_base = base_sD.qualityCategory;
            cat_comp = comp_sD.qualityCategory;
            
            confMat = zeros(7, 7);
            for i = 1:6
                for j = 1:6
                    confMat(i, j) = sum(cat_base == i & cat_comp == j);
                end
            end
            confMat(7, 1:6) = sum(confMat(1:6, 1:6), 1);
            confMat(1:6, 7) = sum(confMat(1:6, 1:6), 2);
            confMat(7, 7)   = sum(confMat(7, 1:6));
            
            hFigHM = figure('Visible', 'off', 'Position', [100, 100, 1200, 1000], 'Color', 'w');
            imagesc(confMat);
            colormap('parula'); colorbar;
            
            max_val = max(confMat(:));
            for i = 1:7
                for j = 1:7
                    val = confMat(i,j);
                    txtColor = 'w';
                    if val > max_val * 0.5, txtColor = 'k'; end
                    if val == 0, txtColor = [0.8 0.8 0.8]; end % Grey out zeros for cleaner look
                    text(j, i, num2str(val), 'HorizontalAlignment', 'center', ...
                        'Color', txtColor, 'FontWeight', 'bold', 'FontSize', 12);
                end
            end
            
            xticks(1:7); yticks(1:7);
            xticklabels(catNamesShort); yticklabels(catNamesShort);
            xlabel(sprintf('Compared Model: %s', comp_label), 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
            ylabel(sprintf('Base Model: %s', base_label), 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
            title(sprintf('Quality Category Matrix: %s vs %s', base_label, comp_label), 'FontSize', 16, 'Interpreter', 'none');
            
            % Draw internal grid lines for the 7x7 matrix
            hold on;
            for k = 0.5:1:7.5
                plot([0.5, 7.5], [k, k], 'k-', 'LineWidth', 0.5);
                plot([k, k], [0.5, 7.5], 'k-', 'LineWidth', 0.5);
            end
            hold off;

            outHM = fullfile(outBaseDir, sprintf('Heatmap_Cat_%s_vs_%s.png', base_label, comp_label));
            exportgraphics(hFigHM, outHM, 'Resolution', 150);
            close(hFigHM);
            
            % --- Prep Data for ErrorHist and Scatter ---
            % We only compare physical values where both networks produced a Category 1 profile
            validPair = (cat_base == 1) & (cat_comp == 1);
            
            % --- 6.2 ErrorHist (Histograms of Delta) ---
            hFigEH = figure('Visible', 'off', 'Position', [100, 100, 1400, 1200], 'Color', 'w');
            sgtitle(sprintf('Error Distribution: %s vs %s', base_label, comp_label), 'FontSize', 18, 'Interpreter', 'none');
            
            for pIdx = 1:size(paramsToPlot, 1)
                pField = paramsToPlot{pIdx, 1};
                pLabel = paramsToPlot{pIdx, 2};
                % Extract unit string from label for clean display
                unitStr = regexp(pLabel, '\((.*?)\)', 'tokens');
                if ~isempty(unitStr), unitStr = ['[', unitStr{1}{1}, ']']; else, unitStr = ''; end
                if contains(unitStr, 'POLAN'), unitStr = '[MHz]'; end
                
                b_val = base_sD.(pField)(validPair);
                c_val = comp_sD.(pField)(validPair);
                
                valid_pts = isfinite(b_val) & isfinite(c_val);
                delta = b_val(valid_pts) - c_val(valid_pts); % Delta = Base - Comp
                
                subplot(2, 2, pIdx);
                if ~isempty(delta)
                    histogram(delta, 100, 'FaceColor', [0.4 0.6 0.9], 'EdgeColor', 'none');
                    hold on;
                    xline(0, 'k-', 'LineWidth', 1.5);
                    xline(mean(delta), 'r--', 'LineWidth', 2.0);
                    hold off;
                    title(sprintf('\\Delta %s (Bias=%+.2f, MAE=%.2f)', pField, mean(delta), mean(abs(delta))), 'FontSize', 14);
                else
                    title(sprintf('\\Delta %s (No Valid Data)', pField), 'FontSize', 14);
                end
                xlabel(sprintf('%s - %s %s', base_label, comp_label, unitStr), 'FontSize', 12, 'Interpreter', 'none');
                ylabel('Count', 'FontSize', 12);
                grid on;
            end
            outEH = fullfile(outBaseDir, sprintf('ErrorHist_%s_vs_%s.png', base_label, comp_label));
            exportgraphics(hFigEH, outEH, 'Resolution', 150);
            close(hFigEH);
            
            % --- 6.3 Scatter (Pearson Regression) ---
            hFigScat = figure('Visible', 'off', 'Position', [100, 100, 1400, 1200], 'Color', 'w');
            sgtitle(sprintf('Regression Analysis: %s vs %s', base_label, comp_label), 'FontSize', 18, 'Interpreter', 'none');
            
            for pIdx = 1:size(paramsToPlot, 1)
                pField = paramsToPlot{pIdx, 1};
                pLabel = paramsToPlot{pIdx, 2};
                unitStr = regexp(pLabel, '\((.*?)\)', 'tokens');
                if ~isempty(unitStr), unitStr = ['[', unitStr{1}{1}, ']']; else, unitStr = ''; end
                if contains(unitStr, 'POLAN'), unitStr = '[MHz]'; end
                
                Y = base_sD.(pField)(validPair); % Base on Y-axis
                X = comp_sD.(pField)(validPair); % Comp on X-axis
                
                valid_pts = isfinite(X) & isfinite(Y);
                X = X(valid_pts); Y = Y(valid_pts);
                
                ax = subplot(2, 2, pIdx);
                if ~isempty(X)
                    scatter(X, Y, 4, [0.3 0.5 0.9], 'filled', 'MarkerFaceAlpha', 0.25);
                    hold on;
                    
                    min_val = min([X; Y]); max_val = max([X; Y]);
                    plot([min_val, max_val], [min_val, max_val], '--k', 'LineWidth', 1.5);
                    
                    p_fit = polyfit(X, Y, 1);
                    x_fit = linspace(min_val, max_val, 100);
                    plot(x_fit, polyval(p_fit, x_fit), '-r', 'LineWidth', 2.0);
                    
                    r_val = corr(X, Y);
                    rmse_val = sqrt(mean((Y - X).^2));
                    
                    title(sprintf('%s (R=%.3f, RMSE=%.2f)', pField, r_val, rmse_val), 'FontSize', 14);
                    xlim([min_val, max_val]); ylim([min_val, max_val]);
                    axis equal;
                else
                    title(sprintf('%s (No Valid Data)', pField), 'FontSize', 14);
                end
                xlabel(sprintf('%s %s', comp_label, unitStr), 'FontSize', 12, 'Interpreter', 'none');
                ylabel(sprintf('%s %s', base_label, unitStr), 'FontSize', 12, 'Interpreter', 'none');
                grid on;
            end
            outScat = fullfile(outBaseDir, sprintf('Scatter_%s_vs_%s.png', base_label, comp_label));
            exportgraphics(hFigScat, outScat, 'Resolution', 150);
            close(hFigScat);

            % --- 6.4 Pairwise Diurnal (IQR Corridors) ---
            % We will generate this ONLY for Group 1 (Good F2 profiles) to keep pairwise comparisons clean.
            for pIdx = 1:size(paramsToPlot, 1)
                pField = paramsToPlot{pIdx, 1};
                pLabel = paramsToPlot{pIdx, 2};
                
                plotData = cell(12, 2); % 2 models: Base and Comp
                all_y_bounds = [];
                
                for mo = 1:12
                    idx_m = (mVec == mo);
                    for pairIdx = 1:2
                        if pairIdx == 1, current_sD = base_sD; else, current_sD = comp_sD; end
                        
                        v_idx = idx_m & (current_sD.qualityCategory == 1);
                        t_vals = utHours(v_idx);
                        y_vals = current_sD.(pField)(v_idx);
                        
                        if isempty(t_vals), continue; end
                        
                        [~, bins] = histc(t_vals, t_edges);
                        p25 = nan(1, length(t_centers));
                        p50 = nan(1, length(t_centers));
                        p75 = nan(1, length(t_centers));
                        
                        for b = 1:length(t_centers)
                            y_b = y_vals(bins == b);
                            if ~isempty(y_b)
                                p25(b) = prctile(y_b, 25);
                                p50(b) = median(y_b);
                                p75(b) = prctile(y_b, 75);
                            end
                        end
                        
                        valid_b = ~isnan(p50);
                        plotData{mo, pairIdx} = struct('tc', t_centers(valid_b), 'p25', p25(valid_b), ...
                                                 'p50', p50(valid_b), 'p75', p75(valid_b), 'valid', valid_b);
                                                 
                        if any(valid_b)
                            all_y_bounds = [all_y_bounds, p25(valid_b), p75(valid_b)]; %#ok<AGROW>
                        end
                    end
                end
                
                if ~isempty(all_y_bounds)
                    y_min_bound = prctile(all_y_bounds, 2);  
                    y_max_bound = prctile(all_y_bounds, 98); 
                    y_span = y_max_bound - y_min_bound;
                    if y_span == 0, y_span = 1; end
                    
                    calc_min = y_min_bound - y_span * 0.10;
                    calc_max = y_max_bound + y_span * 0.15;
                    
                    if strcmp(pField, 'hmF2') || strcmp(pField, 'SlabT')
                        pYLim = [calc_min, calc_max];
                    else
                        pYLim = [max(0, calc_min), calc_max]; 
                    end
                else
                    pYLim = [0, 1]; 
                end

                hFigPD = figure('Visible', 'off', 'Position', [50, 50, 2000, 1200], 'Color', 'w');
                sgtitle(sprintf('Pairwise Diurnal %s: %s (Base) vs %s', pField, base_label, comp_label), ...
                    'FontSize', 16, 'FontWeight', 'bold', 'Interpreter', 'none');

                pairColors = [0.85 0.15 0.15; 0.15 0.35 0.85]; % Red for Base, Blue for Comp
                pairLabels = {base_label, comp_label};
                
                for mo = 1:12
                    ax = subplot(3, 4, mo, 'Parent', hFigPD);
                    hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
                    title(ax, monthNames{mo}, 'Interpreter', 'none');
                    
                    for pairIdx = 1:2
                        if isempty(plotData{mo, pairIdx}), continue; end
                        pd = plotData{mo, pairIdx};
                        if ~any(pd.valid), continue; end
                        
                        x_patch = [pd.tc, fliplr(pd.tc)];
                        y_patch = [pd.p25, fliplr(pd.p75)];
                        patch(ax, x_patch, y_patch, pairColors(pairIdx,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                        plot(ax, pd.tc, pd.p50, 'Color', pairColors(pairIdx,:), 'LineWidth', 2.0, 'DisplayName', pairLabels{pairIdx});
                    end
                    
                    xlim(ax, [0, 24]);
                    xticks(ax, 0:2:24);
                    ylim(ax, pYLim);
                    if mo == 1 || mo == 5 || mo == 9, ylabel(ax, pLabel, 'Interpreter', 'tex'); end
                    if mo > 8, xlabel(ax, 'Time (UT, hours)'); end
                end
                subplot(3,4,1); legend('Location', 'best', 'Interpreter', 'none');

                outPD = fullfile(outBaseDir, sprintf('Diurnal_%s_%s_vs_%s.png', pField, base_label, comp_label));
                exportgraphics(hFigPD, outPD, 'Resolution', 150);
                close(hFigPD);
            end
        end
    end

    fprintf('All plots saved successfully.\n');
end