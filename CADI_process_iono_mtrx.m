% Script for reading and plotting ionogram using CADI data (*.md2 file)
% extracting all ionograms existed in md2 file as a structure 
% and in addition prepare matrices for selected ionograms 
% contained in in md2 file file

% Input parameters
sDataPathBase = 'n:\cadi_synced\';
sStation = 'HA';
Year = 2009;
Month = 07;
Date = 24;
Hour = 05;
sFileType = 'md2';
OutYN = 0;

SNRthr = 10;
dHeight = [90 510];

% [headerStruct, recordsStruct] = CADI_data_reader(ssSite,Year,Month,Day,Hour,'md1'); % not save data to file
time_min = [0 5 10 15 20 25 30 35 40 45 50 55]; % which ionogram save in *.mat
tic;
[headerStruct, recordsStruct, siteStruct] = CADI_data_iono_reader_mtrx(sDataPathBase,sStation,Year,Month,Date,Hour,sFileType,OutYN,time_min);
toc;