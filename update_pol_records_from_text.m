function update_pol_records_from_text(PolPath)
% UPDATE_POL_RECORDS_FROM_TEXT Scans PolPath for *.pol files, extracts ScaleHt and SlabT,
% finds paired *_pol.mat files, updates records.Peak to include foF2, hmF2, ScaleHt, SlabT,
% and saves them back. Failures are logged to pol_update_fail.log in the root of PolPath.
%
% INPUT:
%   - PolPath : Root directory containing *.pol and *_pol.mat files

    if nargin < 1
        error('Please provide PolPath input argument.');
    end

    if ~isfolder(PolPath)
        error('Directory not found: %s', PolPath);
    end

    % Path for failure log in the root of PolPath
    log_file_path = fullfile(PolPath, 'pol_update_fail.log');
    
    % Open log file for writing (overwrite or create new)
    fid_log = fopen(log_file_path, 'w');
    if fid_log == -1
        error('Could not create log file at: %s', log_file_path);
    end
    
    fail_count = 0;
    success_count = 0;

    % Find all *.pol files recursively
    pol_files = dir(fullfile(PolPath, '**', '*.pol'));
    num_files = length(pol_files);

    if num_files == 0
        fprintf('No *.pol files found in %s\n', PolPath);
        fclose(fid_log);
        return;
    end

    fprintf('Found %d *.pol files. Starting update process...\n', num_files);

    for i = 1:num_files
        pol_filename = pol_files(i).name;
        pol_folder   = pol_files(i).folder;
        base_name    = strrep(pol_filename, '.pol', '');
        
        current_pol_path = fullfile(pol_folder, pol_filename);
        corresponding_mat_path = fullfile(pol_folder, [base_name, '_pol.mat']);

        % Helper function to log failures
        log_failure = @(reason) log_error_msg(fid_log, current_pol_path, reason);

        % 1. Check if paired .mat file exists
        if ~isfile(corresponding_mat_path)
            log_failure('Paired *_pol.mat file does not exist.');
            fail_count = fail_count + 1;
            continue;
        end

        % 2. Read .pol file content and extract ScaleHt & SlabT
        [scale_ht, slab_t, read_success] = parse_pol_file(current_pol_path);
        if ~read_success
            log_failure('Failed to parse ScaleHt or SlabT from .pol file text.');
            fail_count = fail_count + 1;
            continue;
        end

        % 3. Load .mat file, update records.Peak, and save back
        try
            loaded_data = load(corresponding_mat_path);
            
            % Identify the records structure name
            rec_field_name = '';
            if isfield(loaded_data, 'records')
                rec_field_name = 'records';
                rec = loaded_data.records;
            else
                fields = fieldnames(loaded_data);
                if ~isempty(fields)
                    rec_field_name = fields{1};
                    rec = loaded_data.(rec_field_name);
                else
                    error('Empty .mat file.');
                end
            end

            % Ensure Peak structure exists
            if ~isfield(rec, 'Peak') || isempty(rec.Peak)
                rec.Peak = struct();
            end

            % Update or add fields to Peak so it strictly contains: foF2, hmF2, ScaleHt, SlabT
            current_fof2 = get_field_safe(rec.Peak, 'foF2', NaN);
            current_hmf2 = get_field_safe(rec.Peak, 'hmF2', NaN);

            rec.Peak = struct(...
                'foF2', current_fof2, ...
                'hmF2', current_hmf2, ...
                'ScaleHt', scale_ht, ...
                'SlabT', slab_t ...
            );

            % Assign back to the structure variable name used in the file
            eval([rec_field_name ' = rec;']);

            % Save back updating the mat file (preserving original variable name)
            save(corresponding_mat_path, rec_field_name, '-v7.3');
            
            success_count = success_count + 1;
            fprintf('[%d/%d] Successfully updated: %s\n', i, num_files, base_name);

        catch ME
            log_failure(sprintf('MATLAB exception during load/save: %s', ME.message));
            fail_count = fail_count + 1;
        end
    end

    fclose(fid_log);

    % If no failures occurred, delete the empty log file
    if fail_count == 0
        delete(log_file_path);
        fprintf('\nAll %d files successfully updated! No failures logged.\n', success_count);
    % If there were failures, inform where the log is
    else
        fprintf('\nCompleted with %d successes and %d failures.\nFailures logged to: %s\n', ...
            success_count, fail_count, log_file_path);
    end
end

function [scale_ht, slab_t, success] = parse_pol_file(filepath)
    scale_ht = NaN;
    slab_t   = NaN;
    success  = false;

    fid = fopen(filepath, 'r');
    if fid == -1
        return;
    end
    
    file_text = fread(fid, '*char')';
    fclose(fid);

    % Use regular expression to find ScaleHt followed by number
    % Matches patterns like: ScaleHt 38.4 or ScaleHt  38.4
    sh_token = regexp(file_text, 'ScaleHt\s+([0-9\.]+)', 'tokens');
    if ~isempty(sh_token)
        scale_ht = str2double(sh_token{1}{1});
    end

    % Use regular expression to find SlabT followed by number
    % Matches patterns like: SlabT 56.2 or SlabT  56.2
    st_token = regexp(file_text, 'SlabT\s+([0-9\.]+)', 'tokens');
    if ~isempty(st_token)
        slab_t = str2double(st_token{1}{1});
    end

    % Consider success only if both values were successfully parsed
    if ~isnan(scale_ht) && ~isnan(slab_t)
        success = true;
    end
end

function log_error_msg(fid, filepath, reason)
    timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    fprintf(fid, '[%s] FILE: %s | ERROR: %s\n', timestamp, filepath, reason);
end

function val = get_field_safe(struct_obj, field_name, default_val)
    if isfield(struct_obj, field_name) && ~isempty(struct_obj.(field_name))
        val = struct_obj.(field_name);
    else
        val = default_val;
    end
end