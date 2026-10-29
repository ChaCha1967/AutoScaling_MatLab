% Script that use CADI_data_iono_reader_mtrx() for reading and plotting one 
% year of ionograms using CADI data (*.md2 file) extracting all ionograms 
% existed in md2 files  as a structure and in addition prepare matrices for 
% selected ionograms contained in in md2 file

% Define the input parameters for the batch process
sDataPathBase = 'N:\cadi_add\'; % Base path ending with slash
sStation = 'RB';                   % 2-character station code
Year = 2009;                       % 4-digit year
sFileType = 'md2';                 % File extension without dot
OutYN = 0;                         % 1 to save the combined .mat file
time_min = 0:5:55;                % Array of minutes to extract

% Construct the full path to the specific Station and Year folder
sYear = sprintf('%04d', Year);
dataDir = fullfile(sDataPathBase, sStation, sYear);

% Find all files matching the extension in the target directory
searchPattern = fullfile(dataDir, ['*.', sFileType]);
fileList = dir(searchPattern);

% Check if files exist
if isempty(fileList)
    fprintf('No %s files found in %s\n', sFileType, dataDir);
    return;
end

fprintf('Found %d files for station %s, year %d. Starting batch processing...\n', length(fileList), sStation, Year);

% Define the month array mapping used in CADI filenames
month_letters = 'ABCDEFGHIJKL';

% Loop through each found file
NF = length(fileList);
for i = 1:NF
    fname = fileList(i).name;

    % Parse the CADI filename format (e.g., "6A011400.md2")
    % Position 2: Month letter ('A'-'L')
    % Position 3-4: Date string
    % Position 5-6: Hour string
    try
        m_letter = upper(fname(2));
        Month = strfind(month_letters, m_letter);
        Date = str2double(fname(3:4));
        Hour = str2double(fname(5:6));

        % Validate parsed parameters to prevent errors
        if isempty(Month) || isnan(Date) || isnan(Hour)
            fprintf('  Warning: Unrecognized file format for %s. Skipping.\n', fname);
            continue;
        end

        fprintf('\n======================================================\n');
        fprintf('Processing file %d of %d: %s\n', i, length(fileList), fname);

        % Call the original single-file processing function
        fprintf('Processing file %05d: from %05d\n', i, NF);
        CADI_data_iono_reader_mtrx(sDataPathBase, sStation, Year, Month, Date, Hour, sFileType, OutYN, time_min);

    catch ME
        % If an error occurs inside the reader function, catch it and continue to the next file
        fprintf('  ERROR processing %s: %s\n', fname, ME.message);
    end
end

fprintf('\nBatch processing completed successfully for %s %d.\n', sStation, Year);