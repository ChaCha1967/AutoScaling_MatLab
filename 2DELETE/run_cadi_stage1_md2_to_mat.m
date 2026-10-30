% run stage1: md2 to mat

inBaseDir = 'n:\cadi';
outBaseDir = 'n:\cadi_out_test';
sStation = 'RB';
startDT = [2008, 01, 01, 00, 00, 00];
endDT = [2008, 01, 02, 00, 00, 00];
opts = struct();
opts.sFileType = 'md2';
opts.minuteStep = 5;
opts.OutYN = 0;

statusReport = cadi_stage1_md2_to_mat(inBaseDir, outBaseDir, sStation, startDT, endDT, opts);