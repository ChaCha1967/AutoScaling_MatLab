% =========================================================================
% MASTER EXECUTION SCRIPT FOR CADI PROCESSING PIPELINE
% =========================================================================
% This script sets up the paths, station parameters, time windows, and 
% executes the complete 5-stage CADI pipeline using cadi_run_pipeline.m.

clear; clc; close all;

% 1. Define base directories and station parameters
inBaseDir  = 'N:/cadi/';
outBaseDir = 'N:/cadi_out_test/';
sStation   = 'RB'; % Station code (e.g., 'RB')

% 2. Define target time range [YYYY, MM, DD, hh, mm, ss]
startDT = [2008, 01, 01, 00, 00, 00];
endDT   = [2008, 02, 01, 00, 00, 00];

% 3. Select which stages to run (e.g., [1, 2, 3, 4, 5] for the full pipeline)
%    - Stage 1: MD2 unpacking & raw data extraction
%    - Stage 2: Interference filtering & tensor construction
%    - Stage 3: U-Net inference & virtual profile extraction
%    - Stage 4: POLAN real-height profile inversion
%    - Stage 5: 20-panel diagnostic plot export
% runStages = [1, 2, 3, 4, 5];
runStages = 5;

% 4. Select Stage 5 plotting variant:
%    - 'new'  (or 'avt') : Runs cadi_stage5_plot.m with tensor column (suffix: '_ion_avt.png')
%    - 'old'  (or 'avr') : Runs cadi_stage5_plot_20panel.m (suffix: '_ion_avr.png')
%    - 'both'            : Runs both scripts sequentially
stage5Variant = 'old'; 

% Determine default suffix based on selected variant
if strcmpi(stage5Variant, 'old') || strcmpi(stage5Variant, 'avr')
    defaultSuffix = '_ion_avr.png';
else
    defaultSuffix = '_ion_avt.png';
end

% 5. Configure custom stage parameters
stageOpts = struct();
stageOpts.stage5 = struct(...
    'plotVariant', stage5Variant, ... % 'new' ('avt'), 'old' ('avr'), or 'both'
    'visible',     'off',         ... % 'off' for fast background batch rendering, 'on' to watch live
    'overwrite',   true,          ... % Set false to skip already rendered PNGs
    'suffix',      defaultSuffix  ... % Automatically set to '_ion_avt.png' or '_ion_avr.png'
    );

% 6. Execute the pipeline
fprintf('Starting CADI pipeline execution for station %s (Stage 5 mode: %s)...\n', sStation, stage5Variant);
pipelineReport = cadi_run_pipeline(inBaseDir, outBaseDir, sStation, startDT, endDT, runStages, stageOpts);

% 7. Display summary results
fprintf('\nPipeline Execution Summary:\n');
fprintf('------------------------------------------------------------\n');
if isfield(pipelineReport, 'stage1')
    fprintf('Stage 1 Extracted Files : %d\n', pipelineReport.stage1.processedFilesCount);
end
if isfield(pipelineReport, 'stage2')
    fprintf('Stage 2 Processed Files : %d\n', pipelineReport.stage2.processedCount);
end
if isfield(pipelineReport, 'stage3')
    fprintf('Stage 3 Traces Detected : %d\n', pipelineReport.stage3.detectedCount);
end
if isfield(pipelineReport, 'stage4')
    fprintf('Stage 4 Successful Invs : %d\n', pipelineReport.stage4.successCount);
end
if isfield(pipelineReport, 'stage5')
    fprintf('Stage 5 Exported Plots  : %d (Variant: %s)\n', pipelineReport.stage5.processedCount, stage5Variant);
end
fprintf('Total Time Elapsed      : %.2f seconds\n', pipelineReport.totalElapsedTimeSec);
fprintf('============================================================\n');