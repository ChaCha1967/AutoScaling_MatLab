% % RUN_CADI_ANALYZE_ANNUAL_STATS Execution wrapper script for launching 
% % the cadi_analyze_annual_stats annual processing and plotting pipeline.
% %
% % DESCRIPTION:
% %   Configures base directories, station parameters, target years, and the 
% %   list of neural network models to extract. Executes the complete 
% %   statistical analysis routine and generates multi-model comparison plots.
% 
% clear; clc; close all;
% 
% outBaseDir = 'N:/cadi_proc/';
% sStation   = 'RB'; 
% targetYear = 2008;
% 
% opts = struct();
% % opts.forceRebuild   = true; % Set to false to load existing summary files if available
% opts.forceRebuild   = false; % Set to false to load existing summary files if available
% % opts.tecScaleFactor = 10.0; % TEC scaling factor for POLAN output
% opts.tecScaleFactor = 1.0; % TEC scaling factor for POLAN output
% 
% % Define all neural networks processed in the MAT files
% % netID must exactly match the suffix used during Stage 3/4 pipeline execution.
% opts.models(1).netID = '';               opts.models(1).label = '6ch_combined';
% opts.models(2).netID = '_3ch_mixed';     opts.models(2).label = '3ch_mixed';
% opts.models(3).netID = '_3ch_filtered';  opts.models(3).label = '3ch_filtered';
% opts.models(4).netID = '_1ch_mixed';     opts.models(4).label = '1ch_mixed';
% 
% % Setup automated diary logging
% diaryFile = fullfile(outBaseDir, sprintf('CADI_Stats_%s_%d_MultiModel.log', sStation, targetYear));
% if isfile(diaryFile) && opts.forceRebuild
%     delete(diaryFile);
% end
% diary(diaryFile);
% diary on;
% 
% % Execute analysis
% summaryDataArray = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts);
% 
% diary off;
% fprintf('Analysis complete. Check the generated PNG plots in %s\n', outBaseDir);

% RUN_CADI_ANALYZE_ANNUAL_STATS Execution wrapper script for launching 
% the cadi_analyze_annual_stats annual processing and plotting pipeline.
%
% DESCRIPTION:
%   Configures base directories, station parameters, target years, and the 
%   list of neural network models to extract. Executes the complete 
%   statistical analysis routine and generates multi-model comparison plots.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% =========================================================================
% RUN_CADI_ANALYZE_ANNUAL_STATS
% Execution wrapper script for the CADI statistical analysis pipeline.
% =========================================================================
clear; clc; close all;

outBaseDir = 'N:/cadi_proc/';
sStation   = 'RB'; 
targetYear = 2008;

opts = struct();
% Set to TRUE to recalculate TEC using the new physical formula and apply global scaling
opts.forceRebuild   = false; 
opts.tecScaleFactor = 1.0; % Legacy parameter (kept for backwards compatibility)

% Define all neural networks processed in the MAT files.
% Notice: labels now use hyphens to prevent TeX subscript rendering issues.
opts.models(1).netID = '';               opts.models(1).label = '6ch-combined';
opts.models(2).netID = '_3ch_mixed';     opts.models(2).label = '3ch-mixed';
opts.models(3).netID = '_3ch_filtered';  opts.models(3).label = '3ch-filtered';
opts.models(4).netID = '_1ch_mixed';     opts.models(4).label = '1ch-mixed';

% Setup automated diary logging
diaryFile = fullfile(outBaseDir, sprintf('CADI_Stats_%s_%d_MultiModel.log', sStation, targetYear));
if isfile(diaryFile) && opts.forceRebuild
    delete(diaryFile);
end
diary(diaryFile);
diary on;

% Execute analysis
summaryDataArray = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear, opts);

diary off;
fprintf('Analysis complete. Check the generated PNG plots in %s\n', outBaseDir);