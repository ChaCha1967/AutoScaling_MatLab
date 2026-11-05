% RUN_CADI_VISUALIZE_FROM_MAT Execution wrapper script for launching the 
% cadi_visualize_from_mat batch visualization pipeline.
%
% DESCRIPTION:
%   Defines target root directories and processing flags (e.g., instructing 
%   the batch function to process original noisy records rather than filtered 
%   files) and executes the main visualization routine.

success = cadi_visualize_from_mat('n:\cadi_synced_out_orig\RB', 0);