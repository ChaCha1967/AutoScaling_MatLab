tic;

% What figures plot 
lFion = 1; % filtered ionogram
lFdis = 1; % filtered distribution
lion = 1; % original ionogram
ldis = 1; % original distribution
lPFion = 1; % filtered polarization ionogram
lPion = 1; % original polarization ionogram

% Set Phase step in histogram
DPh = 20;

% Calculate polarization ionogram custom colormap
PionCmap = CustomColormap;

% Prompt the user to select the directory
%selectedFolder = uigetdir(pwd, 'Select the folder containing *_ion.mat files');
selectedFolder = 'N:\cadi_ionotest';

% Check if the user canceled the dialog
if selectedFolder == 0
    disp('Folder selection canceled. Exiting.');
    return;
end

% Construct the search pattern and get the list of matching files
searchPattern = fullfile(selectedFolder, '*_ion.mat');
fileList = dir(searchPattern);

% Display the number of found files
fprintf('Found %d "*_ion.mat" files.\n', length(fileList));

% Create a new figure for the ionogram plot. 
    % hFig = figure('Visible', 'off');

    hFig1 = figure(1);
    hFig2 = figure(2);
    hFig3 = figure(3);
    hFig4 = figure(4);
    hFig5 = figure(5);
    hFig6 = figure(6);

    % set(hFig1, 'Visible', 'off');
    % set(hFig2, 'Visible', 'off');
    % set(hFig3, 'Visible', 'off');
    % set(hFig4, 'Visible', 'off');
    % set(hFig5, 'Visible', 'off');
    % set(hFig6, 'Visible', 'off');

% Loop through each file sequentially
for i = 1:length(fileList)
    % Get the current file name and construct the full path
    currentFileName = fileList(i).name;
    currentFullPath = fullfile(selectedFolder, currentFileName);
    fprintf('Loading and processing: %s\n', currentFileName);
 
    % Extract the base file name to construct output image filenames
    [~, baseName, ~] = fileparts(currentFileName);
    % Load variables from the file directly into memory (only ONCE)
    load(currentFullPath);

    % Construct the output PNG file name and full path for ion filtered data
    outFileNameIonF = [baseName, '_flt.png'];
    outFullPathIonF = fullfile(selectedFolder, outFileNameIonF);

    % Construct the output PNG file name and full path for ion distribution filtered data
    outFileNameDisF = [baseName, '_distr_flt.png'];
    outFullPathDisF = fullfile(selectedFolder, outFileNameDisF);

    % Construct the output PNG file name and full path for ion filtered data
    outFileNameIonPF = [baseName, '_p_flt.png'];
    outFullPathIonPF = fullfile(selectedFolder, outFileNameIonPF);

    % Construct the output PNG file name and full path for ion filtered data
    outFileNameIon = [baseName, '.png'];
    outFullPathIon = fullfile(selectedFolder, outFileNameIon);

    % Construct the output PNG file name and full path for ion distribution filtered data
    outFileNameDis = [baseName, '_distr.png'];
    outFullPathDis = fullfile(selectedFolder, outFileNameDis);

    % Construct the output PNG file name and full path for ion original data
    outFileNameIonP = [baseName, '_p.png'];
    outFullPathIonP = fullfile(selectedFolder, outFileNameIonP);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% PROCESSING START 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Plot ionogram for testing
        AntDir = ["East", "West", "North", "South"];
        AntDirChar(1:4) = 'EWNS';
        F = double(headerStruct.datablock.FreqS);
        h = double(headerStruct.datablock.heights);
        antOrder = headerStruct.datablock.antOrder;
        anrX = siteStruct.antennax;
        antPol = siteStruct.polarity;
        Ch2Pol = antPol(antOrder+1);
        
        % Calculate ionograms matrixes in dB
        ion1(:,:) = 20*log10(abs(ionoIQ(1,:,:)));
        ion2(:,:) = 20*log10(abs(ionoIQ(2,:,:)));
        ion3(:,:) = 20*log10(abs(ionoIQ(3,:,:)));
        ion4(:,:) = 20*log10(abs(ionoIQ(4,:,:)));
        iona(:,:) = 20*log10(mean(abs(ionoIQ(:,:,:)),1));

        % Calculate ionograms matrixes phase angles in radian taking into
        % account polarity of individual antennas
        Ph1(:,:) = angle(ionoIQ(1,:,:))*Ch2Pol(1); %*siteStruct.polarity(1);
        Ph2(:,:) = angle(ionoIQ(2,:,:))*Ch2Pol(2); %*siteStruct.polarity(2);
        Ph3(:,:) = angle(ionoIQ(3,:,:))*Ch2Pol(3); %*siteStruct.polarity(3);
        Ph4(:,:) = angle(ionoIQ(4,:,:))*Ch2Pol(4); %*siteStruct.polarity(4);
        
        % OLD FILTERING FUNCTION - COMMENTED
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % % REMOVE_CADI_INTERFERENCE FILTER STARTED
        % % Calculate ionogram matrix with NaN when IntAve < dBth;
        % dBth = 6;
        % ionNaN = 20*log10(iona);
        % ionNaN = double(ionNaN>dBth)./double(ionNaN>dBth);
        % % ionNaN = ones(size(ionNaN));
        % % % Filtering vertical interference lines
        % % % Minimum dB difference for a pixel to be classified as a distinct vertical spike
        % % spike_thresh_dB = 6; % 6
        % % % Minimum vertical span (in pixels) to flag an entire frequency column as noise.
        % % % Assuming 3 km per pixel, 10 pixels = 30 km. Protects short vertical asymptotes.
        % % min_vertical_span = 15; % 20
        % % % Apply the absolute 6 dB threshold to generate the "white background"
        % % % format 0 - not remove background
        % % dBthr = 3; % 6
        % % ion1_clean = remove_cadi_interference(ion1,spike_thresh_dB,min_vertical_span,dBthr);
        % % ion2_clean = remove_cadi_interference(ion2,spike_thresh_dB,min_vertical_span,dBthr);
        % % ion3_clean = remove_cadi_interference(ion3,spike_thresh_dB,min_vertical_span,dBthr);
        % % ion4_clean = remove_cadi_interference(ion4,spike_thresh_dB,min_vertical_span,dBthr);
        % % iona_clean = remove_cadi_interference(iona,spike_thresh_dB,min_vertical_span,dBthr);
        % % REMOVE_CADI_INTERFERENCE FILTER FINISHED
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % REMOVE_CADI_INTERFERENCE FILTER STARTED
        % spike_thresh_dB: Threshold for identifying a spike above background (e.g., 2-6 dB).
        spike_thresh_dB = 2; % 6
        % min_extent: Minimum vertical span in pixels between the lowest and highest spike (e.g., 20-30).
        min_extent = 35; %20-30
        % min_count: Minimum number of spike pixels in a column to classify it as noise (e.g., 3-4).
        min_count = 10;
        % dBthr: Absolute dB threshold for the white background format (0 = do not remove).
        dBthr = 3;
        
        % The cleaning function calls remain the same
        ion1_clean = remove_cadi_interference_v2(ion1, spike_thresh_dB, min_extent, min_count, dBthr);
        ion2_clean = remove_cadi_interference_v2(ion2, spike_thresh_dB, min_extent, min_count, dBthr);
        ion3_clean = remove_cadi_interference_v2(ion3, spike_thresh_dB, min_extent, min_count, dBthr);
        ion4_clean = remove_cadi_interference_v2(ion4, spike_thresh_dB, min_extent, min_count, dBthr);
        iona_clean = remove_cadi_interference_v2(iona, spike_thresh_dB, min_extent, min_count, dBthr);

        % Removal of weak signals less than dBthr
        if dBthr > 0
            ion1(ion1 < dBthr) = NaN;
            ion2(ion2 < dBthr) = NaN;
            ion3(ion3 < dBthr) = NaN;
            ion4(ion4 < dBthr) = NaN;
            iona(iona < dBthr) = NaN;
        end
        
        % 1. Count the "votes" from the antennas.
        % The ~isnan function returns 1 if there is a signal in the pixel, and 0 if it is NaN.
        % The sum yields a value from 0 to 4 (the number of antennas that detected a signal in this pixel).
        votes = ~isnan(ion1_clean) + ~isnan(ion2_clean) + ~isnan(ion3_clean) + ~isnan(ion4_clean);
        
        % 2. Set the coincidence threshold (M out of N).
        % A value of 2 means: keep the pixel if at least 2 out of 4 antennas confirm the signal.
        % This is much more robust than requiring confirmation from all 4 antennas.
        required_antennas = 3; 
        
        % 3. Create the final mask.
        % Where votes are below the threshold, set to NaN. Where sufficient, set to 1.
        mask = double(votes >= required_antennas);
        mask(mask == 0) = NaN;
        
        % 4. Apply the mask.
        % Multiplying by 1 preserves the original signal; multiplying by NaN erases it (creates a white background).
        ion1_clean = ion1_clean .* mask;
        ion2_clean = ion2_clean .* mask;
        ion3_clean = ion3_clean .* mask;
        ion4_clean = ion4_clean .* mask;
        iona_clean = iona_clean .* mask;

        % Calculate original phase difference
        % polarization ionogram
        dPh12 = wrapToPi(Ph2-Ph1);
        dPh23 = wrapToPi(Ph3-Ph2);
        dPh34 = wrapToPi(Ph4-Ph3);
        dPh41 = wrapToPi(Ph1-Ph4);
        dPh13 = wrapToPi(Ph3-Ph1);
        dPh24 = wrapToPi(Ph4-Ph2);

        % Remove NaN from original phase differences
        Ph12arr = dPh12(:);
        vec_no_nan12 = Ph12arr(~isnan(Ph12arr));
        Ph23arr = dPh23(:);
        vec_no_nan23 = Ph23arr(~isnan(Ph23arr));
        Ph34arr = dPh34(:);
        vec_no_nan34 = Ph34arr(~isnan(Ph34arr));
        Ph41arr = dPh41(:);
        vec_no_nan41 = Ph41arr(~isnan(Ph41arr));
        Ph13arr = dPh13(:);
        vec_no_nan13 = Ph13arr(~isnan(Ph13arr));
        Ph24arr = dPh24(:);
        vec_no_nan24 = Ph24arr(~isnan(Ph24arr));

        % Calculate filtered phases
        Ph1f = Ph1.*mask;
        Ph2f = Ph2.*mask;
        Ph3f = Ph3.*mask;
        Ph4f = Ph4.*mask;

        % Calculate filtered phase difference
        % polarization ionogram
        dPh12f = wrapToPi(Ph2f-Ph1f);
        dPh23f = wrapToPi(Ph3f-Ph2f);
        dPh34f = wrapToPi(Ph4f-Ph3f);
        dPh41f = wrapToPi(Ph1f-Ph4f);
        dPh13f = wrapToPi(Ph3f-Ph1f);
        dPh24f = wrapToPi(Ph4f-Ph2f);

        % Remove NaN from filtered phase differences
        Ph12arrf = dPh12f(:);
        vec_no_nan12f = Ph12arrf(~isnan(Ph12arrf));
        Ph23arrf = dPh23f(:);
        vec_no_nan23f = Ph23arrf(~isnan(Ph23arrf));
        Ph34arrf = dPh34f(:);
        vec_no_nan34f = Ph34arrf(~isnan(Ph34arrf));
        Ph41arrf = dPh41f(:);
        vec_no_nan41f = Ph41arrf(~isnan(Ph41arrf));
        Ph13arrf = dPh13f(:);
        vec_no_nan13f = Ph13arrf(~isnan(Ph13arrf));
        Ph24arrf = dPh24f(:);
        vec_no_nan24f = Ph24arrf(~isnan(Ph24arrf));

        % Change 0 to NaN in original phase difference  
        % to have white background in polarization ionogram
        dPh12(dPh12 == 0) = NaN;
        dPh23(dPh23 == 0) = NaN;
        dPh34(dPh34 == 0) = NaN;
        dPh41(dPh41 == 0) = NaN;
        dPh13(dPh13 == 0) = NaN;
        dPh24(dPh24 == 0) = NaN;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % PROCESSING FINISHED
        % PLOT DATA BEGIN
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot filtered ionograms
        if lFion
            % Clear window hFig1 content
            clf(hFig1);
            figure(1);
            % set(0, 'CurrentFigure', hFig1);

            % Apply 'jet' colormap
            colormap(hFig1, jet);
             
            % plot channel 1
            subplot(2,3,1);
            pcolor(F./1e6,h,ion1_clean);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, ch(1)  = %s, Thr = %02d dB',...
                  DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(1)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');
            
            % plot channel 2
            subplot(2,3,4);
            pcolor(F./1e6,h,ion2_clean);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, ch(2) = %s, Thr = %d dB',...
                  DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(2)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');
            
            % plot channel 3
            subplot(2,3,2);
            pcolor(F./1e6,h,ion3_clean);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, ch(3) = %s, Thr = %d dB',...
                  DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(3)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');
            
            % plot channel 4
            subplot(2,3,5);
            pcolor(F./1e6,h,ion4_clean);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, ch(4) = %s, Thr = %d dB',...
                  DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(4)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');
            
            % plot channel average
            subplot(2,3,3);

            pcolor(F./1e6,h,iona_clean);
            shading flat;

            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, average, Thr = %02d dB',...
                  DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');
    
            % Export the figure to PNG
            % exportgraphics(hFig1, outFullPathIonF, 'Resolution', 150);
            print(hFig1, outFullPathIonF, '-dpng', '-r150');
            fprintf('Saved image: %s\n', outFileNameIonF);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotting filtered Phase distributions
        if lFdis
            clf(hFig2);
            figure(2);
            % set(0, 'CurrentFigure', hFig2);

            % plot channel 1-2 Phase diagram 
            subplot(2,3,1);
            histogram(vec_no_nan12f*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch1-2(%s%s), Thr = %02d dB',...
                   DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                   AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;
    
            % plot channel 2-3 Phase diagram 
            subplot(2,3,4);
            histogram(vec_no_nan23f*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch2-3(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;
    
            % plot channel 3-4 Phase diagram 
            subplot(2,3,2);
            histogram(vec_no_nan34f*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch3-4(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;
    
            % plot channel 4-1 Phase diagram 
            subplot(2,3,5);
            histogram(vec_no_nan41f*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch4-1(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;
    
            % plot channel 1-3 Phase diagram 
            subplot(2,3,3);
            histogram(vec_no_nan13f*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([0 0],[0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch1-3(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(3)+1),AntDirChar(antOrder(1)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;
    
            % plot channel 2-4 Phase diagram 
            subplot(2,3,6);
            histogram(vec_no_nan24f*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([0 0],[0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch2-4(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(4)+1),AntDirChar(antOrder(2)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;
            
            % Export the figure to PNG 
            % exportgraphics(hFig2, outFullPathDisF, 'Resolution', 300);
            print(hFig2, outFullPathDisF, '-dpng', '-r150');
            fprintf('Saved image: %s\n', outFileNameDisF);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot original ionograms
        if lion
            % Clear window hFig1 content
            clf(hFig3);
            figure(3);
            % set(0, 'CurrentFigure', hFig3);

            % Apply 'jet' colormap
            colormap(hFig3, jet);

            % plot channel 1
            subplot(2,3,1);
            pcolor(F./1e6,h,ion1);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, ch(1)  = %s, Thr = %02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(1)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');

            % plot channel 2
            subplot(2,3,4);
            pcolor(F./1e6,h,ion2);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, ch(2) = %s, Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(2)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');

            % plot channel 3
            subplot(2,3,2);
            pcolor(F./1e6,h,ion3);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, ch(3) = %s, Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(3)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');

            % plot channel 4
            subplot(2,3,5);
            pcolor(F./1e6,h,ion4);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, ch(4) = %s, Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(4)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');

            % plot channel average
            subplot(2,3,3);
            pcolor(F./1e6,h,iona);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, average, Thr = %02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'dB');

            % Export the figure with to PNG
            % exportgraphics(hFig3, outFullPathIon, 'Resolution', 300);
            print(hFig3, outFullPathIon, '-dpng', '-r150');
            fprintf('Saved image: %s\n', outFileNameIon);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotting Phase distributions
        if ldis
            clf(hFig4);
            figure(4);
            % set(0, 'CurrentFigure', hFig4);

            % plot channel 1-2 Phase diagram 
            subplot(2,3,1);
            histogram(vec_no_nan12*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, Ch1-2(%s%s), Thr = %02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;

            % plot channel 2-3 Phase diagram 
            subplot(2,3,4);
            histogram(vec_no_nan23*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, Ch2-3(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;

            % plot channel 3-4 Phase diagram 
            subplot(2,3,2);
            histogram(vec_no_nan34*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, Ch3-4(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;

            % plot channel 4-1 Phase diagram 
            subplot(2,3,5);
            histogram(vec_no_nan41*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, Ch4-1(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;

            % plot channel 1-3 Phase diagram 
            subplot(2,3,3);
            histogram(vec_no_nan13*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([0 0],[0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, Ch1-3(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(3)+1),AntDirChar(antOrder(1)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;

            % plot channel 2-4 Phase diagram 
            subplot(2,3,6);
            histogram(vec_no_nan24*180/pi,-180:DPh:180, 'Normalization', 'probability');
            hold on
            plot([0 0],[0 0.25],'LineWidth',2,'LineStyle',':');
            hold off
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, original, Ch2-4(%s%s), Th=%02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
                AntDirChar(antOrder(4)+1),AntDirChar(antOrder(2)+1),dBthr));
            ylim([0, 0.25]);
            xlim([-180, 180]);
            xticks([-180 -135 -90 -45 0 45 90 135 180]);
            grid on;

            % Export the figure to PNG
            % exportgraphics(hFig4, outFullPathDis, 'Resolution', 300);
            print(hFig4, outFullPathDis, '-dpng', '-r150');
            fprintf('Saved image: %s\n', outFileNameDis);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot filtered polarization ionogram
        if lPFion
            % Clear window hFig1 content
            clf(hFig5);
            figure(5);
            % set(0, 'CurrentFigure', hFig5);

            % Apply 'PionCmap' colormap
            colormap(hFig5, PionCmap);

            % plot channel 12
            subplot(2,3,1);
            pcolor(F./1e6,h,dPh12f*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch1-2(%s%s), Thr = %02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % plot channel 23
            subplot(2,3,4);
            pcolor(F./1e6,h,dPh23f*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch2-3(%s%s), Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % plot channel 34
            subplot(2,3,2);
            pcolor(F./1e6,h,dPh34f*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch3-4(%s%s), Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % plot channel 41
            subplot(2,3,5);
            pcolor(F./1e6,h,dPh41f*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch4-1(%s%s), Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % Export the figure to PNG
            % exportgraphics(hFig5, outFullPathIonPF, 'Resolution', 300);
            print(hFig5, outFullPathIonPF, '-dpng', '-r150');
            fprintf('Saved image: %s\n', outFileNameIonPF);
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot original polarization ionogram
        if lPion
            % Clear window hFig1 content
            clf(hFig6);
            figure(6);
            % set(0, 'CurrentFigure', hFig6);

            % Apply 'PionCmap' colormap
            colormap(hFig6, PionCmap);

            % plot channel 12
            subplot(2,3,1);
            pcolor(F./1e6,h,dPh12*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch1-2(%s%s), Thr = %02d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % plot channel 23
            subplot(2,3,4);
            pcolor(F./1e6,h,dPh23*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch2-3(%s%s), Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % plot channel 34
            subplot(2,3,2);
            pcolor(F./1e6,h,dPh34*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch3-4(%s%s), Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

            % plot channel 41
            subplot(2,3,5);
            pcolor(F./1e6,h,dPh41*180/pi);
            shading flat;
            set(gca, 'XScale', 'log');
            title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch4-1(%s%s), Thr = %d dB',...
                DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
            ylabel('Virtual height, km');
            xlabel('Sounding frequency, MHz');
            xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
            cb = colorbar('vert');
            title(cb,'POL');

           % Export the figure to PNG
           %  exportgraphics(hFig6, outFullPathIonP, 'Resolution', 300);
           print(hFig6, outFullPathIonP, '-dpng', '-r150');
           fprintf('Saved image: %s\n', outFileNameIonP);
        end
    
end

disp('All files have been successfully processed and saved.');

toc;