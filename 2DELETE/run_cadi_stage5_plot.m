% =========================================================================
% EXECUTION SCRIPT FOR CADI STAGE 5: 20-PANEL & TENSOR PLOT EXPORT
% =========================================================================
% This script configures parameters and executes cadi_stage5_plot.m to 
% generate high-resolution 20-panel diagnostic ionogram and U-Net tensor 
% PNG plots for a specified station and datetime window.

clear; clc; close all;

% 1. Define base output directory and station code
outBaseDir = 'N:/cadi_out_test/';
sStation   = 'RB'; % 2-character station code (e.g., 'RB', 'CA', 'HA', 'EU', 'PO')

% 2. Define target time range [YYYY, MM, DD, hh, mm, ss]
startDT = [2008, 01, 10, 20, 00, 00];
endDT   = [2008, 01, 10, 21, 00, 00];

% 3. Configure plotting options
opts = struct();
opts.visible   = 'off';          % 'off' for fast background batch rendering, 'on' to display figure
opts.overwrite = true;           % true to regenerate existing PNG files, false to skip
opts.suffix    = '_ion_avt.png'; % Output PNG filename suffix

% 4. Run Stage 5 plotting function
fprintf('Starting Stage 5 plot export for station %s...\n', sStation);
statusReport = cadi_stage5_plot(outBaseDir, sStation, startDT, endDT, opts);

% 5. Display execution summary
fprintf('\nStage 5 Execution Summary:\n');
fprintf('------------------------------------------------------------\n');
fprintf('Station            : %s\n', statusReport.station);
fprintf('Total Selected     : %d\n', statusReport.totalSelected);
fprintf('Exported PNGs      : %d\n', statusReport.processedCount);
fprintf('Skipped Files      : %d\n', statusReport.skippedCount);
fprintf('Errors / Missing   : %d\n', statusReport.errorCount);
fprintf('Elapsed Time       : %.2f seconds\n', statusReport.elapsedTimeSec);
fprintf('============================================================\n');