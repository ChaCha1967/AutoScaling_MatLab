function [res, rec] = cadi_compare_with_david_mat(mat_filename)
% CADI_COMPARE_WITH_DAVID_MAT Loads David's POLAN results from a .mat file 
% (records struct), runs polan_fortran_exact, and plots a detailed comparison 
% including both bottomside and topside real profiles.
%
% INPUT:
%   - mat_filename : Path to the .mat file (e.g., 'HA9g240819_pol.mat')

    %% 1. Load Data from .mat file
    if ~isfile(mat_filename)
        error('File not found: %s', mat_filename);
    end
    
    loaded_data = load(mat_filename);
    
    % Check if 'records' variable exists in the file
    if isfield(loaded_data, 'records')
        rec = loaded_data.records;
    else
        % Fallback if the struct is saved under a different variable name
        fields = fieldnames(loaded_data);
        rec = loaded_data.(fields{1});
    end

    %% 2. Extract Data Directly from Structure
    raw_data = rec.InputData;

    % Filter out invalid/zero rows if any
    valid_rows = (raw_data(:, 1) > 0) & (raw_data(:, 2) > 0);

    f_virt = raw_data(valid_rows, 1);
    h_virt = raw_data(valid_rows, 2);
    
    % David's reference real heights [N x 2]: col 1 = frequency, col 2 = real height h(f)
    if isfield(rec, 'RealHeights') && ~isempty(rec.RealHeights)
        valid_rh = (rec.RealHeights(:, 1) ~= 0) & (rec.RealHeights(:, 2) ~= 0);
        f_real_ref = rec.RealHeights(valid_rh, 1);
        h_real_ref = rec.RealHeights(valid_rh, 2);
    else
        f_real_ref = [];
        h_real_ref = [];
    end

    % David's reference peak parameters
    if isfield(rec, 'Peak') && ~isempty(rec.Peak)
        ref_foF2 = rec.Peak.foF2; 
        ref_hmF2 = rec.Peak.hmF2;
    else
        ref_foF2 = NaN;
        ref_hmF2 = NaN;
    end

    % Session parameters from struct
    FH = rec.FH;
    dip_angle = rec.Dip;
    start_val = rec.Start;
    amode = rec.Amode;
    list_flag = 1;

    %% 3. Execute MATLAB POLAN Function
    try
        [res, ~, ~, ~, ~] = polan_fortran_exact(f_virt, h_virt, FH, dip_angle, start_val, amode, 10.0, list_flag);
        
        calc_foF2  = res.foF2;
        calc_hmF2  = res.hmF2;
    catch ME
        error('POLAN execution failed for file %s: %s', mat_filename, ME.message);
    end

    %% 4. Print Comparison Report to Command Window
    fprintf('\n==================================================\n');
    fprintf('  POLAN COMPARISON REPORT: %s\n', mat_filename);
    fprintf('==================================================\n');
    fprintf('Parameter     David (.mat)     MATLAB (Ours)    Diff\n');
    fprintf('--------------------------------------------------\n');
    fprintf('foF2 (MHz)    %-14.3f    %-14.3f    %+.3f\n', ref_foF2, calc_foF2, calc_foF2 - ref_foF2);
    fprintf('hmF2 (km)     %-14.1f    %-14.1f    %+.1f\n', ref_hmF2, calc_hmF2, calc_hmF2 - ref_hmF2);
    fprintf('==================================================\n');

    %% 5. Plot Comparison with Text Box Display
    figure('Name', ['POLAN Comparison - ' rec.DateID], 'Color', 'w', 'Position', [150, 150, 900, 650]);
    
    % Plot input virtual heights
    plot(f_virt, h_virt, 'bo-', 'LineWidth', 1.2, 'MarkerFaceColor', 'b', ...
        'DisplayName', 'Input Virtual Height h''(f)');
    hold on;
    
    % Plot David's reference real profile (bottomside + topside)
    if ~isempty(f_real_ref)
        plot(f_real_ref, h_real_ref, 'ko-', 'LineWidth', 2.0, ...
            'DisplayName', 'David''s Reference Real h(f)');
    end
    
    % % Plot our calculated MATLAB bottomside real profile up to the peak
    % if isfield(res, 'h_real') && isfield(res, 'f_real')
    %     plot(res.f_real, res.h_real, 'rs-', 'LineWidth', 1.5, 'MarkerFaceColor', 'r', ...
    %         'DisplayName', 'Our MATLAB Bottomside');
    % end
    % 
    % % Plot our calculated MATLAB topside real profile above the peak
    % if isfield(res, 'h_topside') && isfield(res, 'f_topside') && ~isempty(res.h_topside)
    %     plot(res.f_topside, res.h_topside, 'r^--', 'LineWidth', 1.5, 'MarkerFaceColor', 'magenta', ...
    %         'DisplayName', 'Our MATLAB Topside');
    % end

    % Plot our calculated MATLAB bottomside real profile up to the peak
    if isfield(res, 'h_real_all') && isfield(res, 'f_real_all')
        plot(res.f_real_all, res.h_real_all, 'rs-', 'LineWidth', 1.5, 'MarkerFaceColor', 'r', ...
            'DisplayName', 'Our MATLAB real profile');
    end


    grid on;
    xlabel('Frequency (MHz)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Height (km)', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('POLAN Verification: Session %s (%s)', rec.DateID, rec.Time), 'FontSize', 13, 'FontWeight', 'bold');
    legend('Location', 'NorthWest', 'FontSize', 10);
    set(gca, 'FontSize', 11);

    % Construct text box annotation string for the plot
    text_str = {
        sprintf('\\bf David''s Reference:\\rm'), ...
        sprintf('  foF2 = %.3f MHz', ref_foF2), ...
        sprintf('  hmF2 = %.1f km', ref_hmF2), ...
        ' ', ...
        sprintf('\\bf MATLAB (Ours):\\rm'), ...
        sprintf('  foF2 = %.3f MHz', calc_foF2), ...
        sprintf('  hmF2 = %.1f km', calc_hmF2)
    };

    % Add text box to the figure (top-right area)
    annotation('textbox', [0.65, 0.60, 0.25, 0.25], 'String', text_str, ...
        'FontSize', 10, 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FitBoxToText', 'on');

end