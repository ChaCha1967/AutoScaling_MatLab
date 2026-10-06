function M_clean = remove_cadi_interference(M_raw,spike_thresh_dB,min_vertical_span,dBthr)
% REMOVE_CADI_INTERFERENCE Removes vertical noise lines from CADI ionograms.
% The input M_raw must be the original numerical matrix in dB (no NaNs).

% --- Algorithm Parameters ---
% Window size for horizontal median (must be odd). 
% 5 bins is sufficient to bridge across a 1-3 bin wide interference line.
horiz_window = 5;      

% Minimum dB difference for a pixel to be classified as a distinct vertical spike
%%% spike_thresh_dB = 1; % 6   

% Minimum vertical span (in pixels) to flag an entire frequency column as noise.
% Assuming 3 km per pixel, 20 pixels = 60 km. Protects short vertical asymptotes.
%%% min_vertical_span = 10; % 20

% 1. Create the reference matrix using a horizontal moving median.
% Operates along dimension 2 (columns/frequencies).
% Erases thin vertical lines but fully preserves horizontal/slanted layers.
% 'omitnan' ensures robustness if input already contains some NaNs.
M_ref = movmedian(M_raw, horiz_window, 2, 'omitnan');

% 2. Isolate vertical structures.
% Subtracting the reference removes the layers, leaving only the vertical spikes.
V_noise = M_raw - M_ref;

% 3. Identify columns globally dominated by interference.
% Count how many distinct vertical spike pixels exist in each frequency column.
spike_counts = sum(V_noise > spike_thresh_dB, 1);

% Logical array (1 x N_freqs) flagging the severely noisy columns.
bad_cols = spike_counts > min_vertical_span;

% 4. Create the precise removal mask.
% A pixel is targeted ONLY if it belongs to a known bad column AND is a spike.
% Implicit expansion automatically broadcasts the 1D bad_cols across the 2D matrix.
% This logic perfectly preserves intersection points (where V_noise ~ 0).
remove_mask = (V_noise > spike_thresh_dB) & bad_cols;

% 5. Apply the targeted cleaning.
M_clean = M_raw;

% Replace only the targeted interference pixels with the local background level.
M_clean(remove_mask) = M_ref(remove_mask);

% --- Optional Post-Processing ---
% Apply the absolute 6 dB threshold to generate the "white background" format
%%%dBthr = 6;
if dBthr>0
    M_clean(M_clean < dBthr) = NaN;
end
end