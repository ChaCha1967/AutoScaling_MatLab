function plot_david_annual_stats(inPath, outBaseDir)
% PLOT_DAVID_ANNUAL_STATS Scans David's manual scaling *_pol.mat files,
% extracts Peak parameters (foF2, hmF2, SlabT, and calculated TEC), and 
% exports 4 multi-panel figures showing monthly diurnal variations 
% with individual points, mean curves, and median curves.
%
% SYNTAX:
%   plot_david_annual_stats(inPath, outBaseDir)
%
% INPUTS:
%   - inPath     : Directory containing David's *_pol.mat files 
%                  (e.g., 'N:\cadi_synced\RB\2008_p1_m1_p1_m1')
%   - outBaseDir : Directory where output PNG figures will be saved

    if nargin < 2 || isempty(outBaseDir)
        outBaseDir = pwd;
    end

    if ~isfolder(inPath)
        error('Input directory does not exist: %s', inPath);
    end
    if ~isfolder(outBaseDir)
        mkdir(outBaseDir);
    end

    % Find all *_pol.mat files in the directory
    matFiles = dir(fullfile(inPath, '*_pol.mat'));
    N = numel(matFiles);

    if N == 0
        warning('No *_pol.mat files found in: %s', inPath);
        return;
    end

    fprintf('Found %d David reference files. Extracting parameters...\n', N);

    % Preallocate arrays for speed
    dtNums    = nan(N, 1);
    foF2_arr  = nan(N, 1);
    hmF2_arr  = nan(N, 1);
    SlabT_arr = nan(N, 1);

    for i = 1:N
        filePath = fullfile(matFiles(i).folder, matFiles(i).name);
        try
            d = load(filePath, 'records');
            if isfield(d, 'records') && isfield(d.records, 'DT') && numel(d.records.DT) >= 6
                dtNums(i) = datenum(double(d.records.DT(1:6)));
            end
            
            if isfield(d, 'records') && isfield(d.records, 'Peak') && ~isempty(d.records.Peak)
                p = d.records.Peak;
                if isfield(p, 'foF2') && ~isempty(p.foF2),   foF2_arr(i)  = double(p.foF2);   end
                if isfield(p, 'hmF2') && ~isempty(p.hmF2),   hmF2_arr(i)  = double(p.hmF2);   end
                if isfield(p, 'SlabT') && ~isempty(p.SlabT), SlabT_arr(i) = double(p.SlabT); end
            end
        catch
            % Skip corrupted or unreadable files quietly
        end
    end

    % Filter out invalid or missing values
    validIdx = ~isnan(dtNums) & ~isnan(foF2_arr) & ~isnan(hmF2_arr);
    dtTimes  = datetime(dtNums(validIdx), 'ConvertFrom', 'datenum');
    foF2     = foF2_arr(validIdx);
    hmF2     = hmF2_arr(validIdx);
    SlabT    = SlabT_arr(validIdx);
    
    % Calculate TEC from Slab Thickness and foF2, then divide by 10 to fit [0, 50] TECU range
    TEC = (SlabT .* (foF2 .^ 2) * 0.124) / 10.0;

    mVec    = month(dtTimes);
    utHours = hour(dtTimes) + minute(dtTimes)/60 + second(dtTimes)/3600;

    monthNames = {'January','February','March','April','May','June', ...
                  'July','August','September','October','November','December'};

    % Define parameters to plot: {DataVector, Label, YLimits, FilenameSuffix}
    params = {
        foF2,  'foF2 (MHz)',                [0, 10],   'foF2';
        hmF2,  'hmF2 (km)',                 [150, 500], 'hmF2';
        SlabT, 'Slab Thickness (km)',       [0, 450],   'SlabT';  % Изменено начальное значение с 50 на 0
        TEC,   'TEC (TECU, 10^{16} m^{-2})',[0, 50],   'TEC'
    };

    binStep    = 0.25; % 15-minute time bins for mean/median diurnal profiles
    binCenters = (0 : binStep : (24 - binStep)) + binStep/2;

    for pIdx = 1:size(params, 1)
        yDataAll = params{pIdx, 1};
        pLabel   = params{pIdx, 2};
        pYLim    = params{pIdx, 3};
        pName    = params{pIdx, 4};

        hFig = figure('Visible', 'off', 'Position', [50, 50, 2400, 1300], 'Color', 'w');
        sgtitle(sprintf('David Reference - Monthly Diurnal Variation of %s (Black: Mean, Red: Median)', pLabel), ...
            'FontSize', 16, 'FontWeight', 'bold');

        for m = 1:12
            ax = subplot(3, 4, m, 'Parent', hFig);
            hold(ax, 'on');

            idxM = (mVec == m) & ~isnan(yDataAll);
            tM   = utHours(idxM);
            yM   = yDataAll(idxM);

            if ~isempty(tM)
                % Scatter individual data points
                scatter(ax, tM, yM, 8, [0.55 0.68 0.85], 'filled', ...
                    'MarkerFaceAlpha', 0.25, 'MarkerEdgeAlpha', 0.25, 'HandleVisibility', 'off');

                meanCurve   = nan(size(binCenters));
                medianCurve = nan(size(binCenters));
                
                % Compute bin-based statistics
                for b = 1:numel(binCenters)
                    bLow  = (b - 1) * binStep;
                    bHigh = b * binStep;
                    inBin = (tM >= bLow) & (tM < bHigh);
                    if nnz(inBin) >= 3
                        meanCurve(b)   = mean(yM(inBin), 'omitnan');
                        medianCurve(b) = median(yM(inBin), 'omitnan');
                    end
                end

                % Smooth curves using moving average
                meanSmooth   = movmean(meanCurve, 3, 'omitnan');
                medianSmooth = movmean(medianCurve, 3, 'omitnan');

                hMean = plot(ax, binCenters, meanSmooth, 'k-', 'LineWidth', 2.0, 'DisplayName', 'Mean');
                hMed  = plot(ax, binCenters, medianSmooth, 'r-', 'LineWidth', 2.0, 'DisplayName', 'Median');

                if m == 1
                    legend(ax, [hMean, hMed], {'Mean', 'Median'}, 'Location', 'northwest', 'FontSize', 9);
                end
            end

            hold(ax, 'off');
            xlim(ax, [0, 24]);
            xticks(ax, 0:4:24);
            ylim(ax, pYLim);
            grid(ax, 'on');
            title(ax, sprintf('%s (N = %d)', monthNames{m}, nnz(idxM)), 'FontSize', 11);
            xlabel(ax, 'Time (UT, hours)');
            ylabel(ax, pLabel);
        end

        outPlotPath = fullfile(outBaseDir, sprintf('David_Diurnal_%s.png', pName));
        exportgraphics(hFig, outPlotPath, 'Resolution', 150);
        close(hFig);
        fprintf('Saved David diurnal plot for %s -> %s\n', pName, outPlotPath);
    end
    fprintf('All David reference diurnal plots generated successfully!\n');
end