% Set path & file names
files_2009 = {
    'N:\cadi_out_test\CADI_Summary_RB_2009_6ch.mat', ...   % base (black)
    'N:\cadi_out_test_1ch\CADI_Summary_RB_2009_1ch.mat'    % to compare (red)
    % to add in the future 3-CH: 'N:\cadi_out_3ch\CADI_Summary_RB_2009_3ch.mat'
    };

labels = {'6-CH', '1-CH'}; % Labels
outDir = 'N:\cadi_out_comparison\2009\';

% Запуск
cadi_compare_models_annual(files_2009, labels, outDir, 'RB', '2009');