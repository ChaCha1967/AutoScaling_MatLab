% RUN_CADI_SORT_PNG_BY_CATEGORY Execution wrapper script for launching 
% cadi_sort_png_by_category() with opts.moveMode selection and diary logging.

outBaseDir = 'N:/cadi_out_test/';
sStation   = 'RB'; 
targetYear = 2009;

% Configure options
opts = struct();
opts.moveMode = 3; % Mode 3: Copy to monthly folders first, then move to 6 category folders

% Setup diary logging
diaryFile = fullfile(outBaseDir, sprintf('CADI_Sort_%s_%d_Mode%d.log', sStation, targetYear, opts.moveMode));
if isfile(diaryFile), delete(diaryFile); end
diary(diaryFile);
diary on;

fprintf('Starting CADI PNG sorting process at %s\n', char(datetime('now')));

% Ensure summaryData is loaded (required to get quality categories and file lists)
summaryMatPath = fullfile(outBaseDir, sprintf('CADI_Summary_%s_%4d.mat', sStation, targetYear));
if isfile(summaryMatPath)
    fprintf('Loading existing annual summary from: %s\n', summaryMatPath);
    load(summaryMatPath, 'summaryData');
else
    fprintf('Summary file not found. Running cadi_analyze_annual_stats first...\n');
    analysisOpts = struct('forceRebuild', false);
    summaryData = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, analysisOpts);
end

% Execute sorting function
moveReport = cadi_sort_png_by_category(outBaseDir, sStation, targetYear, summaryData, opts);

fprintf('Sorting execution completed successfully.\n');

diary off;