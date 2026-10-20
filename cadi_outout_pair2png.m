% Batch processing script to scan nested directories, process CADI pairs,
% and mirror the folder structure inside the target dataset directory 
% saving outputs as PNG images.

% Define root directory containing raw CADI data subfolders
PathDat = 'N:\cadi_synced\HA'; % <-- Update this path to your root folder

% Define target output root directory for processed PNG dataset files
out_dataset_dir = 'N:\cadi_synced_npg_pairs\HA'; % <-- Update output path

if ~isfolder(out_dataset_dir)
    mkdir(out_dataset_dir);
end

% Recursively find all *_ion.mat files across all subfolders
fprintf('Scanning directory tree for CADI files...\n');
ion_files = dir(fullfile(PathDat, '**', '*_ion.mat'));
num_files = numel(ion_files);

fprintf('Found %d potential ionogram files. Starting processing...\n', num_files);

success_count = 0;

for i = 1:num_files
    ion_filepath = fullfile(ion_files(i).folder, ion_files(i).name);
    
    % Automatically deduce the matching _pol.mat filename
    pol_filename = strrep(ion_files(i).name, '_ion.mat', '_pol.mat');
    pol_filepath = fullfile(ion_files(i).folder, pol_filename);
    
    % Check if the companion polarization file exists
    if ~isfile(pol_filepath)
        continue; 
    end
    
    % Process the pair using the core conversion function
    [X_tensor, Y_mask, ~, is_valid] = process_cadi_pair(ion_filepath, pol_filepath);
    
    if is_valid
        % Extract sample base name (e.g., 'HA9G270110')
        [~, base_name, ~] = fileparts(ion_files(i).name);
        sample_id = erase(base_name, '_ion');
        
        % Compute relative path of the current source folder with respect to PathDat
        rel_path = char(extractAfter(ion_files(i).folder, PathDat));
        
        % If rel_path starts with a slash/backslash, remove it
        if ~isempty(rel_path) && (rel_path(1) == '\' || rel_path(1) == '/')
            rel_path = rel_path(2:end);
        end
        
        % Construct the corresponding target subfolder path inside out_dataset_dir
        target_subfolder = fullfile(out_dataset_dir, rel_path);
        
        % Create target subfolder if it does not exist
        if ~isfolder(target_subfolder)
            mkdir(target_subfolder);
        end
        
        % Define output file paths for PNGs inside the mirrored folder structure
        tns_out_path = fullfile(target_subfolder, [sample_id, '_tns3.png']);
        lbl_out_path = fullfile(target_subfolder, [sample_id, '_lbl.png']);
        
        % Convert 3-channel single tensor [0, 1] to uint8 [0, 255] for lossless PNG storage
        X_uint8 = uint8(round(X_tensor * 255));
        
        % Save tensor and binary mask as standard PNG images
        imwrite(X_uint8, tns_out_path);
        imwrite(Y_mask, lbl_out_path);
        
        success_count = success_count + 1;
    end
end

fprintf('Batch mirrored PNG generation completed successfully! Processed and saved %d valid pairs into: %s\n', ...
    success_count, out_dataset_dir);