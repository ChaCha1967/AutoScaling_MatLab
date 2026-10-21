function success = cadi_visualize_from_mat_single()
% CADI_VISUALIZE_FROM_MAT Visualizes generated CADI dataset samples from unified .mat files
% on a 3-panel professional figure with logarithmic frequency axis, high-contrast modes,
% full bounding boxes, and enlarged typography.
%
% Output:
%   success : Logical flag (true if visualization completed successfully, false if cancelled/error)

    success = false;

    % Prompt user to select the unified sample MAT file
    [file_name, folder_path] = uigetfile({'*.mat', 'CADI Sample MAT Files (*.mat)'}, 'Select CADI Sample MAT File');

    if isequal(file_name, 0)
        disp('User cancelled file selection.');
        return;
    end

    sample_path = fullfile(folder_path, file_name);

    % Load required variables from the unified .mat file
    loaded_data = load(sample_path);
    required_fields = {'X_tensor', 'Y_mask', 'f_grid', 'h_grid', 'H_orig', 'W_orig', 'david_pts_virtual'};
    for k = 1:numel(required_fields)
        if ~isfield(loaded_data, required_fields{k})
            error('The selected .mat file is missing required field: %s', required_fields{k});
        end
    end

    X_tensor          = loaded_data.X_tensor;
    Y_mask            = loaded_data.Y_mask;
    f_grid            = loaded_data.f_grid;
    h_grid            = loaded_data.h_grid;
    H_orig            = loaded_data.H_orig;
    W_orig            = loaded_data.W_orig;
    david_pts_virtual = loaded_data.david_pts_virtual;

    [~, ~, num_channels] = size(X_tensor);
    if num_channels ~= 3
        error('Loaded X_tensor does not have 3 channels (found %d channels).', num_channels);
    end

    % Ensure mask is logical
    if max(Y_mask(:)) > 1
        Y_mask = Y_mask > 0;
    end

    % --- TRIM TO REAL BOUNDARIES (BEFORE PADDING) ---
    f_axis = double(f_grid(1:W_orig));
    h_axis = double(h_grid(1:H_orig));
    
    amp_trimmed  = double(X_tensor(1:H_orig, 1:W_orig, 1));
    o_trimmed    = double(X_tensor(1:H_orig, 1:W_orig, 2));
    x_trimmed    = double(X_tensor(1:H_orig, 1:W_orig, 3));
    mask_trimmed = Y_mask(1:H_orig, 1:W_orig);

    % Create 2D coordinate matrices for non-uniform frequency scale
    [F_grid, H_grid] = meshgrid(f_axis, h_axis);

    % Typography and axis settings
    axis_font_size  = 13;
    label_font_size = 15;
    title_font_size = 15;
    freq_ticks      = [2 3 4 5 6 7 8 9 10 12 15 19];
    % Keep only ticks that fall within the actual frequency range
    freq_ticks      = freq_ticks(freq_ticks >= f_axis(1) & freq_ticks <= f_axis(end));

    % Create a professional 3-panel inspection figure with white background
    figure('Color', 'w', 'Position', [50, 100, 1750, 620], ...
        'Name', ['CADI Inspection: ', sample_id_clean(file_name)], ...
        'NumberTitle', 'off');

    % =========================================================================
    % Panel 1: Amplitude Power Ionogram (Channel 1) with Parula Colormap
    % =========================================================================
    ax1 = subplot(1, 3, 1);
    custom_parula = parula(256);
    custom_parula(1, :) = [1, 1, 1]; % Pure white background for zero values
    
    surf(F_grid, H_grid, zeros(size(amp_trimmed)), amp_trimmed, 'EdgeColor', 'none');
    view(2);
    colormap(ax1, custom_parula);
    cb1 = colorbar(ax1);
    cb1.FontSize = axis_font_size;
    
    format_ionogram_axes(ax1, f_axis, h_axis, freq_ticks, axis_font_size);
    title('Panel 1: Amplitude (Ch 1)', 'FontSize', title_font_size, 'FontWeight', 'bold');
    xlabel('Frequency (MHz)', 'FontSize', label_font_size);
    ylabel('Virtual Height (km)', 'FontSize', label_font_size);

    % =========================================================================
    % Build High-Contrast RGB Composite for Panels 2 & 3
    % =========================================================================
    rgb_modes = ones(H_orig, W_orig, 3); % Pure white background [1, 1, 1]
    
    mask_o = o_trimmed > 0;
    mask_x = x_trimmed > 0;
    
    % Normalize and apply gamma boost (gamma = 0.55) so weak/medium traces become vivid
    o_scale = prctile(o_trimmed(mask_o), 95);
    if isempty(o_scale) || o_scale <= 0, o_scale = 1; end
    o_norm = min(1, o_trimmed / o_scale) .^ 0.55;
    
    x_scale = prctile(x_trimmed(mask_x), 95);
    if isempty(x_scale) || x_scale <= 0, x_scale = 1; end
    x_norm = min(1, x_trimmed / x_scale) .^ 0.55;

    % Map intensity to [0.35 ... 1.0] so even the faintest nonzero pixel is clearly visible
    o_boost = mask_o .* (0.35 + 0.65 * o_norm);
    x_boost = mask_x .* (0.35 + 0.65 * x_norm);

    % Subtract from white background:
    % O-mode -> Deep Blue (suppress Red and Green strongly)
    % X-mode -> Deep Red  (suppress Green and Blue strongly)
    rgb_modes(:,:,1) = max(0, 1 - 0.95 * o_boost - 0.05 * x_boost); % Red channel
    rgb_modes(:,:,2) = max(0, 1 - 0.85 * o_boost - 0.90 * x_boost); % Green channel
    rgb_modes(:,:,3) = max(0, 1 - 0.05 * o_boost - 0.90 * x_boost); % Blue channel

    % =========================================================================
    % Panel 2: O-mode (Deep Blue) & X-mode (Deep Red)
    % =========================================================================
    ax2 = subplot(1, 3, 2);
    surf(F_grid, H_grid, zeros(H_orig, W_orig), rgb_modes, 'EdgeColor', 'none');
    view(2);
    
    format_ionogram_axes(ax2, f_axis, h_axis, freq_ticks, axis_font_size);
    title('Panel 2: O-mode (Blue) & X-mode (Red)', 'FontSize', title_font_size, 'FontWeight', 'bold');
    xlabel('Frequency (MHz)', 'FontSize', label_font_size);
    ylabel('Virtual Height (km)', 'FontSize', label_font_size);

    % =========================================================================
    % Panel 3: Modes + Mask Contour (Dashed) + David's Profile (Solid)
    % =========================================================================
    ax3 = subplot(1, 3, 3);
    surf(F_grid, H_grid, zeros(H_orig, W_orig), rgb_modes, 'EdgeColor', 'none');
    view(2);
    hold(ax3, 'on');
    
    % Draw binary mask contour mapped to non-uniform grid
    contour(ax3, F_grid, H_grid, double(mask_trimmed), [0.5, 0.5], ...
        'Color', 'k', 'LineStyle', '--', 'LineWidth', 1.5);
    
    % Draw David's manual virtual profile with normal line thickness
    if ~isempty(david_pts_virtual)
        plot(ax3, david_pts_virtual(:, 1), david_pts_virtual(:, 2), ...
            'k-', 'LineWidth', 1.5, 'DisplayName', "David's Profile");
    end
    
    hold(ax3, 'off');
    format_ionogram_axes(ax3, f_axis, h_axis, freq_ticks, axis_font_size);
    title('Panel 3: Mask Contour & David''s Profile', 'FontSize', title_font_size, 'FontWeight', 'bold');
    xlabel('Frequency (MHz)', 'FontSize', label_font_size);
    ylabel('Virtual Height (km)', 'FontSize', label_font_size);

    success = true;
end

% Helper function to enforce logarithmic X-scale, full bounding box, and font sizes
function format_ionogram_axes(ax, f_axis, h_axis, freq_ticks, font_size)
    axis(ax, 'xy');
    axis(ax, 'on');
    box(ax, 'on');
    set(ax, ...
        'XScale', 'log', ...
        'XLim', [f_axis(1), f_axis(end)], ...
        'YLim', [0, max(h_axis)], ...
        'XTick', freq_ticks, ...
        'XTickLabel', arrayfun(@num2str, freq_ticks, 'UniformOutput', false), ...
        'FontSize', font_size, ...
        'LineWidth', 1.2, ...
        'Layer', 'top'); % Ensures the box border and ticks stay above the surf plot
    
    % Draw explicit top/right border lines in case 3D surf projection hides standard box edges
    hold(ax, 'on');
    plot3(ax, [f_axis(1), f_axis(end), f_axis(end), f_axis(1), f_axis(1)], ...
              [0, 0, max(h_axis), max(h_axis), 0], ...
              ones(1, 5) * 0.1, 'k-', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    hold(ax, 'off');
end

% Helper local function to extract clean ID for window title
function id_str = sample_id_clean(filename)
    [~, name, ~] = fileparts(filename);
    id_str = name;
end