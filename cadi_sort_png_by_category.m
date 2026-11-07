% function moveReport = cadi_sort_png_by_category(outBaseDir, sStation, targetYear, summaryData, opts)
% % CADI_SORT_PNG_BY_CATEGORY Automatically sorts and moves generated session PNG 
% % plots into category-specific subdirectories based on automated quality classification.
% %
% % SYNTAX:
% %   moveReport = cadi_sort_png_by_category(outBaseDir, sStation, targetYear, summaryData, opts)
% %
% % INPUTS:
% %   - outBaseDir  : Root output directory path containing the station and year subfolders (e.g., 'N:/cadi_out_test/')
% %   - sStation    : Two-letter station code string defining the station subfolder (e.g., 'RB')
% %   - targetYear  : Numeric target year corresponding to the dataset folder (e.g., 2008)
% %   - summaryData : Structure containing session filenames (fNames) and automated 
% %                   quality classification labels (qualityCategory)
% %   - opts        : (Optional) Structure containing advanced configuration fields:
% %                   * opts.moveMode : Logical flag. When set to true (default), 
% %                                     physically moves the PNG plot files from the 
% %                                     source directory into the respective category 
% %                                     subfolders (categories 1 to 6 mapped to 
% %                                     YYYY_01 through YYYY_06). When set to false, 
% %                                     copies the files instead of moving them 
% %                                     (useful for safety testing, debugging, or 
% %                                     preserving original files in the source directory).
% %
% % OUTPUT:
% %   - moveReport  : Structure containing transfer counts per category, destination 
% %                   folder paths, and total execution time in seconds[cite: 13].
% 
%     if nargin < 5 || isempty(opts), opts = struct(); end
%     if ~isfield(opts, 'moveMode'), opts.moveMode = true; end % true = move, false = copy (for safety test)
%     sYear = sprintf('%04d', targetYear);
%     sourceDir = fullfile(outBaseDir, sStation, sYear);
% 
%     if ~isfolder(sourceDir)
%         error('Source directory does not exist: %s', sourceDir);
%     end
% 
%     if ~isfield(summaryData, 'fNames') || ~isfield(summaryData, 'qualityCategory')
%         error('summaryData structure is missing fNames or qualityCategory fields.');
%     end
% 
%     N = numel(summaryData.fNames);
%     fprintf('============================================================\n');
%     fprintf('   CADI SORTING PNG FILES BY QUALITY CATEGORY               \n');
%     fprintf('============================================================\n');
%     fprintf('Station    : %s\n', sStation);
%     fprintf('Year       : %s\n', sYear);
%     fprintf('Source Dir : %s\n', sourceDir);
%     fprintf('Total Files: %d\n', N);
% 
%     % Define category folder names (YYYY_01 to YYYY_06)
%     catFolders = cell(6, 1);
%     for c = 1:6
%         catFolderName = sprintf('%s_%02d', sYear, c);
%         catFolders{c} = fullfile(outBaseDir, sStation, catFolderName);
%         if ~isfolder(catFolders{c})
%             mkdir(catFolders{c});
%         end
%     end
% 
%     movedCounts = zeros(6, 1);
%     missingCounts = zeros(6, 1);
%     timerVal = tic;
% 
%     for i = 1:N
%         matName = summaryData.fNames{i}; % e.g., 'RB8A010005_ion.mat'
%         catID = summaryData.qualityCategory(i);
% 
%         if catID < 1 || catID > 6
%             continue;
%         end
% 
%         % Extract base name without '_ion.mat' (e.g., 'RB8A010005')
%         baseName = erase(matName, '_ion.mat');
% 
%         % Check both possible PNG suffixes (_ion_avr.png and _ion_avt.png)
%         possiblePngNames = { ...
%             [baseName, '_ion_avt.png'], ...
%             [baseName, '_ion_avr.png'] ...
%         };
% 
%         foundFile = false;
%         for p = 1:numel(possiblePngNames)
%             pngName = possiblePngNames{p};
%             srcPngPath = fullfile(sourceDir, pngName);
% 
%             if isfile(srcPngPath)
%                 targetDir = catFolders{catID};
%                 destPngPath = fullfile(targetDir, pngName);
% 
%                 if opts.moveMode
%                     movefile(srcPngPath, destPngPath);
%                 else
%                     copyfile(srcPngPath, destPngPath);
%                 end
% 
%                 movedCounts(catID) = movedCounts(catID) + 1;
%                 foundFile = true;
%                 break;
%             end
%         end
% 
%         if ~foundFile
%             missingCounts(catID) = missingCounts(catID + 1); % Track categories where PNG was not generated yet
%         end
%     end
% 
%     elapsedSec = toc(timerVal);
% 
%     % Build report
%     moveReport = struct();
%     moveReport.movedCounts = movedCounts;
%     moveReport.catFolders = catFolders;
%     moveReport.elapsedTimeSec = elapsedSec;
% 
%     fprintf('\n============================================================\n');
%     fprintf('   SORTING COMPLETED SUCCESSFULLY (Time: %.2f s)          \n', elapsedSec);
%     fprintf('============================================================\n');
%     catDescriptions = {
%         'Cat 1 (Good Realistic F2 Profile)', ...
%         'Cat 2 (E/Es Misidentified as F2)', ...
%         'Cat 3 (Jagged / Unrealistic Profile)', ...
%         'Cat 4 (Blanketing Es)', ...
%         'Cat 5 (Weak Ionosphere / Blackout)', ...
%         'Cat 6 (Missed Valid F-Region Trace)'
%     };
% 
%     for c = 1:6
%         fprintf('  %-36s -> Folder %s/: %7d files moved\n', ...
%             catDescriptions{c}, sprintf('%s_%02d', sYear, c), movedCounts(c));
%     end
%     fprintf('============================================================\n');
% end

function moveReport = cadi_sort_png_by_category(outBaseDir, sStation, targetYear, summaryData, opts)
% CADI_SORT_PNG_BY_CATEGORY Manages sorting, copying, and moving of generated session 
% PNG plots into category-specific (1-6) and/or monthly (01-12) subdirectories 
% based on automated quality classification and datetime extracted from filenames or summary.
%
% SYNTAX:
%   moveReport = cadi_sort_png_by_category(outBaseDir, sStation, targetYear, summaryData, opts)
%
% INPUTS:
%   - outBaseDir  : Root output directory path containing the station and year subfolders
%   - sStation    : Two-letter station code string defining the station subfolder (e.g., 'RB')
%   - targetYear  : Numeric target year corresponding to the dataset folder (e.g., 2008)
%   - summaryData : Structure containing session filenames (fNames) and quality classification (qualityCategory)
%   - opts        : (Optional) Structure containing configuration fields:
%                   * opts.moveMode : Integer flag defining the operation mode:
%                                     1 = Move PNGs into 6 category folders (YYYY_01 ... YYYYY_06)
%                                     2 = Copy PNGs into 6 category folders (YYYY_01 ... YYYYY_06)
%                                     3 = Copy PNGs into 12 monthly folders (YYYY_png\01 ... 12), 
%                                         then move them into 6 category folders
%                                     4 = Move PNGs into 12 monthly folders (YYYY_png\01 ... 12) only
%                                     5 = Copy PNGs into 12 monthly folders (YYYY_png\01 ... 12) only
%
% OUTPUT:
%   - moveReport  : Structure containing transfer counts, folder paths, and execution time.

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'moveMode'), opts.moveMode = 1; end % Default to mode 1

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
    fprintf('   CADI PNG SORTING & MANAGEMENT (Mode: %d)                 \n', opts.moveMode);
    fprintf('============================================================\n');
    fprintf('Station    : %s\n', sStation);
    fprintf('Year       : %s\n', sYear);
    fprintf('Source Dir : %s\n', sourceDir);
    fprintf('Total Files: %d\n', N);

    timerVal = tic;

    % Define 6 category folder paths if needed (Modes 1, 2, 3)
    catFolders = cell(6, 1);
    if opts.moveMode >= 1 && opts.moveMode <= 3
        for c = 1:6
            catFolderName = sprintf('%s_%02d', sYear, c);
            catFolders{c} = fullfile(outBaseDir, sStation, catFolderName);
            if ~isfolder(catFolders{c})
                mkdir(catFolders{c});
            end
        end
    end

    % Define 12 monthly folder paths if needed (Modes 3, 4, 5)
    monthFolders = cell(12, 1);
    if opts.moveMode >= 3 && opts.moveMode <= 5
        monthlyBaseDir = fullfile(outBaseDir, sStation, sprintf('%s_png', sYear));
        for m = 1:12
            monthFolderName = sprintf('%02d', m);
            monthFolders{m} = fullfile(monthlyBaseDir, monthFolderName);
            if ~isfolder(monthFolders{m})
                mkdir(monthFolders{m});
            end
        end
    end

    processedCounts = zeros(6, 1);
    monthlyCounts   = zeros(12, 1);
    missingCounts   = 0;

    for i = 1:N
        matName = summaryData.fNames{i}; % e.g., 'RB8A010005_ion.mat'
        catID   = summaryData.qualityCategory(i);
        
        % Determine month for modes 3, 4, 5 either from summaryData.dt if available or filename
        fileMonth = 1; % default fallback
        if isfield(summaryData, 'dt') && numel(summaryData.dt) >= i && ~isnat(summaryData.dt(i))
            fileMonth = month(summaryData.dt(i));
        else
            % Fallback: Try parsing month from standard CADI filename format if possible
            % e.g. RB8A010005 -> A01 means Jan (A=Jan, B=Feb, etc.) or extract via regex if embedded
            fileMonth = 1; 
        end

        % Extract base name without '_ion.mat' (e.g., 'RB8A010005')
        baseName = erase(matName, '_ion.mat');

        % Check both possible PNG suffixes (_ion_avt.png and _ion_avr.png)
        possiblePngNames = { ...
            [baseName, '_ion_avt.png'], ...
            [baseName, '_ion_avr.png'] ...
        };

        foundFile = false;
        for p = 1:numel(possiblePngNames)
            pngName = possiblePngNames{p};
            srcPngPath = fullfile(sourceDir, pngName);

            if isfile(srcPngPath)
                foundFile = true;
                
                switch opts.moveMode
                    case 1 % Move into 6 category folders
                        if catID >= 1 && catID <= 6
                            destPath = fullfile(catFolders{catID}, pngName);
                            movefile(srcPngPath, destPath);
                            processedCounts(catID) = processedCounts(catID) + 1;
                        end

                    case 2 % Copy into 6 category folders
                        if catID >= 1 && catID <= 6
                            destPath = fullfile(catFolders{catID}, pngName);
                            copyfile(srcPngPath, destPath);
                            processedCounts(catID) = processedCounts(catID) + 1;
                        end

                    case 3 % Copy to monthly folders first, then move to 6 category folders
                        % 1. Copy to monthly folder
                        tempMonthlyPath = fullfile(monthFolders{fileMonth}, pngName);
                        copyfile(srcPngPath, tempMonthlyPath);
                        monthlyCounts(fileMonth) = monthlyCounts(fileMonth) + 1;
                        
                        % 2. Move to category folder
                        if catID >= 1 && catID <= 6
                            destPath = fullfile(catFolders{catID}, pngName);
                            movefile(srcPngPath, destPath);
                            processedCounts(catID) = processedCounts(catID) + 1;
                        end

                    case 4 % Move into 12 monthly folders only
                        destPath = fullfile(monthFolders{fileMonth}, pngName);
                        movefile(srcPngPath, destPath);
                        monthlyCounts(fileMonth) = monthlyCounts(fileMonth) + 1;

                    case 5 % Copy into 12 monthly folders only
                        destPath = fullfile(monthFolders{fileMonth}, pngName);
                        copyfile(srcPngPath, destPath);
                        monthlyCounts(fileMonth) = monthlyCounts(fileMonth) + 1;
                end
                break;
            end
        end

        if ~foundFile
            missingCounts = missingCounts + 1;
        end
    end

    elapsedSec = toc(timerVal);

    % Build report structure
    moveReport = struct();
    moveReport.processedCounts = processedCounts;
    moveReport.monthlyCounts   = monthlyCounts;
    moveReport.elapsedTimeSec  = elapsedSec;

    fprintf('\n============================================================\n');
    fprintf('   SORTING COMPLETED SUCCESSFULLY (Time: %.2f s)          \n', elapsedSec);
    fprintf('============================================================\n');
    
    if opts.moveMode <= 3
        catDescriptions = {
            'Cat 1 (Good Realistic F2 Profile)', ...
            'Cat 2 (E/Es Misidentified as F2)', ...
            'Cat 3 (Jagged / Unrealistic Profile)', ...
            'Cat 4 (Blanketing Es)', ...
            'Cat 5 (Weak Ionosphere / Blackout)', ...
            'Cat 6 (Missed Valid F-Region Trace)'
        };
        for c = 1:6
            fprintf('  %-36s -> Folder %s/: %7d files\n', ...
                catDescriptions{c}, sprintf('%s_%02d', sYear, c), processedCounts(c));
        end
    end
    
    if opts.moveMode >= 3
        for m = 1:12
            fprintf('  Month %02d (Folder %s_png/%02d/)               -> %7d files\n', ...
                m, sYear, m, monthlyCounts(m));
        end
    end
    fprintf('============================================================\n');
end