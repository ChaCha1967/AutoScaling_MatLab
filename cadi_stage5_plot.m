function statusReport = cadi_stage5_plot(outBaseDir, sStation, startDT, endDT, opts)
% CADI_STAGE5_PLOT Stage 5 (Variant 2) of the CADI pipeline: Generates and exports 
% 20-panel diagnostic ionogram plots including cropped U-Net 6-channel tensor 
% visualizations in the 5th column and NE/SW polarization histograms in Row 4 (Cols 1-2).
%
% Layout (4x5 Grid):
%   Row 1 : Cols 1-4 = Raw Ionograms (dB)            | Col 5 (Sub 5)  = Tensor Unfiltered Amp
%   Row 2 : Cols 1-4 = Filtered Ionograms (dB)       | Col 5 (Sub 10) = Tensor Filtered Amp
%   Row 3 : Cols 1-4 = Raw Polarization (12,34,23,41)| Col 5 (Sub 15) = Tensor Unfiltered Pol (O-X)
%   Row 4 : Col 1 (Sub 16) = Hist 23 (NE)            | Col 2 (Sub 17) = Hist 41 (SW)
%           Col 3 (Sub 18) = Filt Pol 23 (NE)        | Col 4 (Sub 19) = Filt Pol 41 (SW)
%           Col 5 (Sub 20) = Tensor Filtered Pol (O-X)

    if nargin < 5 || isempty(opts), opts = struct(); end
    if ~isfield(opts, 'visible'),   opts.visible   = 'off';  end 
    if ~isfield(opts, 'overwrite'), opts.overwrite = true;   end
    if ~isfield(opts, 'suffix'),    opts.suffix    = '_ion_avt.png'; end

    tStart = datetime(startDT(1), startDT(2), startDT(3), startDT(4), startDT(5), startDT(6));
    tEnd   = datetime(endDT(1), endDT(2), endDT(3), endDT(4), endDT(5), endDT(6));

    yearsToScan  = unique(startDT(1):endDT(1));
    monthLetters = 'ABCDEFGHIJKL';

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
    fprintf('   CADI STAGE 5: 20-PANEL DIAGNOSTIC & TENSOR PLOT EXPORT   \n');
    fprintf('============================================================\n');
    fprintf('Station        : %s\n', sStation);
    fprintf('Time Range     : %s to %s\n', datestr(tStart), datestr(tEnd));
    fprintf('Figure Mode    : %s\n', opts.visible);

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

            if ~ismember('ion_dat', varNames) || ~ismember('ScaleV_unet', varNames) || ...
               ~ismember('ScaleR_polan', varNames) || ~ismember('X_tensor_6ch', varNames)
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

    hFig = figure('Visible', opts.visible, 'Position', [50, 50, 3300, 1350], 'PaperPositionMode', 'auto');
    clf(hFig);

    DPh = 20;
    PionCmap = CustomColormap();
    dummy_X = [1 10];
    dummy_Y = [1 10];
    dummy_C = [NaN NaN; NaN NaN];

    % Pre-build 20 subplots (indexed 1..20 directly to avoid handle offset issues)
    [axesHandles, imgHandles, lineVHandles, lineRHandles, titleHandles, histHandles] = ...
        prebuild_20panel_axes_v2(hFig, dummy_X, dummy_Y, dummy_C, DPh, PionCmap);

    stageTimer     = tic;
    processedCount = 0;
    errorCount     = missingStage4;
    processedFiles = {};

    AntDir = ["East", "West", "North", "South"];
    AntDirChar(1:4) = 'EWNS';

    % All 18 image subplots (all except histograms at 16 and 17)
    imageSubplotIndices = [1,2,3,4,5, 6,7,8,9,10, 11,12,13,14,15, 18,19,20];

    for i = 1:numValid
        fPath = validFileList{i};
        [fFolder, fnameOnly, ext] = fileparts(fPath);

        try
            d = load(fPath, 'ion_dat', 'headerStruct', 'siteStruct', 'DT', ...
                            'ScaleV_unet', 'ScaleR_polan', 'X_tensor_6ch', 'H_orig', 'W_orig');
            ion_dat      = d.ion_dat;
            headerStruct = d.headerStruct;
            DT           = d.DT;
            ScaleV_unet  = d.ScaleV_unet;
            ScaleR_polan = d.ScaleR_polan;
            X_tensor_6ch = double(d.X_tensor_6ch);

            F        = double(headerStruct.datablock.FreqS);
            h        = double(headerStruct.datablock.heights);
            antOrder = headerStruct.datablock.antOrder;

            freq_MHz = F ./ 1e6;
            Z_zeros  = zeros(size(squeeze(ion_dat(1, :, :))));
            FrLim    = [min(freq_MHz), max(freq_MHz)];
            hLim     = [min(h), max(h)];

            % 1. Extract standard ionogram slices from ion_dat
            ion1       = squeeze(ion_dat(1, :, :));
            ion2       = squeeze(ion_dat(2, :, :));
            ion3       = squeeze(ion_dat(3, :, :));
            ion4       = squeeze(ion_dat(4, :, :));
            
            ion1_clean = squeeze(ion_dat(5, :, :));
            ion2_clean = squeeze(ion_dat(6, :, :));
            ion3_clean = squeeze(ion_dat(7, :, :));
            ion4_clean = squeeze(ion_dat(8, :, :));

            dPh12      = squeeze(ion_dat(14, :, :)); 
            dPh34      = squeeze(ion_dat(15, :, :)); 
            dPh23      = squeeze(ion_dat(9, :, :)); 
            dPh41      = squeeze(ion_dat(10, :, :));

            dPh23f     = squeeze(ion_dat(11, :, :));
            dPh41f     = squeeze(ion_dat(12, :, :));

            % 2. Extract and crop X_tensor_6ch to valid non-padded region (e.g., 171 x 92)
            [~, H_ion, W_ion] = size(ion_dat);
            if isfield(d, 'H_orig') && isfield(d, 'W_orig')
                H_crop = min([d.H_orig, H_ion, size(X_tensor_6ch, 1)]);
                W_crop = min([d.W_orig, W_ion, size(X_tensor_6ch, 2)]);
            else
                H_crop = min([171, H_ion, size(X_tensor_6ch, 1)]);
                W_crop = min([92,  W_ion, size(X_tensor_6ch, 2)]);
            end

            f_tensor = freq_MHz(1:W_crop);
            h_tensor = h(1:H_crop);
            Z_tensor = zeros(H_crop, W_crop);

            % Note: In Stage 2, X_tensor_6ch = cat(3, X_tensor_filt, X_tensor_orig)
            % Channels 1..3 = Filtered (Amp, O-mode, X-mode)
            % Channels 4..6 = Unfiltered/Orig (Amp, O-mode, X-mode)
            T_filt_amp = X_tensor_6ch(1:H_crop, 1:W_crop, 1);
            T_filt_O   = X_tensor_6ch(1:H_crop, 1:W_crop, 2);
            T_filt_X   = X_tensor_6ch(1:H_crop, 1:W_crop, 3);

            T_orig_amp = X_tensor_6ch(1:H_crop, 1:W_crop, 4);
            T_orig_O   = X_tensor_6ch(1:H_crop, 1:W_crop, 5);
            T_orig_X   = X_tensor_6ch(1:H_crop, 1:W_crop, 6);

            % Superposition of O-mode (+blue in PionCmap) and X-mode (-red in PionCmap)
            T_orig_pol = T_orig_O - T_orig_X;
            T_filt_pol = T_filt_O - T_filt_X;

            % Set background zeros to NaN for clean white rendering
            T_orig_amp(T_orig_amp == 0) = NaN;
            T_filt_amp(T_filt_amp == 0) = NaN;
            T_orig_pol(T_orig_O == 0 & T_orig_X == 0) = NaN;
            T_filt_pol(T_filt_O == 0 & T_filt_X == 0) = NaN;

            % Set axes limits across all 18 image subplots
            for k = 1:numel(imageSubplotIndices)
                axIdx = imageSubplotIndices(k);
                set(axesHandles(axIdx), 'XLim', FrLim, 'YLim', hLim);
            end

            % --- ROW 1: Cols 1-4 Raw Ionograms | Col 5 (Sub 5) Unfiltered Tensor Amp ---
            update_subplot_ion(imgHandles(1), lineVHandles(1), lineRHandles(1), titleHandles{1}, freq_MHz, h, Z_zeros, ion1, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(1)+1), 'orig');
            update_subplot_ion(imgHandles(2), lineVHandles(2), lineRHandles(2), titleHandles{2}, freq_MHz, h, Z_zeros, ion2, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(2)+1), 'orig');
            update_subplot_ion(imgHandles(3), lineVHandles(3), lineRHandles(3), titleHandles{3}, freq_MHz, h, Z_zeros, ion3, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(3)+1), 'orig');
            update_subplot_ion(imgHandles(4), lineVHandles(4), lineRHandles(4), titleHandles{4}, freq_MHz, h, Z_zeros, ion4, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(4)+1), 'orig');
            update_subplot_tensor(imgHandles(5), lineVHandles(5), lineRHandles(5), titleHandles{5}, f_tensor, h_tensor, Z_tensor, T_orig_amp, ScaleV_unet, ScaleR_polan, DT, 'Tensor Amp (orig)');

            % --- ROW 2: Cols 1-4 Filtered Ionograms | Col 5 (Sub 10) Filtered Tensor Amp ---
            update_subplot_ion(imgHandles(6), lineVHandles(6), lineRHandles(6), titleHandles{6}, freq_MHz, h, Z_zeros, ion1_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(1)+1), 'fltr');
            update_subplot_ion(imgHandles(7), lineVHandles(7), lineRHandles(7), titleHandles{7}, freq_MHz, h, Z_zeros, ion2_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(2)+1), 'fltr');
            update_subplot_ion(imgHandles(8), lineVHandles(8), lineRHandles(8), titleHandles{8}, freq_MHz, h, Z_zeros, ion3_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(3)+1), 'fltr');
            update_subplot_ion(imgHandles(9), lineVHandles(9), lineRHandles(9), titleHandles{9}, freq_MHz, h, Z_zeros, ion4_clean, ScaleV_unet, ScaleR_polan, DT, AntDir(antOrder(4)+1), 'fltr');
            update_subplot_tensor(imgHandles(10), lineVHandles(10), lineRHandles(10), titleHandles{10}, f_tensor, h_tensor, Z_tensor, T_filt_amp, ScaleV_unet, ScaleR_polan, DT, 'Tensor Amp (fltr)');

            % --- ROW 3: Cols 1-4 Raw Polarization | Col 5 (Sub 15) Unfiltered Tensor Pol ---
            update_subplot_pol(imgHandles(11), lineVHandles(11), lineRHandles(11), titleHandles{11}, freq_MHz, h, Z_zeros, dPh12*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(2)+1), AntDirChar(antOrder(1)+1), 'pol orig');
            update_subplot_pol(imgHandles(12), lineVHandles(12), lineRHandles(12), titleHandles{12}, freq_MHz, h, Z_zeros, dPh34*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(4)+1), AntDirChar(antOrder(3)+1), 'pol orig');
            update_subplot_pol(imgHandles(13), lineVHandles(13), lineRHandles(13), titleHandles{13}, freq_MHz, h, Z_zeros, dPh23*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(3)+1), AntDirChar(antOrder(2)+1), 'pol orig');
            update_subplot_pol(imgHandles(14), lineVHandles(14), lineRHandles(14), titleHandles{14}, freq_MHz, h, Z_zeros, dPh41*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(1)+1), AntDirChar(antOrder(4)+1), 'pol orig');
            update_subplot_tensor(imgHandles(15), lineVHandles(15), lineRHandles(15), titleHandles{15}, f_tensor, h_tensor, Z_tensor, T_orig_pol, ScaleV_unet, ScaleR_polan, DT, 'Tensor Pol O/X (orig)');

            % --- ROW 4: Cols 1-2 Histograms (23 & 41) | Cols 3-4 Filt Pol (23 & 41) | Col 5 (Sub 20) Filtered Tensor Pol ---
            vec23f = dPh23f(~isnan(dPh23f)) * 180 / pi;
            vec41f = dPh41f(~isnan(dPh41f)) * 180 / pi;

            set(histHandles{1}, 'Data', vec23f);
            titleHandles{16}.String = sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (fltr)', ...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), AntDirChar(antOrder(3)+1), AntDirChar(antOrder(2)+1));

            set(histHandles{2}, 'Data', vec41f);
            titleHandles{17}.String = sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (fltr)', ...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), AntDirChar(antOrder(1)+1), AntDirChar(antOrder(4)+1));

            update_subplot_pol(imgHandles(18), lineVHandles(18), lineRHandles(18), titleHandles{18}, freq_MHz, h, Z_zeros, dPh23f*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(3)+1), AntDirChar(antOrder(2)+1), 'pol fltr');
            update_subplot_pol(imgHandles(19), lineVHandles(19), lineRHandles(19), titleHandles{19}, freq_MHz, h, Z_zeros, dPh41f*180/pi, ScaleV_unet, ScaleR_polan, DT, AntDirChar(antOrder(1)+1), AntDirChar(antOrder(4)+1), 'pol fltr');
            update_subplot_tensor(imgHandles(20), lineVHandles(20), lineRHandles(20), titleHandles{20}, f_tensor, h_tensor, Z_tensor, T_filt_pol, ScaleV_unet, ScaleR_polan, DT, 'Tensor Pol O/X (fltr)');

            drawnow;
            frame = getframe(hFig);
            outPngName = [fnameOnly(1:end-4), opts.suffix];
            outPngPath = fullfile(fFolder, outPngName);
            imwrite(frame.cdata, outPngPath);
            % exportgraphics(hFig, outPngPath, 'Resolution', 100);

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
% HELPER: PRE-BUILD 20-PANEL SUBPLOTS (DIRECT 1..20 HANDLE INDEXING)
% =========================================================================
function [axesArr, imgArr, lineVArr, lineRArr, titleArr, histArr] = prebuild_20panel_axes_v2(hFig, dX, dY, dC, DPh, cmap)
    axesArr  = gobjects(20, 1);
    imgArr   = gobjects(20, 1);
    lineVArr = gobjects(20, 1);
    lineRArr = gobjects(20, 1);
    titleArr = cell(20, 1);
    histArr  = cell(2, 1);

    for s = 1:20
        ax = subplot(4, 5, s, 'Parent', hFig);
        axesArr(s) = ax;

        isHist = ismember(s, [16, 17]);

        if ~isHist
            im = pcolor(ax, dX, dY, dC);
            shading(ax, 'flat');

            % Rows 1 & 2 (Subplots 1..10): Jet colormap (Amplitude dB and Tensor Amp)
            % Rows 3 & 4 (Subplots 11..15, 18..20): Custom polarization colormap
            if s <= 10
                colormap(ax, jet);
                if ismember(s, [5, 10])
                    clim(ax, [0, 1]); % Tensor amplitude normalized range [0, 1]
                end
            else
                colormap(ax, cmap);
                if ismember(s, [15, 20])
                    clim(ax, [-1, 1]); % Tensor O-X polarization superposition range [-1, 1]
                else
                    clim(ax, [-180, 180]); % Standard phase difference in degrees
                end
            end

            set(ax, 'XScale', 'log');
            xticks(ax, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
            ylabel(ax, 'h'', km');
            xlabel(ax, 'Freq, MHz');
            colorbar(ax, 'vert');

            hold(ax, 'on');
            lV = plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.2, 'Marker', 'none');
            lR = plot(ax, NaN, NaN, 'k--', 'LineWidth', 1.5, 'Marker', 'none');
            hold(ax, 'off');

            imgArr(s)   = im;
            lineVArr(s) = lV;
            lineRArr(s) = lR;
        else
            % Subplots 16 (Hist 23 NE) and 17 (Hist 41 SW)
            hObj = histogram(ax, [], -180:DPh:180, 'Normalization', 'probability');
            hold(ax, 'on');
            plot(ax, [-90 -90 0 90 90], [0 0.25 NaN 0 0.25], 'LineWidth', 2, 'LineStyle', ':');
            hold(ax, 'off');
            ylim(ax, [0, 0.25]);
            xlim(ax, [-180, 180]);
            xticks(ax, [-180 -90 0 90 180]);
            grid(ax, 'on');

            if s == 16
                histArr{1} = hObj;
            else
                histArr{2} = hObj;
            end
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

    titleH.String = sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%s)', ...
        DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), char(antName), modeStr);
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

    titleH.String = sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%s)', ...
        DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), char(ant1), char(ant2), modeStr);
end

% =========================================================================
% HELPER: UPDATE U-NET TENSOR SUBPLOT (COLUMN 5)
% =========================================================================
function update_subplot_tensor(imgH, lineVH, lineRH, titleH, freqMHz, hGrid, Zeros, CData, ScaleV, ScaleR, DT, tensorLabel)
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

    titleH.String = sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s', ...
        DT(1),DT(2),DT(3),DT(4),DT(5),DT(6), tensorLabel);
end