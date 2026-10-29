outBaseDir = 'n:\cadi_out_test';
sStation = 'RB';
startDT = [2008, 01, 01, 00, 00, 00];
endDT = [2008, 01, 02, 00, 00, 00];

opts = struct();
opts.start_val = 0.0;
opts.amode     = 0.0;
opts.valley    = 10.0; % Monotonic (no valley) or 0.0 for standard valley
opts.list_flag = -10;  % Set to 0 if you want to see PEAK printouts in Command Window
opts.overwrite = true;

report4 = cadi_stage4_polan_inversion(outBaseDir, sStation, startDT, endDT, opts);