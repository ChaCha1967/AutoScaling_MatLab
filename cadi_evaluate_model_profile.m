function evalResults = cadi_evaluate_model_profile(model_path, threshold, min_blob_size, edge_choice)
% CADI_EVALUATE_MODEL_PROFILE Evaluates the trained U-Net model on the held-out 
% test split, extracts predicted virtual ionospheric profiles from masks 
% (top, center, or bottom edge), compares them against David's reference 
% virtual profiles (david_pts_virtual), and computes height error metrics.
%
% Inputs:
%   model_path    : Full path to the saved model .mat file
%                   (default: 'N:/cadi_synced_out/cadi_unet_6ch_combined.mat')
%   threshold     : Probability threshold for binary mask (default: 0.5)
%   min_blob_size : Minimum connected component area in pixels to filter noise (default: 15)
%   edge_choice   : Edge extraction method for virtual profile:
%                   'top'    - Upper edge of the trace (default)
%                   'center' - Vertical center of the trace per frequency column
%                   'bottom' - Lower edge of the trace
%
% Outputs:
%   evalResults   : Structure containing per-session metrics, profile errors, 
%                   and summary statistics.

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
    if nargin < 4 || isempty(edge_choice)
        edge_choice = 'top'; % Default to top edge
    end

    fprintf('============================================================\n');
    fprintf('   CADI U-NET PROFILE & TEST SET EVALUATION                 \n');
    fprintf('============================================================\n');
    fprintf('Loading model: %s\n', model_path);
    fprintf('Profile extraction edge mode: [%s]\n', edge_choice);

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
    dice_scores     = zeros(num_test, 1, 'single');
    iou_scores      = zeros(num_test, 1, 'single');
    foF2_true_arr   = nan(num_test, 1);
    foF2_pred_arr   = nan(num_test, 1);
    h_diff_mae_arr  = nan(num_test, 1);
    h_diff_rmse_arr = nan(num_test, 1);

    % Inspect the first test file for grid presence
    sample_info = whos('-file', test_filt_files{1});
    var_names   = {sample_info.name};
    has_f_grid  = any(strcmp(var_names, 'f_grid'));
    
    if has_f_grid
        tmp = load(test_filt_files{1}, 'f_grid');
        default_f_grid = double(tmp.f_grid(:)');
        freq_unit_str  = 'MHz';
    else
        default_f_grid = 1:96;
        freq_unit_str  = 'bins';
    end

    % 3. Run batched GPU inference and profile extraction across test split
    batch_size = 64;
    num_batches = ceil(num_test / batch_size);
    is_6ch = strcmpi(strategy, '6ch_combined');

    fprintf('Running inference & profile comparison on %d test sessions (%d batches)...\n', num_test, num_batches);
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

        % Predict probability maps on GPU
        dlX = dlarray(X_batch, 'SSCB');
        if canUseGPU
            dlX = gpuArray(dlX);
        end
        dlY_pred = predict(trainedNet, dlX);
        Y_prob_batch = gather(extractdata(dlY_pred));

        % Compute segmentation & virtual profile height errors per session
        for k = 1:cur_bs
            file_idx = cur_indices(k);
            prob_map  = Y_prob_batch(:, :, 1, k);
            mask_true = Y_batch_true(:, :, k);
            mask_pred = prob_map >= threshold;

            % Morphological cleanup
            mask_pred_clean = bwareaopen(mask_pred, min_blob_size);

            % Compute Dice and IoU
            inter = single(sum(mask_pred_clean & mask_true, 'all'));
            sum_p = single(sum(mask_pred_clean, 'all'));
            sum_t = single(sum(mask_true, 'all'));
            union_val = single(sum(mask_pred_clean | mask_true, 'all'));

            dice_scores(file_idx) = (2.0 * inter + 1e-5) / (sum_p + sum_t + 1e-5);
            iou_scores(file_idx)  = (inter + 1e-5) / (union_val + 1e-5);

            % Frequency vector for this session
            f_vec = f_grids_batch(k, :);
            h_vec = (1:192)'; % Default 192 height bins
            
            % Try loading custom h_grid if present in file
            f_filt = test_filt_files{file_idx};
            info_mat = whos('-file', f_filt);
            if any(strcmp({info_mat.name}, 'h_grid'))
                d_h = load(f_filt, 'h_grid');
                h_vec = double(d_h.h_grid(:));
            end

            % Extract true and predicted foF2
            [foF2_true_arr(file_idx), ~] = get_trace_foF2(mask_true, f_vec);
            [foF2_pred_arr(file_idx), ~] = get_trace_foF2(mask_pred_clean, f_vec);

            % Extract Virtual Profile from predicted mask and compare with david_pts_virtual
            [pred_f, pred_h] = extract_virtual_profile_from_mask(mask_pred_clean, f_vec, h_vec, edge_choice);
            
            % % Load reference david_pts_virtual directly from the test .mat file
            % d_ref = load(f_filt, 'david_pts_virtual');
            % if isfield(d_ref, 'david_pts_virtual') && ~isempty(d_ref.david_pts_virtual)
            %     ref_pts = d_ref.david_pts_virtual;
            %     valid_ref = ref_pts(:, 1) > 0 & ref_pts(:, 2) > 0;
            %     f_ref = ref_pts(valid_ref, 1);
            %     h_ref = ref_pts(valid_ref, 2);
            % 
            %     if numel(f_ref) > 2 && numel(pred_f) > 2
            %         % Interpolate onto common frequency grid for comparison
            %         common_f = linspace(max(min(f_ref), min(pred_f)), min(max(f_ref), max(pred_f)), 40);
            %         if numel(common_f) > 5
            %             h_ref_interp = interp1(f_ref, h_ref, common_f, 'linear', 'extrap');
            %             h_pred_interp = interp1(pred_f, pred_h, common_f, 'linear', 'extrap');
            % 
            %             dh = h_pred_interp - h_ref_interp;
            %             h_diff_mae_arr(file_idx) = mean(abs(dh));
            %             h_diff_rmse_arr(file_idx) = sqrt(mean(dh.^2));
            %         end
            %     end
            % end

            % Load reference david_pts_virtual directly from the test .mat file
            d_ref = load(f_filt, 'david_pts_virtual');
            if isfield(d_ref, 'david_pts_virtual') && ~isempty(d_ref.david_pts_virtual)
                ref_pts = d_ref.david_pts_virtual;
                valid_ref = ref_pts(:, 1) > 0 & ref_pts(:, 2) > 0;
                f_ref = ref_pts(valid_ref, 1);
                h_ref = ref_pts(valid_ref, 2);

                if numel(f_ref) > 2 && numel(pred_f) > 2
                    % Ensure sample points are strictly unique and sorted
                    [f_ref_unique, ref_idx] = unique(f_ref, 'stable');
                    h_ref_unique = h_ref(ref_idx);

                    [pred_f_unique, pred_idx] = unique(pred_f, 'stable');
                    pred_h_unique = pred_h(pred_idx);

                    if numel(f_ref_unique) > 2 && numel(pred_f_unique) > 2
                        % Interpolate onto common frequency grid for comparison
                        common_f = linspace(max(min(f_ref_unique), min(pred_f_unique)), ...
                            min(max(f_ref_unique), max(pred_f_unique)), 40);
                        if numel(common_f) > 5
                            h_ref_interp = interp1(f_ref_unique, h_ref_unique, common_f, 'linear', 'extrap');
                            h_pred_interp = interp1(pred_f_unique, pred_h_unique, common_f, 'linear', 'extrap');

                            dh = h_pred_interp - h_ref_interp;
                            h_diff_mae_arr(file_idx) = mean(abs(dh));
                            h_diff_rmse_arr(file_idx) = sqrt(mean(dh.^2));
                        end
                    end
                end
            end

        end

        if mod(b, 10) == 0 || b == num_batches
            fprintf('  Processed %d / %d sessions (%.1f s)\n', idx_end, num_test, toc(t_start));
        end
    end

    % 4. Compute statistical summaries
    valid_foF2  = ~isnan(foF2_true_arr) & ~isnan(foF2_pred_arr);
    foF2_err    = foF2_pred_arr(valid_foF2) - foF2_true_arr(valid_foF2);
    foF2_abs    = abs(foF2_err);
    valid_h_err = ~isnan(h_diff_mae_arr);

    evalResults = struct();
    evalResults.model_path      = model_path;
    evalResults.strategy        = strategy;
    evalResults.threshold       = threshold;
    evalResults.edge_choice     = edge_choice;
    evalResults.dice_scores     = dice_scores;
    evalResults.iou_scores      = iou_scores;
    evalResults.foF2_true       = foF2_true_arr;
    evalResults.foF2_pred       = foF2_pred_arr;
    evalResults.foF2_error      = foF2_pred_arr - foF2_true_arr;
    evalResults.h_diff_mae      = h_diff_mae_arr;
    evalResults.h_diff_rmse     = h_diff_rmse_arr;
    evalResults.freq_unit       = freq_unit_str;
    evalResults.test_filt_files = test_filt_files;
    evalResults.test_orig_files = test_orig_files;

    evalResults.mean_dice       = mean(dice_scores);
    evalResults.median_dice     = median(dice_scores);
    evalResults.std_dice        = std(dice_scores);
    evalResults.mean_iou        = mean(iou_scores);
    evalResults.foF2_mae        = mean(foF2_abs);
    evalResults.foF2_rmse       = sqrt(mean(foF2_err .^ 2));
    evalResults.foF2_bias       = mean(foF2_err);
    evalResults.profile_h_mae   = mean(h_diff_mae_arr(valid_h_err));
    evalResults.profile_h_rmse  = sqrt(mean(h_diff_rmse_arr(valid_h_err) .^ 2));
    evalResults.detection_rate  = 100 * sum(~isnan(foF2_pred_arr)) / num_test;

    % Print formatted summary report
    fprintf('\n============================================================\n');
    fprintf('   TEST SET EVALUATION SUMMARY (%d SESSIONS)               \n', num_test);
    fprintf('============================================================\n');
    fprintf('Segmentation Overlap Metrics:\n');
    fprintf('  Mean Dice Score (F1)   : %.4f  (Std: %.4f)\n', evalResults.mean_dice, evalResults.std_dice);
    fprintf('  Median Dice Score      : %.4f\n', evalResults.median_dice);
    fprintf('  Mean IoU (Jaccard)     : %.4f\n', evalResults.mean_iou);
    fprintf('------------------------------------------------------------\n');
    fprintf('Virtual Profile Height Error (%s edge extraction):\n', edge_choice);
    fprintf('  Profile Height MAE     : %.2f km\n', evalResults.profile_h_mae);
    fprintf('  Profile Height RMSE    : %.2f km\n', evalResults.profile_h_rmse);
    fprintf('------------------------------------------------------------\n');
    fprintf('Physical foF2 Accuracy Metrics (Unit: %s):\n', freq_unit_str);
    fprintf('  Trace Detection Rate   : %.2f%%\n', evalResults.detection_rate);
    fprintf('  foF2 MAE               : %.3f %s\n', evalResults.foF2_mae, freq_unit_str);
    fprintf('  foF2 RMSE              : %.3f %s\n', evalResults.foF2_rmse, freq_unit_str);
    fprintf('  foF2 Mean Bias (P - T) : %+.3f %s\n', evalResults.foF2_bias, freq_unit_str);
    fprintf('============================================================\n');

    % 5. Save evaluation results
    [m_dir, m_name, ~] = fileparts(model_path);
    eval_out_path = fullfile(m_dir, [m_name, '_profile_eval_results.mat']);
    save(eval_out_path, 'evalResults', '-v7.3');
    fprintf('Saved full evaluation results to:\n  %s\n', eval_out_path);

    % 6. Generate summary plots including profile error distributions
    plot_summary_distributions_profile(evalResults, foF2_err);

    % 7. Generate visual inspection gallery comparing virtual profiles
    plot_sample_virtual_profiles(trainedNet, evalResults, is_6ch, threshold, min_blob_size, default_f_grid);
end

% =========================================================================
% HELPER: EXTRACT VIRTUAL PROFILE FROM MASK
% =========================================================================

function [f_prof, h_prof] = extract_virtual_profile_from_mask(bw_mask, f_vec, h_vec, edge_choice)
% EXTRACT_VIRTUAL_PROFILE_FROM_MASK Derives f vs h profile based on edge choice.

    [row_indices, col_indices] = find(bw_mask);
    if isempty(col_indices)
        f_prof = [];
        h_prof = [];
        return;
    end

    unique_cols = unique(col_indices)';
    f_prof = zeros(size(unique_cols));
    h_prof = zeros(size(unique_cols));

    for c_i = 1:numel(unique_cols)
        c = unique_cols(c_i);
        rows_in_col = row_indices(col_indices == c);
        
        switch lower(edge_choice)
            case 'top'
                target_row = max(rows_in_col); % Upper edge
            case 'bottom'
                target_row = min(rows_in_col); % Lower edge
            case 'center'
                target_row = round(mean(rows_in_col)); % Vertical center
            otherwise
                target_row = round(mean(rows_in_col)); % Vertical center
        end
        
        h_prof(c_i) = h_vec(target_row);
        f_prof(c_i) = f_vec(c);
    end
end

% =========================================================================
% HELPER: EXTRACT CRITICAL FREQUENCY (foF2)
% =========================================================================

function [foF2_val, col_idx] = get_trace_foF2(bw_mask, f_vec)
    if ~any(bw_mask, 'all')
        foF2_val = NaN;
        col_idx  = NaN;
        return;
    end

    cc = bwconncomp(bw_mask);
    num_px = cellfun(@numel, cc.PixelIdxList);
    max_px = max(num_px);
    
    valid_blobs = find(num_px >= max(10, 0.15 * max_px));
    clean_mask = false(size(bw_mask));
    for idx = valid_blobs
        clean_mask(cc.PixelIdxList{idx}) = true;
    end

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
% HELPER: PLOT EXTENDED METRIC DISTRIBUTIONS
% =========================================================================

function plot_summary_distributions_profile(res, foF2_err)
% PLOT_SUMMARY_DISTRIBUTIONS_PROFILE Creates a 4-panel figure with Dice, foF2, and Profile Height errors.

    fig = figure('Name', 'CADI U-Net Profile & Test Evaluation Metrics', ...
                 'Color', 'w', 'Position', [100, 100, 1500, 480]);
    t = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, sprintf('Independent Test Set & Profile Evaluation (N = %d, Edge: %s)', ...
        numel(res.dice_scores), res.edge_choice), 'FontWeight', 'bold', 'FontSize', 12);

    % Panel 1: Dice Score Histogram
    nexttile;
    histogram(res.dice_scores, 40, 'FaceColor', [0.15, 0.45, 0.75], 'EdgeColor', 'w');
    hold on;
    xline(res.mean_dice, '--r', sprintf('Mean: %.3f', res.mean_dice), 'LineWidth', 1.5, 'LabelVerticalAlignment', 'middle');
    hold off;
    grid on;
    xlabel('Dice Score (F1)');
    ylabel('Number of Sessions');
    title('Dice Score Distribution');
    xlim([0, 1]);

    % Panel 2: Profile Height Error (MAE distribution)
    nexttile;
    valid_h = ~isnan(res.h_diff_mae);
    histogram(res.h_diff_mae(valid_h), 40, 'FaceColor', [0.55, 0.25, 0.65], 'EdgeColor', 'w');
    hold on;
    xline(res.profile_h_mae, '--r', sprintf('Mean MAE: %.1f km', res.profile_h_mae), 'LineWidth', 1.5);
    hold off;
    grid on;
    xlabel('Virtual Height MAE (km)');
    ylabel('Number of Sessions');
    title(sprintf('Virtual Profile Height Error\n(Mean MAE = %.2f km)', res.profile_h_mae));

    % Panel 3: foF2 Error Histogram
    nexttile;
    histogram(foF2_err, 50, 'FaceColor', [0.85, 0.40, 0.15], 'EdgeColor', 'w');
    hold on;
    xline(0, '-k', 'Zero Error', 'LineWidth', 1.2);
    xline(res.foF2_bias, '--b', sprintf('Bias: %+.3f', res.foF2_bias), 'LineWidth', 1.5);
    hold off;
    grid on;
    xlabel(sprintf('\\DeltafoF2 (%s)', res.freq_unit));
    ylabel('Number of Sessions');
    title(sprintf('foF2 Error (MAE = %.3f %s)', res.foF2_mae, res.freq_unit));

    % Panel 4: True vs Predicted foF2 Scatter
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
% HELPER: VISUALIZE SAMPLE VIRTUAL PROFILES (REFERENCE VS PREDICTED)
% =========================================================================

function plot_sample_virtual_profiles(trainedNet, res, is_6ch, threshold, min_blob_size, default_f_grid)
% PLOT_SAMPLE_VIRTUAL_PROFILES Displays 6 test sessions comparing David's 
% reference virtual profile against the U-Net extracted virtual profile.

    % Pick sessions that have valid virtual profile comparisons
    valid_sessions = find(~isnan(res.h_diff_mae));
    if isempty(valid_sessions)
        warning('No valid sessions with virtual profile comparisons found for plotting.');
        return;
    end

    % Select 6 representative sessions (best, median, and challenging)
    [~, sort_idx] = sort(res.h_diff_mae(valid_sessions), 'ascend');
    sorted_valid = valid_sessions(sort_idx);
    N_valid = numel(sorted_valid);

    sample_ranks = round([0.05*N_valid, 0.20*N_valid, 0.40*N_valid, 0.60*N_valid, 0.80*N_valid, 0.95*N_valid]);
    sample_ranks = max(1, min(N_valid, sample_ranks));
    chosen_indices = sorted_valid(sample_ranks);

    fig = function_figure_setup('CADI Virtual Profile Comparison', [120, 80, 1400, 780]);
    t = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
    title(t, sprintf('Virtual Profile Comparison: Reference (David) vs. U-Net Extracted (%s edge)', res.edge_choice), ...
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

        % Extract predicted virtual profile from mask using chosen edge mode
        [pred_f, pred_h] = extract_virtual_profile_from_mask(mask_pred, f_vec, h_vec, res.edge_choice);

        % Load reference david_pts_virtual
        d_ref = load(f_filt, 'david_pts_virtual');
        if isfield(d_ref, 'david_pts_virtual') && ~isempty(d_ref.david_pts_virtual)
            ref_pts = d_ref.david_pts_virtual;
            valid_ref = ref_pts(:, 1) > 0 & ref_pts(:, 2) > 0;
            f_ref = ref_pts(valid_ref, 1);
            h_ref = ref_pts(valid_ref, 2);
        else
            f_ref = []; h_ref = [];
        end

        % Background ionogram image
        bg_img = squeeze(d_orig.X_tensor(:, :, 2));

        nexttile;
        imagesc(1:96, h_vec, bg_img);
        set(gca, 'YDir', 'normal');
        colormap(gca, gray);
        hold on;

        % % Plot Reference Virtual Profile (Black circles/line)
        % if ~isempty(f_ref)
        %     % Map frequency values back to tensor column indices for display alignment
        %     [~, x_ref_idx] = arrayfun(@(f) min(abs(f_vec - f)), f_ref);
        %     plot(x_ref_idx, h_ref, 'ko-', 'LineWidth', 1.8, 'MarkerSize', 5, 'MarkerFaceColor', 'k', ...
        %         'DisplayName', 'Reference (David)');
        % end
        % 
        % % Plot Predicted Virtual Profile (Red squares/line)
        % if ~isempty(pred_f)
        %     [~, x_pred_idx] = arrayfun(@(f) min(abs(f_vec - f)), pred_f);
        %     plot(x_pred_idx, pred_h, 'rs-', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'r', ...
        %         'DisplayName', 'U-Net Extracted');
        % end

        % Plot Reference Virtual Profile (Cyan circles/line)
        if ~isempty(f_ref)
            % Map frequency values back to tensor column indices for display alignment
            [~, x_ref_idx] = arrayfun(@(f) min(abs(f_vec - f)), f_ref);
            plot(x_ref_idx, h_ref, 'co-', 'LineWidth', 2.0, 'MarkerSize', 6, 'MarkerFaceColor', 'c', ...
                'DisplayName', 'Reference (David)');
        end

        % Plot Predicted Virtual Profile (Red squares/line)
        if ~isempty(pred_f)
            [~, x_pred_idx] = arrayfun(@(f) min(abs(f_vec - f)), pred_f);
            plot(x_pred_idx, pred_h, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 4, 'MarkerFaceColor', 'r', ...
                'DisplayName', 'U-Net Extracted');
        end

        % Customize X-Axis ticks to show MHz frequencies
        tick_locs = linspace(1, 96, 6);
        tick_vals = linspace(f_vec(1), f_vec(end), 6);
        set(gca, 'XTick', tick_locs, 'XTickLabel', arrayfun(@(x) sprintf('%.1f', x), tick_vals, 'UniformOutput', false));

        hold off;
        legend('Location', 'NorthWest', 'FontSize', 8);

        [~, s_name, ~] = fileparts(f_filt);
        title(sprintf('%s | Profile MAE: %.1f km', s_name, res.h_diff_mae(idx)), ...
            'Interpreter', 'tex', 'FontSize', 9.5);
        xlabel('Frequency (MHz)');
        ylabel('Virtual Height (km)');
    end
end

function fig = function_figure_setup(fig_name, pos)
    fig = figure('Name', fig_name, 'Color', 'w', 'Position', pos);
end