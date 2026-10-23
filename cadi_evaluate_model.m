% function evalResults = cadi_evaluate_model(model_path, threshold, min_blob_size)
% % CADI_EVALUATE_MODEL Evaluates the trained U-Net model on the held-out 10% test split.
% %
% % Inputs:
% %   model_path    : Full path to the saved model .mat file
% %                   (default: 'N:/cadi_synced_out/cadi_unet_6ch_combined.mat')
% %   threshold     : Probability threshold for binary mask (default: 0.5)
% %   min_blob_size : Minimum connected component area in pixels to filter out noise
% %                   before extracting foF2 (default: 15)
% %
% % Outputs:
% %   evalResults   : Structure containing per-session metrics, summary statistics,
% %                   and test file paths.
% 
%     % 1. Handle default input arguments
%     if nargin < 1 || isempty(model_path)
%         default_path = 'N:/cadi_synced_out/cadi_unet_6ch_combined.mat';
%         if isfile(default_path)
%             model_path = default_path;
%         else
%             [f_name, f_dir] = uigetfile('*.mat', 'Select Trained CADI U-Net Model');
%             if isequal(f_name, 0)
%                 error('Model selection cancelled.');
%             end
%             model_path = fullfile(f_dir, f_name);
%         end
%     end
%     if nargin < 2 || isempty(threshold)
%         threshold = 0.5;
%     end
%     if nargin < 3 || isempty(min_blob_size)
%         min_blob_size = 15;
%     end
% 
%     fprintf('============================================================\n');
%     fprintf('   CADI U-NET INDEPENDENT TEST EVALUATION                   \n');
%     fprintf('============================================================\n');
%     fprintf('Loading model: %s\n', model_path);
% 
%     S = load(model_path, 'trainedNet', 'splitData', 'strategy', 'input_size');
%     trainedNet = S.trainedNet;
%     splitData  = S.splitData;
%     strategy   = S.strategy;
% 
%     test_filt_files = splitData.test_filt;
%     test_orig_files = splitData.test_orig;
%     num_test = numel(test_filt_files);
% 
%     fprintf('Strategy       : %s\n', strategy);
%     fprintf('Test sessions  : %d\n', num_test);
%     fprintf('Mask threshold : %.2f (Min component size: %d px)\n', threshold, min_blob_size);
% 
%     % 2. Preallocate arrays for evaluation metrics
%     dice_scores   = zeros(num_test, 1, 'single');
%     iou_scores    = zeros(num_test, 1, 'single');
%     foF2_true_arr = nan(num_test, 1);
%     foF2_pred_arr = nan(num_test, 1);
%     foF2_idx_true = nan(num_test, 1);
%     foF2_idx_pred = nan(num_test, 1);
% 
%     % Inspect the first test file to check if physical frequency grid is stored
%     sample_info = whos('-file', test_filt_files{1});
%     var_names   = {sample_info.name};
%     has_f_grid  = any(strcmp(var_names, 'f_grid'));
% 
%     if has_f_grid
%         tmp = load(test_filt_files{1}, 'f_grid');
%         default_f_grid = double(tmp.f_grid(:)');
%         freq_unit_str  = 'MHz';
%     else
%         % Fallback to standard 96-column index if f_grid is not inside the file
%         default_f_grid = 1:96;
%         freq_unit_str  = 'bins';
%     end
% 
%     % 3. Run batched GPU inference across the test split
%     batch_size = 64;
%     num_batches = ceil(num_test / batch_size);
%     is_6ch = strcmpi(strategy, '6ch_combined');
% 
%     fprintf('Running inference on %d test sessions (%d batches)...\n', num_test, num_batches);
%     t_start = tic;
% 
%     for b = 1:num_batches
%         idx_start = (b - 1) * batch_size + 1;
%         idx_end   = min(b * batch_size, num_test);
%         cur_indices = idx_start:idx_end;
%         cur_bs = numel(cur_indices);
% 
%         if is_6ch
%             X_batch = zeros(192, 96, 6, cur_bs, 'single');
%         else
%             X_batch = zeros(192, 96, 3, cur_bs, 'single');
%         end
%         Y_batch_true = false(192, 96, cur_bs);
%         f_grids_batch = repmat(default_f_grid, cur_bs, 1);
% 
%         % Load batch files
%         for k = 1:cur_bs
%             file_idx = cur_indices(k);
%             f_filt = test_filt_files{file_idx};
%             f_orig = test_orig_files{file_idx};
% 
%             if is_6ch
%                 d_filt = load(f_filt);
%                 d_orig = load(f_orig, 'X_tensor');
%                 X_batch(:, :, :, k) = cat(3, single(d_filt.X_tensor), single(d_orig.X_tensor));
%                 Y_batch_true(:, :, k) = logical(d_filt.Y_mask > 0);
%                 if isfield(d_filt, 'f_grid')
%                     f_grids_batch(k, :) = double(d_filt.f_grid(:)');
%                 end
%             elseif strcmpi(strategy, '3ch_filtered_only')
%                 d_filt = load(f_filt);
%                 X_batch(:, :, :, k) = single(d_filt.X_tensor);
%                 Y_batch_true(:, :, k) = logical(d_filt.Y_mask > 0);
%                 if isfield(d_filt, 'f_grid')
%                     f_grids_batch(k, :) = double(d_filt.f_grid(:)');
%                 end
%             else
%                 d_orig = load(f_orig);
%                 X_batch(:, :, :, k) = single(d_orig.X_tensor);
%                 Y_batch_true(:, :, k) = logical(d_orig.Y_mask > 0);
%                 if isfield(d_orig, 'f_grid')
%                     f_grids_batch(k, :) = double(d_orig.f_grid(:)');
%                 end
%             end
%         end
% 
%         % Predict probability maps on GPU using dlarray ('SSCB' format)
%         dlX = dlarray(X_batch, 'SSCB');
%         if canUseGPU
%             dlX = gpuArray(dlX);
%         end
%         dlY_pred = predict(trainedNet, dlX);
%         Y_prob_batch = gather(extractdata(dlY_pred)); % [192 x 96 x 1 x cur_bs]
% 
%         % Compute per-session segmentation & physical metrics
%         for k = 1:cur_bs
%             file_idx = cur_indices(k);
%             prob_map  = Y_prob_batch(:, :, 1, k);
%             mask_true = Y_batch_true(:, :, k);
%             mask_pred = prob_map >= threshold;
% 
%             % Morphological cleanup to eliminate isolated noise specks
%             mask_pred_clean = bwareaopen(mask_pred, min_blob_size);
% 
%             % Compute Dice and IoU scores
%             inter = single(sum(mask_pred_clean & mask_true, 'all'));
%             sum_p = single(sum(mask_pred_clean, 'all'));
%             sum_t = single(sum(mask_true, 'all'));
%             union_val = single(sum(mask_pred_clean | mask_true, 'all'));
% 
%             dice_scores(file_idx) = (2.0 * inter + 1e-5) / (sum_p + sum_t + 1e-5);
%             iou_scores(file_idx)  = (inter + 1e-5) / (union_val + 1e-5);
% 
%             % Extract true and predicted foF2 (rightmost frequency column of O-mode trace)
%             f_vec = f_grids_batch(k, :);
%             [foF2_true_arr(file_idx), foF2_idx_true(file_idx)] = get_trace_foF2(mask_true, f_vec);
%             [foF2_pred_arr(file_idx), foF2_idx_pred(file_idx)] = get_trace_foF2(mask_pred_clean, f_vec);
%         end
% 
%         if mod(b, 10) == 0 || b == num_batches
%             fprintf('  Processed %d / %d sessions (%.1f s)\n', idx_end, num_test, toc(t_start));
%         end
%     end
% 
%     % 4. Compute statistical summary
%     valid_foF2 = ~isnan(foF2_true_arr) & ~isnan(foF2_pred_arr);
%     foF2_err   = foF2_pred_arr(valid_foF2) - foF2_true_arr(valid_foF2); % Signed error (Pred - True)
%     foF2_abs   = abs(foF2_err);
% 
%     evalResults = struct();
%     evalResults.model_path      = model_path;
%     evalResults.strategy        = strategy;
%     evalResults.threshold       = threshold;
%     evalResults.test_filt_files = test_filt_files;
%     evalResults.test_orig_files = test_orig_files;
%     evalResults.dice_scores     = dice_scores;
%     evalResults.iou_scores      = iou_scores;
%     evalResults.foF2_true       = foF2_true_arr;
%     evalResults.foF2_pred       = foF2_pred_arr;
%     evalResults.foF2_error      = foF2_pred_arr - foF2_true_arr;
%     evalResults.freq_unit       = freq_unit_str;
% 
%     evalResults.mean_dice       = mean(dice_scores);
%     evalResults.median_dice     = median(dice_scores);
%     evalResults.std_dice        = std(dice_scores);
%     evalResults.mean_iou        = mean(iou_scores);
%     evalResults.foF2_mae        = mean(foF2_abs);
%     evalResults.foF2_median_ae  = median(foF2_abs);
%     evalResults.foF2_rmse       = sqrt(mean(foF2_err .^ 2));
%     evalResults.foF2_bias       = mean(foF2_err);
%     evalResults.detection_rate  = 100 * sum(~isnan(foF2_pred_arr)) / num_test;
% 
%     % Print formatted report to Command Window
%     fprintf('\n============================================================\n');
%     fprintf('   TEST SET EVALUATION SUMMARY (%d SESSIONS)               \n', num_test);
%     fprintf('============================================================\n');
%     fprintf('Segmentation Overlap Metrics:\n');
%     fprintf('  Mean Dice Score (F1)   : %.4f  (Std: %.4f)\n', evalResults.mean_dice, evalResults.std_dice);
%     fprintf('  Median Dice Score      : %.4f  (IQR: %.4f - %.4f)\n', ...
%         evalResults.median_dice, prctile(dice_scores, 25), prctile(dice_scores, 75));
%     fprintf('  Mean IoU (Jaccard)     : %.4f\n', evalResults.mean_iou);
%     fprintf('  Sessions with Dice>0.80: %.1f%%\n', 100 * mean(dice_scores > 0.80));
%     fprintf('------------------------------------------------------------\n');
%     fprintf('Physical foF2 Accuracy Metrics (Unit: %s):\n', freq_unit_str);
%     fprintf('  Trace Detection Rate   : %.2f%% (%d / %d)\n', ...
%         evalResults.detection_rate, sum(~isnan(foF2_pred_arr)), num_test);
%     fprintf('  foF2 MAE (Mean Abs Err): %.3f %s\n', evalResults.foF2_mae, freq_unit_str);
%     fprintf('  foF2 Median Abs Error  : %.3f %s\n', evalResults.foF2_median_ae, freq_unit_str);
%     fprintf('  foF2 RMSE              : %.3f %s\n', evalResults.foF2_rmse, freq_unit_str);
%     fprintf('  foF2 Mean Bias (P - T) : %+.3f %s\n', evalResults.foF2_bias, freq_unit_str);
%     if strcmp(freq_unit_str, 'MHz')
%         fprintf('  Within +/- 0.10 MHz    : %.1f%%\n', 100 * mean(foF2_abs <= 0.10));
%         fprintf('  Within +/- 0.25 MHz    : %.1f%%\n', 100 * mean(foF2_abs <= 0.25));
%         fprintf('  Within +/- 0.50 MHz    : %.1f%%\n', 100 * mean(foF2_abs <= 0.50));
%     end
%     fprintf('============================================================\n');
% 
%     % 5. Save evaluation results next to the model file
%     [m_dir, m_name, ~] = fileparts(model_path);
%     eval_out_path = fullfile(m_dir, [m_name, '_eval_results.mat']);
%     save(eval_out_path, 'evalResults', '-v7.3');
%     fprintf('Saved full evaluation results to:\n  %s\n', eval_out_path);
% 
%     % 6. Generate summary plots and visual inspection gallery
%     plot_summary_distributions(evalResults, foF2_err);
%     plot_sample_predictions(trainedNet, evalResults, is_6ch, threshold, min_blob_size, default_f_grid);
% end
% 
% % =========================================================================
% % HELPER: EXTRACT CRITICAL FREQUENCY (foF2) FROM BINARY MASK
% % =========================================================================
% 
% function [foF2_val, col_idx] = get_trace_foF2(bw_mask, f_vec)
% % GET_TRACE_FOF2 Finds the high-frequency edge of the dominant O-mode trace.
% 
%     if ~any(bw_mask, 'all')
%         foF2_val = NaN;
%         col_idx  = NaN;
%         return;
%     end
% 
%     % Keep largest connected structures to prevent stray high-frequency noise from skewing foF2
%     cc = bwconncomp(bw_mask);
%     num_px = cellfun(@numel, cc.PixelIdxList);
%     max_px = max(num_px);
% 
%     % Retain blobs that are at least 15% of the main trace size (handles split traces safely)
%     valid_blobs = find(num_px >= max(10, 0.15 * max_px));
%     clean_mask = false(size(bw_mask));
%     for idx = valid_blobs
%         clean_mask(cc.PixelIdxList{idx}) = true;
%     end
% 
%     % Find columns containing at least one active trace pixel
%     active_cols = find(any(clean_mask, 1));
%     if isempty(active_cols)
%         foF2_val = NaN;
%         col_idx  = NaN;
%     else
%         col_idx  = active_cols(end);
%         foF2_val = f_vec(col_idx);
%     end
% end
% 
% % =========================================================================
% % HELPER: PLOT METRIC DISTRIBUTIONS
% % =========================================================================
% 
% function plot_summary_distributions(res, foF2_err)
% % PLOT_SUMMARY_DISTRIBUTIONS Creates a 3-panel figure with Dice and foF2 statistics.
% 
%     fig = figure('Name', 'CADI U-Net Test Evaluation Metrics', ...
%                  'Color', 'w', 'Position', [100, 100, 1350, 420]);
%     t = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
%     title(t, sprintf('Independent Test Set Evaluation (N = %d, Strategy: %s)', ...
%         numel(res.dice_scores), strrep(res.strategy, '_', '\_')), 'FontWeight', 'bold', 'FontSize', 12);
% 
%     % Panel 1: Dice Score Histogram
%     nexttile;
%     histogram(res.dice_scores, 40, 'FaceColor', [0.15, 0.45, 0.75], 'EdgeColor', 'w');
%     hold on;
%     xline(res.mean_dice, '--r', sprintf('Mean: %.3f', res.mean_dice), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'middle');
%     xline(res.median_dice, '-k', sprintf('Median: %.3f', res.median_dice), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
%     hold off;
%     grid on;
%     xlabel('Dice Score (F1)');
%     ylabel('Number of Sessions');
%     title('Dice Score Distribution');
%     xlim([0, 1]);
% 
%     % Panel 2: foF2 Error Histogram (Pred - True)
%     nexttile;
%     histogram(foF2_err, 50, 'FaceColor', [0.85, 0.40, 0.15], 'EdgeColor', 'w');
%     hold on;
%     xline(0, '-k', 'Zero Error', 'LineWidth', 1.2);
%     xline(res.foF2_bias, '--b', sprintf('Bias: %+.3f', res.foF2_bias), 'LineWidth', 1.5);
%     hold off;
%     grid on;
%     xlabel(sprintf('\\DeltafoF2 = foF2_{pred} - foF2_{true} (%s)', res.freq_unit));
%     ylabel('Number of Sessions');
%     title(sprintf('foF2 Error (MAE = %.3f %s, RMSE = %.3f)', res.foF2_mae, res.freq_unit, res.foF2_rmse));
% 
%     % Panel 3: True vs Predicted foF2 Scatter
%     nexttile;
%     valid = ~isnan(res.foF2_true) & ~isnan(res.foF2_pred);
%     scatter(res.foF2_true(valid), res.foF2_pred(valid), 12, [0.2, 0.6, 0.4], 'filled', 'MarkerFaceAlpha', 0.35);
%     hold on;
%     min_f = min([res.foF2_true(valid); res.foF2_pred(valid)]);
%     max_f = max([res.foF2_true(valid); res.foF2_pred(valid)]);
%     plot([min_f, max_f], [min_f, max_f], '--k', 'LineWidth', 1.5);
%     hold off;
%     grid on;
%     axis equal;
%     xlim([min_f, max_f]);
%     ylim([min_f, max_f]);
%     xlabel(sprintf('Ground Truth foF2 (%s)', res.freq_unit));
%     ylabel(sprintf('Predicted foF2 (%s)', res.freq_unit));
%     title('foF2: Ground Truth vs. U-Net Prediction');
% end
% 
% % =========================================================================
% % HELPER: VISUALIZE SAMPLE TEST PREDICTIONS
% % =========================================================================
% 
% function plot_sample_predictions(trainedNet, res, is_6ch, threshold, min_blob_size, default_f_grid)
% % PLOT_SAMPLE_PREDICTIONS Displays 6 representative test sessions (High, Median, and Lower Dice).
% 
%     [~, sorted_idx] = sort(res.dice_scores, 'descend');
%     N = numel(sorted_idx);
% 
%     % Pick 2 high-performing, 2 median, and 2 lower-quartile examples (avoiding empty/corrupted masks)
%     sample_ranks = round([0.05*N, 0.15*N, 0.45*N, 0.55*N, 0.80*N, 0.90*N]);
%     sample_ranks = max(1, min(N, sample_ranks));
%     chosen_indices = sorted_idx(sample_ranks);
% 
%     fig = figure('Name', 'CADI U-Net Sample Test Predictions', ...
%                  'Color', 'w', 'Position', [120, 80, 1400, 780]);
%     t = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
%     title(t, 'Visual Inspection on Unseen Test Sessions (Green = True Mask, Red = U-Net Prediction)', ...
%         'FontWeight', 'bold', 'FontSize', 12);
% 
%     for i = 1:numel(chosen_indices)
%         idx = chosen_indices(i);
%         f_filt = res.test_filt_files{idx};
%         f_orig = res.test_orig_files{idx};
% 
%         d_filt = load(f_filt);
%         d_orig = load(f_orig);
% 
%         if is_6ch
%             X_in = cat(3, single(d_filt.X_tensor), single(d_orig.X_tensor));
%         else
%             X_in = single(d_orig.X_tensor);
%         end
% 
%         dlX = dlarray(X_in, 'SSCB');
%         if canUseGPU
%             dlX = gpuArray(dlX);
%         end
%         prob_map = gather(extractdata(predict(trainedNet, dlX)));
%         mask_pred = bwareaopen(prob_map >= threshold, min_blob_size);
%         mask_true = logical(d_filt.Y_mask > 0);
% 
%         if isfield(d_filt, 'f_grid')
%             f_vec = double(d_filt.f_grid(:)');
%         else
%             f_vec = default_f_grid;
%         end
%         if isfield(d_filt, 'h_grid')
%             h_vec = double(d_filt.h_grid(:));
%         else
%             h_vec = (1:192)';
%         end
% 
%         % Display raw O-mode normalized channel from unfiltered ionogram as background
%         bg_img = squeeze(d_orig.X_tensor(:, :, 2));
% 
%         nexttile;
%         imagesc(f_vec, h_vec, bg_img);
%         set(gca, 'YDir', 'normal');
%         colormap(gca, gray);
%         hold on;
% 
%         % Overlay Ground Truth contour (Green) and Predicted contour (Red)
%         if any(mask_true, 'all')
%             contour(f_vec, h_vec, double(mask_true), [0.5, 0.5], 'g', 'LineWidth', 1.2);
%         end
%         if any(mask_pred, 'all')
%             contour(f_vec, h_vec, double(mask_pred), [0.5, 0.5], 'r--', 'LineWidth', 1.5);
%         end
% 
%         % Mark foF2 vertical lines
%         if ~isnan(res.foF2_true(idx))
%             xline(res.foF2_true(idx), '-g', 'LineWidth', 1.0);
%         end
%         if ~isnan(res.foF2_pred(idx))
%             xline(res.foF2_pred(idx), '--r', 'LineWidth', 1.2);
%         end
%         hold off;
% 
%         [~, s_name, ~] = fileparts(f_filt);
%         title(sprintf('%s | Dice: %.3f | \\DeltafoF2: %+.2f %s', ...
%             s_name, res.dice_scores(idx), res.foF2_error(idx), res.freq_unit), ...
%             'Interpreter', 'tex', 'FontSize', 9.5);
%         xlabel(sprintf('Frequency (%s)', res.freq_unit));
%         ylabel('Virtual Height');
%     end
% end

function evalResults = cadi_evaluate_model(model_path, threshold, min_blob_size)
% CADI_EVALUATE_MODEL Evaluates the trained U-Net model on the held-out 10% test split.
%
% Inputs:
%   model_path    : Full path to the saved model .mat file
%                   (default: 'N:/cadi_synced_out/cadi_unet_6ch_combined.mat')
%   threshold     : Probability threshold for binary mask (default: 0.5)
%   min_blob_size : Minimum connected component area in pixels to filter out noise
%                   before extracting foF2 (default: 15)
%
% Outputs:
%   evalResults   : Structure containing per-session metrics, summary statistics,
%                   and test file paths.

    % 1. Handle default input arguments
    if nargin < 1 || isempty(model_path)
        default_path = 'N:/cadi_synced_out/cadi_unet_6ch_combined.mat';
        if isfile(default_path)
            model_path = default_path;
        else
            [f_name, f_dir] = uigetfile('*.mat', 'Select Trained CADI U-Net Model');
            if isequal(f_name, 0)
                error('Model selection cancelled.');
            end
            model_path = fullfile(f_dir, f_name);
        end
    end
    if nargin < 2 || isempty(threshold)
        threshold = 0.5;
    end
    if nargin < 3 || isempty(min_blob_size)
        min_blob_size = 15;
    end

    fprintf('============================================================\n');
    fprintf('   CADI U-NET INDEPENDENT TEST EVALUATION                   \n');
    fprintf('============================================================\n');
    fprintf('Loading model: %s\n', model_path);

    S = load(model_path, 'trainedNet', 'splitData', 'strategy', 'input_size');
    trainedNet = S.trainedNet;
    splitData  = S.splitData;
    strategy   = S.strategy;

    test_filt_files = splitData.test_filt;
    test_orig_files = splitData.test_orig;
    num_test = numel(test_filt_files);

    fprintf('Strategy       : %s\n', strategy);
    fprintf('Test sessions  : %d\n', num_test);
    fprintf('Mask threshold : %.2f (Min component size: %d px)\n', threshold, min_blob_size);

    % 2. Preallocate arrays for evaluation metrics
    dice_scores   = zeros(num_test, 1, 'single');
    iou_scores    = zeros(num_test, 1, 'single');
    foF2_true_arr = nan(num_test, 1);
    foF2_pred_arr = nan(num_test, 1);
    foF2_idx_true = nan(num_test, 1);
    foF2_idx_pred = nan(num_test, 1);

    % Inspect the first test file to check if physical frequency grid is stored
    sample_info = whos('-file', test_filt_files{1});
    var_names   = {sample_info.name};
    has_f_grid  = any(strcmp(var_names, 'f_grid'));
    
    if has_f_grid
        tmp = load(test_filt_files{1}, 'f_grid');
        default_f_grid = double(tmp.f_grid(:)');
        freq_unit_str  = 'MHz';
    else
        % Fallback to standard 96-column index if f_grid is not inside the file
        default_f_grid = 1:96;
        freq_unit_str  = 'bins';
    end

    % 3. Run batched GPU inference across the test split
    batch_size = 64;
    num_batches = ceil(num_test / batch_size);
    is_6ch = strcmpi(strategy, '6ch_combined');

    fprintf('Running inference on %d test sessions (%d batches)...\n', num_test, num_batches);
    t_start = tic;

    for b = 1:num_batches
        idx_start = (b - 1) * batch_size + 1;
        idx_end   = min(b * batch_size, num_test);
        cur_indices = idx_start:idx_end;
        cur_bs = numel(cur_indices);

        if is_6ch
            X_batch = zeros(192, 96, 6, cur_bs, 'single');
        else
            X_batch = zeros(192, 96, 3, cur_bs, 'single');
        end
        Y_batch_true = false(192, 96, cur_bs);
        f_grids_batch = repmat(default_f_grid, cur_bs, 1);

        % Load batch files
        for k = 1:cur_bs
            file_idx = cur_indices(k);
            f_filt = test_filt_files{file_idx};
            f_orig = test_orig_files{file_idx};

            if is_6ch
                d_filt = load(f_filt);
                d_orig = load(f_orig, 'X_tensor');
                X_batch(:, :, :, k) = cat(3, single(d_filt.X_tensor), single(d_orig.X_tensor));
                Y_batch_true(:, :, k) = logical(d_filt.Y_mask > 0);
                if isfield(d_filt, 'f_grid')
                    f_grids_batch(k, :) = double(d_filt.f_grid(:)');
                end
            elseif strcmpi(strategy, '3ch_filtered_only')
                d_filt = load(f_filt);
                X_batch(:, :, :, k) = single(d_filt.X_tensor);
                Y_batch_true(:, :, k) = logical(d_filt.Y_mask > 0);
                if isfield(d_filt, 'f_grid')
                    f_grids_batch(k, :) = double(d_filt.f_grid(:)');
                end
            else
                d_orig = load(f_orig);
                X_batch(:, :, :, k) = single(d_orig.X_tensor);
                Y_batch_true(:, :, k) = logical(d_orig.Y_mask > 0);
                if isfield(d_orig, 'f_grid')
                    f_grids_batch(k, :) = double(d_orig.f_grid(:)');
                end
            end
        end

        % Predict probability maps on GPU using dlarray ('SSCB' format)
        dlX = dlarray(X_batch, 'SSCB');
        if canUseGPU
            dlX = gpuArray(dlX);
        end
        dlY_pred = predict(trainedNet, dlX);
        Y_prob_batch = gather(extractdata(dlY_pred)); % [192 x 96 x 1 x cur_bs]

        % Compute per-session segmentation & physical metrics
        for k = 1:cur_bs
            file_idx = cur_indices(k);
            prob_map  = Y_prob_batch(:, :, 1, k);
            mask_true = Y_batch_true(:, :, k);
            mask_pred = prob_map >= threshold;

            % Morphological cleanup to eliminate isolated noise specks
            mask_pred_clean = bwareaopen(mask_pred, min_blob_size);

            % Compute Dice and IoU scores
            inter = single(sum(mask_pred_clean & mask_true, 'all'));
            sum_p = single(sum(mask_pred_clean, 'all'));
            sum_t = single(sum(mask_true, 'all'));
            union_val = single(sum(mask_pred_clean | mask_true, 'all'));

            dice_scores(file_idx) = (2.0 * inter + 1e-5) / (sum_p + sum_t + 1e-5);
            iou_scores(file_idx)  = (inter + 1e-5) / (union_val + 1e-5);

            % Extract true and predicted foF2 (rightmost frequency column of O-mode trace)
            f_vec = f_grids_batch(k, :);
            [foF2_true_arr(file_idx), foF2_idx_true(file_idx)] = get_trace_foF2(mask_true, f_vec);
            [foF2_pred_arr(file_idx), foF2_idx_pred(file_idx)] = get_trace_foF2(mask_pred_clean, f_vec);
        end

        if mod(b, 10) == 0 || b == num_batches
            fprintf('  Processed %d / %d sessions (%.1f s)\n', idx_end, num_test, toc(t_start));
        end
    end

    % 4. Compute statistical summary
    valid_foF2 = ~isnan(foF2_true_arr) & ~isnan(foF2_pred_arr);
    foF2_err   = foF2_pred_arr(valid_foF2) - foF2_true_arr(valid_foF2); % Signed error (Pred - True)
    foF2_abs   = abs(foF2_err);

    evalResults = struct();
    evalResults.model_path      = model_path;
    evalResults.strategy        = strategy;
    evalResults.threshold       = threshold;
    evalResults.test_filt_files = test_filt_files;
    evalResults.test_orig_files = test_orig_files;
    evalResults.dice_scores     = dice_scores;
    evalResults.iou_scores      = iou_scores;
    evalResults.foF2_true       = foF2_true_arr;
    evalResults.foF2_pred       = foF2_pred_arr;
    evalResults.foF2_error      = foF2_pred_arr - foF2_true_arr;
    evalResults.freq_unit       = freq_unit_str;

    evalResults.mean_dice       = mean(dice_scores);
    evalResults.median_dice     = median(dice_scores);
    evalResults.std_dice        = std(dice_scores);
    evalResults.mean_iou        = mean(iou_scores);
    evalResults.foF2_mae        = mean(foF2_abs);
    evalResults.foF2_median_ae  = median(foF2_abs);
    evalResults.foF2_rmse       = sqrt(mean(foF2_err .^ 2));
    evalResults.foF2_bias       = mean(foF2_err);
    evalResults.detection_rate  = 100 * sum(~isnan(foF2_pred_arr)) / num_test;

    % Print formatted report to Command Window
    fprintf('\n============================================================\n');
    fprintf('   TEST SET EVALUATION SUMMARY (%d SESSIONS)               \n', num_test);
    fprintf('============================================================\n');
    fprintf('Segmentation Overlap Metrics:\n');
    fprintf('  Mean Dice Score (F1)   : %.4f  (Std: %.4f)\n', evalResults.mean_dice, evalResults.std_dice);
    fprintf('  Median Dice Score      : %.4f  (IQR: %.4f - %.4f)\n', ...
        evalResults.median_dice, prctile(dice_scores, 25), prctile(dice_scores, 75));
    fprintf('  Mean IoU (Jaccard)     : %.4f\n', evalResults.mean_iou);
    fprintf('  Sessions with Dice>0.80: %.1f%%\n', 100 * mean(dice_scores > 0.80));
    fprintf('------------------------------------------------------------\n');
    fprintf('Physical foF2 Accuracy Metrics (Unit: %s):\n', freq_unit_str);
    fprintf('  Trace Detection Rate   : %.2f%% (%d / %d)\n', ...
        evalResults.detection_rate, sum(~isnan(foF2_pred_arr)), num_test);
    fprintf('  foF2 MAE (Mean Abs Err): %.3f %s\n', evalResults.foF2_mae, freq_unit_str);
    fprintf('  foF2 Median Abs Error  : %.3f %s\n', evalResults.foF2_median_ae, freq_unit_str);
    fprintf('  foF2 RMSE              : %.3f %s\n', evalResults.foF2_rmse, freq_unit_str);
    fprintf('  foF2 Mean Bias (P - T) : %+.3f %s\n', evalResults.foF2_bias, freq_unit_str);
    if strcmp(freq_unit_str, 'MHz')
        fprintf('  Within +/- 0.10 MHz    : %.1f%%\n', 100 * mean(foF2_abs <= 0.10));
        fprintf('  Within +/- 0.25 MHz    : %.1f%%\n', 100 * mean(foF2_abs <= 0.25));
        fprintf('  Within +/- 0.50 MHz    : %.1f%%\n', 100 * mean(foF2_abs <= 0.50));
    end
    fprintf('============================================================\n');

    % 5. Save evaluation results next to the model file
    [m_dir, m_name, ~] = fileparts(model_path);
    eval_out_path = fullfile(m_dir, [m_name, '_eval_results.mat']);
    save(eval_out_path, 'evalResults', '-v7.3');
    fprintf('Saved full evaluation results to:\n  %s\n', eval_out_path);

    % 6. Generate summary plots and visual inspection gallery
    plot_summary_distributions(evalResults, foF2_err);
    plot_sample_predictions(trainedNet, evalResults, is_6ch, threshold, min_blob_size, default_f_grid);
end

% =========================================================================
% HELPER: EXTRACT CRITICAL FREQUENCY (foF2) FROM BINARY MASK
% =========================================================================

function [foF2_val, col_idx] = get_trace_foF2(bw_mask, f_vec)
% GET_TRACE_FOF2 Finds the high-frequency edge of the dominant O-mode trace.

    if ~any(bw_mask, 'all')
        foF2_val = NaN;
        col_idx  = NaN;
        return;
    end

    % Keep largest connected structures to prevent stray high-frequency noise from skewing foF2
    cc = bwconncomp(bw_mask);
    num_px = cellfun(@numel, cc.PixelIdxList);
    max_px = max(num_px);
    
    % Retain blobs that are at least 15% of the main trace size (handles split traces safely)
    valid_blobs = find(num_px >= max(10, 0.15 * max_px));
    clean_mask = false(size(bw_mask));
    for idx = valid_blobs
        clean_mask(cc.PixelIdxList{idx}) = true;
    end

    % Find columns containing at least one active trace pixel
    active_cols = find(any(clean_mask, 1));
    if isempty(active_cols)
        foF2_val = NaN;
        col_idx  = NaN;
    else
        col_idx  = active_cols(end);
        foF2_val = f_vec(col_idx);
    end
end

% =========================================================================
% HELPER: PLOT METRIC DISTRIBUTIONS
% =========================================================================

function plot_summary_distributions(res, foF2_err)
% PLOT_SUMMARY_DISTRIBUTIONS Creates a 3-panel figure with Dice and foF2 statistics.

    fig = figure('Name', 'CADI U-Net Test Evaluation Metrics', ...
                 'Color', 'w', 'Position', [100, 100, 1350, 420]);
    t = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, sprintf('Independent Test Set Evaluation (N = %d, Strategy: %s)', ...
        numel(res.dice_scores), strrep(res.strategy, '_', '\_')), 'FontWeight', 'bold', 'FontSize', 12);

    % Panel 1: Dice Score Histogram
    nexttile;
    histogram(res.dice_scores, 40, 'FaceColor', [0.15, 0.45, 0.75], 'EdgeColor', 'w');
    hold on;
    xline(res.mean_dice, '--r', sprintf('Mean: %.3f', res.mean_dice), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'middle');
    xline(res.median_dice, '-k', sprintf('Median: %.3f', res.median_dice), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'bottom');
    hold off;
    grid on;
    xlabel('Dice Score (F1)');
    ylabel('Number of Sessions');
    title('Dice Score Distribution');
    xlim([0, 1]);

    % Panel 2: foF2 Error Histogram (Pred - True)
    nexttile;
    histogram(foF2_err, 50, 'FaceColor', [0.85, 0.40, 0.15], 'EdgeColor', 'w');
    hold on;
    xline(0, '-k', 'Zero Error', 'LineWidth', 1.2);
    xline(res.foF2_bias, '--b', sprintf('Bias: %+.3f', res.foF2_bias), 'LineWidth', 1.5);
    hold off;
    grid on;
    xlabel(sprintf('\\DeltafoF2 = foF2_{pred} - foF2_{true} (%s)', res.freq_unit));
    ylabel('Number of Sessions');
    title(sprintf('foF2 Error (MAE = %.3f %s, RMSE = %.3f)', res.foF2_mae, res.freq_unit, res.foF2_rmse));

    % Panel 3: True vs Predicted foF2 Scatter
    nexttile;
    valid = ~isnan(res.foF2_true) & ~isnan(res.foF2_pred);
    scatter(res.foF2_true(valid), res.foF2_pred(valid), 12, [0.2, 0.6, 0.4], 'filled', 'MarkerFaceAlpha', 0.35);
    hold on;
    min_f = min([res.foF2_true(valid); res.foF2_pred(valid)]);
    max_f = max([res.foF2_true(valid); res.foF2_pred(valid)]);
    plot([min_f, max_f], [min_f, max_f], '--k', 'LineWidth', 1.5);
    hold off;
    grid on;
    axis equal;
    xlim([min_f, max_f]);
    ylim([min_f, max_f]);
    xlabel(sprintf('Ground Truth foF2 (%s)', res.freq_unit));
    ylabel(sprintf('Predicted foF2 (%s)', res.freq_unit));
    title('foF2: Ground Truth vs. U-Net Prediction');
end

% =========================================================================
% HELPER: VISUALIZE SAMPLE TEST PREDICTIONS
% =========================================================================

function plot_sample_predictions(trainedNet, res, is_6ch, threshold, min_blob_size, default_f_grid)
% PLOT_SAMPLE_PREDICTIONS Displays 6 representative test sessions (High, Median, and Lower Dice).

    [~, sorted_idx] = sort(res.dice_scores, 'descend');
    N = numel(sorted_idx);

    % Pick 2 high-performing, 2 median, and 2 lower-quartile examples (avoiding empty/corrupted masks)
    sample_ranks = round([0.05*N, 0.15*N, 0.45*N, 0.55*N, 0.80*N, 0.90*N]);
    sample_ranks = max(1, min(N, sample_ranks));
    chosen_indices = sorted_idx(sample_ranks);

    fig = figure('Name', 'CADI U-Net Sample Test Predictions', ...
                 'Color', 'w', 'Position', [120, 80, 1400, 780]);
    t = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, 'Visual Inspection on Unseen Test Sessions (Green = True Mask, Red = U-Net Prediction)', ...
        'FontWeight', 'bold', 'FontSize', 12);

    for i = 1:numel(chosen_indices)
        idx = chosen_indices(i);
        f_filt = res.test_filt_files{idx};
        f_orig = res.test_orig_files{idx};

        d_filt = load(f_filt);
        d_orig = load(f_orig);

        if is_6ch
            X_in = cat(3, single(d_filt.X_tensor), single(d_orig.X_tensor));
        else
            X_in = single(d_orig.X_tensor);
        end

        dlX = dlarray(X_in, 'SSCB');
        if canUseGPU
            dlX = gpuArray(dlX);
        end
        prob_map = gather(extractdata(predict(trainedNet, dlX)));
        mask_pred = bwareaopen(prob_map >= threshold, min_blob_size);
        mask_true = logical(d_filt.Y_mask > 0);

        if isfield(d_filt, 'f_grid')
            f_vec = double(d_filt.f_grid(:)');
        else
            f_vec = default_f_grid;
        end
        if isfield(d_filt, 'h_grid')
            h_vec = double(d_filt.h_grid(:));
        else
            h_vec = (1:192)';
        end

        % Display raw O-mode normalized channel using matrix column indices (1 to 96)
        % to match the U-Net tensor coordinate space perfectly.
        bg_img = squeeze(d_orig.X_tensor(:, :, 2));

        nexttile;
        imagesc(1:96, h_vec, bg_img);
        set(gca, 'YDir', 'normal');
        colormap(gca, gray);
        hold on;

        % Overlay Ground Truth (Green) and Predicted (Red) contours directly in tensor pixel coordinates
        if any(mask_true, 'all')
            contour(1:96, h_vec, double(mask_true), [0.5, 0.5], 'g', 'LineWidth', 1.2);
        end
        if any(mask_pred, 'all')
            contour(1:96, h_vec, double(mask_pred), [0.5, 0.5], 'r--', 'LineWidth', 1.5);
        end

        % Map physical foF2 values back to tensor column index space for correct line placement
        if ~isnan(res.foF2_true(idx))
            [~, idx_f_true] = min(abs(f_vec - res.foF2_true(idx)));
            xline(idx_f_true, '-g', 'LineWidth', 1.0);
        end
        if ~isnan(res.foF2_pred(idx))
            [~, idx_f_pred] = min(abs(f_vec - res.foF2_pred(idx)));
            xline(idx_f_pred, '--r', 'LineWidth', 1.2);
        end

        % Customize X-Axis ticks to show actual MHz frequencies instead of matrix column indices
        tick_locs = linspace(1, 96, 6);
        tick_vals = linspace(f_vec(1), f_vec(end), 6);
        set(gca, 'XTick', tick_locs, 'XTickLabel', arrayfun(@(x) sprintf('%.1f', x), tick_vals, 'UniformOutput', false));

        hold off;

        [~, s_name, ~] = fileparts(f_filt);
        title(sprintf('%s | Dice: %.3f | \\DeltafoF2: %+.2f %s', ...
            s_name, res.dice_scores(idx), res.foF2_error(idx), res.freq_unit), ...
            'Interpreter', 'tex', 'FontSize', 9.5);
        xlabel('Frequency (MHz)');
        ylabel('Virtual Height (km)');
    end
end