% =========================================================================
% MASTER MULTI-MODEL EXECUTION SCRIPT FOR CADI PROCESSING PIPELINE
% =========================================================================
% Sets up paths, station parameters, time windows, and executes the CADI 
% pipeline for the baseline model (Stages 1-5) and additional models (Stages 3-4).

clear; clc; close all;

% 1. Define base directories and station parameters
inBaseDir  = 'N:/cadi/';
outBaseDir = 'N:/cadi_proc/';
sStation   = 'RB'; 

% 2. Define target time range [YYYY, MM, DD, hh, mm, ss]
startDT = [2013, 01, 01, 00, 00, 00];
endDT   = [2013, 12, 31, 23, 55, 00];

% 3. Define neural network models to process
% The first element must be the BASELINE model. 
% Baseline runs all requested stages and uses empty netID for Stage 5 compatibility.
models = struct();

% --- BASELINE MODEL (6-CH) ---
models(1).path      = 'N:/cadi_proc/cadi_unet_6ch_combined.mat';
models(1).netID     = ''; 
% models(1).runStages = [1, 2, 3, 4, 5]; % Build raw data, filter, infer, invert, and plot
models(1).runStages = [1, 2, 3, 4]; % Build raw data, filter, infer, invert, and plot
% models(1).runStages = [3, 4]; % Build raw data, filter, infer, invert, and plot

% --- ADDITIONAL MODELS (Appended) ---
models(2).path      = 'N:/cadi_proc/cadi_unet_3ch_mixed.mat';
models(2).netID     = '_3ch_mixed'; 
models(2).runStages = [3, 4]; % Only requires inference and inversion

models(3).path      = 'N:/cadi_proc/cadi_unet_3ch_filtered.mat';
models(3).netID     = '_3ch_filtered'; 
models(3).runStages = [3, 4];

models(4).path      = 'N:/cadi_proc/cadi_unet_1ch_mixed.mat';
models(4).netID     = '_1ch_mixed'; 
models(4).runStages = [3, 4];

% 4. Master execution loop
for m = 1:length(models)

    currentModel = models(m);
    fprintf('\n************************************************************\n');
    fprintf(' INITIATING PIPELINE FOR MODEL %d / %d: %s\n', m, length(models), currentModel.netID);
    fprintf(' Model Path: %s\n', currentModel.path);
    fprintf('************************************************************\n');

    stageOpts = struct();
    stageOpts.enableLog   = true; 
    stageOpts.logFileName = sprintf('cadi_pipeline_%s.log', sStation); 
    stageOpts.logAppend   = true; 
    stageOpts.netID       = currentModel.netID; % Propagate suffix

    % Stage 3 configurations
    stageOpts.stage3 = struct(...
        'model_path', currentModel.path, ...
        'edge_choice', 'center' ...
        );

    % Stage 5 configurations (only relevant if runStages includes 5)
    if ismember(5, currentModel.runStages)
        stageOpts.stage5 = struct(...
            'plotVariant', 'new', ...
            'visible',     'off', ...
            'overwrite',   true,  ...
            'suffix',      '_ion_avt.png' ...
            );
    end

    % Execute Pipeline for current model
    pipelineReport = cadi_run_pipeline(inBaseDir, outBaseDir, sStation, startDT, endDT, currentModel.runStages, stageOpts);

    % Close down loops cleanly
    fprintf('Completed execution for network ID [%s].\n\n', currentModel.netID);
end

fprintf('MASTER SCRIPT EXECUTION FINISHED.\n');