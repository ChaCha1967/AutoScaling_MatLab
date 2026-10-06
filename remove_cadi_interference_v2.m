% REMOVE_CADI_INTERFERENCE_V2 Removes solid and dashed vertical noise lines.

function M_clean = remove_cadi_interference_v2(M_raw, spike_thresh_dB, min_extent, min_count, dBthr)
%%%%%%%%%%%%%%%%% Input values 
% M_raw: Original numerical matrix in dB (no NaNs).
% spike_thresh_dB: Threshold for identifying a spike above background (e.g., 2-6 dB).
% min_extent: Minimum vertical span in pixels between the lowest and highest spike (e.g., 20-30).
% min_count: Minimum number of spike pixels in a column to classify it as noise (e.g., 3-4).
% dBthr: Absolute dB threshold for the white background format (0 = do not remove).
%%%%%%%%%%%%%%%%% Output values
% M_raw: Cleaned numerical matrix in dB (with NaNs if dBthr > 0).

% 1. Create the reference matrix (horizontal median filter)
horiz_window = 5;      
M_ref = movmedian(M_raw, horiz_window, 2, 'omitnan');

% 2. Isolate spikes (Top-Hat transformation)
V_noise = M_raw - M_ref;
spike_mask = V_noise > spike_thresh_dB;

% 3. Identify columns with dashed and solid vertical interference lines
[num_rows, num_cols] = size(M_raw);
bad_cols = false(1, num_cols);

% Find coordinates of all spike pixels
[rows, cols] = find(spike_mask);

if ~isempty(rows)
    % Vectorized search for the minimum and maximum spike height for each frequency column
    min_row = accumarray(cols, rows, [num_cols, 1], @min, NaN);
    max_row = accumarray(cols, rows, [num_cols, 1], @max, NaN);

    % Count the total number of spikes in each column
    counts = accumarray(cols, rows, [num_cols, 1], @numel, 0);

    % Calculate vertical extent (distance from the highest to the lowest point of the dashed line)
    extent = max_row - min_row;

    % A column is noise if the extent exceeds the threshold AND it meets the minimum point count
    bad_cols = (extent > min_extent) & (counts >= min_count);
    bad_cols = bad_cols'; % Transpose for dimensional compatibility with implicit expansion
end

% 4. Smart removal (targeted replacement of spikes with local background level)
remove_mask = spike_mask & bad_cols;

M_clean = M_raw;
M_clean(remove_mask) = M_ref(remove_mask);

% 5. Optional conversion to white background (removal of weak signals entirely)
if dBthr > 0
    M_clean(M_clean < dBthr) = NaN;
end
end