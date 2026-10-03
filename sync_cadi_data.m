% sync_cadi_data.m
% Script to synchronize and extract matching .pol and .md2.gz files
% Includes hierarchical scanning, dual logging, and a final summary table

% 1. Configuration Block
path_pol = 'N:\cadi_scaling';
path_md2 = 'N:\cadi';
path_out = 'N:\cadi_synced'; % Directory for the new synced structure

% Create output directory if it doesn't exist
if ~exist(path_out, 'dir')
    mkdir(path_out);
end

% Initialize Log File
log_filepath = fullfile(path_out, 'sync_pol_md2.log');
fid_log = fopen(log_filepath, 'wt');
if fid_log == -1
    error('Cannot create log file at %s', log_filepath);
end

% Month letter to number mapping array
month_letters = 'abcdefghijkl';

print_log(fid_log, '=== CADI SYNC STARTED AT %s ===\n', datestr(now));
print_log(fid_log, 'Source POL: %s\n', path_pol);
print_log(fid_log, 'Source MD2: %s\n', path_md2);
print_log(fid_log, 'Output Dir: %s\n\n', path_out);

total_match_count = 0;
final_summary = {}; % Cell array to store [Station, Year, Count]

% 2. Hierarchical Scanning (Station -> Year)
stations = dir(path_pol);
for s = 1:length(stations)
    % Skip hidden/system folders like '.' and '..'
    if stations(s).isdir && ~startsWith(stations(s).name, '.')
        station_name = stations(s).name;
        station_path = fullfile(path_pol, station_name);
        
        years = dir(station_path);
        for y = 1:length(years)
            if years(y).isdir && ~startsWith(years(y).name, '.')
                year_str = years(y).name;
                year_path = fullfile(station_path, year_str);
                
                % Ensure it is a 4-digit year folder
                if length(year_str) ~= 4
                    print_log(fid_log, 'Warning: Folder %s is not a 4-digit year. Skipping.\n', year_path);
                    continue;
                end
                
                % Scan .pol files inside this specific Station/Year folder
                pol_files = dir(fullfile(year_path, '*.pol'));
                if isempty(pol_files)
                    continue; % Skip empty folders
                end
                
                print_log(fid_log, 'Processing Station: %s, Year: %s (%d .pol files found)...\n', ...
                    station_name, year_str, length(pol_files));
                
                year_match_count = 0;
                
                for f = 1:length(pol_files)
                    pol_name = pol_files(f).name;
                    
                    % Parse filename (e.g., CA9f120000.pol)
                    tokens = regexp(pol_name, '^([a-zA-Z]{2})(\d)([a-zA-Z])(\d{2})(\d{4})\.pol$', 'tokens');
                    if isempty(tokens)
                        print_log(fid_log, '  Warning: Unrecognized format %s. Skipping.\n', pol_name);
                        continue;
                    end
                    
                    st_code = upper(tokens{1}{1});
                    y_digit = tokens{1}{2};
                    m_letter = tokens{1}{3};
                    d_str = tokens{1}{4};
                    t_str = tokens{1}{5};
                    
                    yy_str = year_str(3:4);
                    m_idx = strfind(month_letters, lower(m_letter));
                    if isempty(m_idx)
                        print_log(fid_log, '  Warning: Invalid month letter in %s. Skipping.\n', pol_name);
                        continue;
                    end
                    mm_str = sprintf('%02d', m_idx);
                    
                    % Construct expected .md2.gz paths
                    day_folder = sprintf('%s%s%s%s', yy_str, mm_str, d_str, st_code);
                    md2_name = sprintf('%s%s%s%s.md2.gz', y_digit, upper(m_letter), d_str, t_str);
                    
                    expected_md2_path = fullfile(path_md2, st_code, year_str, day_folder, md2_name);
                    
                    % Check existence and synchronize
                    if exist(expected_md2_path, 'file')
                        out_dir = fullfile(path_out, st_code, year_str);
                        
                        if ~exist(out_dir, 'dir')
                            mkdir(out_dir);
                        end
                        
                        pol_full_path = fullfile(year_path, pol_name);
                        dest_pol_path = fullfile(out_dir, pol_name);
                        
                        md2_extracted_name = strrep(md2_name, '.gz', '');
                        dest_md2_path = fullfile(out_dir, md2_extracted_name);
                        
                        if ~exist(dest_pol_path, 'file') || ~exist(dest_md2_path, 'file')
                            try
                                copyfile(pol_full_path, dest_pol_path);
                                gunzip(expected_md2_path, out_dir);
                                
                                year_match_count = year_match_count + 1;
                                total_match_count = total_match_count + 1;
                                print_log(fid_log, '  Synced: %s & %s\n', pol_name, md2_name);
                            catch ME
                                print_log(fid_log, '  Error processing %s: %s\n', pol_name, ME.message);
                            end
                        else
                            % Already synced previously
                            year_match_count = year_match_count + 1;
                            total_match_count = total_match_count + 1;
                        end
                    end
                end
                
                % Store summary data for the end of the log
                final_summary(end+1, :) = {station_name, year_str, year_match_count};
                
                print_log(fid_log, '>>> Finished %s [%s]: %d pairs synced.\n\n', ...
                    station_name, year_str, year_match_count);
            end
        end
    end
end

% 3. Print Final Summary Table
print_log(fid_log, '========================================\n');
print_log(fid_log, '=== FINAL SYNCHRONIZATION SUMMARY ===\n');
print_log(fid_log, '========================================\n');
print_log(fid_log, '%-10s | %-10s | %-10s\n', 'STATION', 'YEAR', 'FILES SYNCED');
print_log(fid_log, '----------------------------------------\n');

for i = 1:size(final_summary, 1)
    print_log(fid_log, '%-10s | %-10s | %-10d\n', ...
        final_summary{i, 1}, final_summary{i, 2}, final_summary{i, 3});
end

print_log(fid_log, '----------------------------------------\n');
print_log(fid_log, 'GRAND TOTAL FILES SYNCED: %d\n', total_match_count);
print_log(fid_log, '========================================\n');

% Close the log file
if fid_log ~= -1
    fclose(fid_log);
end

% Local Helper Function for Dual Logging
function print_log(fid, format_str, varargin)
    % Print to Command Window
    fprintf(1, format_str, varargin{:});
    % Print to Text File
    if fid ~= -1
        fprintf(fid, format_str, varargin{:});
    end
end