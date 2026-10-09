% % Start calculating running time
tic;

% Scaling file exists and
lScaleV = 0; % flag for virtual heighths profile
lScaleR = 0; % flag for real heighths profile

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
NmatF = length(fileList);
fprintf('Found %d "*_ion.mat" files.\n', NmatF);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DUMMY FIG CREATION START
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Force MATLAB to use Figure 1 and assign it to hFig
hFig = figure(1);
% set(hFig, 'Visible', 'off', ...
%     'Position', [10, 10, 1920, 1080], ...
%     'PaperPositionMode', 'auto');
set(hFig, 'Visible', 'on');
% Clear the current content of the figure
clf(hFig);


% Dummy data for initial allocation (2x2 matrices)
dummy_X = [1 10];
dummy_Y = [1 10];
dummy_C = [NaN NaN; NaN NaN];

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 1: Original ionogram, channel 1
% ---------------------------------------------------------
ax11 = subplot(4, 5, 1);
img11 = pcolor(ax11, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax11, 'flat');
colormap(ax11, jet);
set(ax11, 'XScale', 'log');
xticks(ax11, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax11, 'Virtual height, km');
xlabel(ax11, 'Sounding frequency, MHz');
cb11 = colorbar(ax11, 'vert');
title(cb11, 'dB');
title11 = title(ax11, 'Initializing...'); % Save the title handle

hold(ax11, 'on');
line1V = plot(ax11, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax11, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax11, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 2: Original ionogram, channel 2
% ---------------------------------------------------------
ax12 = subplot(4, 5, 2);
img12 = pcolor(ax12, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax12, 'flat');
colormap(ax12, jet);
set(ax12, 'XScale', 'log');
xticks(ax12, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax12, 'Virtual height, km');
xlabel(ax12, 'Sounding frequency, MHz');
cb12 = colorbar(ax12, 'vert');
title(cb12, 'dB');
title12 = title(ax12, 'Initializing...'); % Save the title handle

hold(ax12, 'on');
line1V = plot(ax12, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax12, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax12, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 3: Original ionogram, channel 3
% ---------------------------------------------------------
ax13 = subplot(4, 5, 3);
img13 = pcolor(ax13, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax13, 'flat');
colormap(ax13, jet);
set(ax13, 'XScale', 'log');
xticks(ax13, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax13, 'Virtual height, km');
xlabel(ax13, 'Sounding frequency, MHz');
cb13 = colorbar(ax13, 'vert');
title(cb13, 'dB');
title13 = title(ax13, 'Initializing...'); % Save the title handle

hold(ax13, 'on');
line1V = plot(ax13, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax13, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax13, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 4: Original ionogram, channel 4
% ---------------------------------------------------------
ax14 = subplot(4, 5, 4);
img14 = pcolor(ax14, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax14, 'flat');
colormap(ax14, jet);
set(ax14, 'XScale', 'log');
xticks(ax14, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax14, 'Virtual height, km');
xlabel(ax14, 'Sounding frequency, MHz');
cb14 = colorbar(ax14, 'vert');
title(cb14, 'dB');
title14 = title(ax14, 'Initializing...'); % Save the title handle

hold(ax14, 'on');
line1V = plot(ax14, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax14, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax14, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 5: Filtered Phase distribution 1-2
% ---------------------------------------------------------
ax15 = subplot(4, 5, 5);
% Save the histogram handle
hist15 = histogram(ax15, [], -180:DPh:180, 'Normalization', 'probability'); 
hold(ax15, 'on');
plot(ax15, [-90 -90 0 90 90], [0 0.25 NaN 0 0.25], 'LineWidth', 2, 'LineStyle', ':');
hold(ax15, 'off');
ylim(ax15, [0, 0.25]);
xlim(ax15, [-180, 180]);
xticks(ax15, [-180 -135 -90 -45 0 45 90 135 180]);
grid(ax15, 'on');
title15 = title(ax15, 'Initializing...'); % Save the title handle

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 6: Filtered ionogram, channel 1
% ---------------------------------------------------------
ax21 = subplot(4, 5, 6);
img21 = pcolor(ax21, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax21, 'flat');
colormap(ax21, jet);
set(ax21, 'XScale', 'log');
xticks(ax21, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax21, 'Virtual height, km');
xlabel(ax21, 'Sounding frequency, MHz');
cb21 = colorbar(ax21, 'vert');
title(cb21, 'dB');
title21 = title(ax21, 'Initializing...'); % Save the title handle

hold(ax21, 'on');
line1V = plot(ax21, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax21, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax21, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 7: Filtered ionogram, channel 2
% ---------------------------------------------------------
ax22 = subplot(4, 5, 7);
img22 = pcolor(ax22, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax22, 'flat');
colormap(ax22, jet);
set(ax22, 'XScale', 'log');
xticks(ax22, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax22, 'Virtual height, km');
xlabel(ax22, 'Sounding frequency, MHz');
cb22 = colorbar(ax22, 'vert');
title(cb22, 'dB');
title22 = title(ax22, 'Initializing...'); % Save the title handle

hold(ax22, 'on');
line1V = plot(ax22, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax22, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax22, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 8: Filtered ionogram, channel 3
% ---------------------------------------------------------
ax23 = subplot(4, 5, 8);
img23 = pcolor(ax23, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax23, 'flat');
colormap(ax23, jet);
set(ax23, 'XScale', 'log');
xticks(ax23, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax23, 'Virtual height, km');
xlabel(ax23, 'Sounding frequency, MHz');
cb23 = colorbar(ax23, 'vert');
title(cb23, 'dB');
title23 = title(ax23, 'Initializing...'); % Save the title handle

hold(ax23, 'on');
line1V = plot(ax23, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax23, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax23, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 9: Filtered ionogram, channel 4
% ---------------------------------------------------------
ax24 = subplot(4, 5, 9);
img24 = pcolor(ax24, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax24, 'flat');
colormap(ax24, jet);
set(ax24, 'XScale', 'log');
xticks(ax24, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax24, 'Virtual height, km');
xlabel(ax24, 'Sounding frequency, MHz');
cb24 = colorbar(ax24, 'vert');
title(cb24, 'dB');
title24 = title(ax24, 'Initializing...'); % Save the title handle

hold(ax24, 'on');
line1V = plot(ax24, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax24, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax24, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 10: Filtered Phase distribution 2-3
% ---------------------------------------------------------
ax15 = subplot(4, 5, 10);
% Save the histogram handle
hist15 = histogram(ax15, [], -180:DPh:180, 'Normalization', 'probability'); 
hold(ax15, 'on');
plot(ax15, [-90 -90 0 90 90], [0 0.25 NaN 0 0.25], 'LineWidth', 2, 'LineStyle', ':');
hold(ax15, 'off');
ylim(ax15, [0, 0.25]);
xlim(ax15, [-180, 180]);
xticks(ax15, [-180 -135 -90 -45 0 45 90 135 180]);
grid(ax15, 'on');
title25 = title(ax15, 'Initializing...'); % Save the title handle

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 11: Filtered ionogram, channel 1-2
% ---------------------------------------------------------
ax31 = subplot(4, 5, 11);
img31 = pcolor(ax31, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax31, 'flat');
colormap(ax31, jet);
set(ax31, 'XScale', 'log');
xticks(ax31, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax31, 'Virtual height, km');
xlabel(ax31, 'Sounding frequency, MHz');
cb31 = colorbar(ax31, 'vert');
title(cb31, 'dB');
title31 = title(ax31, 'Initializing...'); % Save the title handle

hold(ax31, 'on');
line1V = plot(ax31, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax31, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax31, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 12: Filtered ionogram, channel 3-4
% ---------------------------------------------------------
ax32 = subplot(4, 5, 12);
img32 = pcolor(ax32, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax32, 'flat');
colormap(ax32, jet);
set(ax32, 'XScale', 'log');
xticks(ax32, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax32, 'Virtual height, km');
xlabel(ax32, 'Sounding frequency, MHz');
cb32 = colorbar(ax32, 'vert');
title(cb32, 'dB');
title32 = title(ax32, 'Initializing...'); % Save the title handle

hold(ax32, 'on');
line1V = plot(ax32, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax32, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax32, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 13: Filtered ionogram, channel 2-3% ---------------------------------------------------------
ax33 = subplot(4, 5, 13);
img33 = pcolor(ax33, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax33, 'flat');
colormap(ax33, jet);
set(ax33, 'XScale', 'log');
xticks(ax33, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax33, 'Virtual height, km');
xlabel(ax33, 'Sounding frequency, MHz');
cb33 = colorbar(ax33, 'vert');
title(cb33, 'dB');
title33 = title(ax33, 'Initializing...'); % Save the title handle

hold(ax33, 'on');
line1V = plot(ax33, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax33, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax33, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 14: Filtered ionogram, channel 4-1
% ---------------------------------------------------------
ax34 = subplot(4, 5, 14);
img34 = pcolor(ax34, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax34, 'flat');
colormap(ax34, jet);
set(ax34, 'XScale', 'log');
xticks(ax34, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax34, 'Virtual height, km');
xlabel(ax34, 'Sounding frequency, MHz');
cb34 = colorbar(ax34, 'vert');
title(cb34, 'dB');
title34 = title(ax34, 'Initializing...'); % Save the title handle

hold(ax34, 'on');
line1V = plot(ax34, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax34, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax34, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 15: Filtered Phase distribution 2-3
% ---------------------------------------------------------
ax35 = subplot(4, 5, 15);
% Save the histogram handle
hist35 = histogram(ax35, [], -180:DPh:180, 'Normalization', 'probability'); 
hold(ax35, 'on');
plot(ax35, [-90 -90 0 90 90], [0 0.25 NaN 0 0.25], 'LineWidth', 2, 'LineStyle', ':');
hold(ax35, 'off');
ylim(ax35, [0, 0.25]);
xlim(ax35, [-180, 180]);
xticks(ax35, [-180 -135 -90 -45 0 45 90 135 180]);
grid(ax35, 'on');
title35 = title(ax35, 'Initializing...'); % Save the title handle

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 16: Filtered ionogram, channel 1-2
% ---------------------------------------------------------
ax41 = subplot(4, 5, 16);
img41 = pcolor(ax41, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax41, 'flat');
colormap(ax41, jet);
set(ax41, 'XScale', 'log');
xticks(ax41, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax41, 'Virtual height, km');
xlabel(ax41, 'Sounding frequency, MHz');
cb41 = colorbar(ax41, 'vert');
title(cb41, 'dB');
title41 = title(ax41, 'Initializing...'); % Save the title handle

hold(ax41, 'on');
line1V = plot(ax41, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax41, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax41, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 17: Filtered ionogram, channel 3-4
% ---------------------------------------------------------
ax42 = subplot(4, 5, 17);
img42 = pcolor(ax42, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax42, 'flat');
colormap(ax42, jet);
set(ax42, 'XScale', 'log');
xticks(ax42, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax42, 'Virtual height, km');
xlabel(ax42, 'Sounding frequency, MHz');
cb42 = colorbar(ax42, 'vert');
title(cb42, 'dB');
title42 = title(ax42, 'Initializing...'); % Save the title handle

hold(ax42, 'on');
line1V = plot(ax42, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax42, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax42, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 18: Filtered ionogram, channel 2-3
% ---------------------------------------------------------
ax43 = subplot(4, 5, 18);
img43 = pcolor(ax43, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax43, 'flat');
colormap(ax43, jet);
set(ax43, 'XScale', 'log');
xticks(ax43, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax43, 'Virtual height, km');
xlabel(ax43, 'Sounding frequency, MHz');
cb43 = colorbar(ax43, 'vert');
title(cb43, 'dB');
title43 = title(ax43, 'Initializing...'); % Save the title handle

hold(ax43, 'on');
line1V = plot(ax43, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax43, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax43, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 19: Filtered ionogram, channel 4-1
% ---------------------------------------------------------
ax44 = subplot(4, 5, 19);
img44 = pcolor(ax44, dummy_X, dummy_Y, dummy_C); % Save the surface handle
shading(ax44, 'flat');
colormap(ax44, jet);
set(ax44, 'XScale', 'log');
xticks(ax44, [1 2 3 4 5 6 7 8 9 10 12 15 19]);
ylabel(ax44, 'Virtual height, km');
xlabel(ax44, 'Sounding frequency, MHz');
cb44 = colorbar(ax44, 'vert');
title(cb44, 'dB');
title44 = title(ax44, 'Initializing...'); % Save the title handle

hold(ax44, 'on');
line1V = plot(ax44, NaN, NaN, 'k', 'LineWidth', 1);   % Save ScaleV line handle
line1R = plot(ax44, NaN, NaN, 'k--', 'LineWidth', 1); % Save ScaleR line handle
hold(ax44, 'off');

% ---------------------------------------------------------
% PRE-BUILD SUBPLOT 10: Filtered Phase distribution 4-1
% ---------------------------------------------------------
ax45 = subplot(4, 5, 20);
% Save the histogram handle
hist45 = histogram(ax45, [], -180:DPh:180, 'Normalization', 'probability'); 
hold(ax45, 'on');
plot(ax45, [-90 -90 0 90 90], [0 0.25 NaN 0 0.25], 'LineWidth', 2, 'LineStyle', ':');
hold(ax45, 'off');
ylim(ax45, [0, 0.25]);
xlim(ax45, [-180, 180]);
xticks(ax45, [-180 -135 -90 -45 0 45 90 135 180]);
grid(ax45, 'on');
title45 = title(ax45, 'Initializing...'); % Save the title handle

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DUMMY FIG CREATION FINISH
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Loop through each file sequentially
for i = 1:length(fileList)

    % Get the current ion file name and construct the full path
    currentFileName = fileList(i).name;
    currentFullPath = fullfile(selectedFolder, currentFileName);
    % Making name of the correspondent scale mat file
    currentScaleFileName = currentFileName;
    currentScaleFileName(12:14) = 'pol';
    currentScaleFullPath = fullfile(selectedFolder, currentScaleFileName);
    % Verify that the corresponding scale mat file exists
    if isfile(currentScaleFullPath) % load and test data from polarization scale mat file 
        fprintf('Loading and processing ion: %s and scale: %s data\n', currentFileName, currentScaleFileName);
        % load data 
        load(currentScaleFullPath);
        % configure & set virtual scaled profile
        if isfield(records, 'InputData') && ~isempty(records.InputData) % data exists
            ScaleV = records.InputData;
            lScaleV = 1;
        else % data not exists
            ScaleV = zeros(1,2)*NaN;
            lScaleV = 0;
        end
        % configure & set virtual scaled profile
        if isfield(records, 'RealHeights') && ~isempty(records.RealHeights) % data exists
            ScaleR = records.RealHeights;
            lScaleR = 1;
        else % data not exists
            ScaleR = zeros(1,2)*NaN;
            lScaleR = 0;
        end
    else % set scale data to NaN and scale flags to 0
        ScaleV = zeros(1,2)*NaN;
        lScaleV = 0;
        ScaleR = zeros(1,2)*NaN;
        lScaleR = 0;
    end
 
    % Extract the base file name to construct output image filenames
    [~, baseName, ~] = fileparts(currentFileName);
    % Load variables from the ion file directly into memory
    load(currentFullPath);

    % Construct the output PNG file name and full path for all ion plots
    outFileNameIonA = [baseName, 'a.png'];
    outFullPathIonA = fullfile(selectedFolder, outFileNameIonA);

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
        freq_MHz = F ./ 1e6;

        % % Clear the current content of the figure
        % clf(hFig);
        % % Set hFig as the active figure for drawing without forcing it to pop up
        % set(0, 'CurrentFigure', hFig);

        % ---------------------------------------------------------
        % UPDATE SUBPLOT 1
        % ---------------------------------------------------------
        % Update the pcolor matrix and its axis limits
        set(img11, 'XData', freq_MHz, 'YData', h, 'CData', ion1);

        % Update the scaling lines
        set(line1V, 'XData', ScaleV(:,1), 'YData', ScaleV(:,2));
        set(line1R, 'XData', ScaleR(:,1), 'YData', ScaleR(:,2));

        % Update the specific title string
        title11.String = sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(1)+1),dBthr);        
 
        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot original ionograms

        % % plot channel 1
        % subplot(4,5,1);
        % pcolor(F./1e6,h,ion1);
        % shading flat;
        % colormap(gca, jet);
        % hold on;
        % plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        % plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        % hold off;
        % set(gca, 'XScale', 'log');
        % title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, orig)',...
        %       DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(1)+1),dBthr));
        % ylabel('Virtual height, km');
        % xlabel('Sounding frequency, MHz');
        % xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        % cb = colorbar('vert');
        % title(cb,'dB');

        % plot channel 2
        subplot(4,5,2);
        pcolor(F./1e6,h,ion2);
        shading flat;
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        colormap(gca, jet);
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(2)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % plot channel 3
        subplot(4,5,3);
        pcolor(F./1e6,h,ion3);
        shading flat;
        colormap(gca, jet);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(3)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % plot channel 4
        subplot(4,5,4);
        pcolor(F./1e6,h,ion4);
        shading flat;
        colormap(gca, jet);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(4)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot filtered ionograms

        % plot channel 1
        subplot(4,5,6);
        pcolor(F./1e6,h,ion1_clean);
        shading flat;
        colormap(gca, jet);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(1)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % plot channel 2
        subplot(4,5,7);
        pcolor(F./1e6,h,ion2_clean);
        shading flat;
        colormap(gca, jet);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(2)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % plot channel 3
        subplot(4,5,8);
        pcolor(F./1e6,h,ion3_clean);
        shading flat;
        colormap(gca, jet);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(3)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % plot channel 4
        subplot(4,5,9);
        pcolor(F./1e6,h,ion4_clean);
        shading flat;
        colormap(gca, jet);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s (%02ddB, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDir(antOrder(4)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'dB');

        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot original polarization ionograms
 
        % plot channel 12
        subplot(4,5,11);
        pcolor(F./1e6,h,dPh12*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % plot channel 23
        subplot(4,5,13);
        pcolor(F./1e6,h,dPh23*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % plot channel 34
        subplot(4,5,12);
        pcolor(F./1e6,h,dPh34*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % plot channel 41
        subplot(4,5,14);
        pcolor(F./1e6,h,dPh41*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol orig)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plot filtered polarization ionograms

        % plot channel 12
        subplot(4,5,16);
        pcolor(F./1e6,h,dPh12f*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % plot channel 23
        subplot(4,5,18);
        pcolor(F./1e6,h,dPh23f*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % plot channel 34
        subplot(4,5,17);
        pcolor(F./1e6,h,dPh34f*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        % plot channel 41
        subplot(4,5,19);
        pcolor(F./1e6,h,dPh41f*180/pi);
        shading flat;
        colormap(gca, PionCmap);
        hold on;
        plot(ScaleV(:,1),ScaleV(:,2), 'k', 'LineWidth', 1);
        plot(ScaleR(:,1),ScaleR(:,2), 'k--', 'LineWidth', 1);
        hold off;
        set(gca, 'XScale', 'log');
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02dUT, %s%s (%02ddB, pol fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
        ylabel('Virtual height, km');
        xlabel('Sounding frequency, MHz');
        xticks([1 2 3 4 5 6 7 8 9 10 12 15 19]);
        cb = colorbar('vert');
        title(cb,'POL');

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Plotting filtered Phase distributions

        % plot channel 1-2 Phase diagram 
        subplot(4,5,5);
        histogram(vec_no_nan12f*180/pi,-180:DPh:180, 'Normalization', 'probability');
        hold on
        plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
        hold off
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (%02d, fltr)',...
               DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
               AntDirChar(antOrder(2)+1),AntDirChar(antOrder(1)+1),dBthr));
        ylim([0, 0.25]);
        xlim([-180, 180]);
        xticks([-180 -135 -90 -45 0 45 90 135 180]);
        grid on;

        % plot channel 2-3 Phase diagram 
        subplot(4,5,15);
        histogram(vec_no_nan23f*180/pi,-180:DPh:180, 'Normalization', 'probability');
        hold on
        plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
        hold off
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (%02d, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
            AntDirChar(antOrder(3)+1),AntDirChar(antOrder(2)+1),dBthr));
        ylim([0, 0.25]);
        xlim([-180, 180]);
        xticks([-180 -135 -90 -45 0 45 90 135 180]);
        grid on;

        % plot channel 3-4 Phase diagram 
        subplot(4,5,10);
        histogram(vec_no_nan34f*180/pi,-180:DPh:180, 'Normalization', 'probability');
        hold on
        plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
        hold off
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (%02d, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
            AntDirChar(antOrder(4)+1),AntDirChar(antOrder(3)+1),dBthr));
        ylim([0, 0.25]);
        xlim([-180, 180]);
        xticks([-180 -135 -90 -45 0 45 90 135 180]);
        grid on;

        % plot channel 4-1 Phase diagram 
        subplot(4,5,20);
        histogram(vec_no_nan41f*180/pi,-180:DPh:180, 'Normalization', 'probability');
        hold on
        plot([-90 -90 0 90 90],[0 0.25 NaN 0 0.25],'LineWidth',2,'LineStyle',':');
        hold off
        title(sprintf('%04d/%02d/%02d %02d:%02d:%02d UT, %s%s, (%02d, fltr)',...
            DT(1),DT(2),DT(3),DT(4),DT(5),DT(6),...
            AntDirChar(antOrder(1)+1),AntDirChar(antOrder(4)+1),dBthr));
        ylim([0, 0.25]);
        xlim([-180, 180]);
        xticks([-180 -135 -90 -45 0 45 90 135 180]);
        grid on;

        % Export the figure with to PNG
        % Out PNG using rendering
        set(hFig, 'PaperPositionMode', 'auto');
        print(hFig, outFullPathIonA, '-dpng', '-r150');

        % % Out PNG as a screenshot
        % % Force all graphics rendering to complete before taking the snapshot
        % drawnow; 
        % % Capture the pixels directly from the figure window buffer
        % frame = getframe(hFig);
        % % Save the captured pixel matrix to a PNG file without re-rendering
        % imwrite(frame.cdata, outFullPathIonA);    

        fprintf('Saved image: %s (%05d of %05d)\n', outFileNameIonA, i, NmatF);

end

% Successful data processing
disp('All files have been successfully processed and saved.');

% Calculate and show running time
toc;