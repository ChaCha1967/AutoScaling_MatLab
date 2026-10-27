function [X_tensor, Y_mask, f_grid_padded, h_grid_padded, H_orig, W_orig, roi_bbox, david_pts_virtual, david_pts_real, Peak_foF2, Peak_hmF2, is_valid] = process_cadi_pair(ion_filepath, pol_filepath, nCell_Y_mask, dirCell_Y_mask, use_filtered)
% PROCESS_CADI_PAIR Loads a pair of CADI _ion.mat and _pol.mat files, resamples/pads
% them to a standardized 3-channel tensor (192x96x3) and binary logical mask (192x96),
% extracts virtual/real profiles and F2 peak parameters from POLAN records.
%
% Inputs:
%   ion_filepath   : Full path to the *_ion.mat file
%   pol_filepath   : Full path to the corresponding *_pol.mat file
%   nCell_Y_mask   : Number of cells/pixels to expand the mask (default: 2)
%   dirCell_Y_mask : Direction of expansion (-1: down from upper edge, 0: symmetric, +1: up)
%   use_filtered   : Logical flag (true = filtered slices [5:8, 11:12], false = original noisy slices [1:4, 9:10])

    % Set default parameters if not provided
    if nargin < 3 || isempty(nCell_Y_mask), nCell_Y_mask = 2; end
    if nargin < 4 || isempty(dirCell_Y_mask), dirCell_Y_mask = -1; end
    if nargin < 5 || isempty(use_filtered), use_filtered = true; end

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

    % Select slices based on use_filtered flag
    if logical(use_filtered)
        amp_slices = 5:8;
        ph_ne_idx  = 11;
        ph_sw_idx  = 12;
    else
        amp_slices = 1:4;
        ph_ne_idx  = 9;
        ph_sw_idx  = 10;
    end

    % 2. Extract Channel 1: Mean Amplitude in dB
    M_4ch = ion_dat(amp_slices, :, :);
    M_mean = squeeze(mean(M_4ch, 1, 'omitnan'));
    M_mean(isnan(M_mean)) = 0;
    
    % Suppress non-physical E-region ground clutter below 85 km
    M_mean(h_grid_orig < 85, :) = 0;
    
    max_dB = 50.0;
    Ch1_raw = min(max(M_mean, 0), max_dB) / max_dB;

    % 3. Extract Phase Differences (in radians [-pi, pi])
    dPh23 = squeeze(ion_dat(ph_ne_idx, :, :));
    dPh41 = squeeze(ion_dat(ph_sw_idx, :, :));

    X_weight_23 = max(0, -sin(dPh23)); X_weight_23(isnan(X_weight_23)) = 0;
    X_weight_41 = max(0, -sin(dPh41)); X_weight_41(isnan(X_weight_41)) = 0;
    O_weight_23 = max(0, +sin(dPh23)); O_weight_23(isnan(O_weight_23)) = 0;
    O_weight_41 = max(0, +sin(dPh41)); O_weight_41(isnan(O_weight_41)) = 0;

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