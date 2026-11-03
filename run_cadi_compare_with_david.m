pipelineOutDir = 'N:/cadi_out_test/RB/2008';
davidPolDir    = 'N:/cadi_synced/RB/2008_p1_m1_p1_m1/'; % Укажите точный путь к папке с *_pol.mat
outBaseDir     = 'N:/cadi_out_test/';

report = cadi_compare_with_david(pipelineOutDir, davidPolDir, outBaseDir);