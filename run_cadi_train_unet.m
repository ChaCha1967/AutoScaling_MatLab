% [trainedNet, trainInfo, splitData] = cadi_train_unet('N:\cadi_synced_out');

% Starting the training of a 3-channel network on filtered data
dataset_dir = 'N:\cadi_synced_out';
model_out   = 'N:\cadi_synced_out\3ch_mixed';
strategy    = '3ch_mixed';

[trainedNet, trainInfo, splitData] = cadi_train_unet(dataset_dir, model_out, strategy);