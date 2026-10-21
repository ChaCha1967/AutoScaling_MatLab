% % function [X_tensor, Y_mask, roi_bbox, is_valid] = process_cadi_pair(ion_filepath, pol_filepath)
% % % PROCESS_CADI_PAIR Loads a pair of CADI _ion.mat and _pol.mat files and converts
% % % them into a 3-channel normalized input tensor (192x96x3) and binary ground truth mask (192x96).
% % %
% % % Inputs:
% % %   ion_filepath : Full path to the *_ion.mat file
% % %   pol_filepath : Full path to the corresponding *_pol.mat file
% % %
% % % Outputs:
% % %   X_tensor     : [192 x 96 x 3] single precision array in range [0, 1]
% % %                  Ch1 = Normalized mean cleaned amplitude (dB)
% % %                  Ch2 = O-mode energy map (corrected to match phase grouping)
% % %                  Ch3 = X-mode energy map (corrected to match phase grouping)
% % %   Y_mask       : [192 x 96] uint8 binary mask (0 = background, 1 = O-mode trace)
% % %   roi_bbox     : [1 x 4] bounding box [x_min, y_min, width, height] in pixels
% % %   is_valid     : Logical flag (false if data is corrupted or profile is empty)
% % 
% %     % Initialize default outputs
% %     H_pad = 192;
% %     W_pad = 96;
% %     X_tensor = zeros(H_pad, W_pad, 3, 'single');
% %     Y_mask   = zeros(H_pad, W_pad, 'uint8');
% %     roi_bbox = [0, 0, 0, 0];
% %     is_valid = false;
% % 
% %     % 1. Load data structures from .mat files
% %     if ~isfile(ion_filepath) || ~isfile(pol_filepath)
% %         return;
% %     end
% % 
% %     ion_data = load(ion_filepath, 'ion_dat', 'headerStruct');
% %     pol_data = load(pol_filepath, 'records');
% % 
% %     if ~isfield(ion_data, 'ion_dat') || ~isfield(pol_data, 'records')
% %         return;
% %     end
% % 
% %     ion_dat = ion_data.ion_dat;
% %     % Convert FreqS from Hz to MHz to match David's profile frequency scale
% %     f_grid  = double(ion_data.headerStruct.datablock.FreqS(:)') / 1e6; % [1 x W_orig] MHz
% %     h_grid  = double(ion_data.headerStruct.datablock.heights(:));       % [171 x 1] km
% % 
% %     david_pts = pol_data.records.InputData; % [N x 2] matrix: [Freq_MHz, VirtualHeight_km]
% %     if isempty(david_pts) || size(david_pts, 1) < 2
% %         return;
% %     end
% % 
% %     [~, H_orig, W_orig] = size(ion_dat); % Expected: 13 x 171 x 95 (or 92)
% % 
% %     % 2. Extract Channel 1: Mean Filtered Amplitude (slices 5 to 8) in dB
% %     M_clean_4ch = ion_dat(5:8, :, :);
% %     M_mean = squeeze(mean(M_clean_4ch, 1, 'omitnan'));
% %     M_mean(isnan(M_mean)) = 0;
% % 
% %     % Suppress non-physical E-region ground clutter below 85 km (rows 1:29)
% %     M_mean(h_grid < 85, :) = 0;
% % 
% %     max_dB = 50.0; % Upper saturation threshold for normalization
% %     Ch1_raw = min(max(M_mean, 0), max_dB) / max_dB;
% % 
% %     % 3. Extract Filtered Phase Differences (slices 11 and 12, in radians [-pi, pi])
% %     dPh23f = squeeze(ion_dat(11, :, :)); % NE pair (rad)
% %     dPh41f = squeeze(ion_dat(12, :, :)); % SW pair (rad)
% % 
% %     % Corrected mapping based on user analysis:
% %     % X-mode weights (previously assigned to O-mode variables)
% %     X_weight_23 = max(0, -sin(dPh23f)); X_weight_23(isnan(X_weight_23)) = 0;
% %     X_weight_41 = max(0, -sin(dPh41f)); X_weight_41(isnan(X_weight_41)) = 0;
% % 
% %     % O-mode weights (previously assigned to X-mode variables)
% %     O_weight_23 = max(0, +sin(dPh23f)); O_weight_23(isnan(O_weight_23)) = 0;
% %     O_weight_41 = max(0, +sin(dPh41f)); O_weight_41(isnan(O_weight_41)) = 0;
% % 
% %     % Modulate phase probabilities by normalized amplitude (Ch1_raw)
% %     % Ch2_raw assigned to True O-mode, Ch3_raw assigned to True X-mode
% %     Ch2_raw = Ch1_raw .* (0.5 * (O_weight_23 + O_weight_41)); % Pure O-mode energy
% %     Ch3_raw = Ch1_raw .* (0.5 * (X_weight_23 + X_weight_41)); % Pure X-mode energy
% % 
% %     % 4. Assemble and Zero-Pad Input Tensor X (192 x 96 x 3)
% %     X_tensor(1:H_orig, 1:W_orig, 1) = single(Ch1_raw);
% %     X_tensor(1:H_orig, 1:W_orig, 2) = single(Ch2_raw);
% %     X_tensor(1:H_orig, 1:W_orig, 3) = single(Ch3_raw);
% % 
% %     % 5. Rasterize David's Manual Profile into Binary Mask Y
% %     Y_mask_raw = false(H_orig, W_orig);
% % 
% %     d_freq   = david_pts(:, 1);  % Frequency in MHz
% %     d_height = david_pts(:, 2);  % Virtual height in km
% % 
% %     col_indices = zeros(size(d_freq));
% %     row_indices = zeros(size(d_height));
% % 
% %     for k = 1:numel(d_freq)
% %         [~, col_indices(k)] = min(abs(f_grid - d_freq(k)));
% %         [~, row_indices(k)] = min(abs(h_grid - d_height(k)));
% %     end
% % 
% %     % Filter out-of-bounds points
% %     valid_pts = col_indices >= 1 & col_indices <= W_orig & row_indices >= 1 & row_indices <= H_orig;
% %     col_indices = col_indices(valid_pts);
% %     row_indices = row_indices(valid_pts);
% % 
% %     if numel(col_indices) >= 2
% %         for k = 1:(numel(col_indices) - 1)
% %             c1 = col_indices(k);   r1 = row_indices(k);
% %             c2 = col_indices(k+1); r2 = row_indices(k+1);
% % 
% %             num_steps = ceil(max(abs(c2 - c1), abs(r2 - r1)) * 2) + 1;
% %             c_seg = round(linspace(c1, c2, num_steps));
% %             r_seg = round(linspace(r1, r2, num_steps));
% % 
% %             in_bounds = c_seg >= 1 & c_seg <= W_orig & r_seg >= 1 & r_seg <= H_orig;
% %             c_seg = c_seg(in_bounds);
% %             r_seg = r_seg(in_bounds);
% % 
% %             if ~isempty(c_seg)
% %                 lin_idx = sub2ind([H_orig, W_orig], r_seg, c_seg);
% %                 Y_mask_raw(lin_idx) = true;
% %             end
% %         end
% % 
% %         se = strel('disk', 2, 0);
% %         Y_mask_raw = imdilate(Y_mask_raw, se);
% % 
% %         [r_idx, c_idx] = find(Y_mask_raw);
% %         if ~isempty(r_idx)
% %             x_min = min(c_idx); x_max = max(c_idx);
% %             y_min = min(r_idx); y_max = max(r_idx);
% %             roi_bbox = [x_min, y_min, (x_max - x_min + 1), (y_max - y_min + 1)];
% %             is_valid = true;
% %         end
% %     end
% % 
% %     % Pad Ground Truth Mask to 192 x 96
% %     Y_mask(1:H_orig, 1:W_orig) = uint8(Y_mask_raw);
% % end

% % function [X_tensor, Y_mask, f_grid_padded, h_grid_padded, roi_bbox, is_valid] = process_cadi_pair(ion_filepath, pol_filepath)
% % % PROCESS_CADI_PAIR Loads a pair of CADI _ion.mat and _pol.mat files, resamples/pads
% % % them to a standardized 3-channel tensor (192x96x3) and binary mask (192x96),
% % % and extends frequency and height grids accordingly.
% % %
% % % Inputs:
% % %   ion_filepath  : Full path to the *_ion.mat file
% % %   pol_filepath  : Full path to the corresponding *_pol.mat file
% % %
% % % Outputs:
% % %   X_tensor      : [192 x 96 x 3] single precision array in range [0, 1]
% % %   Y_mask        : [192 x 96] uint8 binary mask (0 = background, 1 = O-mode trace)
% % %   f_grid_padded : [1 x 96] extended frequency grid (MHz)
% % %   h_grid_padded : [192 x 1] extended height grid (km)
% % %   roi_bbox      : [1 x 4] bounding box [x_min, y_min, width, height] in pixels
% % %   is_valid      : Logical flag (false if data is corrupted or profile is empty)
% % 
% %     % Initialize default outputs for target dimensions
% %     H_pad = 192;
% %     W_pad = 96;
% %     X_tensor = zeros(H_pad, W_pad, 3, 'single');
% %     Y_mask   = zeros(H_pad, W_pad, 'uint8');
% %     roi_bbox = [0, 0, 0, 0];
% %     is_valid = false;
% % 
% %     f_grid_padded = zeros(1, W_pad);
% %     h_grid_padded = zeros(H_pad, 1);
% % 
% %     % 1. Load data structures from .mat files
% %     if ~isfile(ion_filepath) || ~isfile(pol_filepath)
% %         return;
% %     end
% % 
% %     ion_data = load(ion_filepath, 'ion_dat', 'headerStruct');
% %     pol_data = load(pol_filepath, 'records');
% % 
% %     if ~isfield(ion_data, 'ion_dat') || ~isfield(pol_data, 'records')
% %         return;
% %     end
% % 
% %     ion_dat = ion_data.ion_dat;
% %     f_grid_orig = double(ion_data.headerStruct.datablock.FreqS(:)') / 1e6; % [1 x W_orig] MHz
% %     h_grid_orig = double(ion_data.headerStruct.datablock.heights(:));       % [H_orig x 1] km
% % 
% %     david_pts = pol_data.records.InputData; % [N x 2] matrix: [Freq_MHz, VirtualHeight_km]
% %     if isempty(david_pts) || size(david_pts, 1) < 2
% %         return;
% %     end
% % 
% %     [~, H_orig, W_orig] = size(ion_dat); % e.g., H_orig = 171, W_orig = 95 or 92
% % 
% %     % --- EXTEND HEIGHT GRID FROM H_orig TO H_pad (192) ---
% %     % Standard height step is 3 km. Add missing heights on top.
% %     h_step = 3.0; 
% %     if H_orig < H_pad
% %         h_grid_padded = zeros(H_pad, 1);
% %         h_grid_padded(1:H_orig) = h_grid_orig;
% %         for k = (H_orig + 1):H_pad
% %             h_grid_padded(k) = h_grid_padded(k-1) + h_step;
% %         end
% %     else
% %         h_grid_padded = h_grid_orig(1:H_pad);
% %     end
% % 
% %     % --- EXTEND FREQUENCY GRID FROM W_orig TO W_pad (96) ---
% %     % Frequency step increases in logarithmic/geometric proportion.
% %     if W_orig < W_pad
% %         f_grid_padded = zeros(1, W_pad);
% %         f_grid_padded(1:W_orig) = f_grid_orig;
% % 
% %         % Estimate average geometric growth factor from the tail of the existing grid
% %         log_diffs = diff(log(f_grid_orig(end-5:end)));
% %         avg_log_step = mean(log_diffs);
% % 
% %         for k = (W_orig + 1):W_pad
% %             f_grid_padded(k) = f_grid_padded(k-1) * exp(avg_log_step);
% %         end
% %     else
% %         f_grid_padded = f_grid_orig(1:W_pad);
% %     end
% % 
% %     % 2. Extract Channel 1: Mean Filtered Amplitude (slices 5 to 8) in dB
% %     M_clean_4ch = ion_dat(5:8, :, :);
% %     M_mean = squeeze(mean(M_clean_4ch, 1, 'omitnan'));
% %     M_mean(isnan(M_mean)) = 0;
% % 
% %     % Suppress non-physical E-region ground clutter below 85 km
% %     M_mean(h_grid_orig < 85, :) = 0;
% % 
% %     max_dB = 50.0; % Upper saturation threshold for normalization
% %     Ch1_raw = min(max(M_mean, 0), max_dB) / max_dB;
% % 
% %     % 3. Extract Filtered Phase Differences (slices 11 and 12, in radians [-pi, pi])
% %     dPh23f = squeeze(ion_dat(11, :, :)); % NE pair (rad)
% %     dPh41f = squeeze(ion_dat(12, :, :)); % SW pair (rad)
% % 
% %     % Corrected phase weighting mapping
% %     X_weight_23 = max(0, -sin(dPh23f)); X_weight_23(isnan(X_weight_23)) = 0;
% %     X_weight_41 = max(0, -sin(dPh41f)); X_weight_41(isnan(X_weight_41)) = 0;
% % 
% %     O_weight_23 = max(0, +sin(dPh23f)); O_weight_23(isnan(O_weight_23)) = 0;
% %     O_weight_41 = max(0, +sin(dPh41f)); O_weight_41(isnan(O_weight_41)) = 0;
% % 
% %     Ch2_raw = Ch1_raw .* (0.5 * (O_weight_23 + O_weight_41)); % Pure O-mode energy
% %     Ch3_raw = Ch1_raw .* (0.5 * (X_weight_23 + X_weight_41)); % Pure X-mode energy
% % 
% %     % 4. Assemble into padded Input Tensor X (192 x 96 x 3)
% %     % Copy original data into the upper-left (or corresponding) region
% %     copy_H = min(H_orig, H_pad);
% %     copy_W = min(W_orig, W_pad);
% % 
% %     X_tensor(1:copy_H, 1:copy_W, 1) = single(Ch1_raw(1:copy_H, 1:copy_W));
% %     X_tensor(1:copy_H, 1:copy_W, 2) = single(Ch2_raw(1:copy_H, 1:copy_W));
% %     X_tensor(1:copy_H, 1:copy_W, 3) = single(Ch3_raw(1:copy_H, 1:copy_W));
% % 
% %     % 5. Rasterize David's Manual Profile into Binary Mask Y on original scale, then pad
% %     Y_mask_raw = false(H_orig, W_orig);
% % 
% %     d_freq   = david_pts(:, 1);  % Frequency in MHz
% %     d_height = david_pts(:, 2);  % Virtual height in km
% % 
% %     col_indices = zeros(size(d_freq));
% %     row_indices = zeros(size(d_height));
% % 
% %     for k = 1:numel(d_freq)
% %         [~, col_indices(k)] = min(abs(f_grid_orig - d_freq(k)));
% %         [~, row_indices(k)] = min(abs(h_grid_orig - d_height(k)));
% %     end
% % 
% %     valid_pts = col_indices >= 1 & col_indices <= W_orig & row_indices >= 1 & row_indices <= H_orig;
% %     col_indices = col_indices(valid_pts);
% %     row_indices = row_indices(valid_pts);
% % 
% %     if numel(col_indices) >= 2
% %         for k = 1:(numel(col_indices) - 1)
% %             c1 = col_indices(k);   r1 = row_indices(k);
% %             c2 = col_indices(k+1); r2 = row_indices(k+1);
% % 
% %             num_steps = ceil(max(abs(c2 - c1), abs(r2 - r1)) * 2) + 1;
% %             c_seg = round(linspace(c1, c2, num_steps));
% %             r_seg = round(linspace(r1, r2, num_steps));
% % 
% %             in_bounds = c_seg >= 1 & c_seg <= W_orig & r_seg >= 1 & r_seg <= H_orig;
% %             c_seg = c_seg(in_bounds);
% %             r_seg = r_seg(in_bounds);
% % 
% %             if ~isempty(c_seg)
% %                 lin_idx = sub2ind([H_orig, W_orig], r_seg, c_seg);
% %                 Y_mask_raw(lin_idx) = true;
% %             end
% %         end
% % 
% %         se = strel('disk', 2, 0);
% %         Y_mask_raw = imdilate(Y_mask_raw, se);
% % 
% %         [r_idx, c_idx] = find(Y_mask_raw);
% %         if ~isempty(r_idx)
% %             x_min = min(c_idx); x_max = max(c_idx);
% %             y_min = min(r_idx); y_max = max(r_idx);
% %             roi_bbox = [x_min, y_min, (x_max - x_min + 1), (y_max - y_min + 1)];
% %             is_valid = true;
% %         end
% %     end
% % 
% %     % Pad Ground Truth Mask to 192 x 96
% %     Y_mask(1:copy_H, 1:copy_W) = uint8(Y_mask_raw(1:copy_H, 1:copy_W));
% % end

function [X_tensor, Y_mask, f_grid_padded, h_grid_padded, H_orig, W_orig, roi_bbox, david_pts_virtual, david_pts_real, Peak_foF2, Peak_hmF2, is_valid] = process_cadi_pair(ion_filepath, pol_filepath, nCell_Y_mask, dirCell_Y_mask)
% PROCESS_CADI_PAIR Loads a pair of CADI _ion.mat and _pol.mat files, resamples/pads
% them to a standardized 3-channel tensor (192x96x3) and binary logical mask (192x96),
% extracts virtual/real profiles and F2 peak parameters from POLAN records.

    % Set default parameters if not provided
    if nargin < 3 || isempty(nCell_Y_mask), nCell_Y_mask = 2; end
    if nargin < 4 || isempty(dirCell_Y_mask), dirCell_Y_mask = -1; end

    % Initialize default outputs for target dimensions
    H_pad = 192;
    W_pad = 96;
    X_tensor = zeros(H_pad, W_pad, 3, 'single');
    Y_mask   = false(H_pad, W_pad); 
    roi_bbox = [0, 0, 0, 0];
    is_valid = false;
    H_orig = 0;
    W_orig = 0;
    
    f_grid_padded = zeros(1, W_pad);
    h_grid_padded = zeros(H_pad, 1);
    david_pts_virtual = [];
    david_pts_real = [];
    Peak_foF2 = NaN;
    Peak_hmF2 = NaN;

    % 1. Load data structures from .mat files
    if ~isfile(ion_filepath) || ~isfile(pol_filepath)
        return;
    end
    
    ion_data = load(ion_filepath, 'ion_dat', 'headerStruct');
    pol_data = load(pol_filepath);
    
    if ~isfield(ion_data, 'ion_dat') || ~isfield(pol_data, 'records')
        return;
    end
    
    ion_dat = ion_data.ion_dat;
    f_grid_orig = double(ion_data.headerStruct.datablock.FreqS(:)') / 1e6; % [1 x W_orig] MHz
    h_grid_orig = double(ion_data.headerStruct.datablock.heights(:));       % [H_orig x 1] km
    
    % --- EXTRACT VIRTUAL PROFILE (InputData) ---
    if isfield(pol_data.records, 'InputData')
        david_pts_virtual = pol_data.records.InputData;
    end
    
    if isempty(david_pts_virtual) || size(david_pts_virtual, 1) < 2
        return;
    end

    % --- EXTRACT REAL POLAN PROFILE (RealHeights: 2 x N -> transpose to N x 2) ---
    if isfield(pol_data.records, 'RealHeights') && ~isempty(pol_data.records.RealHeights)
        rh = pol_data.records.RealHeights;
        if size(rh, 1) == 2 && size(rh, 2) > 2
            david_pts_real = rh'; % Convert [2 x N] to [N x 2]
        else
            david_pts_real = rh;
        end
    end

    % --- EXTRACT F2 PEAK PARAMETERS (foF2 and hmF2) ---
    if isfield(pol_data.records, 'Peak')
        if isfield(pol_data.records.Peak, 'foF2') && ~isempty(pol_data.records.Peak.foF2)
            Peak_foF2 = pol_data.records.Peak.foF2;
        end
        if isfield(pol_data.records.Peak, 'hmF2') && ~isempty(pol_data.records.Peak.hmF2)
            Peak_hmF2 = pol_data.records.Peak.hmF2;
        end
    end

    [~, H_orig, W_orig] = size(ion_dat);

    % --- EXTEND HEIGHT GRID FROM H_orig TO H_pad (192) ---
    h_step = 3.0; 
    if H_orig < H_pad
        h_grid_padded(1:H_orig) = h_grid_orig;
        for k = (H_orig + 1):H_pad
            h_grid_padded(k) = h_grid_padded(k-1) + h_step;
        end
    else
        h_grid_padded = h_grid_orig(1:H_pad);
    end

    % --- EXTEND FREQUENCY GRID FROM W_orig TO W_pad (96) ---
    if W_orig < W_pad
        f_grid_padded(1:W_orig) = f_grid_orig;
        log_diffs = diff(log(f_grid_orig(end-5:end)));
        avg_log_step = mean(log_diffs);
        for k = (W_orig + 1):W_pad
            f_grid_padded(k) = f_grid_padded(k-1) * exp(avg_log_step);
        end
    else
        f_grid_padded = f_grid_orig(1:W_pad);
    end

    % 2. Extract Channel 1: Mean Filtered Amplitude (slices 5 to 8) in dB
    M_clean_4ch = ion_dat(5:8, :, :);
    M_mean = squeeze(mean(M_clean_4ch, 1, 'omitnan'));
    M_mean(isnan(M_mean)) = 0;
    
    % Suppress non-physical E-region ground clutter below 85 km
    M_mean(h_grid_orig < 85, :) = 0;
    
    max_dB = 50.0;
    Ch1_raw = min(max(M_mean, 0), max_dB) / max_dB;

    % 3. Extract Filtered Phase Differences (slices 11 and 12, in radians [-pi, pi])
    dPh23f = squeeze(ion_dat(11, :, :));
    dPh41f = squeeze(ion_dat(12, :, :));

    X_weight_23 = max(0, -sin(dPh23f)); X_weight_23(isnan(X_weight_23)) = 0;
    X_weight_41 = max(0, -sin(dPh41f)); X_weight_41(isnan(X_weight_41)) = 0;
    O_weight_23 = max(0, +sin(dPh23f)); O_weight_23(isnan(O_weight_23)) = 0;
    O_weight_41 = max(0, +sin(dPh41f)); O_weight_41(isnan(O_weight_41)) = 0;

    Ch2_raw = Ch1_raw .* (0.5 * (O_weight_23 + O_weight_41));
    Ch3_raw = Ch1_raw .* (0.5 * (X_weight_23 + X_weight_41));

    % 4. Assemble into padded Input Tensor X (192 x 96 x 3)
    copy_H = min(H_orig, H_pad);
    copy_W = min(W_orig, W_pad);
    
    X_tensor(1:copy_H, 1:copy_W, 1) = single(Ch1_raw(1:copy_H, 1:copy_W));
    X_tensor(1:copy_H, 1:copy_W, 2) = single(Ch2_raw(1:copy_H, 1:copy_W));
    X_tensor(1:copy_H, 1:copy_W, 3) = single(Ch3_raw(1:copy_H, 1:copy_W));

    % 5. Rasterize David's Manual Profile into Binary Mask Y on original scale
    Y_mask_raw = false(H_orig, W_orig);

    d_freq   = david_pts_virtual(:, 1);
    d_height = david_pts_virtual(:, 2);

    col_indices = zeros(size(d_freq));
    row_indices = zeros(size(d_height));

    for k = 1:numel(d_freq)
        [~, col_indices(k)] = min(abs(f_grid_orig - d_freq(k)));
        [~, row_indices(k)] = min(abs(h_grid_orig - d_height(k)));
    end

    valid_pts = col_indices >= 1 & col_indices <= W_orig & row_indices >= 1 & row_indices <= H_orig;
    col_indices = col_indices(valid_pts);
    row_indices = row_indices(valid_pts);

    if numel(col_indices) >= 2
        for k = 1:(numel(col_indices) - 1)
            c1 = col_indices(k);   r1 = row_indices(k);
            c2 = col_indices(k+1); r2 = row_indices(k+1);

            num_steps = ceil(max(abs(c2 - c1), abs(r2 - r1)) * 2) + 1;
            c_seg = round(linspace(c1, c2, num_steps));
            r_seg = round(linspace(r1, r2, num_steps));

            in_bounds = c_seg >= 1 & c_seg <= W_orig & r_seg >= 1 & r_seg <= H_orig;
            c_seg = c_seg(in_bounds);
            r_seg = r_seg(in_bounds);

            if ~isempty(c_seg)
                lin_idx = sub2ind([H_orig, W_orig], r_seg, c_seg);
                Y_mask_raw(lin_idx) = true;
            end
        end

        % Apply directional expansion based on user parameters (default: -1 downwards from upper edge)
        Y_mask_raw = directional_dilate(Y_mask_raw, nCell_Y_mask, dirCell_Y_mask);

        [r_idx, c_idx] = find(Y_mask_raw);
        if ~isempty(r_idx)
            x_min = min(c_idx); x_max = max(c_idx);
            y_min = min(r_idx); y_max = max(r_idx);
            roi_bbox = [x_min, y_min, (x_max - x_min + 1), (y_max - y_min + 1)];
            is_valid = true;
        end
    end

    % Pad Ground Truth Mask to 192 x 96 (logical type)
    Y_mask(1:copy_H, 1:copy_W) = logical(Y_mask_raw(1:copy_H, 1:copy_W));
end

function mask_out = directional_dilate(mask_in, nCell, dirCell)
    mask_out = mask_in;
    if nCell <= 0, return; end
    
    if dirCell == 0
        se = strel('disk', nCell, 0);
        mask_out = imdilate(mask_in, se);
    elseif dirCell == -1
        for d = 1:nCell
            shifted = false(size(mask_in));
            shifted(1:end-d, :) = mask_in(d+1:end, :);
            mask_out = mask_out | shifted;
        end
        se = strel('line', 3, 0);
        mask_out = imdilate(mask_out, se);
    elseif dirCell == +1
        for d = 1:nCell
            shifted = false(size(mask_in));
            shifted(d+1:end, :) = mask_in(1:end-d, :);
            mask_out = mask_out | shifted;
        end
        se = strel('line', 3, 0);
        mask_out = imdilate(mask_out, se);
    end
end