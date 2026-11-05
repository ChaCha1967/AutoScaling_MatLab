% =========================================================================
% CADI VALIDATION RUN SCRIPT WITH DIARY LOGGING
% =========================================================================

% Define directory paths for pipeline results, David's reference files, and outputs
pipelineOutDir = 'N:/cadi_out_test/RB/2008';
davidPolDir    = 'N:/cadi_synced/RB/2008_p1_m1_p1_m1/'; % Path to files with *_pol.mat
outBaseDir     = 'N:/cadi_out_test/';

% Specify the path for the final validation log file
logFilePath = fullfile(outBaseDir, 'CADI_Validation_Log.txt');

% Check if an old log file exists; if so, delete it to start fresh
if isfile(logFilePath)
    delete(logFilePath);
end

% Enable MATLAB diary function to capture and record all console output to the log file
diary(logFilePath);
diary on;

try
    % Execute the main cross-validation comparison function
    report = cadi_compare_with_david(pipelineOutDir, davidPolDir, outBaseDir);

    fprintf('\nValidation completed successfully!\n');
catch ME
    % Catch and print any unexpected errors during execution
    fprintf('\nERROR during validation: %s\n', ME.message);
end

% Disable diary recording
diary off;

% Confirm successful log saving to the console
fprintf('Log successfully saved to: %s\n', logFilePath);