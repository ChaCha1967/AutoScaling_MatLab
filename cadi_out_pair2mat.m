% Batch processing script to scan nested directories, process CADI pairs,
% and mirror the folder structure inside the target dataset directory 
% saving tensors as .mat and masks as PNG images with periodic progress reporting.

% Define root directory containing raw CADI data subfolders
PathDat = 'N:\cadi_synced_mat_source'; % <-- Update this path to your root folder

% Define target output root directory for processed dataset files
out_dataset_dir = 'N:\cadi_synced_mat_out'; % <-- Update output path

if ~isfolder(out_dataset_dir)
    mkdir(out_dataset_dir);
end

% Recursively find all *_ion.mat files across all subfolders
fprintf('Scanning directory tree for CADI files...\n');
ion_files = dir(fullfile(PathDat, '**', '*_ion.mat'));
num_files = numel(ion_files);

fprintf('Found %d potential ionogram files. Starting processing...\n', num_files);

success_count = 0;
report_interval = max(1, floor(num_files / 20)); 

for i = 1:num_files
    ion_filepath = fullfile(ion_files(i).folder, ion_files(i).name);

    % Automatically deduce the matching _pol.mat filename
    pol_filename = strrep(ion_files(i).name, '_ion.mat', '_pol.mat');
    pol_filepath = fullfile(ion_files(i).folder, pol_filename);

    if ~isfile(pol_filepath)
        continue; 
    end

    % Process the pair using the core conversion function
    [X_tensor, Y_mask, ~, is_valid] = process_cadi_pair(ion_filepath, pol_filepath);

    if is_valid
        [~, base_name, ~] = fileparts(ion_files(i).name);
        sample_id = erase(base_name, '_ion');

        % Compute relative path
        rel_path = char(extractAfter(ion_files(i).folder, PathDat));
        if ~isempty(rel_path) && (rel_path(1) == '\' || rel_path(1) == '/')
            rel_path = rel_path(2:end);
        end

        target_subfolder = fullfile(out_dataset_dir, rel_path);
        if ~isfolder(target_subfolder)
            mkdir(target_subfolder);
        end

        % Define output file paths (_tns3.mat for tensor, _lbl.png for mask)
        tns_out_path = fullfile(target_subfolder, [sample_id, '_tns3.mat']);
        lbl_out_path = fullfile(target_subfolder, [sample_id, '_lbl.png']);

        % Save tensor as floating-point .mat (-v6 disables compression for speed)
        save(tns_out_path, 'X_tensor', '-v6');

        % Save binary mask as PNG
        imwrite(Y_mask, lbl_out_path);

        success_count = success_count + 1;
    end

    if mod(i, report_interval) == 0 || i == num_files
        percent_done = (i / num_files) * 100;
        fprintf('Progress: %.1f%% (%d / %d files processed, %d valid pairs saved)\n', ...
            percent_done, i, num_files, success_count);
    end
end

fprintf('Batch dataset generation completed successfully! Saved %d valid pairs into: %s\n', ...
    success_count, out_dataset_dir);