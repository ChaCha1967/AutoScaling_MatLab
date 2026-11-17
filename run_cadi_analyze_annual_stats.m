% % =========================================================================
% % RUN_CADI_ANALYZE_ANNUAL_STATS
% % Execution wrapper script for the CADI statistical analysis pipeline.
% % =========================================================================
% clear; clc; close all;
% 
% outBaseDir = 'N:/cadi_proc/';
% sStation   = 'RB'; 
% targetYear = 2008;
% 
% opts = struct();
% % Set to FALSE to quickly redraw plots using existing summary files.
% opts.forceRebuild   = false; 
% opts.tecScaleFactor = 1.0; % TEC scaling factor (physically recalculated, multiplier is 1.0)
% 
% % Define all neural networks processed in the MAT files.
% opts.models(1).netID = '';               opts.models(1).label = '6ch-combined';
% opts.models(2).netID = '_3ch_mixed';     opts.models(2).label = '3ch-mixed';
% opts.models(3).netID = '_3ch_filtered';  opts.models(3).label = '3ch-filtered';
% opts.models(4).netID = '_1ch_mixed';     opts.models(4).label = '1ch-mixed';
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% =========================================================================
% RUN_CADI_ANALYZE_ANNUAL_STATS
% Execution wrapper script for the CADI statistical analysis pipeline.
% =========================================================================
clear; clc; close all;

outBaseDir = 'N:/cadi_proc/';
sStation   = 'RB'; 
targetYear = 2009;

opts = struct();
% Set to FALSE to quickly redraw plots using existing summary files.
opts.forceRebuild   = true; 
opts.tecScaleFactor = 1.0; % TEC scaling factor (physically recalculated, multiplier is 1.0)

% Define all neural networks processed in the MAT files.
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