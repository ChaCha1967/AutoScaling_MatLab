function records = parse_polan_file_synced(filepath, filename)
    % Construct the full path to the data file
    full_data_path = fullfile(filepath, filename);
    
    % Open the file for reading
    fid = fopen(full_data_path, 'rt');
    if fid == -1
        error('Failed to open file: %s', full_data_path);
    end
    
    % Initialize the structure array with all required fields
    records = struct('DateID', {}, 'Station', {}, 'FH', {}, 'Dip', {}, ...
                     'Amode', {}, 'Valy', {}, 'List', {}, 'Time', {}, ...
                     'DT', {}, 'Start', {}, 'InputData', {}, 'Errors', {}, ...
                     'Peak', {}, 'RealHeights', {}, 'Coefficients', {});
                     
    % Create a strict empty template to prevent "dissimilar structures" error
    empty_record = struct('DateID', [], 'Station', [], 'FH', [], 'Dip', [], ...
                     'Amode', [], 'Valy', [], 'List', [], 'Time', [], ...
                     'DT', [], 'Start', [], 'InputData', [], 'Errors', {cell(0,1)}, ...
                     'Peak', struct('foF2', [], 'hmF2', []), 'RealHeights', [], 'Coefficients', []);
                     
    current_record = [];
    state = 'SEARCH_DATE';
    
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        if isempty(line)
            continue;
        end
        
        % Check for the record block separator
        if contains(line, '====================================================')
            if ~isempty(current_record)
                records(end+1) = current_record;
                current_record = [];
            end
            state = 'SEARCH_DATE';
            continue;
        end
        
        switch state
            case 'SEARCH_DATE'
                % Extract Date, Station, and header parameters
                if startsWith(line, 'Date =')
                    expr = 'Date =\s*(\S+)\s+FH\s+([\d\.]+)\s+Dip\s+([\d\.\-]+)\s+Amode\s+([\d\.]+)\s+Valy\s+([\d\.]+)\s+List\s+(\d+)';
                    tokens = regexp(line, expr, 'tokens');
                    
                    % Initialize with the strict template
                    current_record = empty_record;
                    current_record.DT = zeros(1, 6);
                    
                    if ~isempty(tokens)
                        current_record.DateID = tokens{1}{1};
                        current_record.Station = regexprep(current_record.DateID, '\d', '');
                        
                        % Parse Year, Month, Day from DateID
                        yy = str2double(current_record.DateID(1:2));
                        if yy < 50
                            yyyy = 2000 + yy;
                        else
                            yyyy = 1900 + yy;
                        end
                        mm = str2double(current_record.DateID(3:4));
                        dd = str2double(current_record.DateID(5:6));
                        
                        current_record.DT(1) = yyyy;
                        current_record.DT(2) = mm;
                        current_record.DT(3) = dd;
                        
                        current_record.FH = str2double(tokens{1}{2});
                        current_record.Dip = str2double(tokens{1}{3});
                        current_record.Amode = str2double(tokens{1}{4});
                        current_record.Valy = str2double(tokens{1}{5});
                        current_record.List = str2double(tokens{1}{6});
                    end
                    state = 'SEARCH_TIME';
                end
                
            case 'SEARCH_TIME'
                % Extract sounding time and Start parameter
                if contains(line, 'Start =')
                    time_token = sscanf(line, '%s', 1);
                    current_record.Time = time_token;
                    
                    time_parts = sscanf(time_token, '%d:%d');
                    if length(time_parts) == 2
                        current_record.DT(4) = time_parts(1);
                        current_record.DT(5) = time_parts(2);
                    end
                    current_record.DT(6) = 0; 
                    
                    start_tokens = regexp(line, 'Start =\s*([\d\.\-]+)', 'tokens');
                    if ~isempty(start_tokens)
                        current_record.Start = str2double(start_tokens{1}{1});
                    end
                    state = 'SEARCH_INPUT';
                end
                
            case 'SEARCH_INPUT'
                if startsWith(line, 'Input data')
                    state = 'READ_INPUT';
                end
                
            case 'READ_INPUT'
                % Catch multiple types of POLAN error outputs
                if startsWith(line, '*****') || startsWith(line, '>>>>>') || startsWith(line, '#')
                    current_record.Errors{end+1} = line;
                elseif startsWith(line, 'PEAK')
                    nums = regexp(line, 'PEAK\s+([\d\.]+).*?Height\s+([\d\.]+)', 'tokens');
                    if ~isempty(nums)
                        current_record.Peak.foF2 = str2double(nums{1}{1});
                        current_record.Peak.hmF2 = str2double(nums{1}{2});
                    end
                    state = 'SEARCH_REAL';
                else
                    nums = sscanf(line, '%f');
                    for i = 1:2:length(nums)-1
                        f = nums(i);
                        h = nums(i+1);
                        if h > 0 
                            current_record.InputData = [current_record.InputData; f, h];
                        end
                    end
                end
                
            case 'SEARCH_REAL'
                if startsWith(line, 'Real Heights')
                    state = 'READ_REAL';
                end
                
            case 'READ_REAL'
                if startsWith(line, 'Coefficients QQ')
                    state = 'READ_COEFFS';
                else
                    nums = sscanf(line, '%f');
                    for i = 1:2:length(nums)-1
                        f = nums(i);
                        h = nums(i+1);
                        if f < 30 && h > 50
                            current_record.RealHeights = [current_record.RealHeights; f, h];
                        end
                    end
                end
                
            case 'READ_COEFFS'
                nums = sscanf(line, '%f');
                if ~isempty(nums)
                    current_record.Coefficients = [current_record.Coefficients; nums];
                end
        end
    end
    fclose(fid);
    
    % Add the last record if EOF is reached without a separator
    if ~isempty(current_record)
        records(end+1) = current_record;
    end
    
    % Save the records structure to a .mat file in the SAME directory
    [~, base_name, ~] = fileparts(filename);
    mat_filename = fullfile(filepath, [base_name, '_pol.mat']);
    save(mat_filename, 'records');
end