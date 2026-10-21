% % % Batch processing script to scan nested directories, process CADI pairs,
% % % and mirror the folder structure inside the target dataset directory 
% % % saving all sample data into a single unified .mat file per pair.
% % 
% % % Define root directory containing raw CADI data subfolders
% % PathDat = 'N:\cadi_synced_mat_source'; % <-- Update this path to your root folder
% % 
% % % Define target output root directory for processed dataset files
% % out_dataset_dir = 'N:\cadi_synced_mat_out'; % <-- Update output path
% % 
% % if ~isfolder(out_dataset_dir)
% %     mkdir(out_dataset_dir);
% % end
% % 
% % % Recursively find all *_ion.mat files across all subfolders
% % fprintf('Scanning directory tree for CADI files...\n');
% % ion_files = dir(fullfile(PathDat, '**', '*_ion.mat'));
% % num_files = numel(ion_files);
% % 
% % fprintf('Found %d potential ionogram files. Starting processing...\n', num_files);
% % 
% % success_count = 0;
% % report_interval = max(1, floor(num_files / 20)); 
% % 
% % for i = 1:num_files
% %     ion_filepath = fullfile(ion_files(i).folder, ion_files(i).name);
% % 
% %     % Automatically deduce the matching _pol.mat filename
% %     pol_filename = strrep(ion_files(i).name, '_ion.mat', '_pol.mat');
% %     pol_filepath = fullfile(ion_files(i).folder, pol_filename);
% % 
% %     if ~isfile(pol_filepath)
% %         continue; 
% %     end
% % 
% %     % Process the pair using the updated core conversion function
% %     [X_tensor, Y_mask, f_grid, h_grid, roi_bbox, is_valid] = process_cadi_pair(ion_filepath, pol_filepath);
% % 
% %     if is_valid
% %         [~, base_name, ~] = fileparts(ion_files(i).name);
% %         sample_id = erase(base_name, '_ion');
% % 
% %         % Compute relative path
% %         rel_path = char(extractAfter(ion_files(i).folder, PathDat));
% %         if ~isempty(rel_path) && (rel_path(1) == '\' || rel_path(1) == '/')
% %             rel_path = rel_path(2:end);
% %         end
% % 
% %         target_subfolder = fullfile(out_dataset_dir, rel_path);
% %         if ~isfolder(target_subfolder)
% %             mkdir(target_subfolder);
% %         end
% % 
% %         % Define unified output file path (.mat)
% %         sample_out_path = fullfile(target_subfolder, [sample_id, '.mat']);
% % 
% %         % Save all sample components into a single unified .mat file (-v6 for speed)
% %         save(sample_out_path, 'X_tensor', 'Y_mask', 'f_grid', 'h_grid', 'roi_bbox', '-v6');
% % 
% %         success_count = success_count + 1;
% %     end
% % 
% %     if mod(i, report_interval) == 0 || i == num_files
% %         percent_done = (i / num_files) * 100;
% %         fprintf('Progress: %.1f%% (%d / %d files processed, %d valid pairs saved)\n', ...
% %             percent_done, i, num_files, success_count);
% %     end
% % end
% % 
% % fprintf('Batch dataset generation completed successfully! Saved %d unified mat files into: %s\n', ...
% %     success_count, out_dataset_dir);

function unprocessed_count = cadi_out_pair2mat(ion_filepath, pol_filepath, out_filepath, nCell_Y_mask, dirCell_Y_mask)
% CADI_OUT_PAIR2MAT Batch processes CADI ionogram and polarization files, 
% saving all required tensors, masks, grids, real profiles and peaks into unified .mat files.

    % Set default expansion parameters if not provided
    if nargin < 4 || isempty(nCell_Y_mask), nCell_Y_mask = 2; end
    if nargin < 5 || isempty(dirCell_Y_mask), dirCell_Y_mask = -1; end

    start_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    start_tic = tic;

    % Resolve input files / directories
    if isfolder(ion_filepath)
        ion_dir = ion_filepath;
        ion_files_struct = dir(fullfile(ion_dir, '**', '*_ion.mat'));
    elseif isfile(ion_filepath)
        [ion_dir, name, ext] = fileparts(ion_filepath);
        ion_files_struct = struct('folder', ion_dir, 'name', [name ext]);
    else
        error('Invalid ion_filepath provided: %s', ion_filepath);
    end

    if nargin < 2 || isempty(pol_filepath)
        pol_filepath = ion_dir;
    end

    % Resolve output directory
    if isfolder(out_filepath)
        out_dir = out_filepath;
    elseif ~isempty(out_filepath) && isfile(out_filepath)
        out_dir = fileparts(out_filepath);
    else
        out_dir = out_filepath;
    end
    
    if ~isfolder(out_dir)
        mkdir(out_dir);
    end

    num_files = numel(ion_files_struct);
    unprocessed_count = 0;
    unprocessed_names = {};

    fprintf('=== Starting CADI Batch Processing ===\n');
    fprintf('Total files found: %d\n', num_files);
    fprintf('Output directory: %s\n', out_dir);

    for i = 1:num_files
        curr_ion_file = fullfile(ion_files_struct(i).folder, ion_files_struct(i).name);

        % Determine matching pol file path
        if isfolder(pol_filepath)
            pol_filename = strrep(ion_files_struct(i).name, '_ion.mat', '_pol.mat');
            curr_pol_file = fullfile(ion_files_struct(i).folder, pol_filename);
        else
            curr_pol_file = pol_filepath;
        end

        if ~isfile(curr_pol_file)
            unprocessed_count = unprocessed_count + 1;
            unprocessed_names{end+1} = ion_files_struct(i).name; %#ok<AGROW>
            continue;
        end

        % Process the pair using process_cadi_pair with updated outputs
        [X_tensor, Y_mask, f_grid, h_grid, H_orig, W_orig, roi_bbox, ...
         david_pts_virtual, david_pts_real, Peak_foF2, Peak_hmF2, is_valid] = ...
            process_cadi_pair(curr_ion_file, curr_pol_file, nCell_Y_mask, dirCell_Y_mask);

        if is_valid
            [~, base_name, ~] = fileparts(ion_files_struct(i).name);
            sample_id = erase(base_name, '_ion');

            % Mirror folder structure if input was a nested directory tree
            rel_path = '';
            if isfolder(ion_filepath) && ~strcmp(ion_filepath, ion_files_struct(i).folder)
                rel_path = char(extractAfter(ion_files_struct(i).folder, ion_filepath));
                if ~isempty(rel_path) && (rel_path(1) == '\' || rel_path(1) == '/')
                    rel_path = rel_path(2:end);
                end
            end

            target_subfolder = fullfile(out_dir, rel_path);
            if ~isfolder(target_subfolder)
                mkdir(target_subfolder);
            end

            % Define unified output .mat file path
            sample_out_path = fullfile(target_subfolder, [sample_id, '.mat']);

            % Save all required components including real profiles and peaks into a single .mat file
            save(sample_out_path, 'X_tensor', 'Y_mask', 'f_grid', 'h_grid', ...
                 'H_orig', 'W_orig', 'roi_bbox', 'david_pts_virtual', 'david_pts_real', ...
                 'Peak_foF2', 'Peak_hmF2', 'nCell_Y_mask', 'dirCell_Y_mask', '-v6');
        else
            unprocessed_count = unprocessed_count + 1;
            unprocessed_names{end+1} = ion_files_struct(i).name; %#ok<AGROW>
        end
    end

    finish_time = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    elapsed_time = toc(start_tic);

    % Generate processing log file in the root of out_dir
    log_filename = fullfile(out_dir, 'cadi_processing_log.txt');
    fid = fopen(log_filename, 'w');
    if fid ~= -1
        fprintf(fid, '========================================\n');
        fprintf(fid, '         CADI DATASET PROCESSING LOG    \n');
        fprintf(fid, '========================================\n');
        fprintf(fid, 'Start Time:    %s\n', start_time);
        fprintf(fid, 'Finish Time:   %s\n', finish_time);
        fprintf(fid, 'Elapsed Time:  %.2f seconds\n', elapsed_time);
        fprintf(fid, 'Total Files:   %d\n', num_files);
        fprintf(fid, 'Success Count: %d\n', num_files - unprocessed_count);
        fprintf(fid, 'Failed/Skipped:%d\n', unprocessed_count);
        fprintf(fid, '----------------------------------------\n');
        
        if unprocessed_count > 0
            fprintf(fid, 'Unprocessed Files List:\n');
            for k = 1:numel(unprocessed_names)
                fprintf(fid, '  [%d] %s\n', k, unprocessed_names{k});
            end
        else
            fprintf(fid, 'Status: SUCCESS (All files processed successfully)\n');
        end
        fprintf(fid, '========================================\n');
        fclose(fid);
    end

    fprintf('Batch processing completed. Unprocessed: %d. Log saved to: %s\n', unprocessed_count, log_filename);
end