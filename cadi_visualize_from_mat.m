% Script to visually inspect generated CADI dataset pairs from unified .mat files.
% Prompts the user to select a sample file (*.mat) containing tensor, mask, and grids.

% Prompt user to select the sample file
[file_name, folder_path] = uigetfile({'*.mat', 'CADI Sample MAT Files (*.mat)'}, 'Select CADI Sample MAT File');

if isequal(file_name, 0)
    disp('User cancelled file selection.');
    return;
end

sample_path = fullfile(folder_path, file_name);

% Load all variables from the unified .mat file
loaded_data = load(sample_path);
if ~isfield(loaded_data, 'X_tensor') || ~isfield(loaded_data, 'Y_mask')
    error('The selected .mat file does not contain required dataset variables.');
end

X_tensor = loaded_data.X_tensor;
Y_mask   = loaded_data.Y_mask;
f_grid   = loaded_data.f_grid; % [1 x 96] frequency grid in MHz
h_grid   = loaded_data.h_grid; % [192 x 1] height grid in km

[H_dim, W_dim, num_channels] = size(X_tensor);
if num_channels ~= 3
    error('Loaded X_tensor does not have 3 channels (found %d channels).', num_channels);
end

% Ensure mask is binary logical/numeric 0 and 1
if max(Y_mask(:)) > 1
    Y_mask = Y_mask > 0;
end

% Thin out the mask visually for inspection (skeletonization) 
Y_mask_display = bwmorph(Y_mask, 'skel', Inf); 

% Create a professional 4-panel inspection figure with white background
figure('Color', 'w', 'Position', [100, 100, 1400, 700], ...
    'Name', ['CADI Inspection: ', sample_id_clean(file_name)], ...
    'NumberTitle', 'off');

% --- Custom Colormap with White Background for Panel 1 ---
custom_jet = jet(256);
custom_jet(1, :) = [1, 1, 1]; % Set background (value == 0) to pure white

% Axis coordinate vectors for physical scaling in imagesc
freq_axis = f_grid;
height_axis = h_grid(:)';

% --- Panel 1: Amplitude in dB (Channel 1) ---
subplot(2, 2, 1);
amp_data = X_tensor(:, :, 1);
imagesc(freq_axis, height_axis, amp_data); 
axis xy; colormap(gca, custom_jet); colorbar;
title('Panel 1: Cleaned Amplitude (Norm [0, 1])');
xlabel('Frequency (MHz)'); ylabel('Virtual Height (km)');

% --- Panel 2: O-mode only (Channel 2 in pure blue shades on white background) ---
subplot(2, 2, 2);
o_data = X_tensor(:, :, 2);
o_rgb = ones(H_dim, W_dim, 3, 'single'); 
mask_o = o_data > 0;
o_rgb(:,:,1) = mask_o .* (1 - o_data * 0.7) + (~mask_o) .* 1; 
o_rgb(:,:,2) = mask_o .* (1 - o_data * 0.3) + (~mask_o) .* 1; 
o_rgb(:,:,3) = mask_o .* 1                  + (~mask_o) .* 1; 

imagesc(freq_axis, height_axis, o_rgb); 
axis xy; axis on;
colorbar;
title('Panel 2: True O-mode (Blue Shades, White BG)');
xlabel('Frequency (MHz)'); ylabel('Virtual Height (km)');

% --- Panel 3: X-mode only (Channel 3 in pure red shades on white background) ---
subplot(2, 2, 3);
x_data = X_tensor(:, :, 3);
x_rgb = ones(H_dim, W_dim, 3, 'single'); 
mask_x = x_data > 0;
x_rgb(:,:,1) = mask_x .* 1                  + (~mask_x) .* 1; 
x_rgb(:,:,2) = mask_x .* (1 - x_data * 0.7) + (~mask_x) .* 1; 
x_rgb(:,:,3) = mask_x .* (1 - x_data * 0.7) + (~mask_x) .* 1; 

imagesc(freq_axis, height_axis, x_rgb); 
axis xy; axis on;
colorbar;
title('Panel 3: True X-mode (Red Shades, White BG)');
xlabel('Frequency (MHz)'); ylabel('Virtual Height (km)');

% --- Panel 4: Combined O-mode + X-mode + Thin Mask in Black ---
subplot(2, 2, 4);
comp_rgb = ones(H_dim, W_dim, 3, 'single'); 

sig_loc = (x_data > 0) | (o_data > 0);
comp_rgb(:,:,1) = sig_loc .* (1 - x_data * 0.4) + (~sig_loc) .* 1; 
comp_rgb(:,:,2) = sig_loc .* 0.9                + (~sig_loc) .* 1; 
comp_rgb(:,:,3) = sig_loc .* (1 - o_data * 0.4) + (~sig_loc) .* 1; 

% Overlay thin/skeletonized David's mask (Y_mask_display) in solid Black [0, 0, 0]
mask_pixels = Y_mask_display > 0;
comp_rgb(repmat(mask_pixels, [1, 1, 3])) = 0; 

imagesc(freq_axis, height_axis, comp_rgb); 
axis xy; axis on;
colorbar;
title('Panel 4: Modes Composite + Thin Mask (Black)');
xlabel('Frequency (MHz)'); ylabel('Virtual Height (km)');

% Helper local function to extract clean ID for window title
function id_str = sample_id_clean(filename)
    [~, name, ~] = fileparts(filename);
    id_str = name;
end