% run stage2 filter and tensor

outBaseDir = 'n:\cadi_out_test';
sStation = 'RB';
startDT = [2008, 01, 01, 00, 00, 00];
endDT = [2008, 01, 02, 00, 00, 00];
opts = struct();
opts.spike_thresh_dB = 2;    
opts.min_extent = 35;        
opts.min_count = 10;         
opts.dBthr = 3;              
opts.required_antennas = 3;  
opts.overwrite = true;       

statusReport = cadi_stage2_filter_and_tensors(outBaseDir, sStation, startDT, endDT, opts);