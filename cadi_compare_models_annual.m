% function cadi_compare_models_annual(files, labels, outDir, sStation, yearStr)
% % CADI_COMPARE_MODELS_ANNUAL - Script to compare N neural networks (1 base + M compared)
% % 
% % Input parameters:
% %   files    - cell array of paths to CADI_Summary_...mat files (first file is the BASE model)
% %   labels   - cell array of model names for plots (e.g., {'6-CH', '1-CH', '3-CH'})
% %   outDir   - directory to save reports and PNGs
% %   sStation - Station code (e.g., 'RB')
% %   yearStr  - Year as a string (e.g., '2008')
% 
%     % --- 1. INPUT VALIDATION AND SETUP ---
%     if nargin < 1 || isempty(files)
%         % Default fallback for debugging
%         files = {
%             'n:\cadi_out_test\CADI_Summary_RB_2008_6ch.mat', ...
%             'n:\cadi_out_test_1ch\CADI_Summary_RB_2008_1ch.mat'
%         };
%         labels = {'6-CH', '1-CH'};
%         outDir = 'n:\cadi_out_comparison\';
%         sStation = 'RB';
%         yearStr = '2008';
%     end
% 
%     if ~isfolder(outDir), mkdir(outDir); end
% 
%     numModels = length(files);
%     if numModels < 2
%         error('At least 2 files are required for comparison.');
%     end
% 
%     % Logging configuration
%     logFile = fullfile(outDir, sprintf('Comparison_%s_%s.log', sStation, yearStr));
%     if isfile(logFile), delete(logFile); end
%     diary(logFile); diary on;
%     cleanUp = onCleanup(@() diary('off'));
% 
%     fprintf('============================================================\n');
%     fprintf(' CADI ANNUAL MODELS COMPARISON: %s %s\n', sStation, yearStr);
%     fprintf(' Base Model : %s (%s)\n', labels{1}, files{1});
%     for m = 2:numModels
%         fprintf(' Compared to: %s (%s)\n', labels{m}, files{m});
%     end
%     fprintf('============================================================\n\n');
% 
%     % --- 2. DATA LOADING AND SYNCHRONIZATION ---
%     fprintf('Loading data and synchronizing timestamps...\n');
%     data = cell(numModels, 1);
%     common_dt = [];
% 
%     for m = 1:numModels
%         tmp = load(files{m});
%         if isfield(tmp, 'summaryData')
%             data{m} = tmp.summaryData;
%         else
%             error('Structure ''summaryData'' not found in file %s.', files{m});
%         end
% 
%         if m == 1
%             common_dt = data{m}.dt;
%         else
%             common_dt = intersect(common_dt, data{m}.dt); % Find common timestamps
%         end
%     end
% 
%     % Keep only common sessions across all loaded structures
%     for m = 1:numModels
%         [~, idx] = ismember(common_dt, data{m}.dt);
%         % Filter all vector fields within the structure
%         fields = fieldnames(data{m});
%         for f = 1:length(fields)
%             fn = fields{f};
%             if size(data{m}.(fn), 1) == length(data{m}.dt)
%                 data{m}.(fn) = data{m}.(fn)(idx, :);
%             end
%         end
%     end
% 
%     N_total = length(common_dt);
%     fprintf('Synchronized successfully. Total common sessions: %d\n\n', N_total);
% 
%     % Color palette (1: Base=Black, 2: Red, 3: Blue, 4: Green, 5: Magenta)
%     colors = [0 0 0; 0.8 0.1 0.1; 0.1 0.3 0.8; 0.1 0.7 0.2; 0.7 0.1 0.7]; 
%     params = {'foF2', 'hmF2', 'TEC', 'SlabT'};
%     units = {'MHz', 'km', 'TECU', 'km'};
% 
%     % --- 3. GROUP DIURNAL PLOTS (ALL MODELS COMBINED) ---
%     fprintf('Generating Group Diurnal Plots (All Models)...\n');
%     timeHours = hour(common_dt) + minute(common_dt)/60;
%     months = month(common_dt);
%     t_edges = 0:0.25:24; % 15-minute bins
%     t_centers = t_edges(1:end-1) + 0.125;
%     monthNames = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
% 
%     for p = 1:length(params)
%         paramName = params{p};
%         fig = figure('Visible', 'off', 'Position', [100 100 1600 1000]);
% 
%         for mo = 1:12
%             subplot(3, 4, mo); hold on; grid on; box on;
%             title(sprintf('%s', monthNames{mo}));
%             idx_m = (months == mo);
% 
%             % Plot IQR bounds and medians for each model
%             for m = 1:numModels
%                 % Only use valid profiles (qualityCategory 1) and positive values
%                 valid_idx = idx_m & (data{m}.qualityCategory == 1) & (data{m}.(paramName) > 0);
%                 x_vals = timeHours(valid_idx);
%                 y_vals = data{m}.(paramName)(valid_idx);
% 
%                 if isempty(x_vals), continue; end
% 
%                 [~, bins] = histc(x_vals, t_edges);
%                 p25 = nan(1, length(t_centers));
%                 p50 = nan(1, length(t_centers));
%                 p75 = nan(1, length(t_centers));
% 
%                 for b = 1:length(t_centers)
%                     y_b = y_vals(bins == b);
%                     if ~isempty(y_b)
%                         p25(b) = prctile(y_b, 25);
%                         p50(b) = median(y_b);
%                         p75(b) = prctile(y_b, 75);
%                     end
%                 end
% 
%                 % Clean up NaNs for patch rendering
%                 valid_b = ~isnan(p50);
%                 if any(valid_b)
%                     tc = t_centers(valid_b);
%                     % IQR Patch (Shading)
%                     x_patch = [tc, fliplr(tc)];
%                     y_patch = [p25(valid_b), fliplr(p75(valid_b))];
%                     patch(x_patch, y_patch, colors(m,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
%                     % Median line
%                     plot(tc, p50(valid_b), 'Color', colors(m,:), 'LineWidth', 2, 'DisplayName', labels{m});
%                 end
%             end
%             xlim([0 24]);
%             if mo == 1 || mo == 5 || mo == 9, ylabel(sprintf('%s (%s)', paramName, units{p})); end
%             if mo > 8, xlabel('Time (UT, hours)'); end
%         end
%         % Legend on the first panel
%         subplot(3,4,1); legend('Location', 'best');
% 
%         sgtitle(sprintf('Group Diurnal Variations (Medians & IQR): %s (%s %s)', paramName, sStation, yearStr));
%         saveas(fig, fullfile(outDir, sprintf('Group_Diurnal_%s_%s_%s.png', paramName, sStation, yearStr)));
%         close(fig);
%     end
% 
%     % --- 4. PAIRWISE COMPARISON (BASE vs MODEL M) ---
%     bCat = data{1}.qualityCategory; % Base model categories
% 
%     for m = 2:numModels
%         fprintf('\n============================================================\n');
%         fprintf(' CROSS-ANALYSIS: BASE [%s] vs COMPARED [%s]\n', labels{1}, labels{m});
%         fprintf('============================================================\n');
% 
%         cCat = data{m}.qualityCategory;
% 
%         % 4.1 Quality Category Matrix (Confusion Matrix)
%         confMat = zeros(6, 6);
%         for i = 1:6
%             for j = 1:6
%                 confMat(i, j) = sum(bCat == i & cCat == j);
%             end
%         end
% 
%         fprintf('\n--- QUALITY CATEGORY MIGRATION ---\n');
%         fprintf('Rows (Y): Base [%s] | Columns (X): Compared [%s]\n', labels{1}, labels{m});
%         fprintf('        C1      C2      C3      C4      C5      C6    | TOTAL\n');
%         fprintf('-----------------------------------------------------------------\n');
%         for i = 1:6
%             fprintf(' C%d |', i);
%             for j = 1:6
%                 fprintf(' %6d', confMat(i,j));
%             end
%             fprintf('  | %6d\n', sum(confMat(i,:)));
%         end
%         fprintf('-----------------------------------------------------------------\n');
%         fprintf('TOT |');
%         for j = 1:6
%             fprintf(' %6d', sum(confMat(:,j)));
%         end
%         fprintf('  | %6d\n\n', N_total);
% 
%         % Render Heatmap
%         figMat = figure('Visible', 'off', 'Position', [100 100 800 600]);
%         h = heatmap( {'C1 (Good)', 'C2 (E/Es)', 'C3 (Jagged)', 'C4 (Es Block)', 'C5 (Weak)', 'C6 (Missed)'}, ...
%                      {'C1 (Good)', 'C2 (E/Es)', 'C3 (Jagged)', 'C4 (Es Block)', 'C5 (Weak)', 'C6 (Missed)'}, ...
%                      confMat, 'Colormap', parula, 'CellLabelFormat', '%d');
%         h.Title = sprintf('Quality Category Matrix: %s vs %s', labels{1}, labels{m});
%         h.XLabel = sprintf('Compared Model: %s', labels{m});
%         h.YLabel = sprintf('Base Model: %s', labels{1});
%         saveas(figMat, fullfile(outDir, sprintf('Heatmap_Cat_%s_vs_%s.png', labels{1}, labels{m})));
%         close(figMat);
% 
%         % 4.2 Physical Metrics and Plots (Intersection where BOTH are Cat 1)
%         valid_both = (bCat == 1) & (cCat == 1);
%         N_valid = sum(valid_both);
%         fprintf('--- PHYSICAL PARAMETERS CROSS-STATISTICS (N = %d, %.1f%%) ---\n', N_valid, N_valid/N_total*100);
% 
%         figScat = figure('Visible', 'off', 'Position', [100 100 1200 1000]);
%         figHist = figure('Visible', 'off', 'Position', [100 100 1200 1000]);
% 
%         for p = 1:length(params)
%             paramName = params{p};
%             valB = data{1}.(paramName)(valid_both);
%             valC = data{m}.(paramName)(valid_both);
% 
%             % Remove NaNs and zeros just in case
%             idx_good = ~isnan(valB) & ~isnan(valC) & (valB > 0) & (valC > 0);
%             valB = valB(idx_good);
%             valC = valC(idx_good);
%             delta = valB - valC;
% 
%             Bias = mean(delta);
%             MAE = mean(abs(delta));
%             RMSE = sqrt(mean(delta.^2));
%             R_mat = corrcoef(valB, valC);
%             R = R_mat(1,2);
% 
%             fprintf('%-6s (%-4s) : Bias = %+7.3f, MAE = %7.3f, RMSE = %7.3f, R = %.4f\n', ...
%                 paramName, units{p}, Bias, MAE, RMSE, R);
% 
%             % Scatter Plot 1-to-1
%             figure(figScat); subplot(2, 2, p); hold on; grid on; box on;
%             scatter(valC, valB, 5, colors(m,:), 'filled', 'MarkerFaceAlpha', 0.1); % X: Compared, Y: Base
%             minV = min([valB; valC]); maxV = max([valB; valC]);
%             plot([minV maxV], [minV maxV], 'k--', 'LineWidth', 1.5); % 1:1 Ideal Line
% 
%             pFit = polyfit(valC, valB, 1);
%             plot([minV maxV], polyval(pFit, [minV maxV]), 'r-', 'LineWidth', 2); % Regression Line
% 
%             title(sprintf('%s (R=%.3f, RMSE=%.2f)', paramName, R, RMSE));
%             xlabel(sprintf('%s [%s]', labels{m}, units{p}));
%             ylabel(sprintf('%s [%s]', labels{1}, units{p}));
% 
%             % Histogram Plot
%             figure(figHist); subplot(2, 2, p); hold on; grid on; box on;
%             histogram(delta, 100, 'FaceColor', colors(m,:), 'EdgeColor', 'none');
%             xline(0, 'k-', 'LineWidth', 2);
%             xline(Bias, 'r--', 'LineWidth', 2);
%             title(sprintf('\\Delta %s (Bias=%+.2f, MAE=%.2f)', paramName, Bias, MAE));
%             xlabel(sprintf('%s - %s [%s]', labels{1}, labels{m}, units{p}));
%             ylabel('Count');
%         end
% 
%         sgtitle(figScat, sprintf('Regression Analysis: %s vs %s', labels{1}, labels{m}));
%         saveas(figScat, fullfile(outDir, sprintf('Scatter_%s_vs_%s.png', labels{1}, labels{m})));
%         close(figScat);
% 
%         sgtitle(figHist, sprintf('Error Distribution: %s vs %s', labels{1}, labels{m}));
%         saveas(figHist, fullfile(outDir, sprintf('ErrorHist_%s_vs_%s.png', labels{1}, labels{m})));
%         close(figHist);
% 
%         % 4.3 Pairwise Diurnal Plots (with scatter clouds)
%         for p = 1:length(params)
%             paramName = params{p};
%             figDiur = figure('Visible', 'off', 'Position', [100 100 1600 1000]);
% 
%             for mo = 1:12
%                 subplot(3, 4, mo); hold on; grid on; box on;
%                 title(monthNames{mo});
%                 idx_m = (months == mo) & valid_both;
% 
%                 t_vals = timeHours(idx_m);
%                 valB = data{1}.(paramName)(idx_m);
%                 valC = data{m}.(paramName)(idx_m);
% 
%                 % Base cloud (Light gray)
%                 scatter(t_vals, valB, 3, [0.7 0.7 0.7], 'filled', 'MarkerFaceAlpha', 0.2);
%                 % Compared cloud (Colored)
%                 scatter(t_vals, valC, 3, colors(m,:), 'filled', 'MarkerFaceAlpha', 0.2);
% 
%                 % Medians
%                 [~, bins] = histc(t_vals, t_edges);
%                 p50B = nan(1, length(t_centers));
%                 p50C = nan(1, length(t_centers));
%                 for b = 1:length(t_centers)
%                     if any(bins == b)
%                         p50B(b) = median(valB(bins == b));
%                         p50C(b) = median(valC(bins == b));
%                     end
%                 end
% 
%                 plot(t_centers, p50B, 'k-', 'LineWidth', 2, 'DisplayName', labels{1});
%                 plot(t_centers, p50C, 'Color', colors(m,:), 'LineWidth', 2, 'DisplayName', labels{m});
% 
%                 xlim([0 24]);
%                 if mo == 1 || mo == 5 || mo == 9, ylabel(sprintf('%s (%s)', paramName, units{p})); end
%                 if mo > 8, xlabel('Time (UT)'); end
%             end
%             subplot(3,4,1); legend('Location', 'best', 'AutoUpdate', 'off');
%             sgtitle(figDiur, sprintf('Pairwise Diurnal %s: %s (Base) vs %s', paramName, labels{1}, labels{m}));
%             saveas(figDiur, fullfile(outDir, sprintf('Diurnal_%s_%s_vs_%s.png', paramName, labels{1}, labels{m})));
%             close(figDiur);
%         end
%     end
% 
%     fprintf('\n============================================================\n');
%     fprintf(' ALL TASKS COMPLETED. RESULTS SAVED TO: %s\n', outDir);
%     fprintf('============================================================\n');
% end




% function cadi_compare_models_annual(files, labels, outDir, sStation, yearStr)
% % CADI_COMPARE_MODELS_ANNUAL - Script to compare N neural networks (1 base + M compared)
% % 
% % Input parameters:
% %   files    - cell array of paths to CADI_Summary_...mat files (first file is the BASE model)
% %   labels   - cell array of model names for plots (e.g., {'6-CH', '1-CH', '3-CH'})
% %   outDir   - directory to save reports and PNGs
% %   sStation - Station code (e.g., 'RB')
% %   yearStr  - Year as a string (e.g., '2008')
% 
%     % --- 1. INPUT VALIDATION AND SETUP ---
%     if nargin < 1 || isempty(files)
%         % Default fallback for debugging
%         files = {
%             'N:\cadi_out_test\CADI_Summary_RB_2008_6ch.mat', ...
%             'N:\cadi_out_test_1ch\CADI_Summary_RB_2008_1ch.mat'
%         };
%         labels = {'6-CH', '1-CH'};
%         outDir = 'N:\cadi_out_comparison\';
%         sStation = 'RB';
%         yearStr = '2008';
%     end
% 
%     if ~isfolder(outDir), mkdir(outDir); end
% 
%     numModels = length(files);
%     if numModels < 2
%         error('At least 2 files are required for comparison.');
%     end
% 
%     % Logging configuration
%     logFile = fullfile(outDir, sprintf('Comparison_%s_%s.log', sStation, yearStr));
%     if isfile(logFile), delete(logFile); end
%     diary(logFile); diary on;
%     cleanUp = onCleanup(@() diary('off'));
% 
%     fprintf('============================================================\n');
%     fprintf(' CADI ANNUAL MODELS COMPARISON: %s %s\n', sStation, yearStr);
%     fprintf(' Base Model : %s (%s)\n', labels{1}, files{1});
%     for m = 2:numModels
%         fprintf(' Compared to: %s (%s)\n', labels{m}, files{m});
%     end
%     fprintf('============================================================\n\n');
% 
%     % --- 2. DATA LOADING AND SYNCHRONIZATION ---
%     fprintf('Loading data and synchronizing timestamps...\n');
%     data = cell(numModels, 1);
%     common_dt = [];
% 
%     for m = 1:numModels
%         tmp = load(files{m});
%         if isfield(tmp, 'summaryData')
%             data{m} = tmp.summaryData;
%         else
%             error('Structure ''summaryData'' not found in file %s.', files{m});
%         end
% 
%         if m == 1
%             common_dt = data{m}.dt;
%         else
%             common_dt = intersect(common_dt, data{m}.dt); % Find common timestamps
%         end
%     end
% 
%     % Keep only common sessions across all loaded structures
%     for m = 1:numModels
%         [~, idx] = ismember(common_dt, data{m}.dt);
%         % Filter all vector fields within the structure
%         fields = fieldnames(data{m});
%         for f = 1:length(fields)
%             fn = fields{f};
%             if size(data{m}.(fn), 1) == length(data{m}.dt)
%                 data{m}.(fn) = data{m}.(fn)(idx, :);
%             end
%         end
%     end
% 
%     N_total = length(common_dt);
%     fprintf('Synchronized successfully. Total common sessions: %d\n\n', N_total);
% 
%     % Color palette setup
%     % 1: Base = Red, 2: Comp1 = Blue, 3: Comp2 = Green, 4: Comp3 = Magenta
%     colors = [
%         0.85, 0.15, 0.15; % Base (Red)
%         0.15, 0.35, 0.85; % Compared 1 (Blue)
%         0.20, 0.80, 0.20; % Compared 2 (Green / Salad)
%         0.70, 0.20, 0.70; % Compared 3 (Magenta)
%         0.10, 0.80, 0.80  % Compared 4 (Cyan)
%     ]; 
% 
%     params = {'foF2', 'hmF2', 'TEC', 'SlabT'};
%     units = {'MHz', 'km', 'TECU', 'km'};
% 
%     % --- 3. GROUP DIURNAL PLOTS (ALL MODELS COMBINED - MEDIANS + IQR) ---
%     fprintf('Generating Group Diurnal Plots (All Models)...\n');
%     timeHours = hour(common_dt) + minute(common_dt)/60;
%     months = month(common_dt);
%     t_edges = 0:0.25:24; % 15-minute bins
%     t_centers = t_edges(1:end-1) + 0.125;
%     monthNames = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
% 
%     for p = 1:length(params)
%         paramName = params{p};
%         fig = figure('Visible', 'off', 'Position', [100 100 1600 1000]);
% 
%         for mo = 1:12
%             subplot(3, 4, mo); hold on; grid on; box on;
%             title(sprintf('%s', monthNames{mo}));
%             idx_m = (months == mo);
% 
%             % Plot IQR bounds and medians for each model
%             for m = 1:numModels
%                 % Only use valid profiles (Cat 1) and positive values
%                 valid_idx = idx_m & (data{m}.qualityCategory == 1) & (data{m}.(paramName) > 0);
%                 x_vals = timeHours(valid_idx);
%                 y_vals = data{m}.(paramName)(valid_idx);
% 
%                 if isempty(x_vals), continue; end
% 
%                 [~, bins] = histc(x_vals, t_edges);
%                 p25 = nan(1, length(t_centers));
%                 p50 = nan(1, length(t_centers));
%                 p75 = nan(1, length(t_centers));
% 
%                 for b = 1:length(t_centers)
%                     y_b = y_vals(bins == b);
%                     if ~isempty(y_b)
%                         p25(b) = prctile(y_b, 25);
%                         p50(b) = median(y_b);
%                         p75(b) = prctile(y_b, 75);
%                     end
%                 end
% 
%                 valid_b = ~isnan(p50);
%                 if any(valid_b)
%                     tc = t_centers(valid_b);
%                     % IQR Patch (Shading)
%                     x_patch = [tc, fliplr(tc)];
%                     y_patch = [p25(valid_b), fliplr(p75(valid_b))];
%                     patch(x_patch, y_patch, colors(m,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
%                     % Median line
%                     plot(tc, p50(valid_b), 'Color', colors(m,:), 'LineWidth', 2, 'DisplayName', labels{m});
%                 end
%             end
%             xlim([0 24]);
%             if mo == 1 || mo == 5 || mo == 9, ylabel(sprintf('%s (%s)', paramName, units{p})); end
%             if mo > 8, xlabel('Time (UT, hours)'); end
%         end
%         % Legend on the first panel
%         subplot(3,4,1); legend('Location', 'best');
% 
%         sgtitle(sprintf('Group Diurnal Variations (Medians & IQR): %s (%s %s)', paramName, sStation, yearStr));
%         saveas(fig, fullfile(outDir, sprintf('Group_Diurnal_%s_%s_%s.png', paramName, sStation, yearStr)));
%         close(fig);
%     end
% 
%     % --- 4. PAIRWISE COMPARISON (BASE vs MODEL M) ---
%     bCat = data{1}.qualityCategory; % Base model categories
% 
%     for m = 2:numModels
%         fprintf('\n============================================================\n');
%         fprintf(' CROSS-ANALYSIS: BASE [%s] vs COMPARED [%s]\n', labels{1}, labels{m});
%         fprintf('============================================================\n');
% 
%         cCat = data{m}.qualityCategory;
% 
%         % 4.1 Quality Category Matrix (Confusion Matrix)
%         confMat = zeros(6, 6);
%         for i = 1:6
%             for j = 1:6
%                 confMat(i, j) = sum(bCat == i & cCat == j);
%             end
%         end
% 
%         fprintf('\n--- QUALITY CATEGORY MIGRATION ---\n');
%         fprintf('Rows (Y): Base [%s] | Columns (X): Compared [%s]\n', labels{1}, labels{m});
%         fprintf('        C1      C2      C3      C4      C5      C6    | TOTAL\n');
%         fprintf('-----------------------------------------------------------------\n');
%         for i = 1:6
%             fprintf(' C%d |', i);
%             for j = 1:6
%                 fprintf(' %6d', confMat(i,j));
%             end
%             fprintf('  | %6d\n', sum(confMat(i,:)));
%         end
%         fprintf('-----------------------------------------------------------------\n');
%         fprintf('TOT |');
%         for j = 1:6
%             fprintf(' %6d', sum(confMat(:,j)));
%         end
%         fprintf('  | %6d\n\n', N_total);
% 
%         % Render Heatmap (Expanded to 7x7 to include TOTALs)
%         confMat7 = zeros(7,7);
%         confMat7(1:6, 1:6) = confMat;
%         confMat7(1:6, 7) = sum(confMat, 2);
%         confMat7(7, 1:6) = sum(confMat, 1);
%         confMat7(7, 7)   = N_total;
% 
%         catLabels = {'C1 (Good)', 'C2 (E/Es)', 'C3 (Jagged)', 'C4 (Es Block)', 'C5 (Weak)', 'C6 (Missed)', 'TOTAL'};
% 
%         figMat = figure('Visible', 'off', 'Position', [100 100 900 700]);
%         h = heatmap(catLabels, catLabels, confMat7, 'Colormap', parula, 'CellLabelFormat', '%d');
%         h.Title = sprintf('Quality Category Matrix: %s vs %s', labels{1}, labels{m});
%         h.XLabel = sprintf('Compared Model: %s', labels{m});
%         h.YLabel = sprintf('Base Model: %s', labels{1});
%         saveas(figMat, fullfile(outDir, sprintf('Heatmap_Cat_%s_vs_%s.png', labels{1}, labels{m})));
%         close(figMat);
% 
%         % 4.2 Physical Metrics and Plots (Intersection where BOTH are Cat 1)
%         valid_both = (bCat == 1) & (cCat == 1);
%         N_valid = sum(valid_both);
%         fprintf('--- PHYSICAL PARAMETERS CROSS-STATISTICS (N = %d, %.1f%%) ---\n', N_valid, N_valid/N_total*100);
% 
%         figScat = figure('Visible', 'off', 'Position', [100 100 1200 1000]);
%         figHist = figure('Visible', 'off', 'Position', [100 100 1200 1000]);
% 
%         for p = 1:length(params)
%             paramName = params{p};
%             valB = data{1}.(paramName)(valid_both);
%             valC = data{m}.(paramName)(valid_both);
% 
%             % Remove NaNs and zeros just in case
%             idx_good = ~isnan(valB) & ~isnan(valC) & (valB > 0) & (valC > 0);
%             valB = valB(idx_good);
%             valC = valC(idx_good);
%             delta = valB - valC;
% 
%             Bias = mean(delta);
%             MAE = mean(abs(delta));
%             RMSE = sqrt(mean(delta.^2));
%             R_mat = corrcoef(valB, valC);
%             R = R_mat(1,2);
% 
%             fprintf('%-6s (%-4s) : Bias = %+7.3f, MAE = %7.3f, RMSE = %7.3f, R = %.4f\n', ...
%                 paramName, units{p}, Bias, MAE, RMSE, R);
% 
%             % Scatter Plot 1-to-1
%             figure(figScat); subplot(2, 2, p); hold on; grid on; box on;
%             % X: Compared (m), Y: Base (1) -> colored by Compared model
%             scatter(valC, valB, 8, 'MarkerFaceColor', colors(m,:), 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.2); 
%             minV = min([valB; valC]); maxV = max([valB; valC]);
%             plot([minV maxV], [minV maxV], 'k--', 'LineWidth', 1.5); % 1:1 Ideal Line
% 
%             pFit = polyfit(valC, valB, 1);
%             plot([minV maxV], polyval(pFit, [minV maxV]), 'r-', 'LineWidth', 2); % Regression Line
% 
%             title(sprintf('%s (R=%.3f, RMSE=%.2f)', paramName, R, RMSE));
%             xlabel(sprintf('%s [%s]', labels{m}, units{p}));
%             ylabel(sprintf('%s [%s]', labels{1}, units{p}));
% 
%             % Histogram Plot
%             figure(figHist); subplot(2, 2, p); hold on; grid on; box on;
%             histogram(delta, 100, 'FaceColor', colors(m,:), 'EdgeColor', 'none');
%             xline(0, 'k-', 'LineWidth', 2);
%             xline(Bias, 'r--', 'LineWidth', 2);
%             title(sprintf('\\Delta %s (Bias=%+.2f, MAE=%.2f)', paramName, Bias, MAE));
%             xlabel(sprintf('%s - %s [%s]', labels{1}, labels{m}, units{p}));
%             ylabel('Count');
%         end
% 
%         sgtitle(figScat, sprintf('Regression Analysis: %s vs %s', labels{1}, labels{m}));
%         saveas(figScat, fullfile(outDir, sprintf('Scatter_%s_vs_%s.png', labels{1}, labels{m})));
%         close(figScat);
% 
%         sgtitle(figHist, sprintf('Error Distribution: %s vs %s', labels{1}, labels{m}));
%         saveas(figHist, fullfile(outDir, sprintf('ErrorHist_%s_vs_%s.png', labels{1}, labels{m})));
%         close(figHist);
% 
%         % 4.3 Pairwise Diurnal Plots (with scatter clouds)
%         for p = 1:length(params)
%             paramName = params{p};
%             figDiur = figure('Visible', 'off', 'Position', [100 100 1600 1000]);
% 
%             for mo = 1:12
%                 subplot(3, 4, mo); hold on; grid on; box on;
%                 title(monthNames{mo});
%                 idx_m = (months == mo) & valid_both;
% 
%                 t_vals = timeHours(idx_m);
%                 valB = data{1}.(paramName)(idx_m);
%                 valC = data{m}.(paramName)(idx_m);
% 
%                 % Base cloud (Red translucent)
%                 scatter(t_vals, valB, 6, 'MarkerFaceColor', colors(1,:), 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.15);
%                 % Compared cloud (Blue/Green translucent)
%                 scatter(t_vals, valC, 6, 'MarkerFaceColor', colors(m,:), 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.15);
% 
%                 % Medians
%                 [~, bins] = histc(t_vals, t_edges);
%                 p50B = nan(1, length(t_centers));
%                 p50C = nan(1, length(t_centers));
%                 for b = 1:length(t_centers)
%                     if any(bins == b)
%                         p50B(b) = median(valB(bins == b));
%                         p50C(b) = median(valC(bins == b));
%                     end
%                 end
% 
%                 % Plot Median Lines
%                 plot(t_centers, p50B, 'Color', colors(1,:), 'LineWidth', 2, 'DisplayName', labels{1});
%                 plot(t_centers, p50C, 'Color', colors(m,:), 'LineWidth', 2, 'DisplayName', labels{m});
% 
%                 xlim([0 24]);
%                 if mo == 1 || mo == 5 || mo == 9, ylabel(sprintf('%s (%s)', paramName, units{p})); end
%                 if mo > 8, xlabel('Time (UT)'); end
%             end
%             subplot(3,4,1); legend('Location', 'best', 'AutoUpdate', 'off');
%             sgtitle(figDiur, sprintf('Pairwise Diurnal %s: %s (Base) vs %s', paramName, labels{1}, labels{m}));
%             saveas(figDiur, fullfile(outDir, sprintf('Diurnal_%s_%s_vs_%s.png', paramName, labels{1}, labels{m})));
%             close(figDiur);
%         end
%     end
% 
%     fprintf('\n============================================================\n');
%     fprintf(' ALL TASKS COMPLETED. RESULTS SAVED TO: %s\n', outDir);
%     fprintf('============================================================\n');
% end



function cadi_compare_models_annual(files, labels, outDir, sStation, yearStr)
% CADI_COMPARE_MODELS_ANNUAL - Script to compare N neural networks (1 base + M compared)
% 
% Input parameters:
%   files    - cell array of paths to CADI_Summary_...mat files (first file is the BASE model)
%   labels   - cell array of model names for plots (e.g., {'6-CH', '1-CH', '3-CH'})
%   outDir   - directory to save reports and PNGs
%   sStation - Station code (e.g., 'RB')
%   yearStr  - Year as a string (e.g., '2008')

    % --- 1. INPUT VALIDATION AND SETUP ---
    if nargin < 1 || isempty(files)
        % Default fallback for debugging
        files = {
            'N:\cadi_out_test\CADI_Summary_RB_2008_6ch.mat', ...
            'N:\cadi_out_test_1ch\CADI_Summary_RB_2008_1ch.mat'
        };
        labels = {'6-CH', '1-CH'};
        outDir = 'N:\cadi_out_comparison\';
        sStation = 'RB';
        yearStr = '2008';
    end
    
    if ~isfolder(outDir), mkdir(outDir); end
    
    numModels = length(files);
    if numModels < 2
        error('At least 2 files are required for comparison.');
    end
    
    % Logging configuration
    logFile = fullfile(outDir, sprintf('Comparison_%s_%s.log', sStation, yearStr));
    if isfile(logFile), delete(logFile); end
    diary(logFile); diary on;
    cleanUp = onCleanup(@() diary('off'));

    fprintf('============================================================\n');
    fprintf(' CADI ANNUAL MODELS COMPARISON: %s %s\n', sStation, yearStr);
    fprintf(' Base Model : %s (%s)\n', labels{1}, files{1});
    for m = 2:numModels
        fprintf(' Compared to: %s (%s)\n', labels{m}, files{m});
    end
    fprintf('============================================================\n\n');

    % --- 2. DATA LOADING AND SYNCHRONIZATION ---
    fprintf('Loading data and synchronizing timestamps...\n');
    data = cell(numModels, 1);
    common_dt = [];
    
    for m = 1:numModels
        tmp = load(files{m});
        if isfield(tmp, 'summaryData')
            data{m} = tmp.summaryData;
        else
            error('Structure ''summaryData'' not found in file %s.', files{m});
        end
        
        if m == 1
            common_dt = data{m}.dt;
        else
            common_dt = intersect(common_dt, data{m}.dt); % Find common timestamps
        end
    end
    
    % Keep only common sessions across all loaded structures
    for m = 1:numModels
        [~, idx] = ismember(common_dt, data{m}.dt);
        % Filter all vector fields within the structure
        fields = fieldnames(data{m});
        for f = 1:length(fields)
            fn = fields{f};
            if size(data{m}.(fn), 1) == length(data{m}.dt)
                data{m}.(fn) = data{m}.(fn)(idx, :);
            end
        end
    end
    
    N_total = length(common_dt);
    fprintf('Synchronized successfully. Total common sessions: %d\n\n', N_total);

    % Color palette setup
    % 1: Base = Red, 2: Comp1 = Blue, 3: Comp2 = Green, 4: Comp3 = Magenta
    colors = [
        0.85, 0.15, 0.15; % Base (Red)
        0.15, 0.35, 0.85; % Compared 1 (Blue)
        0.20, 0.80, 0.20; % Compared 2 (Green / Salad)
        0.70, 0.20, 0.70; % Compared 3 (Magenta)
        0.10, 0.80, 0.80  % Compared 4 (Cyan)
    ]; 
    
    params = {'foF2', 'hmF2', 'TEC', 'SlabT'};
    units = {'MHz', 'km', 'TECU', 'km'};

    % --- 3. GROUP DIURNAL PLOTS (ALL MODELS COMBINED - MEDIANS + IQR) ---
    fprintf('Generating Group Diurnal Plots (All Models)...\n');
    timeHours = hour(common_dt) + minute(common_dt)/60;
    months = month(common_dt);
    t_edges = 0:0.25:24; % 15-minute bins
    t_centers = t_edges(1:end-1) + 0.125;
    monthNames = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
    
    for p = 1:length(params)
        paramName = params{p};
        fig = figure('Visible', 'off', 'Position', [100 100 1600 1000]);
        
        for mo = 1:12
            subplot(3, 4, mo); hold on; grid on; box on;
            title(sprintf('%s', monthNames{mo}));
            idx_m = (months == mo);
            
            % Plot IQR bounds and medians for each model
            for m = 1:numModels
                % Only use valid profiles (Cat 1) and positive values
                valid_idx = idx_m & (data{m}.qualityCategory == 1) & (data{m}.(paramName) > 0);
                x_vals = timeHours(valid_idx);
                y_vals = data{m}.(paramName)(valid_idx);
                
                if isempty(x_vals), continue; end
                
                [~, bins] = histc(x_vals, t_edges);
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
                if any(valid_b)
                    tc = t_centers(valid_b);
                    % IQR Patch (Shading)
                    x_patch = [tc, fliplr(tc)];
                    y_patch = [p25(valid_b), fliplr(p75(valid_b))];
                    patch(x_patch, y_patch, colors(m,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
                    % Median line
                    plot(tc, p50(valid_b), 'Color', colors(m,:), 'LineWidth', 2, 'DisplayName', labels{m});
                end
            end
            xlim([0 24]);
            if mo == 1 || mo == 5 || mo == 9, ylabel(sprintf('%s (%s)', paramName, units{p})); end
            if mo > 8, xlabel('Time (UT, hours)'); end
        end
        % Legend on the first panel
        subplot(3,4,1); legend('Location', 'best');
        
        sgtitle(sprintf('Group Diurnal Variations (Medians & IQR): %s (%s %s)', paramName, sStation, yearStr));
        saveas(fig, fullfile(outDir, sprintf('Group_Diurnal_%s_%s_%s.png', paramName, sStation, yearStr)));
        close(fig);
    end

    % --- 4. PAIRWISE COMPARISON (BASE vs MODEL M) ---
    bCat = data{1}.qualityCategory; % Base model categories
    
    for m = 2:numModels
        fprintf('\n============================================================\n');
        fprintf(' CROSS-ANALYSIS: BASE [%s] vs COMPARED [%s]\n', labels{1}, labels{m});
        fprintf('============================================================\n');
        
        cCat = data{m}.qualityCategory;
        
        % 4.1 Quality Category Matrix (Confusion Matrix)
        confMat = zeros(6, 6);
        for i = 1:6
            for j = 1:6
                confMat(i, j) = sum(bCat == i & cCat == j);
            end
        end
        
        fprintf('\n--- QUALITY CATEGORY MIGRATION ---\n');
        fprintf('Rows (Y): Base [%s] | Columns (X): Compared [%s]\n', labels{1}, labels{m});
        fprintf('        C1      C2      C3      C4      C5      C6    | TOTAL\n');
        fprintf('-----------------------------------------------------------------\n');
        for i = 1:6
            fprintf(' C%d |', i);
            for j = 1:6
                fprintf(' %6d', confMat(i,j));
            end
            fprintf('  | %6d\n', sum(confMat(i,:)));
        end
        fprintf('-----------------------------------------------------------------\n');
        fprintf('TOT |');
        for j = 1:6
            fprintf(' %6d', sum(confMat(:,j)));
        end
        fprintf('  | %6d\n\n', N_total);
        
        % Render Heatmap (Expanded to 7x7 to include TOTALs)
        confMat7 = zeros(7,7);
        confMat7(1:6, 1:6) = confMat;
        confMat7(1:6, 7) = sum(confMat, 2);
        confMat7(7, 1:6) = sum(confMat, 1);
        confMat7(7, 7)   = N_total;

        catLabels = {'C1 (Good)', 'C2 (E/Es)', 'C3 (Jagged)', 'C4 (Es Block)', 'C5 (Weak)', 'C6 (Missed)', 'TOTAL'};
        
        figMat = figure('Visible', 'off', 'Position', [100 100 900 700]);
        h = heatmap(catLabels, catLabels, confMat7, 'Colormap', parula, 'CellLabelFormat', '%d');
        h.Title = sprintf('Quality Category Matrix: %s vs %s', labels{1}, labels{m});
        h.XLabel = sprintf('Compared Model: %s', labels{m});
        h.YLabel = sprintf('Base Model: %s', labels{1});
        saveas(figMat, fullfile(outDir, sprintf('Heatmap_Cat_%s_vs_%s.png', labels{1}, labels{m})));
        close(figMat);
        
        % 4.2 Physical Metrics and Plots (Intersection where BOTH are Cat 1)
        valid_both = (bCat == 1) & (cCat == 1);
        N_valid = sum(valid_both);
        fprintf('--- PHYSICAL PARAMETERS CROSS-STATISTICS (N = %d, %.1f%%) ---\n', N_valid, N_valid/N_total*100);
        
        figScat = figure('Visible', 'off', 'Position', [100 100 1200 1000]);
        figHist = figure('Visible', 'off', 'Position', [100 100 1200 1000]);
        
        for p = 1:length(params)
            paramName = params{p};
            valB = data{1}.(paramName)(valid_both);
            valC = data{m}.(paramName)(valid_both);
            
            % Remove NaNs and zeros just in case
            idx_good = ~isnan(valB) & ~isnan(valC) & (valB > 0) & (valC > 0);
            valB = valB(idx_good);
            valC = valC(idx_good);
            delta = valB - valC;
            
            Bias = mean(delta);
            MAE = mean(abs(delta));
            RMSE = sqrt(mean(delta.^2));
            R_mat = corrcoef(valB, valC);
            R = R_mat(1,2);
            
            fprintf('%-6s (%-4s) : Bias = %+7.3f, MAE = %7.3f, RMSE = %7.3f, R = %.4f\n', ...
                paramName, units{p}, Bias, MAE, RMSE, R);
                
            % Scatter Plot 1-to-1
            figure(figScat); subplot(2, 2, p); hold on; grid on; box on;
            % X: Compared (m), Y: Base (1) -> colored by Compared model
            scatter(valC, valB, 8, 'MarkerFaceColor', colors(m,:), 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.2); 
            minV = min([valB; valC]); maxV = max([valB; valC]);
            plot([minV maxV], [minV maxV], 'k--', 'LineWidth', 1.5); % 1:1 Ideal Line
            
            pFit = polyfit(valC, valB, 1);
            plot([minV maxV], polyval(pFit, [minV maxV]), 'r-', 'LineWidth', 2); % Regression Line
            
            title(sprintf('%s (R=%.3f, RMSE=%.2f)', paramName, R, RMSE));
            xlabel(sprintf('%s [%s]', labels{m}, units{p}));
            ylabel(sprintf('%s [%s]', labels{1}, units{p}));
            
            % Histogram Plot
            figure(figHist); subplot(2, 2, p); hold on; grid on; box on;
            histogram(delta, 100, 'FaceColor', colors(m,:), 'EdgeColor', 'none');
            xline(0, 'k-', 'LineWidth', 2);
            xline(Bias, 'r--', 'LineWidth', 2);
            title(sprintf('\\Delta %s (Bias=%+.2f, MAE=%.2f)', paramName, Bias, MAE));
            xlabel(sprintf('%s - %s [%s]', labels{1}, labels{m}, units{p}));
            ylabel('Count');
        end
        
        sgtitle(figScat, sprintf('Regression Analysis: %s vs %s', labels{1}, labels{m}));
        saveas(figScat, fullfile(outDir, sprintf('Scatter_%s_vs_%s.png', labels{1}, labels{m})));
        close(figScat);
        
        sgtitle(figHist, sprintf('Error Distribution: %s vs %s', labels{1}, labels{m}));
        saveas(figHist, fullfile(outDir, sprintf('ErrorHist_%s_vs_%s.png', labels{1}, labels{m})));
        close(figHist);
        
        % 4.3 Pairwise Diurnal Plots (Compared drawn first, Base drawn ON TOP)
        for p = 1:length(params)
            paramName = params{p};
            figDiur = figure('Visible', 'off', 'Position', [100 100 1600 1000]);
            
            for mo = 1:12
                subplot(3, 4, mo); hold on; grid on; box on;
                title(monthNames{mo});
                idx_m = (months == mo) & valid_both;
                
                t_vals = timeHours(idx_m);
                valB = data{1}.(paramName)(idx_m);
                valC = data{m}.(paramName)(idx_m);
                
                % 1. FIRST: Draw Compared Model (Blue translucent cloud & Blue median line)
                scatter(t_vals, valC, 6, 'MarkerFaceColor', colors(m,:), 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.15);
                
                % 2. SECOND: Draw Base Model ON TOP (Red translucent cloud & Red median line)
                scatter(t_vals, valB, 6, 'MarkerFaceColor', colors(1,:), 'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.20);
                
                % Calculate medians
                [~, bins] = histc(t_vals, t_edges);
                p50B = nan(1, length(t_centers));
                p50C = nan(1, length(t_centers));
                for b = 1:length(t_centers)
                    if any(bins == b)
                        p50B(b) = median(valB(bins == b));
                        p50C(b) = median(valC(bins == b));
                    end
                end
                
                % Plot Medians (Compared first, Base on top)
                plot(t_centers, p50C, 'Color', colors(m,:), 'LineWidth', 2, 'DisplayName', labels{m});
                plot(t_centers, p50B, 'Color', colors(1,:), 'LineWidth', 2.5, 'DisplayName', labels{1});
                
                xlim([0 24]);
                if mo == 1 || mo == 5 || mo == 9, ylabel(sprintf('%s (%s)', paramName, units{p})); end
                if mo > 8, xlabel('Time (UT)'); end
            end
            subplot(3,4,1); legend('Location', 'best', 'AutoUpdate', 'off');
            sgtitle(figDiur, sprintf('Pairwise Diurnal %s: %s (Base) vs %s', paramName, labels{1}, labels{m}));
            saveas(figDiur, fullfile(outDir, sprintf('Diurnal_%s_%s_vs_%s.png', paramName, labels{1}, labels{m})));
            close(figDiur);
        end
    end
    
    fprintf('\n============================================================\n');
    fprintf(' ALL TASKS COMPLETED. RESULTS SAVED TO: %s\n', outDir);
    fprintf('============================================================\n');
end