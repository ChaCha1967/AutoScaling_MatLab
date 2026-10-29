% run stage3 unet & Virtual_profile

outBaseDir = 'n:\cadi_out_test';
sStation = 'RB';
startDT = [2008, 01, 01, 00, 00, 00];
endDT = [2008, 01, 02, 00, 00, 00];
opts = struct();
opts.model_path = 'N:/cadi_out_test/cadi_unet_6ch_combined.mat';
opts.threshold = 0.50;
opts.min_blob_size = 15;
opts.edge_choice = 'center';
opts.batchSize = 64;
opts.overwrite = true;

statusReport = cadi_stage3_unet_virtual_profile(outBaseDir, sStation, startDT, endDT, opts);