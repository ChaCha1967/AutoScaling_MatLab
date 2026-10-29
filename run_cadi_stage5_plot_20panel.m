outBaseDir = 'n:\cadi_out_test';
sStation = 'RB';
startDT = [2008, 01, 01, 00, 00, 00];
endDT = [2008, 01, 02, 00, 00, 00];

opts = struct();
opts.visible   = 'on'; % Set 'on' if you want to watch panels rendering live
opts.overwrite = true;
opts.suffix    = '_ion_avr.png';

report5 = cadi_stage5_plot_20panel(outBaseDir, sStation, startDT, endDT, opts);