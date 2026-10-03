% CADI Data Reader              
% extracting all ionograms existed in md2 file as a structure 
% and in addition prepare matrices for selected ionograms 
% contained in in md2 file file


% Input parameters
% sDataPathBase - data path prefix (like "d:\cadi_synced\")
% sStation - name of the Station (2 chars) 'HA' - Hall Beach
% Year - 4 digits
% Month
% Date
% Hour
% sFileType ('md2' - iono predefined type, 'md2' - iono additional type)
% OutYN - 1 - save mat file 2 - not save mat file
% time_min() - array of minutes for ionogram's matrixes to be extracted 
%  
%
% Output Parameters
% headerStruct - header of the data file
% recordsStruct - records with DFS & IQ data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WARNING: In IDL array indexes start from 0, In MatLab array indexes start from 0   !!!!!!
% So ALL MatLab_index = IDL_index+1  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
% (binDFS), (hnum)
% IN SITE CONFIGURATION WE HAVE FOR ANTENNAS
% (0 1 2 3) -> E W N S
% WE HAVE CONVERT TO (S E N W) -> (3 0 2 1)
% WORKS WITH STANDARD CADI VIRTUAL HEIGHT INTERVAL 0-510 KM 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [headerStruct, recordsStruct, siteStruct] = CADI_data_iono_reader_mtrx(sDataPathBase,sStation,Year,Month,Date,Hour,sFileType,OutYN,time_min)

% Initialize time accumulators at the very beginning of the function
total_processing_time = 0;
total_saving_time = 0;
% Start the processing timer before entering the main loop
proc_timer = tic;

sYear = sprintf('%04d',Year);
sMonth = sprintf('%02d',Month);
sDate = sprintf('%02d',Date);
sHour = sprintf('%02d',Hour);

% Show number of arguments
% fprintf('Nuber of arguments: %d\n',nargin);

% Inital parmeters
% ftp_string = 'ftp.chain-project.net'; % ftp link
sM = 'ABCDEFGHIJKL'; % char of month
DataFolderLocal = [sDataPathBase,sStation,'\',sYear,'\']; % local folder
FileName = [sYear(4) sM(str2num(sMonth)) sDate sHour '00.' sFileType];
ionoFileName = [sStation sprintf('%01d',Year-2000) sM(str2num(sMonth)) sDate sHour '00_ion.mat'];

% % Open ftp
% s = ftp(ftp_string,'ftp','alex.koloskov@unb.ca');
% % CD to folder
% cd(s,['/cadi/' sStation '/' sYear '/' sYear(3:4) sMonth sDate sStation '/']);
% % set FileName
% FileName = [sYear(4) sM(str2num(sMonth)) sDate sHour '00.' sFileType];
% % download file
% mget(s,[FileName '.gz'],DataFolderLocal);
% % unzip file
% gunzip([DataFolderLocal FileName  '.gz']); 
% % delete gz file
% delete([DataFolderLocal FileName  '.gz']); 

% Initialize structures to store header
headerStruct = struct();
datablockStruct = struct();

% Initialize structures to store records
recordsStruct = struct();
dataStruct = struct();
freqStruct = struct();
heightStruct = struct();
DFSbinStruct = struct();
ReImStruct = struct();

% Open data file and determine its size
% fileID = fopen([DataFolder FileName]);
fileID = fopen([DataFolderLocal,FileName]);
fseek(fileID,0,'eof');
SizeFileInBytes = ftell(fileID);
fseek(fileID,0,'bof');

% Read and set timestamp from header
headerStruct.timestamp = fread(fileID,25,'*char');

% Set my datablock fields
datablockStruct.sStation = sStation; 
datablockStruct.sYear = sYear;
datablockStruct.sMonth = sMonth;
datablockStruct.sDate = sDate; 
datablockStruct.sHour = sHour;
% datablockStruct.ftp_string = ftp_string;
datablockStruct.DataFolderLocal = DataFolderLocal;
datablockStruct.FileName = FileName;
datablockStruct.SizeFileInBytes = SizeFileInBytes;
% Set antenna order for CADI configuration S-E-N-W
datablockStruct.antOrder = [3 0 2 1];
% Read and set datablock fields from header
datablockStruct.filetype = fread(fileID,1,'*char');
datablockStruct.frequ = fread(fileID,1,'*int16');
datablockStruct.length_DFS = fread(fileID,1,'*uint8');
length2DFS = datablockStruct.length_DFS/2;
datablockStruct.height_min = fread(fileID,1,'*int16');
datablockStruct.height_max = fread(fileID,1,'*int16');
datablockStruct.pps = fread(fileID,1,'*uint8');
datablockStruct.p_aver = fread(fileID,1,'*uint8');
datablockStruct.basethreshold100 = fread(fileID,1,'*int16');
datablockStruct.noisethreshold100 = fread(fileID,1,'*int16');
datablockStruct.min_num_DFS = fread(fileID,1,'*uint8');
datablockStruct.sec_between_samples = fread(fileID,1,'*int16');
datablockStruct.gainecontrol = fread(fileID,1,'*char');
datablockStruct.sigprocess = fread(fileID,1,'*char');
datablockStruct.rec_num = fread(fileID,1,'*uint8');
datablockStruct.spairs = fread(fileID,11,'*uint8');
% read and set sounding frequencies values
datablockStruct.FreqS = fread(fileID,datablockStruct.frequ,'*single');
nfreqs = double(datablockStruct.frequ);
% calculate DFS frequencies
length_DFS = double(datablockStruct.length_DFS);
p_aver = double(datablockStruct.p_aver);
pps = double(datablockStruct.pps);
datablockStruct.FreqDFS = linspace(-(length_DFS/2)/(length_DFS*p_aver/pps),(length_DFS/2-1)/(length_DFS*p_aver/pps),length_DFS);
% calculate heights and related parameters
dheight = 3; % MANUALLY ADDON
nheights = double(datablockStruct.height_max)/round(dheight)+1;
datablockStruct.heights = linspace(0,double(datablockStruct.height_max),double(nheights));
datablockStruct.dheight = dheight;
datablockStruct.nheights = nheights;
% add datablock structure with sounding frequencies to header as a field
headerStruct.datablock = datablockStruct;
% set siteStruct
siteStruct = CADI_site_mtrx(datablockStruct.sStation);

% clear separate datablock structure
clear('datablockStruct');

% Start reading record(s) if any

% lEOF = ~feof(fileID);
ind_rec = 1; % initial record number 
hnum = 255; % set flag to last frequency reached
ind_cur_field = 0;
ind_mtrx = 0;
% ind_hnum_eq_30 = 0;

% Allocate memory for one ionogram matrix
ionoIQ = complex(zeros(4, nheights, nfreqs, 'like', 1i));
% Date time
DT(1,1:6) = [Year Month Date Hour 0 0];
% Frequency flags
GainNoise = zeros(3,nfreqs);


% loop for records
while ftell(fileID)<SizeFileInBytes && hnum==255 % continue
% continue while not eof and last frequency were reached in previous record if any

    % add time to record
    recordsStruct(ind_rec).time_min = fread(fileID,1,'*uint8');
    recordsStruct(ind_rec).time_sec = fread(fileID,1,'*uint8');
    if any(double(recordsStruct(ind_rec).time_min) == time_min) % calculate ionogram matrices
       make_iono = 1;
       ind_mtrx = ind_mtrx+1;
       % fill iono data with zerros
       ionoIQ(:) = 0;
       % Set date time for ind_mtr iono
       DT(1,5:6) = [double(recordsStruct(ind_rec).time_min) double(recordsStruct(ind_rec).time_sec)];
       GainNoise(:) = 0;
    else % not calculate ionogram matrices
       make_iono(:) = 0;
    end    

    % add frequency to record
    for j=1:nfreqs %headerStruct.datablock.frequ
    
        ind_height = 1; % set in of heights to 1
        
        % read and set gain/noise flags and averagenoisepower
        recordsStruct(ind_rec).freqStruct(j).gainflag = fread(fileID,1,'*uint8');
        recordsStruct(ind_rec).freqStruct(j).noiseflag = fread(fileID,1,'*uint8');
        recordsStruct(ind_rec).freqStruct(j).averagenoisepower10 = fread(fileID,1,'*uint16');
        % Set flags for ind_mtr iono and frequency
        if make_iono
            GainNoise(:,j) = double([recordsStruct(ind_rec).freqStruct(j).gainflag ...
                                     recordsStruct(ind_rec).freqStruct(j).noiseflag ...
                                     recordsStruct(ind_rec).freqStruct(j).averagenoisepower10]);
        end


        % read hnum if exist
        hnum = fread(fileID,1,'*uint8');  
        % return file position to previous location 
        fseek(fileID,-1,"cof");
        % % if hnum>200
        % %     hnum = hnum-200;
        % % end
        % start adding hegihts data if exist
        if hnum<hex2dec('E0') || hnum>hex2dec('EF')  
            % loop for adding heights
            while (hnum)<nheights %171
                % read hnum
                hnum = fread(fileID,1,'*uint8');
                % % if hnum>200
                % %     hnum = hnum-200;
                % %     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).tnum = fread(fileID,1,'*uint8')+128;
                % % else
                % %     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).tnum = fread(fileID,1,'*uint8');
                % % end
                 
                % set hnum
                recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).hnum = hnum+1;
                % set hnum
                % if hnum == 30
                %     ind_hnum_eq_30 = ind_hnum_eq_30+1
                % end
                % read and set tnum
                recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).tnum = fread(fileID,1,'*uint8');
    
                % read and set binIQ struct(s)
% % % % %                 for k=1:recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).tnum
% % % % % %                    recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).binDFS = fread(fileID,1,'*uint8');
% % % % %                     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %                     % correct for 
% % % % %                     binDFS = fread(fileID,1,'*uint8');
% % % % %                     if binDFS>(length2DFS)
% % % % %                         binDFS = binDFS-length2DFS+1;
% % % % %                     else
% % % % %                         binDFS = binDFS+length2DFS+1;
% % % % %                     end
% % % % %                     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).binDFS = uint8(binDFS);
% % % % %                     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %                     % Current field nimber to compare with IDL will be  removed in the future
% % % % %                     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).ind_cur_field = ind_cur_field;
% % % % %                     ind_cur_field = ind_cur_field+1;
% % % % %                     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %                     % % % % dataReIm =  fread(fileID,2*headerStruct.datablock.rec_num,'*uint8');
% % % % %                     % % % % for n=1:headerStruct.datablock.rec_num
% % % % %                     % % % %     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ReB(n) = dataReIm(1+(n-1)*2);
% % % % %                     % % % %     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ImB(n) = dataReIm(n*2);
% % % % %                     % % % %     IQ = complex(double(dataReIm(1+(n-1)*2))-256*((dataReIm(1+(n-1)*2))>=128),double(dataReIm(n*2))-256*(dataReIm(n*2)>=128));
% % % % %                     % % % %     %%%%%amp = abs(IQ);
% % % % %                     % % % %     %%%%%amp_dB = 20*log10(amp);
% % % % %                     % % % %     % (?) ampN_dB = 20*log10(amp/sqrt(double(recordsStruct(ind_rec).freqStruct(j).averagenoisepower10)/10*double(length2DFS)*2));
% % % % %                     % % % %     ph = angle(IQ);
% % % % %                     % % % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %                     % % % %     if n == 1 % emphirical phase correction for E antenna
% % % % %                     % % % %         ph = ph-pi/2;
% % % % %                     % % % %     end
% % % % %                     % % % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% % % % %                     % % % %     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQ(n) = IQ;
% % % % %                     % % % %     %%%%recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).amp(n) = amp;
% % % % %                     % % % %     %%%%recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).amp_dB(n) = amp_dB;
% % % % %                     % % % %     % (?) recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).amp(n) = ampN_dB;
% % % % %                     % % % %     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ph(n) = ph;
% % % % %                     % % % % end
% % % % %                     %%%%%%%%%%%%%%%%%%% REPLACES by optimized code start
% % % % %                     % Read data directly as 8-bit signed integers (int8)
% % % % %                     dataReIm = fread(fileID, 2 * headerStruct.datablock.rec_num, '*int8');
% % % % % 
% % % % %                     % Vectorized extraction (odd indices - Re, even indices - Im)
% % % % %                     Re_vec = double(dataReIm(1:2:end));
% % % % %                     Im_vec = double(dataReIm(2:2:end));
% % % % % 
% % % % %                     % Instant formation of complex numbers array for all antennas
% % % % %                     IQ_vec = complex(Re_vec, Im_vec);
% % % % % 
% % % % %                     % Vectorized phase calculation for all antennas
% % % % %                     ph_vec = angle(IQ_vec);
% % % % % 
% % % % %                     % Empirical phase correction only for the first antenna E (index 1)
% % % % %                     ph_vec(1) = ph_vec(1) - pi/2;
% % % % % 
% % % % %                     % Bulk write vectors to the data structure
% % % % %                     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ReB = Re_vec.';
% % % % %                     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ImB = Im_vec.';
% % % % %                     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQ = IQ_vec.';
% % % % %                     recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ph = ph_vec.';
% % % % %                     %%%%%%%%%%%%%%%%%%% REPLACES by optimized code finish
% % % % % 
% % % % %                     % set iono mtrx IQ values
% % % % %                     if make_iono
% % % % %                         ionoIQ(:,hnum,j) = recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQ;
% % % % %                     end
% % % % %                     % recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQsenw = ...
% % % % %                     % recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQ([4 1 3 2]);
% % % % %                 end
% % % % %                 ind_height = ind_height+1; % increase heights index
% % % % %                 hnum = fread(fileID,1,'*uint8'); % read next hnum if any
% % % % %                 fseek(fileID,-1,"cof"); % return file position to previous location
% % % % %             end


                % % % % % % % for k=1:recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).tnum
                % % % % % % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % % % % % % %     % correct for 
                % % % % % % %     binDFS = fread(fileID,1,'*uint8');
                % % % % % % %     if binDFS>(length2DFS)
                % % % % % % %         binDFS = binDFS-length2DFS+1;
                % % % % % % %     else
                % % % % % % %         binDFS = binDFS+length2DFS+1;
                % % % % % % %     end
                % % % % % % % 
                % % % % % % %     % OPTIMIZATION 1: Write to the structure only if a consolidated file has been requested.
                % % % % % % %     if OutYN == 1
                % % % % % % %         recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).binDFS = uint8(binDFS);
                % % % % % % %         recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).ind_cur_field = ind_cur_field;
                % % % % % % %     end
                % % % % % % %     ind_cur_field = ind_cur_field+1;
                % % % % % % %     %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % % % % % % % 
                % % % % % % %     %%%%%%%%%%%%%%%%%%% REPLACES by optimized code start
                % % % % % % %     % Read data directly as 8-bit signed integers (int8)
                % % % % % % %     dataReIm = fread(fileID, 2 * headerStruct.datablock.rec_num, '*int8');
                % % % % % % % 
                % % % % % % %     % Vectorized extraction (odd indices - Re, even indices - Im)
                % % % % % % %     Re_vec = double(dataReIm(1:2:end));
                % % % % % % %     Im_vec = double(dataReIm(2:2:end));
                % % % % % % % 
                % % % % % % %     % Instant formation of complex numbers array for all antennas
                % % % % % % %     IQ_vec = complex(Re_vec, Im_vec);
                % % % % % % % 
                % % % % % % %     % Vectorized phase calculation for all antennas
                % % % % % % %     ph_vec = angle(IQ_vec);
                % % % % % % % 
                % % % % % % %     % Empirical phase correction only for the first antenna E (index 1)
                % % % % % % %     ph_vec(1) = ph_vec(1) - pi/2;
                % % % % % % % 
                % % % % % % %     % OPTIMIZATION 2: Write the vectors directly into the ionogram matrix.
                % % % % % % %     if make_iono
                % % % % % % %         ionoIQ(:,hnum,j) = IQ_vec.';
                % % % % % % %     end
                % % % % % % % 
                % % % % % % %     % OPTIMIZATION 3: Collect arrays into a structure only if necessary
                % % % % % % %     if OutYN == 1
                % % % % % % %         recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ReB = Re_vec.';
                % % % % % % %         recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ImB = Im_vec.';
                % % % % % % %         recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQ = IQ_vec.';
                % % % % % % %         recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ph = ph_vec.';
                % % % % % % %     end
                % % % % % % % end


                %%%%%%%%%%%%%%%%%%% REPLACES by optimized code finish
                % read and set binIQ struct(s)
                for k=1:recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).tnum

                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % correct for 
                    binDFS = fread(fileID,1,'*uint8');
                    if binDFS>(length2DFS)
                        binDFS = binDFS-length2DFS+1;
                    else
                        binDFS = binDFS+length2DFS+1;
                    end

                    % ОПТИМИЗАЦИЯ: Записываем DFSbinStruct только если нужен общий файл
                    if OutYN == 1
                        recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).binDFS = uint8(binDFS);
                        recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).DFSbinStruct(k).ind_cur_field = ind_cur_field;
                    end
                    ind_cur_field = ind_cur_field+1;
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

                    %%%%%%%%%%%%%%%%%%% REPLACES by optimized code start
                    % Read data directly as 8-bit signed integers (int8)
                    dataReIm = fread(fileID, 2 * headerStruct.datablock.rec_num, '*int8');

                    % Vectorized extraction (odd indices - Re, even indices - Im)
                    Re_vec = double(dataReIm(1:2:end));
                    Im_vec = double(dataReIm(2:2:end));

                    % Instant formation of complex numbers array for all antennas
                    IQ_vec = complex(Re_vec, Im_vec);

                    % Vectorized phase calculation for all antennas
                    ph_vec = angle(IQ_vec);

                    % Empirical phase correction only for the first antenna E (index 1)
                    ph_vec(1) = ph_vec(1) - pi/2;

                    % OPTIMIZATION: Fill the ionogram matrix immediately (works instantly)
                    if make_iono
                        ionoIQ(:,hnum,j) = IQ_vec.';
                    end

                    % OPTIMIZATION: Generate a heavy structure ONLY if a combined file is ordered.
                    if OutYN == 1
                        recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ReB = Re_vec.';
                        recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ImB = Im_vec.';
                        recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).IQ = IQ_vec.';
                        recordsStruct(ind_rec).freqStruct(j).heightStruct(ind_height).ReImStruct(k).ph = ph_vec.';
                    end
                end                
            % % % % % % %     %%%%%%%%%%%%%%%%%%% REPLACES by optimized code finish
                
                ind_height = ind_height+1; % increase heights index
                hnum = fread(fileID,1,'*uint8'); % read next hnum if any
                fseek(fileID,-1,"cof"); % return file position to previous location
            end                
        end
        
    end
    
    if hnum == 255 % check if last frequency of current record reached
        hnum = fread(fileID,1,'*uint8'); % read last frequency of current record reached if any
        ind_rec = ind_rec+1; % incre se records index 
    end

    % Save iono mtrx file if required
    if make_iono
        % 1. Stop processing timer and accumulate time
        total_processing_time = total_processing_time + toc(proc_timer);
        % 2. Start saving timer
        save_timer = tic;        
        
        % Save individual iono
        ionoFileName(9:10) = sprintf('%02d',DT(5));
        save([DataFolderLocal ionoFileName],'headerStruct','siteStruct','ionoIQ','DT','GainNoise');
        fprintf('Iono file: %s calculated and saved \n',ionoFileName);

        % 3. Stop saving timer and accumulate time
        total_saving_time = total_saving_time + toc(save_timer);
        % 4. Restart processing timer for the next loop iteration
        proc_timer = tic;        
    end

end

% data file close
fclose(fileID);
% delete('c:\cadi\4A011400.md1');
% delete Local File
% delete([DataFolderLocal FileName]);

%%if nargin == 8
    if OutYN == 1
        % Start saving timer for the final hourly file
        save_timer = tic;        % Set out file name and show output to the screen

        ionoFileNameH = [sStation sprintf('%01d',Year-2000) sM(str2num(sMonth)) sDate sHour '_ion.mat'];
        fprintf('Hourly iono file %s calculated and start saving \n', ionoFileNameH);
        % Use fullfile for safe paths
        sOutPathFile = fullfile(DataFolderLocal, ionoFileNameH); 
        % Structure saving
        save(sOutPathFile, 'headerStruct', 'recordsStruct', 'siteStruct');

        % Accumulate final save time
        total_saving_time = total_saving_time + toc(save_timer);    
    end

% close all openrd files
fclose('all');
% clear not used variables
% clear('ans','binIQStruct','DataFolderLocal','ftp_string','s','sYear','sM','sMonth','sDate','sHour','Year','Month','Date','Hour',...
%       'sStation','dataStruct','fileID','FileName','freqStruct','heightStruct','hnum','ind_height','ind_rec','j','k',...
%       'SizeFileInBytes','dataReIm','DFSbinStruct','n','ReImStruct');

% Print the final profiling summary to the console
fprintf('\n--- Execution Profiling Summary ---\n');
fprintf('Total Processing Time : %.3f seconds\n', total_processing_time);
fprintf('Total Saving Time     : %.3f seconds\n', total_saving_time);
fprintf('-----------------------------------\n');
end