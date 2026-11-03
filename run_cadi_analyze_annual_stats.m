outBaseDir = 'N:/cadi_out_test/';
sStation = 'RB'; 
targetYear = 2008;

diaryFile = fullfile(outBaseDir, sprintf('CADI_Stats_%s_%d.log', sStation, targetYear));
diary(diaryFile);
diary on;

summaryData = cadi_analyze_annual_stats(outBaseDir, sStation, targetYear);

diary off;