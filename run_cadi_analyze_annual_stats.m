% RUN_CADI_ANALYZE_ANNUAL_STATS Execution wrapper script for launching 
% the cadi_analyze_annual_stats annual processing and plotting pipeline.
%
% DESCRIPTION:
%   Configures base directories, station parameters, and target years, 
%   enables automated diary logging to a text file, and executes the 
%   complete statistical analysis routine.

outBaseDir = 'N:/cadi_out_test/';
sStation = 'RB'; 
targetYear = 2009;
opts = struct();
opts.forceRebuild = true; % false

diaryFile = fullfile(outBaseDir, sprintf('CADI_Stats_%s_%d.log', sStation, targetYear));
diary(diaryFile);
diary on;

summaryData = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts);

diary off;