function success = cadi_visualize_from_mat(out_filepath, use_filtered)
% CADI_VISUALIZE_FROM_MAT Batch visualizes unified CADI dataset .mat files across a
% directory tree using pre-initialized graphics handles for maximum rendering speed,
% saving output figures as .png files alongside the source .mat files.
%
% Inputs:
%   out_filepath : Path to the root folder containing processed .mat files (or a single .mat file)
%   use_filtered : Logical flag (true = visualize filtered ID.mat -> ID.png; 
%                                false = visualize original noisy IDo.mat -> IDo.png)
%
% Output:
%   success      : Logical flag (true if batch visualization completed successfully)

    success = false;

    % 1. Resolve input arguments
    if nargin < 1 || isempty(out_filepath)
        out_filepath = uigetdir(pwd, 'Select Root Folder with Processed CADI MAT Files');
        if isequal(out_filepath, 0)
            disp('User cancelled folder selection.');
            return;
        end
    end
    if nargin < 2 || isempty(use_filtered)
        use_filtered = true;
    end
    use_filtered = logical(use_filtered);

    if isfolder(out_filepath)
        all_mat = dir(fullfile(out_filepath, '**', '*.mat'));
        % Filter out raw *_ion.mat and *_pol.mat files in case folders overlap
        is_raw = endsWith({all_mat.name}, '_ion.mat', 'IgnoreCase', true) | ...
                 endsWith({all_mat.name}, '_pol.mat', 'IgnoreCase', true);
        candidate_files = all_mat(~is_raw);
        
        % Select either original noisy (*o.mat) or filtered (*.mat without trailing 'o')
        is_orig_noisy = endsWith({candidate_files.name}, 'o.mat', 'IgnoreCase', false);
        if use_filtered
            mat_files = candidate_files(~is_orig_noisy);
        else
            mat_files = candidate_files(is_orig_noisy);
        end
    elseif isfile(out_filepath)
        [f_dir, f_name, f_ext] = fileparts(out_filepath);
        mat_files = struct('folder', f_dir, 'name', [f_name, f_ext]);
    else
        error('Invalid out_filepath specified: %s', out_filepath);
    end

    num_files = numel(mat_files);
    if num_files == 0
        fprintf('No matching dataset .mat files (use_filtered = %d) found in: %s\n', use_filtered, out_filepath);
        return;
    end

    fprintf('Found %d MAT files (use_filtered = %d) for visualization. Initializing graphics template...\n', ...
        num_files, use_filtered);

    % =========================================================================
    % 2. PRE-INITIALIZE FIGURE, AXES, AND GRAPHICS OBJECTS (ONCE BEFORE LOOP)
    % =========================================================================
    axis_font_size  = 13;
    label_font_size = 15;
    title_font_size = 15;
    base_freq_ticks = [2 3 4 5 6 7 8 9 10 12 15 19];

    % Create main figure window
    hFig = figure('Color', 'w', 'Position', [50, 100, 1750, 620], ...
        'Name', 'CADI Batch Visualization', 'NumberTitle', 'off', ...
        'PaperPositionMode', 'auto');

    % Dummy initial grids (2x2) to instantiate graphics handles
    [F_init, H_init] = meshgrid([2, 19], [0, 510]);
    Z_init   = zeros(2, 2);
    C_init   = zeros(2, 2);
    RGB_init = ones(2, 2, 3);

    % --- Initialize Panel 1: Amplitude Power Ionogram ---
    ax1 = subplot(1, 3, 1, 'Parent', hFig);
    custom_parula = parula(256);
    custom_parula(1, :) = [1, 1, 1]; % Pure white background for zero values
    
    hSurf1 = surf(ax1, F_init, H_init, Z_init, C_init, 'EdgeColor', 'none');
    view(ax1, 2);
    colormap(ax1, custom_parula);
    cb1 = colorbar(ax1);
    cb1.FontSize = axis_font_size;
    
    hBox1 = init_panel_axes(ax1, [2, 19], 510, base_freq_ticks, axis_font_size);
    hTitle1 = title(ax1, 'Amplitude (Ch 1)', 'FontSize', title_font_size, 'FontWeight', 'bold', 'Interpreter', 'none');
    xlabel(ax1, 'Frequency (MHz)', 'FontSize', label_font_size);
    ylabel(ax1, 'Virtual Height (km)', 'FontSize', label_font_size);

    % --- Initialize Panel 2: O-mode (Blue) & X-mode (Red) ---
    ax2 = subplot(1, 3, 2, 'Parent', hFig);
    hSurf2 = surf(ax2, F_init, H_init, Z_init, RGB_init, 'EdgeColor', 'none');
    view(ax2, 2);
    
    hBox2 = init_panel_axes(ax2, [2, 19], 510, base_freq_ticks, axis_font_size);
    title(ax2, 'O-mode (Blue) & X-mode (Red)', 'FontSize', title_font_size, 'FontWeight', 'bold');
    xlabel(ax2, 'Frequency (MHz)', 'FontSize', label_font_size);
    ylabel(ax2, 'Virtual Height (km)', 'FontSize', label_font_size);

    % --- Initialize Panel 3: Modes + Mask Contour & Profile ---
    ax3 = subplot(1, 3, 3, 'Parent', hFig);
    hSurf3 = surf(ax3, F_init, H_init, Z_init, RGB_init, 'EdgeColor', 'none');
    view(ax3, 2);
    hold(ax3, 'on');
    
    % Initialize contour object and profile line elevated in Z so they stay above surf
    [~, hCont3] = contour(ax3, F_init, H_init, [0 1; 0 1], [0.5, 0.5], ...
        'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5);
    hProf3 = plot3(ax3, NaN, NaN, NaN, 'k-', 'LineWidth', 1.5);
    hold(ax3, 'off');
    
    hBox3 = init_panel_axes(ax3, [2, 19], 510, base_freq_ticks, axis_font_size);
    title(ax3, 'Mask Contour & Profile', 'FontSize', title_font_size, 'FontWeight', 'bold');
    xlabel(ax3, 'Frequency (MHz)', 'FontSize', label_font_size);
    ylabel(ax3, 'Virtual Height (km)', 'FontSize', label_font_size);

    % =========================================================================
    % 3. BATCH PROCESSING LOOP (FAST HANDLE UPDATES ONLY)
    % =========================================================================
    required_fields = {'X_tensor', 'Y_mask', 'f_grid', 'h_grid', 'H_orig', 'W_orig', 'david_pts_virtual'};
    rendered_count  = 0;
    report_step     = max(1, floor(num_files / 20));

    for i = 1:num_files
        sample_path = fullfile(mat_files(i).folder, mat_files(i).name);
        
        % Load sample data safely
        try
            loaded_data = load(sample_path);
        catch
            warning('Failed to load file: %s. Skipping.', sample_path);
            continue;
        end

        % Verify required dataset fields
        has_all_fields = true;
        for k = 1:numel(required_fields)
            if ~isfield(loaded_data, required_fields{k})
                has_all_fields = false;
                break;
            end
        end
        if ~has_all_fields
            continue;
        end

        X_tensor          = loaded_data.X_tensor;
        Y_mask            = loaded_data.Y_mask > 0;
        f_grid            = loaded_data.f_grid;
        h_grid            = loaded_data.h_grid;
        H_orig            = loaded_data.H_orig;
        W_orig            = loaded_data.W_orig;
        david_pts_virtual = loaded_data.david_pts_virtual;

        if size(X_tensor, 3) ~= 3 || H_orig < 2 || W_orig < 2
            continue;
        end

        % Trim data to original boundaries before zero-padding
        f_axis = double(f_grid(1:W_orig));
        h_axis = double(h_grid(1:H_orig));
        
        amp_trimmed  = double(X_tensor(1:H_orig, 1:W_orig, 1));
        o_trimmed    = double(X_tensor(1:H_orig, 1:W_orig, 2));
        x_trimmed    = double(X_tensor(1:H_orig, 1:W_orig, 3));
        mask_trimmed = double(Y_mask(1:H_orig, 1:W_orig));

        [F_grid, H_grid] = meshgrid(f_axis, h_axis);
        Z_zeros = zeros(H_orig, W_orig);

        % Build High-Contrast RGB Composite for Panels 2 & 3
        rgb_modes = ones(H_orig, W_orig, 3);
        mask_o = o_trimmed > 0;
        mask_x = x_trimmed > 0;
        
        if any(mask_o(:))
            o_scale = prctile(o_trimmed(mask_o), 95);
            if o_scale <= 0, o_scale = 1; end
            o_norm = min(1, o_trimmed / o_scale) .^ 0.55;
        else
            o_norm = zeros(H_orig, W_orig);
        end
        
        if any(mask_x(:))
            x_scale = prctile(x_trimmed(mask_x), 95);
            if x_scale <= 0, x_scale = 1; end
            x_norm = min(1, x_trimmed / x_scale) .^ 0.55;
        else
            x_norm = zeros(H_orig, W_orig);
        end

        o_boost = mask_o .* (0.35 + 0.65 * o_norm);
        x_boost = mask_x .* (0.35 + 0.65 * x_norm);

        rgb_modes(:,:,1) = max(0, 1 - 0.95 * o_boost - 0.05 * x_boost);
        rgb_modes(:,:,2) = max(0, 1 - 0.85 * o_boost - 0.90 * x_boost);
        rgb_modes(:,:,3) = max(0, 1 - 0.05 * o_boost - 0.90 * x_boost);

        % --- Update Axes Limits & Ticks if Grid Dimensions Changed ---
        f_min = f_axis(1);
        f_max = f_axis(end);
        h_max = max(h_axis);
        valid_ticks = base_freq_ticks(base_freq_ticks >= f_min & base_freq_ticks <= f_max);
        tick_labels = arrayfun(@num2str, valid_ticks, 'UniformOutput', false);

        update_panel_limits(ax1, hBox1, f_min, f_max, h_max, valid_ticks, tick_labels);
        update_panel_limits(ax2, hBox2, f_min, f_max, h_max, valid_ticks, tick_labels);
        update_panel_limits(ax3, hBox3, f_min, f_max, h_max, valid_ticks, tick_labels);

        % --- Update Panel 1 Data & Date/Time Title ---
        set(hSurf1, 'XData', F_grid, 'YData', H_grid, 'ZData', Z_zeros, 'CData', amp_trimmed);
        max_amp = max(amp_trimmed(:));
        if max_amp > 0
            caxis(ax1, [0, max_amp]);
        else
            caxis(ax1, [0, 1]);
        end
        
        [~, base_name, ~] = fileparts(mat_files(i).name);
        dt_str = extract_cadi_datetime(base_name, loaded_data);
        if use_filtered
            set(hTitle1, 'String', sprintf('%s | Amplitude (Ch 1)', dt_str));
        else
            set(hTitle1, 'String', sprintf('%s | Amplitude Orig (Ch 1)', dt_str));
        end

        % --- Update Panel 2 Data ---
        set(hSurf2, 'XData', F_grid, 'YData', H_grid, 'ZData', Z_zeros, 'CData', rgb_modes);

        % --- Update Panel 3 Data (Surf + Contour + David's Profile) ---
        set(hSurf3, 'XData', F_grid, 'YData', H_grid, 'ZData', Z_zeros, 'CData', rgb_modes);
        set(hCont3, 'XData', F_grid, 'YData', H_grid, 'ZData', mask_trimmed);

        if ~isempty(david_pts_virtual)
            n_pts = size(david_pts_virtual, 1);
            set(hProf3, 'XData', david_pts_virtual(:, 1), ...
                        'YData', david_pts_virtual(:, 2), ...
                        'ZData', ones(n_pts, 1) * 0.2); % Elevated in Z to stay above surf
        else
            set(hProf3, 'XData', NaN, 'YData', NaN, 'ZData', NaN);
        end

        % Flush graphics pipeline and save PNG in the same folder with the same base name (including 'o' if noisy)
        drawnow limitrate;
        png_out_path = fullfile(mat_files(i).folder, [base_name, '.png']);
        exportgraphics(hFig, png_out_path, 'Resolution', 150);

        rendered_count = rendered_count + 1;
        if mod(i, report_step) == 0 || i == num_files
            fprintf('Visualization progress: %.1f%% (%d / %d files processed, %d PNGs saved)\n', ...
                (i / num_files) * 100, i, num_files, rendered_count);
        end
    end

    drawnow;
    fprintf('Batch visualization finished! Saved %d PNG images.\n', rendered_count);
    success = (rendered_count > 0);
end

% =========================================================================
% HELPER FUNCTIONS
% =========================================================================

function hBox = init_panel_axes(ax, f_lim, h_max, freq_ticks, font_size)
% INIT_PANEL_AXES Configures logarithmic X-axis, ticks, and creates top/right border handle
    axis(ax, 'xy');
    axis(ax, 'on');
    box(ax, 'on');
    set(ax, ...
        'XScale', 'log', ...
        'XLim', f_lim, ...
        'YLim', [0, h_max], ...
        'XTick', freq_ticks, ...
        'XTickLabel', arrayfun(@num2str, freq_ticks, 'UniformOutput', false), ...
        'FontSize', font_size, ...
        'LineWidth', 1.2, ...
        'Layer', 'top');
    
    hold(ax, 'on');
    hBox = plot3(ax, [f_lim(1), f_lim(2), f_lim(2), f_lim(1), f_lim(1)], ...
                     [0, 0, h_max, h_max, 0], ...
                     ones(1, 5) * 0.3, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    hold(ax, 'off');
end

function update_panel_limits(ax, hBox, f_min, f_max, h_max, valid_ticks, tick_labels)
% UPDATE_PANEL_LIMITS Updates axis limits and bounding box coordinates without recreating objects
    set(ax, 'XLim', [f_min, f_max], ...
            'YLim', [0, h_max], ...
            'XTick', valid_ticks, ...
            'XTickLabel', tick_labels);
    set(hBox, 'XData', [f_min, f_max, f_max, f_min, f_min], ...
              'YData', [0, 0, h_max, h_max, 0]);
end

function dt_str = extract_cadi_datetime(base_name, loaded_data)
% EXTRACT_CADI_DATETIME Parses date and time from metadata or standard CADI filename
% Standard CADI format: SSYMDDHHMM (e.g., HA9G270000 or RB8A010300o -> 2008/01/01 03:00:00 UT)
    if isfield(loaded_data, 'obs_datetime') && ~isempty(loaded_data.obs_datetime)
        dt_str = char(loaded_data.obs_datetime);
        return;
    end

    clean_name = erase(base_name, {'_clean', '_noisy', '_ion', '_pol', '_tns3'});
    % Strip trailing 'o' suffix if present on original noisy files
    if endsWith(clean_name, 'o') && numel(clean_name) > 10
        clean_name = clean_name(1:end-1);
    end

    % Match standard 10-character CADI naming convention: [Station(2)][Year(1)][MonthLetter(1)][Day(2)][HH(2)][MM(2)]
    if numel(clean_name) >= 10
        yr_char  = clean_name(3);
        mo_char  = upper(clean_name(4));
        day_str  = clean_name(5:6);
        hh_str   = clean_name(7:8);
        mm_str   = clean_name(9:10);

        if isstrprop(yr_char, 'digit') && (mo_char >= 'A' && mo_char <= 'L') && ...
           all(isstrprop([day_str, hh_str, mm_str], 'digit'))
            
            yr_num = 2000 + str2double(yr_char); % Adjust base decade if needed
            mo_num = double(mo_char) - double('A') + 1;
            
            if numel(clean_name) >= 12 && all(isstrprop(clean_name(11:12), 'digit'))
                ss_str = clean_name(11:12);
            else
                ss_str = '00';
            end
            
            dt_str = sprintf('%04d/%02d/%s %s:%s:%s UT', yr_num, mo_num, day_str, hh_str, mm_str, ss_str);
            return;
        end
    end

    % Match 12 or 14 digit numeric timestamp in filename (YYYYMMDDHHMM[SS])
    tok = regexp(clean_name, '(\d{4})(\d{2})(\d{2})[_-]?(\d{2})(\d{2})(\d{2})?', 'tokens', 'once');
    if ~isempty(tok)
        ss = '00';
        if numel(tok) >= 6 && ~isempty(tok{6})
            ss = tok{6};
        end
        dt_str = sprintf('%s/%s/%s %s:%s:%s UT', tok{1}, tok{2}, tok{3}, tok{4}, tok{5}, ss);
        return;
    end

    % Fallback to clean filename if non-standard naming is used
    dt_str = clean_name;
end