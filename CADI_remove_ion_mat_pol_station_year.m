% Scans a directory to synchronize and clean up data archives by identifying 
% and deleting orphaned/asynchronous .pol and minute .mat files that lack 
% corresponding pairs, ensuring archive integrity.

% Define the target folder to scan
targetFolder = 'N:\cadi_synced\RB\2009';

% Get lists of all .pol and .mat files in the directory
polFiles = dir(fullfile(targetFolder, '*.pol'));
matFiles = dir(fullfile(targetFolder, '*_ion.mat'));

% Initialize cell arrays to store the base timestamp identifiers
polBaseNames = cell(length(polFiles), 1);
matBaseNames = cell(length(matFiles), 1);

% Extract the 10-character base name from .pol files (e.g., 'CA9F120000')
for i = 1:length(polFiles)
    [~, name, ~] = fileparts(polFiles(i).name);
    polBaseNames{i} = upper(name); % Convert to uppercase for safe comparison
end

% Extract the 10-character base name from .mat files
% We only process minute files (base name length == 10) to avoid deleting hourly summary files
for i = 1:length(matFiles)
    name = matFiles(i).name;
    baseName = strrep(name, '_ion.mat', '');

    if length(baseName) == 10
        matBaseNames{i} = upper(baseName);
    else
        % Ignore hourly files (e.g., 'CA9F1200' has 8 characters)
        matBaseNames{i} = 'IGNORE'; 
    end
end

% Find identifiers that exist in POL but not in MAT (Orphaned POL files)
[orphanedPol, polIdx] = setdiff(polBaseNames, matBaseNames);

% Find identifiers that exist in MAT but not in POL (Orphaned MAT files)
% We exclude the 'IGNORE' tag from the orphaned list
[orphanedMat, matIdx] = setdiff(matBaseNames, polBaseNames);
ignoreIdx = strcmp(orphanedMat, 'IGNORE');
matIdx(ignoreIdx) = []; 

% Counters for final report
deletedPolCount = 0;
deletedMatCount = 0;

% Delete orphaned .pol files
for i = 1:length(polIdx)
    fileToDelete = fullfile(targetFolder, polFiles(polIdx(i)).name);
    delete(fileToDelete);
    fprintf('Deleted asynchronous POL file: %s\n', polFiles(polIdx(i)).name);
    deletedPolCount = deletedPolCount + 1;
end

% Delete orphaned .mat files
for i = 1:length(matIdx)
    fileToDelete = fullfile(targetFolder, matFiles(matIdx(i)).name);
    delete(fileToDelete);
    fprintf('Deleted asynchronous MAT file: %s\n', matFiles(matIdx(i)).name);
    deletedMatCount = deletedMatCount + 1;
end

% Print final summary
fprintf('\n--- Synchronization Cleanup Summary ---\n');
fprintf('Deleted .pol files: %d\n', deletedPolCount);
fprintf('Deleted minute .mat files: %d\n', deletedMatCount);
fprintf('---------------------------------------\n');