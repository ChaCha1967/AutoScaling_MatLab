function statusReport = cadi_stage5_plot_20panel(outBaseDir, sStation, startDT, endDT, opts)
% CADI_STAGE5_PLOT_20PANEL Stage 5 of the CADI pipeline: Generates and exports 
% comprehensive 20-panel diagnostic ionogram plots with overlaid U-Net virtual 
% profiles (ScaleV_unet) and POLAN real-height profiles (ScaleR_polan) as high-resolution PNGs.
%
% Inputs:
%   outBaseDir : Base directory where processed *_ion.mat files are stored
%   sStation   : 2-character station code (e.g., 'RB', 'CA', 'HA', 'EU', 'PO')
%   startDT    : Start datetime vector [YYYY, MM, DD, hh, mm, ss]
%   endDT      : End datetime vector [YYYY, MM, DD, hh, mm, ss]
%   opts       : Structure with optional plotting parameters:
%                - visible     : 'on' or 'off' window visibility (default: 'off' for fast batch)
%                - overwrite   : Logical flag to regenerate existing PNGs (default: true)
%                - suffix      : Output image filename suffix (default: '_ion_avr.png')
%
% Output:
%   statusReport : Structure containing execution statistics and processed file list

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'visible'),   opts.visible   = 'off';  end 
    if ~isfield(opts, 'overwrite'), opts.overwrite = true;   end
    if ~isfield(opts, 'suffix'),    opts.suffix    = '_ion_avr.png'; end

    tStart = datetime(startDT(1), startDT(2), startDT(3), startDT(4), startDT(5), startDT(6));
    tEnd   = datetime(endDT(1), endDT(2), endDT(3), endDT(4), endDT(5), endDT(6));

    yearsToScan  = unique(startDT(1):endDT(1));
    monthLetters = 'ABCDEFGHIJKL';

    % 1. Collect candidate *_ion.mat files across all years in the range
    candidateFiles = [];
    for yIdx = 1:numel(yearsToScan)
        sYear   = sprintf('%04d', yearsToScan(yIdx));
        yearDir = fullfile(outBaseDir, sStation, sYear);
        if isfolder(yearDir)
            dirFiles = dir(fullfile(yearDir, '*_ion.mat'));
            for k = 1:numel(dirFiles)
                dirFiles(k).yearVal = yearsToScan(yIdx);
            end
            candidateFiles = [candidateFiles; dirFiles]; %#ok<AGROW>
        end
    end

    fprintf('============================================================\n');
    fprintf('   CADI STAGE 5: 20-PANEL DIAGNOSTIC PLOT EXPORT            \n');
    fprintf('============================================================\n');
    fprintf('Station        : %s\n', sStation);
    fprintf('Time Range     : %s to %s\n', datestr(tStart), datestr(tEnd));
    fprintf('Figure Mode    : %s\n', opts.visible);

    % 2. Filter minute session files matching the datetime window
    validFileList = {};
    skippedCount  = 0;
    missingStage4 = 0;

    for i = 1:numel(candidateFiles)
        fname    = candidateFiles(i).name;
        baseName = erase(fname, '_ion.mat');

        if length(baseName) ~= 10
            continue;
        end

        mChar     = upper(baseName(4));
        fileMonth = strfind(monthLetters, mChar);
        fileDay   = str2double(baseName(5:6));
        fileHour  = str2double(baseName(7:8));
        fileMin   = str2double(baseName(9:10));

        if isempty(fileMonth) || isnan(fileDay) || isnan(fileHour) || isnan(fileMin)
            continue;
        end

        fileDT = datetime(candidateFiles(i).yearVal, fileMonth, fileDay, fileHour, fileMin, 0);
        if fileDT >= tStart && fileDT <= tEnd
            fullPath = fullfile(candidateFiles(i).folder, fname);
            fileVars = whos('-file', fullPath);
            varNames = {fileVars.name};

            if ~ismember('ion_dat', varNames) || ~ismember('ScaleV_unet', varNames) || ~ismember('ScaleR_polan', varNames)
                missingStage4 = missingStage4 + 1;
                continue;
            end

            [fFolder, fNameOnly, ~] = fileparts(fullPath);
            outPngName = [fNameOnly(1:end-4), opts.suffix]; 
            outPngPath = fullfile(fFolder, outPngName);

            if ~opts.overwrite && isfile(outPngPath)
                skippedCount = skippedCount + 1;
                continue;
            end

            validFileList{end+1} = fullPath; %#ok<AGROW>
        end
    end

    numValid = numel(validFileList);
    fprintf('Selected %d minute sessions for plotting (Skipped: %d, Missing Stages 2-4: %d).\n', ...
        numValid, skippedCount, missingStage4);

    if numValid == 0
        statusReport = struct('station', sStation, 'totalSelected', 0, ...
            'processedCount', 0, 'skippedCount', skippedCount, 'errorCount', missingStage4, ...
            'processedFiles', {{}}, 'elapsedTimeSec', 0);
        return;
    end

    % 3. Pre-build reusable Figure and Subplots
    hFig = figure('Visible', opts.visible, 'Position', [50, 50, 1920, 1080], 'PaperPositionMode', 'auto');
    clf(hFig);

    DPh = 20;
    PionCmap = CustomColormap();
    dummy_X = [1 10];
    dummy_Y = [1 10];
    dummy_C = [NaN NaN; NaN NaN];

    [axesHandles, imgHandles, lineVHandles, lineRHandles, titleHandles, histHandles] = prebuild_20panel_axes(hFig, dummy_X, dummy_Y, dummy_C, DPh, PionCmap);

    stageTimer     = tic;
    processedCount = 0;
    errorCount     = missingStage4;
    processedFiles = {};

    AntDir = ["East", "West", "North", "South"];
    AntDirChar(1:4) = 'EWNS';

    for i = 1:numValid
        fPath = validFileList{i};
        [fFolder, fnameOnly, ext] = fileparts(fPath);

        try
            d = load(fPath, 'ion_dat', 'headerStruct', 'siteStruct', 'DT', 'ScaleV_unet', 'ScaleR_polan');
            ion_dat      = d.ion_dat;
            headerStruct = d.headerStruct;
            siteStruct   = d.siteStruct;
            DT           = d.DT;
            ScaleV_unet  = d.ScaleV_unet;
            ScaleR_polan = d.ScaleR_polan;

            F        = double(headerStruct.datablock.FreqS);
            h        = double(headerStruct.datablock.heights);
            antOrder = headerStruct.datablock.antOrder;
            antPol   = siteStruct.polarity;
            Ch2Pol   = antPol(antOrder + 1);

            freq_MHz = F ./ 1e6;
            Z_zeros  = zeros(size(squeeze(ion_dat(1, :, :))));
            FrLim    = [min(freq_MHz), max(freq_MHz)];
            hLim     = [min(h), max(h)];

            % Extract ionogram slices from ion_dat
            ion1         = squeeze(ion_dat(1, :, :));
            ion2         = squeeze(ion_dat(2, :, :));
            ion3         = squeeze(ion_dat(3, :, :));
            ion4         = squeeze(ion_dat(4, :, :));
            
            ion1_clean   = squeeze(ion_dat(5, :, :));
            ion2_clean   = squeeze(ion_dat(6, :, :));
            ion3_clean   = squeeze(ion_dat(7, :, :));
            ion4_clean   = squeeze(ion_dat(8, :, :));

            dPh23        = squeeze(ion_dat(9, :, :)); 
            dPh41        = squeeze(ion_dat(10, :, :));
            dPh23f       = squeeze(ion_dat(11, :, :));
            dPh41f       = squeeze(ion_dat(12, :, :));

            % Set axes limits strictly across the 16 ionogram subplots (skipping histograms at 5, 10, 15, 20)
            ionogramAxesIndices = [1,2,3,4, 6,7,8,9, 11,12,13,14, 16,17,18,19];
            for k = 1:16
                axIdx = ionogramAxesIndices(k);
                set(axesHandles(axIdx), 'XLim', FrLim, 'YLim', hLim);
            end

            % 1. Row 1: Original ionograms (Subplots 1-4, imgHandles 1-4)
            update_subplot_ion(imgHandles(1), lineVHandles(1), lineRHandles(1), titleHandles{1}, freq_MHz, h, Z_zeros, ion1, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(1)+1), 'orig');
            update_subplot_ion(imgHandles(2), lineVHandles(2), lineRHandles(2), titleHandles{2}, freq_MHz, h, Z_zeros, ion2, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(2)+1), 'orig');
            update_subplot_ion(imgHandles(3), lineVHandles(3), lineRHandles(3), titleHandles{3}, freq_MHz, h, Z_zeros, ion3, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(3)+1), 'orig');
            update_subplot_ion(imgHandles(4), lineVHandles(4), lineRHandles(4), titleHandles{4}, freq_MHz, h, Z_zeros, ion4, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(4)+1), 'orig');

            % 2. Row 2: Filtered ionograms (Subplots 6-9, imgHandles 5-8)
            update_subplot_ion(imgHandles(5), lineVHandles(5), lineRHandles(5), titleHandles{6}, freq_MHz, h, Z_zeros, ion1_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(1)+1), 'fltr');
            update_subplot_ion(imgHandles(6), lineVHandles(6), lineRHandles(6), titleHandles{7}, freq_MHz, h, Z_zeros, ion2_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(2)+1), 'fltr');
            update_subplot_ion(imgHandles(7), lineVHandles(7), lineRHandles(7), titleHandles{8}, freq_MHz, h, Z_zeros, ion3_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(3)+1), 'fltr');
            update_subplot_ion(imgHandles(8), lineVHandles(8), lineRHandles(8), titleHandles{9}, freq_MHz, h, Z_zeros, ion4_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(4)+1), 'fltr');

            % 3. Row 3: Polarization ionograms - Original (Subplots 11-14, imgHandles 9-12)
            % update_subplot_pol(imgHandles(9),  lineVHandles(9),  lineRHandles(9),  titleHandles{11}, freq_MHz, h, Z_zeros, dPh23*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(2)+1), AntDirChar(antOrder(1)+1), 'pol orig');
            % update_subplot_pol(imgHandles(10), lineVHandles(10), lineRHandles(10), titleHandles{12}, freq_MHz, h, Z_zeros, dPh41*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(4)+1), AntDirChar(antOrder(3)+1), 'pol orig');
            update_subplot_pol(imgHandles(11), lineVHandles(11), lineRHandles(11), titleHandles{13}, freq_MHz, h, Z_zeros, dPh23*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(3)+1), AntDirChar(antOrder(2)+1), 'pol orig');
            update_subplot_pol(imgHandles(12), lineVHandles(12), lineRHandles(12), titleHandles{14}, freq_MHz, h, Z_zeros, dPh41*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(1)+1), AntDirChar(antOrder(4)+1), 'pol orig');

            % 4. Row 4: Polarization ionograms - Filtered (Subplots 16-19, imgHandles 13-16)
            % update_subplot_pol(imgHandles(13), lineVHandles(13), lineRHandles(13), titleHandles{16}, freq_MHz, h, Z_zeros, dPh41f*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(2)+1), AntDirChar(antOrder(1)+1), 'pol fltr');
            % update_subplot_pol(imgHandles(14), lineVHandles(14), lineRHandles(14), titleHandles{17}, freq_MHz, h, Z_zeros, dPh41f*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(4)+1), AntDirChar(antOrder(3)+1), 'pol fltr');
            update_subplot_pol(imgHandles(15), lineVHandles(15), lineRHandles(15), titleHandles{18}, freq_MHz, h, Z_zeros, dPh23f*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(3)+1), AntDirChar(antOrder(2)+1), 'pol fltr');
            update_subplot_pol(imgHandles(16), lineVHandles(16), lineRHandles(16), titleHandles{19}, freq_MHz, h, Z_zeros, dPh41f*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(1)+1), AntDirChar(antOrder(4)+1), 'pol fltr');
            
            % 5. Column 5 (Rows 1-4): Histograms (Subplots 5, 10, 15, 20)
            % vec12f = dPh12f(~isnan(dPh12f)) * 180 / pi;
            % vec34f = dPh34f(~isnan(dPh34f)) * 180 / pi;
            vec23f = dPh23f(~isnan(dPh23f)) * 180 / pi;
            vec41f = dPh41f(~isnan(dPh41f)) * 180 / pi;

            % set(histHandles{1}, 'Data', vec12f); titleHandles{5}.String  = sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (fltr)', DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1));
            % set(histHandles{2}, 'Data', vec34f); titleHandles{10}.String = sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (fltr)', DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1));
            set(histHandles{3}, 'Data', vec41f); titleHandles{15}.String = sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (fltr)', DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1));
            set(histHandles{4}, 'Data', vec23f); titleHandles{20}.String = sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (fltr)', DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1));

            % Render and save to PNG
            drawnow;
            frame = getframe(hFig);
            outPngName = [fnameOnly(1:end-4), opts.suffix];
            outPngPath = fullfile(fFolder, outPngName);
            imwrite(frame.cdata, outPngPath);

            processedCount = processedCount + 1;
            processedFiles{end+1} = outPngName; %#ok<AGROW>

            if mod(processedCount, 10) == 0 || i == numValid
                fprintf('  Exported %d / %d plots (%.1f s)\n', processedCount, numValid, toc(stageTimer));
            end

        catch ME
            fprintf('  ERROR plotting session %s%s: %s\n', fnameOnly, ext, ME.message);
            errorCount = errorCount + 1;
        end
    end

    if ishandle(hFig)
        close(hFig);
    end

    statusReport = struct();
    statusReport.station        = sStation;
    statusReport.totalSelected  = numValid;
    statusReport.processedCount = processedCount;
    statusReport.skippedCount   = skippedCount;
    statusReport.errorCount     = errorCount;
    statusReport.processedFiles = processedFiles;
    statusReport.elapsedTimeSec = toc(stageTimer);

    fprintf('\n============================================================\n');
    fprintf('   STAGE 5 COMPLETED SUCCESSFULLY                           \n');
    fprintf('   Exported PNGs    : %d / %d                               \n', processedCount, numValid);
    fprintf('   Elapsed Time     : %.2f seconds                          \n', statusReport.elapsedTimeSec);
    fprintf('============================================================\n');
end

% =========================================================================
% HELPER: PRE-BUILD 20-PANEL SUBPLOTS & GRAPHIC HANDLES (USING CELL ARRAY)
% =========================================================================
function [axesArr, imgArr, lineVArr, lineRArr, titleArr, histArr] = prebuild_20panel_axes(hFig, dX, dY, dC, DPh, cmap)
    axesArr  = gobjects(20, 1);
    imgArr   = gobjects(16, 1);
    lineVArr = gobjects(16, 1);
    lineRArr = gobjects(16, 1);
    titleArr = cell(20, 1); % Cell-array for titles
    histArr  = cell(4, 1);  % Cell-array for histograms

    imgIdx = 1;
    histIdx = 1;

    for s = 1:20
        ax = subplot(4, 5, s, 'Parent', hFig);
        axesArr(s) = ax;

        isHist = ismember(s, [5, 10, 15, 20]);

        if ~isHist
            im = pcolor(ax, dX, dY, dC);
            shading(ax, 'flat');
            if s <= 10
                colormap(ax, jet);
            else
                colormap(ax, cmap);
            end
            set(ax, 'XScale', 'log');
            xticks(ax, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
            ylabel(ax, 'h'', km');
            xlabel(ax, 'Freq, MHz');
            colorbar(ax, 'vert');

            hold(ax, 'on');
            % lV = plot(ax, NaN, NaN, 'co-', 'LineWidth', 1.8, 'MarkerSize', 4, 'MarkerFaceColor', 'c');
            % lR = plot(ax, NaN, NaN, 'rs--', 'LineWidth', 1.2, 'MarkerSize', 3, 'MarkerFaceColor', 'r');
            % U-Net virtual profile 
            lV = plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.2, 'Marker', 'none');
            % POLAN real profile 
            lR = plot(ax, NaN, NaN, 'k--', 'LineWidth', 1.5, 'Marker', 'none');
            hold(ax, 'off');

            imgArr(imgIdx)   = im;
            lineVArr(imgIdx) = lV;
            lineRArr(imgIdx) = lR;
            imgIdx = imgIdx + 1;
        else
            hObj = histogram(ax, [], -180:DPh:180, 'Normalization', 'probability');
            hold(ax, 'on');
            plot(ax, [-90 -90 0 90 90], [0 0.25 NaN 0 0.25], 'LineWidth', 2, 'LineStyle', ':');
            hold(ax, 'off');
            ylim(ax, [0, 0.25]);
            xlim(ax, [-180, 180]);
            xticks(ax, [-180 -90 0 90 180]);
            grid(ax, 'on');

            histArr{histIdx} = hObj;
            histIdx = histIdx + 1;
        end

        titleArr{s} = title(ax, 'Initializing...');
    end
end

% =========================================================================
% HELPER: UPDATE IONOGRAM SUBPLOT
% =========================================================================
function update_subplot_ion(imgH, lineVH, lineRH, titleH, freqMHz, hGrid, Zeros, CData, ScaleV, ScaleR, DT, antName, modeStr)
    set(imgH, 'XData', freqMHz, 'YData', hGrid, 'ZData', Zeros, 'CData', CData);

    if ~isempty(ScaleV)
        set(lineVH, 'XData', ScaleV(:, 1), 'YData', ScaleV(:, 2));
    else
        set(lineVH, 'XData', NaN, 'YData', NaN);
    end

    if ~isempty(ScaleR)
        set(lineRH, 'XData', ScaleR(:, 1), 'YData', ScaleR(:, 2));
    else
        set(lineRH, 'XData', NaN, 'YData', NaN);
    end

    titleH.String = sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%s)', DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), char(antName), modeStr);
end

% =========================================================================
% HELPER: UPDATE POLARIZATION SUBPLOT
% =========================================================================
function update_subplot_pol(imgH, lineVH, lineRH, titleH, freqMHz, hGrid, Zeros, CData, ScaleV, ScaleR, DT, ant1, ant2, modeStr)
    set(imgH, 'XData', freqMHz, 'YData', hGrid, 'ZData', Zeros, 'CData', CData);

    if ~isempty(ScaleV)
        set(lineVH, 'XData', ScaleV(:, 1), 'YData', ScaleV(:, 2));
    else
        set(lineVH, 'XData', NaN, 'YData', NaN);
    end

    if ~isempty(ScaleR)
        set(lineRH, 'XData', ScaleR(:, 1), 'YData', ScaleR(:, 2));
    else
        set(lineRH, 'XData', NaN, 'YData', NaN);
    end

    titleH.String = sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%s)', DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), char(ant1), char(ant2), modeStr);
end