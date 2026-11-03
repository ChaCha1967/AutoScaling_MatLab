function moveReport = cadi_sort_png_by_category(outBaseDir, sStation, targetYear, summaryData, opts)
% CADI_SORT_PNG_BY_CATEGORY Moves PNG files into subdirectories based on 
% summaryData.qualityCategory (categories 1 to 6 into folders YYYY_01 ... YYYY_06).
%
% Syntax:
%   moveReport = cadi_sort_png_by_category('N:/cadi_out_test/', 'RB', 2008, summaryData);

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'moveMode'), opts.moveMode = true; end % true = move, false = copy (for safety test)

    sYear = sprintf('%04d', targetYear);
    sourceDir = fullfile(outBaseDir, sStation, sYear);

    if ~isfolder(sourceDir)
        error('Source directory does not exist: %s', sourceDir);
    end

    if ~isfield(summaryData, 'fNames') || ~isfield(summaryData, 'qualityCategory')
        error('summaryData structure is missing fNames or qualityCategory fields.');
    end

    N = numel(summaryData.fNames);
    fprintf('============================================================\n');
    fprintf('   CADI SORTING PNG FILES BY QUALITY CATEGORY               \n');
    fprintf('============================================================\n');
    fprintf('Station    : %s\n', sStation);
    fprintf('Year       : %s\n', sYear);
    fprintf('Source Dir : %s\n', sourceDir);
    fprintf('Total Files: %d\n', N);

    % Define category folder names (YYYY_01 to YYYY_06)
    catFolders = cell(6, 1);
    for c = 1:6
        catFolderName = sprintf('%s_%02d', sYear, c);
        catFolders{c} = fullfile(outBaseDir, sStation, catFolderName);
        if ~isfolder(catFolders{c})
            mkdir(catFolders{c});
        end
    end

    movedCounts = zeros(6, 1);
    missingCounts = zeros(6, 1);
    timerVal = tic;

    for i = 1:N
        matName = summaryData.fNames{i}; % e.g., 'RB8A010005_ion.mat'
        catID = summaryData.qualityCategory(i);

        if catID < 1 || catID > 6
            continue;
        end

        % Extract base name without '_ion.mat' (e.g., 'RB8A010005')
        baseName = erase(matName, '_ion.mat');

        % Check both possible PNG suffixes (_ion_avr.png and _ion_avt.png)
        possiblePngNames = { ...
            [baseName, '_ion_avt.png'], ...
            [baseName, '_ion_avr.png'] ...
        };

        foundFile = false;
        for p = 1:numel(possiblePngNames)
            pngName = possiblePngNames{p};
            srcPngPath = fullfile(sourceDir, pngName);

            if isfile(srcPngPath)
                targetDir = catFolders{catID};
                destPngPath = fullfile(targetDir, pngName);

                if opts.moveMode
                    movefile(srcPngPath, destPngPath);
                else
                    copyfile(srcPngPath, destPngPath);
                end

                movedCounts(catID) = movedCounts(catID) + 1;
                foundFile = true;
                break;
            end
        end

        if ~foundFile
            missingCounts(catID) = missingCounts(catID + 1); % Track categories where PNG was not generated yet
        end
    end

    elapsedSec = toc(timerVal);

    % Build report
    moveReport = struct();
    moveReport.movedCounts = movedCounts;
    moveReport.catFolders = catFolders;
    moveReport.elapsedTimeSec = elapsedSec;

    fprintf('\n============================================================\n');
    fprintf('   SORTING COMPLETED SUCCESSFULLY (Time: %.2f s)          \n', elapsedSec);
    fprintf('============================================================\n');
    catDescriptions = {
        'Cat 1 (Good Realistic F2 Profile)', ...
        'Cat 2 (E/Es Misidentified as F2)', ...
        'Cat 3 (Jagged / Unrealistic Profile)', ...
        'Cat 4 (Blanketing Es)', ...
        'Cat 5 (Weak Ionosphere / Blackout)', ...
        'Cat 6 (Missed Valid F-Region Trace)'
    };

    for c = 1:6
        fprintf('  %-36s -> Folder %s/: %7d files moved\n', ...
            catDescriptions{c}, sprintf('%s_%02d', sYear, c), movedCounts(c));
    end
    fprintf('============================================================\n');
end