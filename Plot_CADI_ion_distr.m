% Prompt the user to select the directory
selectedFolder = uigetdir(pwd, 'Select the folder containing *_ion.mat files');

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

% Loop through each file sequentially
for i = 1:length(fileList)
    % Get the current file name and construct the full path
    currentFileName = fileList(i).name;
    currentFullPath = fullfile(selectedFolder, currentFileName);

    fprintf('Loading and processing: %s\n', currentFileName);

    % Load the .mat file into memory (creates a struct containing file variables)
    ionoData = load(currentFullPath);

    % Create a new figure for the ionogram plot. 
    % Setting 'Visible' to 'off' prevents the window from popping up,
    % which drastically speeds up the loop and prevents focus stealing.
    hFig = figure('Visible', 'off');

    % Extract the base file name without the .mat extension 
    [~, baseName, ~] = fileparts(currentFileName);
    inFileName = [baseName, '.mat'];
    inFullPath = fullfile(selectedFolder, inFileName);
    % load *_ion.mat
    load(inFullPath);

    % Construct the output PNG file name and full path for filtered data
    outFileNameF = [baseName, '_flt.png'];
    outFullPathF = fullfile(selectedFolder, outFileNameF);

    % % Construct the output PNG file name and full path for original data
    % outFileName = [baseName, '.png'];
    % outFullPath = fullfile(selectedFolder, outFileName);

        %%% PROCESSING START 
    
        % Plot ionogram for testing
        AntDir = ["East", "West", "North", "South"];
        F = double(headerStruct.datablock.FreqS);
        h = double(headerStruct.datablock.heights);
        antOrder = headerStruct.datablock.antOrder;
        
        % Calculate ionograms matrixes in dB
        ion1(:,:) = 20*log10(abs(ionoIQ(1,:,:)));
        ion2(:,:) = 20*log10(abs(ionoIQ(2,:,:)));
        ion3(:,:) = 20*log10(abs(ionoIQ(3,:,:)));
        ion4(:,:) = 20*log10(abs(ionoIQ(4,:,:)));
        iona(:,:) = 20*log10(mean(abs(ionoIQ(:,:,:)),1));

        % Calculate ionograms matrixes phase angles in radian
        Ph1(:,:) = angle(ionoIQ(1,:,:));
        Ph2(:,:) = angle(ionoIQ(2,:,:));
        Ph3(:,:) = angle(ionoIQ(3,:,:));
        Ph4(:,:) = angle(ionoIQ(4,:,:));
        
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

        % Calculate Ph considering polarity
        Ph1 = Ph1.*mask*siteStruct.polarity(1);
        Ph2 = Ph2.*mask*siteStruct.polarity(2);
        Ph3 = Ph3.*mask*siteStruct.polarity(3);
        Ph4 = Ph4.*mask*siteStruct.polarity(4);
        % Calculate phase difference
        dPh12 = Ph1-Ph2;
        dPh34 = Ph3-Ph4;

        % Correct phase differences
        Ph12arr = dPh12(:);
        vec_no_nan12 = Ph12arr(~isnan(Ph12arr));
        Ph34arr = dPh34(:);
        vec_no_nan34 = Ph34arr(~isnan(Ph34arr));

        % REMOVE_CADI_INTERFERENCE FILTER FINISHED
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%
        % PLOT FILTERED DATA
        % REMOVE_CADI_INTERFERENCE FILTER FINISHED
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%%%%%%%%%%%%%%%%%%%
        % PLOT FILTERED DATA
        % plot channel 1
        subplot(2,4,1);
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
        subplot(2,4,5);
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
        subplot(2,4,2);
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
        subplot(2,4,6);
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

        % plot channel 1-2 Phase diagram 
        subplot(2,4,7);
        histogram(vec_no_nan34*180/pi,-180:10:180);
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch1-2, Thr = %02d dB',...
               DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),dBthr));

        % plot channel 1-2 Phase diagram 
        subplot(2,4,8);
        histogram(vec_no_nan34*180/pi,-180:10:180);
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, filtered, Ch3-4, Thr = %02d dB',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),dBthr));

        
        % Export the figure with filtered data to PNG with high resolution (300 DPI).
        % exportgraphics is the standard method for MATLAB R2020a and newer.
        exportgraphics(hFig, outFullPathF, 'Resolution', 300);
        fprintf('Saved image: %s\n', outFileNameF);
    
        % % %%%%%%%%%%%%%%%%%%%%
        % % % PLOT ORIGINAL DATA
        % % % remove background less than dBthr
        % % if dBthr>0
        % %     ion1(ion1 < dBthr) = NaN;
        % %     ion2(ion2 < dBthr) = NaN;
        % %     ion3(ion3 < dBthr) = NaN;
        % %     ion4(ion4 < dBthr) = NaN;
        % %     iona(iona < dBthr) = NaN;
        % % end
        % % 
        % % % plot channel 1
        % % subplot(2,3,1);
        % % pcolor(F./1e6,h,ion1);
        % % shading flat;
        % % set(gca, 'XScale', 'log');
        % % title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, ch(1)  = %s, Thr = %02d dB',...
        % %     DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(1)+1),dBthr));
        % % ylabel('Virtual height, km');
        % % xlabel('Sounding frequency, MHz');
        % % xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        % % cb = colorbar('vert');
        % % title(cb,'dB');
        % % 
        % % % plot channel 2
        % % subplot(2,3,4);
        % % pcolor(F./1e6,h,ion2);
        % % shading flat;
        % % set(gca, 'XScale', 'log');
        % % title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, ch(2) = %s, Thr = %d dB',...
        % %     DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(2)+1),dBthr));
        % % ylabel('Virtual height, km');
        % % xlabel('Sounding frequency, MHz');
        % % xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        % % cb = colorbar('vert');
        % % title(cb,'dB');
        % % 
        % % % plot channel 3
        % % subplot(2,3,2);
        % % pcolor(F./1e6,h,ion3);
        % % shading flat;
        % % set(gca, 'XScale', 'log');
        % % title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, ch(3) = %s, Thr = %d dB',...
        % %     DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(3)+1),dBthr));
        % % ylabel('Virtual height, km');
        % % xlabel('Sounding frequency, MHz');
        % % xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        % % cb = colorbar('vert');
        % % title(cb,'dB');
        % % 
        % % % plot channel 4
        % % subplot(2,3,5);
        % % pcolor(F./1e6,h,ion4);
        % % shading flat;
        % % set(gca, 'XScale', 'log');
        % % title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, ch(4) = %s, Thr = %d dB',...
        % %     DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(4)+1),dBthr));
        % % ylabel('Virtual height, km');
        % % xlabel('Sounding frequency, MHz');
        % % xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        % % cb = colorbar('vert');
        % % title(cb,'dB');
        % % 
        % % % plot channel average
        % % subplot(2,3,3);
        % % pcolor(F./1e6,h,iona);
        % % shading flat;
        % % set(gca, 'XScale', 'log');
        % % title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, average, Thr = %02d dB',...
        % %     DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),dBthr));
        % % ylabel('Virtual height, km');
        % % xlabel('Sounding frequency, MHz');
        % % xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        % % cb = colorbar('vert');
        % % title(cb,'dB');
        % % 
        % % % Export the figure with original data to PNG with high resolution (300 DPI).
        % % % exportgraphics is the standard method for MATLAB R2020a and newer.
        % % exportgraphics(hFig, outFullPath, 'Resolution', 300);
        % % fprintf('Saved image: %s\n', outFileName);
    
        %%% PROCESSING FINISH 

    % Close the figure to free up system memory (critical for loops)
    close(hFig);
end

disp('All files have been successfully processed and saved.');







