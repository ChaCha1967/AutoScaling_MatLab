% =========================================================================
% RUN_CADI_ANALYZE_WITH_DAVID
% Execution wrapper script for comparing Neural Networks against David's 
% manual scaling reference data (Ground Truth).
% =========================================================================
clear; clc; close all;

% Directory with compiled NN summary files (CADI_Summary_RB_2009_...)
outBaseDir = 'N:/cadi_proc/';
% Directory containing David's *_pol.mat reference files
davidDir   = 'N:/cadi_synced/RB/2009_p1_m1_p1_m1/'; 
sStation   = 'RB'; 
targetYear = 2009;

opts = struct();
% forceRebuild applies to David's cache. If false, instantly loads CADI_Summary_RB_2009_David.mat
opts.forceRebuild = true; % Set to true initially to rebuild David's cache with new TEC scale
opts.tecScaleFactor = 1.0; % TEC scaling factor for David's data (default 1.0 for true Bottomside EC)

% List of networks to compare against David's reference
opts.models(1).label = '6ch-combined';
opts.models(2).label = '3ch-mixed';
opts.models(3).label = '3ch-filtered';
opts.models(4).label = '1ch-mixed';

% Enable automated logging
diaryFile = fullfile(outBaseDir, sprintf('CADI_David_Stats_%s_%d.log', sStation, targetYear));
if isfile(diaryFile) && opts.forceRebuild
    delete(diaryFile);
end
diary(diaryFile);
diary on;

% Execute the main analysis pipeline
cadi_analyze_annual_stats_with_david(outBaseDir, davidDir, sStation, targetYear, opts);

diary off;
fprintf('Analysis complete. Comparison plots against David are saved in %s\n', outBaseDir);