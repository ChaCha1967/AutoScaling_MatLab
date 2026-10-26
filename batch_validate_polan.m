function batch_validate_polan(InPath, OutPath)
% BATCH_VALIDATE_POLAN Batch processes _pol.mat files, runs MATLAB POLAN,
% saves individual comparison PNG plots using a single reusable window,
% compiles a consolidated log.mat, and generates statistical metric plots.
%
% INPUTS:
%   - InPath  : Root directory containing subfolders with *_pol.mat files
%   - OutPath : Root directory where results, PNGs, and log.mat will be saved

    if nargin < 2
        error('Please provide both InPath and OutPath arguments.');
    end

    if ~isfolder(InPath)
        error('Input folder does not exist: %s', InPath);
    end

    if ~isfolder(OutPath)
        mkdir(OutPath);
    end

    % Find all *_pol.mat files recursively
    mat_files = dir(fullfile(InPath, '**', '*_pol.mat'));
    num_files = length(mat_files);

    if num_files == 0
        warning('No *_pol.mat files found in %s', InPath);
        return;
    end

    fprintf('Found %d files for batch processing.\n', num_files);

    % Initialize storage cell arrays / structures for log.mat
    res_all = {};
    rec_all = {};
    valid_indices = 0;

    % Create a single reusable figure window for fast batch plotting
    hFig = figure('Name', 'POLAN Batch Verification', 'Color', 'w', 'Position', [100, 100, 900, 650]);

    for i = 1:num_files
        current_mat = fullfile(mat_files(i).folder, mat_files(i).name);
        
        % Determine relative path and create corresponding output directory
        rel_path = extractAfter(mat_files(i).folder, InPath);
        if startsWith(rel_path, filesep)
            rel_path = rel_path(2:end);
        end
        out_sub_dir = fullfile(OutPath, rel_path);
        if ~isfolder(out_sub_dir)
            mkdir(out_sub_dir);
        end

        base_name = strrep(mat_files(i).name, '_pol.mat', '');
        out_png_name = fullfile(out_sub_dir, [base_name, '_pol.png']);

        try
            % 1. Load reference data
            loaded_data = load(current_mat);
            if isfield(loaded_data, 'records')
                rec = loaded_data.records;
            else
                fields = fieldnames(loaded_data);
                rec = loaded_data.(fields{1});
            end

            raw_data = rec.InputData;
            valid_rows = (raw_data(:, 1) > 0) & (raw_data(:, 2) > 0);
            f_virt = raw_data(valid_rows, 1);
            h_virt = raw_data(valid_rows, 2);

            if isfield(rec, 'RealHeights') && ~isempty(rec.RealHeights)
                valid_rh = (rec.RealHeights(:, 1) ~= 0) & (rec.RealHeights(:, 2) ~= 0);
                f_real_ref = rec.RealHeights(valid_rh, 1);
                h_real_ref = rec.RealHeights(valid_rh, 2);
            else
                f_real_ref = [];
                h_real_ref = [];
            end

            if isfield(rec, 'Peak') && ~isempty(rec.Peak)
                ref_foF2  = get_field_safe(rec.Peak, 'foF2', NaN);
                ref_hmF2  = get_field_safe(rec.Peak, 'hmF2', NaN);
                ref_SH    = get_field_safe(rec.Peak, 'ScaleHt', NaN);
                ref_Slab  = get_field_safe(rec.Peak, 'SlabT', NaN);
            else
                ref_foF2 = NaN; ref_hmF2 = NaN; ref_SH = NaN; ref_Slab = NaN;
            end

            FH = rec.FH;
            dip_angle = rec.Dip;
            start_val = rec.Start;
            amode = rec.Amode;

            % 2. Run MATLAB POLAN
            [res, ~, ~, ~, ~] = polan_fortran_exact(f_virt, h_virt, FH, dip_angle, start_val, amode, 10.0, 0);

            % Extract our parameters
            calc_foF2  = res.foF2;
            calc_hmF2  = res.hmF2;
            calc_SH    = res.H_scale;
            if isfield(res, 'TEC') && calc_foF2 > 0
                % Convert MATLAB SlabT from meters to kilometers to match reference units
                calc_Slab = (res.TEC / (1.24e-4 * (calc_foF2^2))) / 1000.0; 
            else
                calc_Slab = NaN;
            end
            res.SlabT = calc_Slab;

            % Store valid records
            valid_indices = valid_indices + 1;
            res_all{valid_indices} = res;
            rec_all{valid_indices} = rec;

            % 3. Render and save PNG using the reusable figure window
            clf(hFig);
            plot(f_virt, h_virt, 'bo-', 'LineWidth', 1.2, 'MarkerFaceColor', 'b', ...
                'DisplayName', 'Input Virtual Height h''(f)');
            hold on;
            if ~isempty(f_real_ref)
                plot(f_real_ref, h_real_ref, 'ko-', 'LineWidth', 2.0, ...
                    'DisplayName', 'Reference Real h(f)');
            end
            if isfield(res, 'h_real_all') && isfield(res, 'f_real_all')
                plot(res.f_real_all, res.h_real_all, 'rs-', 'LineWidth', 1.5, 'MarkerFaceColor', 'r', ...
                    'DisplayName', 'Our MATLAB real profile');
            end
            grid on;
            xlabel('Frequency (MHz)', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Height (km)', 'FontSize', 12, 'FontWeight', 'bold');
            date_str = get_field_safe(rec, 'DateID', 'N/A');
            time_str = get_field_safe(rec, 'Time', 'N/A');
            title(sprintf('POLAN Verification: Session %s (%s)', date_str, time_str), 'FontSize', 13, 'FontWeight', 'bold');
            legend('Location', 'NorthWest', 'FontSize', 10);
            set(gca, 'FontSize', 11);

            text_str = {
                sprintf('\\bf Reference:\\rm'), ...
                sprintf('  foF2 = %.3f MHz', ref_foF2), ...
                sprintf('  hmF2 = %.1f km', ref_hmF2), ...
                sprintf('  ScaleHt = %.1f km', ref_SH), ...
                sprintf('  SlabT = %.1f km', ref_Slab), ...
                ' ', ...
                sprintf('\\bf MATLAB (Ours):\\rm'), ...
                sprintf('  foF2 = %.3f MHz', calc_foF2), ...
                sprintf('  hmF2 = %.1f km', calc_hmF2), ...
                sprintf('  ScaleHt = %.1f km', calc_SH), ...
                sprintf('  SlabT = %.1f km', calc_Slab)
            };
            annotation(hFig, 'textbox', [0.65, 0.55, 0.28, 0.35], 'String', text_str, ...
                'FontSize', 9, 'BackgroundColor', 'w', 'EdgeColor', 'k', 'FitBoxToText', 'on');

            saveas(hFig, out_png_name);
            fprintf('[%d/%d] Processed & Saved: %s\n', i, num_files, mat_files(i).name);

        catch ME
            fprintf('ERROR processing file %s: %s\n', mat_files(i).name, ME.message);
        end
    end

    % Close the persistent figure window after batch loop completes
    if ishandle(hFig)
        close(hFig);
    end

    %% 4. Save consolidated log.mat in OutPath root
    log_file_path = fullfile(OutPath, 'log.mat');
    save(log_file_path, 'res_all', 'rec_all');
    fprintf('Consolidated log saved to: %s\n', log_file_path);

    %% 5. Generate Evaluation Metrics and Comparative Plots
    if valid_indices > 0
        generate_evaluation_metrics(res_all, rec_all, OutPath);
    end
end

function val = get_field_safe(struct_obj, field_name, default_val)
    if isfield(struct_obj, field_name) && ~isempty(struct_obj.(field_name))
        val = struct_obj.(field_name);
    else
        val = default_val;
    end
end

function generate_evaluation_metrics(res_all, rec_all, OutPath)
    n = length(res_all);
    foF2_ref  = zeros(n, 1); foF2_matlab = zeros(n, 1);
    hmF2_ref  = zeros(n, 1); hmF2_matlab = zeros(n, 1);
    SH_ref    = zeros(n, 1); SH_matlab   = zeros(n, 1);
    Slab_ref  = zeros(n, 1); Slab_matlab = zeros(n, 1);

    for i = 1:n
        res_curr = res_all{i};
        rec_curr = rec_all{i};

        foF2_matlab(i) = res_curr.foF2;
        hmF2_matlab(i) = res_curr.hmF2;
        SH_matlab(i)   = res_curr.H_scale;
        Slab_matlab(i) = get_field_safe(res_curr, 'SlabT', NaN);

        if isfield(rec_curr, 'Peak') && ~isempty(rec_curr.Peak)
            foF2_ref(i) = get_field_safe(rec_curr.Peak, 'foF2', NaN);
            hmF2_ref(i) = get_field_safe(rec_curr.Peak, 'hmF2', NaN);
            SH_ref(i)   = get_field_safe(rec_curr.Peak, 'ScaleHt', NaN);
            Slab_ref(i) = get_field_safe(rec_curr.Peak, 'SlabT', NaN);
        else
            foF2_ref(i) = NaN; hmF2_ref(i) = NaN; SH_ref(i) = NaN; Slab_ref(i) = NaN;
        end
    end

    metrics = {
        'foF2', foF2_ref, foF2_matlab, 'MHz';
        'hmF2', hmF2_ref, hmF2_matlab, 'km';
        'ScaleHt', SH_ref, SH_matlab, 'km';
        'SlabT', Slab_ref, Slab_matlab, 'km'
    };

    hFigMetric = figure('Name', 'POLAN Evaluation Metrics', 'Color', 'w', 'Position', [50, 50, 1400, 900]);

    for m = 1:size(metrics, 1)
        name  = metrics{m, 1};
        v_ref = metrics{m, 2};
        v_calc= metrics{m, 3};
        units = metrics{m, 4};

        valid_idx = ~isnan(v_ref) & ~isnan(v_calc);
        r = v_ref(valid_idx);
        c = v_calc(valid_idx);
        diffs = c - r;

        mae = mean(abs(diffs));
        rmse = sqrt(mean(diffs.^2));

        % Subplot 1: Difference Histogram (Left)
        subplot(4, 2, 2*m - 1);
        histogram(diffs, 30, 'FaceColor', [0.85, 0.33, 0.10], 'EdgeColor', 'none');
        grid on;
        xlabel(sprintf('\\Delta %s (%s) [MatLab - Reference]', name, units), 'FontSize', 10, 'FontWeight', 'bold');
        ylabel('Count', 'FontSize', 10, 'FontWeight', 'bold');
        title(sprintf('%s Error (MAE = %.3f, RMSE = %.3f)', name, mae, rmse), 'FontSize', 11, 'FontWeight', 'bold');
        xline(0, '--b', 'LineWidth', 1.5);

        % Subplot 2: Regression Scatter Plot (Right) with equal axis lengths and smaller markers
        subplot(4, 2, 2*m);
        scatter(r, c, 10, [0.15, 0.65, 0.25], 'filled', 'MarkerFaceAlpha', 0.6);
        hold on;
        min_val = min([r; c]); max_val = max([r; c]);
        plot([min_val, max_val], [min_val, max_val], 'k--', 'LineWidth', 1.5);
        grid on;
        xlabel(sprintf('Reference %s (%s)', name, units), 'FontSize', 10, 'FontWeight', 'bold');
        ylabel(sprintf('MatLab (Ours) %s (%s)', name, units), 'FontSize', 10, 'FontWeight', 'bold');
        title(sprintf('%s: Reference vs MatLab', name), 'FontSize', 11, 'FontWeight', 'bold');
        
        if min_val < max_val
            axis([min_val, max_val, min_val, max_val]);
            axis equal; % Ensures X and Y axes have identical physical lengths
        end
    end

    metrics_fig_path = fullfile(OutPath, 'polan_evaluation_metrics.png');
    saveas(hFigMetric, metrics_fig_path);
    close(hFigMetric);
    fprintf('Evaluation metrics plots saved to: %s\n', metrics_fig_path);
end