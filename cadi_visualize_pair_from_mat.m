% Script to visually inspect generated CADI dataset pairs on a 4-panel figure.
% Prompts the user to select a tensor file (*_tns3.mat) and automatically finds
% its companion mask file (*_lbl.png).

% Prompt user to select the tensor file (using working filter syntax)
[file_name, folder_path] = uigetfile({'*.mat', 'CADI Tensor MAT Files (*_tns3.mat)'}, 'Select CADI Tensor MAT File');

if isequal(file_name, 0)
    disp('User cancelled file selection.');
    return;
end

% Construct full paths for tensor and deduce mask file path
tns_path = fullfile(folder_path, file_name);
lbl_name = strrep(file_name, '_tns3.mat', '_lbl.png');
lbl_path = fullfile(folder_path, lbl_name);

% Verify that the matching label/mask file exists
if ~isfile(lbl_path)
    errordlg(sprintf('Companion mask file not found:\n%s', lbl_name), 'Missing File Error');
    return;
end

% Load the 3-channel tensor directly from .mat file
loaded_data = load(tns_path, 'X_tensor');
if ~isfield(loaded_data, 'X_tensor')
    error('The selected .mat file does not contain "X_tensor".');
end
X_tensor = loaded_data.X_tensor;

[H_dim, W_dim, num_channels] = size(X_tensor);
if num_channels ~= 3
    error('Loaded X_tensor does not have 3 channels (found %d channels).', num_channels);
end

% Load the binary mask (0 and 1)
Y_mask = imread(lbl_path);
if max(Y_mask(:)) > 1
    Y_mask = Y_mask > 0;
end

% Optional: Thin out the mask visually for inspection (skeletonization) 
Y_mask_display = bwmorph(Y_mask, 'skel', Inf); 

% Create a professional 4-panel inspection figure with white background
figure('Color', 'w', 'Position', [100, 100, 1400, 700], ...
    'Name', ['CADI Inspection: ', sample_id_clean(file_name)], ...
    'NumberTitle', 'off');

% --- Custom Colormap with White Background for Panel 1 ---
custom_jet = jet(256);
custom_jet(1, :) = [1, 1, 1]; % Set background (value == 0) to pure white

% --- Panel 1: Amplitude in dB (Channel 1) ---
subplot(2, 2, 1);
amp_data = X_tensor(:, :, 1);
imagesc(amp_data); 
axis xy; colormap(gca, custom_jet); colorbar;
title('Panel 1: Cleaned Amplitude (Norm [0, 1])');
xlabel('Frequency Index'); ylabel('Height Index');

% --- Panel 2: O-mode only (Channel 2 in pure blue shades on white background) ---
subplot(2, 2, 2);
o_data = X_tensor(:, :, 2);
o_rgb = ones(H_dim, W_dim, 3, 'single'); % White background by default
mask_o = o_data > 0;
o_rgb(:,:,1) = mask_o .* (1 - o_data * 0.7) + (~mask_o) .* 1; 
o_rgb(:,:,2) = mask_o .* (1 - o_data * 0.3) + (~mask_o) .* 1; 
o_rgb(:,:,3) = mask_o .* 1                  + (~mask_o) .* 1; 

imagesc(o_rgb); 
axis xy; axis on;
colorbar;
title('Panel 2: True O-mode (Blue Shades, White BG)');
xlabel('Frequency Index'); ylabel('Height Index');

% --- Panel 3: X-mode only (Channel 3 in pure red shades on white background) ---
subplot(2, 2, 3);
x_data = X_tensor(:, :, 3);
x_rgb = ones(H_dim, W_dim, 3, 'single'); % White background by default
mask_x = x_data > 0;
x_rgb(:,:,1) = mask_x .* 1                  + (~mask_x) .* 1; 
x_rgb(:,:,2) = mask_x .* (1 - x_data * 0.7) + (~mask_x) .* 1; 
x_rgb(:,:,3) = mask_x .* (1 - x_data * 0.7) + (~mask_x) .* 1; 

imagesc(x_rgb); 
axis xy; axis on;
colorbar;
title('Panel 3: True X-mode (Red Shades, White BG)');
xlabel('Frequency Index'); ylabel('Height Index');

% --- Panel 4: Combined O-mode + X-mode + Thin Mask in Black ---
subplot(2, 2, 4);
comp_rgb = ones(H_dim, W_dim, 3, 'single'); % White background

sig_loc = (x_data > 0) | (o_data > 0);
comp_rgb(:,:,1) = sig_loc .* (1 - x_data * 0.4) + (~sig_loc) .* 1; 
comp_rgb(:,:,2) = sig_loc .* 0.9                + (~sig_loc) .* 1; 
comp_rgb(:,:,3) = sig_loc .* (1 - o_data * 0.4) + (~sig_loc) .* 1; 

% Overlay thin/skeletonized David's mask (Y_mask_display) in solid Black [0, 0, 0]
mask_pixels = Y_mask_display > 0;
comp_rgb(repmat(mask_pixels, [1, 1, 3])) = 0; 

imagesc(comp_rgb); 
axis xy; axis on;
colorbar;
title('Panel 4: Modes Composite + Thin Mask (Black)');
xlabel('Frequency Index'); ylabel('Height Index');

% Helper local function to extract clean ID for window title
function id_str = sample_id_clean(filename)
    [~, name, ~] = fileparts(filename);
    id_str = erase(name, '_tns3');
end