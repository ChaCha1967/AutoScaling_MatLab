function [trainedNet, trainInfo, splitData] = cadi_train_unet(dataset_dir, model_out_path, strategy)
% CADI_TRAIN_UNET Trains a U-Net deep learning model in MATLAB R2026b using trainnet
% for ionogram O-mode trace segmentation.
%
% Inputs:
%   dataset_dir    : Root directory containing processed *.mat (filtered) and *o.mat (noisy) files
%   model_out_path : Full path to save the trained model .mat file (optional)
%   strategy       : Training mode string (default: '6ch_combined'):
%                    - '6ch_combined'      : [192x96x6] tensor combining filtered (Ch 1-3) + noisy (Ch 4-6)
%                    - '3ch_two_stage'     : [192x96x3] Phase 1 on mixed, Phase 2 fine-tuning on noisy (*o.mat)
%                    - '3ch_mixed'         : [192x96x3] trained on mixed filtered + noisy files
%                    - '3ch_noisy_only'    : [192x96x3] trained strictly on noisy (*o.mat) files
%                    - '3ch_filtered_only' : [192x96x3] trained strictly on filtered (*.mat) files
%
% Outputs:
%   trainedNet     : Trained dlnetwork object
%   trainInfo      : Training history structure returned by trainnet
%   splitData      : Structure containing train, val, and test file lists

    % 1. Handle default input arguments
    if nargin < 1 || isempty(dataset_dir)
        dataset_dir = uigetdir(pwd, 'Select Root Folder with Processed CADI Dataset (.mat)');
        if isequal(dataset_dir, 0)
            error('Dataset directory selection cancelled.');
        end
    end
    if nargin < 3 || isempty(strategy)
        strategy = '6ch_combined';
    end
    if nargin < 2 || isempty(model_out_path)
        model_out_path = fullfile(dataset_dir, ['cadi_unet_', lower(strategy), '.mat']);
    end

    fprintf('============================================================\n');
    fprintf('   CADI U-NET TRAINING PIPELINE (MATLAB R2026b / trainnet)  \n');
    fprintf('============================================================\n');
    fprintf('Dataset root : %s\n', dataset_dir);
    fprintf('Strategy     : %s\n', strategy);

    % 2. Scan directory and pair filtered (*.mat) and noisy (*o.mat) files by session
    all_mat = dir(fullfile(dataset_dir, '**', '*.mat'));
    
    % Exclude raw files and previously saved model files
    is_excluded = endsWith({all_mat.name}, {'_ion.mat', '_pol.mat'}, 'IgnoreCase', true) | ...
                  startsWith({all_mat.name}, 'cadi_unet_', 'IgnoreCase', true);
    all_mat = all_mat(~is_excluded);

    is_noisy = endsWith({all_mat.name}, 'o.mat', 'IgnoreCase', false);
    filt_struct  = all_mat(~is_noisy);
    noisy_struct = all_mat(is_noisy);

    % Build lookup map for noisy files to pair them with filtered files
    noisy_map = containers.Map('KeyType', 'char', 'ValueType', 'char');
    for k = 1:numel(noisy_struct)
        [~, bname, ~] = fileparts(noisy_struct(k).name);
        session_key = fullfile(noisy_struct(k).folder, bname(1:end-1)); % Strip trailing 'o'
        noisy_map(session_key) = fullfile(noisy_struct(k).folder, noisy_struct(k).name);
    end

    paired_filt  = {};
    paired_noisy = {};
    for k = 1:numel(filt_struct)
        [~, bname, ~] = fileparts(filt_struct(k).name);
        session_key = fullfile(filt_struct(k).folder, bname);
        if isKey(noisy_map, session_key)
            paired_filt{end+1, 1}  = fullfile(filt_struct(k).folder, filt_struct(k).name); %#ok<AGROW>
            paired_noisy{end+1, 1} = noisy_map(session_key); %#ok<AGROW>
        end
    end

    num_sessions = numel(paired_filt);
    if num_sessions == 0 && strcmpi(strategy, '6ch_combined')
        error('No paired filtered (*.mat) and noisy (*o.mat) files found for 6-channel mode.');
    end
    fprintf('Total paired sessions found: %d\n', num_sessions);

    % 3. Reproducible Train (80%) / Validation (10%) / Test (10%) Split by Session
    rng(42, 'twister');
    perm_idx = randperm(num_sessions);
    
    n_train = round(0.80 * num_sessions);
    n_val   = round(0.10 * num_sessions);
    
    idx_train = perm_idx(1 : n_train);
    idx_val   = perm_idx(n_train + 1 : n_train + n_val);
    idx_test  = perm_idx(n_train + n_val + 1 : end);

    splitData = struct();
    splitData.strategy   = strategy;
    splitData.train_filt = paired_filt(idx_train);
    splitData.train_orig = paired_noisy(idx_train);
    splitData.val_filt   = paired_filt(idx_val);
    splitData.val_orig   = paired_noisy(idx_val);
    splitData.test_filt  = paired_filt(idx_test);
    splitData.test_orig  = paired_noisy(idx_test);

    fprintf('Session split: Train = %d | Val = %d | Test = %d\n', ...
        numel(idx_train), numel(idx_val), numel(idx_test));

    % 4. Construct U-Net Architecture (192x96x6 or 192x96x3)
    if strcmpi(strategy, '6ch_combined')
        num_channels = 6;
    else
        num_channels = 3;
    end
    
    input_size = [192, 96, num_channels];
    net_untrained = build_cadi_unet(input_size);

    % 5. Configure Datastores and Execute Training According to Strategy
    mini_batch_size = 32;

    switch lower(strategy)
        case '6ch_combined'
            % Build 6-channel datastores (reads both .mat and o.mat on the fly)
            dsTrain = fileDatastore(splitData.train_filt, 'ReadFcn', @read_pair_6ch);
            dsVal   = fileDatastore(splitData.val_filt,   'ReadFcn', @read_pair_6ch);

            val_freq = max(10, floor(numel(splitData.train_filt) / mini_batch_size));
            options = get_training_options(dsVal, 40, 1e-3, mini_batch_size, val_freq);

            fprintf('Starting 6-Channel U-Net training [192 x 96 x 6]...\n');
            [trainedNet, trainInfo] = trainnet(dsTrain, net_untrained, @dice_bce_loss, options);

        case '3ch_two_stage'
            % Phase 1: Train on mixed (filtered + noisy), Validate on noisy
            mixed_train_files = [splitData.train_filt; splitData.train_orig];
            mixed_train_files = mixed_train_files(randperm(numel(mixed_train_files)));
            
            dsTrain_P1 = fileDatastore(mixed_train_files,    'ReadFcn', @read_single_3ch);
            dsVal      = fileDatastore(splitData.val_orig,   'ReadFcn', @read_single_3ch);

            val_freq_p1 = max(10, floor(numel(mixed_train_files) / mini_batch_size));
            opts_P1 = get_training_options(dsVal, 25, 1e-3, mini_batch_size, val_freq_p1);

            fprintf('--- Phase 1: Pre-training on Mixed Filtered + Noisy Data ---\n');
            [net_P1, info_P1] = trainnet(dsTrain_P1, net_untrained, @dice_bce_loss, opts_P1);

            % Phase 2: Fine-tune strictly on noisy (*o.mat) with lower learning rate
            dsTrain_P2 = fileDatastore(splitData.train_orig, 'ReadFcn', @read_single_3ch);
            val_freq_p2 = max(10, floor(numel(splitData.train_orig) / mini_batch_size));
            opts_P2 = get_training_options(dsVal, 15, 1e-4, mini_batch_size, val_freq_p2);

            fprintf('--- Phase 2: Fine-tuning strictly on Unfiltered Noisy Data (*o.mat) ---\n');
            [trainedNet, info_P2] = trainnet(dsTrain_P2, net_P1, @dice_bce_loss, opts_P2);
            trainInfo = struct('Phase1', info_P1, 'Phase2', info_P2);

        case '3ch_mixed'
            mixed_train_files = [splitData.train_filt; splitData.train_orig];
            mixed_train_files = mixed_train_files(randperm(numel(mixed_train_files)));
            
            dsTrain = fileDatastore(mixed_train_files,  'ReadFcn', @read_single_3ch);
            dsVal   = fileDatastore(splitData.val_orig, 'ReadFcn', @read_single_3ch);

            val_freq = max(10, floor(numel(mixed_train_files) / mini_batch_size));
            options = get_training_options(dsVal, 35, 1e-3, mini_batch_size, val_freq);

            [trainedNet, trainInfo] = trainnet(dsTrain, net_untrained, @dice_bce_loss, options);

        case '3ch_noisy_only'
            dsTrain = fileDatastore(splitData.train_orig, 'ReadFcn', @read_single_3ch);
            dsVal   = fileDatastore(splitData.val_orig,   'ReadFcn', @read_single_3ch);

            val_freq = max(10, floor(numel(splitData.train_orig) / mini_batch_size));
            options = get_training_options(dsVal, 40, 1e-3, mini_batch_size, val_freq);

            [trainedNet, trainInfo] = trainnet(dsTrain, net_untrained, @dice_bce_loss, options);

        case '3ch_filtered_only'
            dsTrain = fileDatastore(splitData.train_filt, 'ReadFcn', @read_single_3ch);
            dsVal   = fileDatastore(splitData.val_filt,   'ReadFcn', @read_single_3ch);

            val_freq = max(10, floor(numel(splitData.train_filt) / mini_batch_size));
            options = get_training_options(dsVal, 40, 1e-3, mini_batch_size, val_freq);

            [trainedNet, trainInfo] = trainnet(dsTrain, net_untrained, @dice_bce_loss, options);

        otherwise
            error('Unknown training strategy: %s', strategy);
    end

    % 6. Save trained network, training history, and test split metadata
    save(model_out_path, 'trainedNet', 'trainInfo', 'splitData', 'strategy', 'input_size', '-v7.3');
    fprintf('============================================================\n');
    fprintf('Training complete! Saved trained model to:\n  %s\n', model_out_path);
    fprintf('============================================================\n');
end

% =========================================================================
% ARCHITECTURE BUILDER (MATLAB R2026b dlnetwork)
% =========================================================================

function net = build_cadi_unet(input_size)
% BUILD_CADI_UNET Generates a U-Net dlnetwork with unnormalized input [192x96xC]
% and a single-channel sigmoid probability output [192x96x1].

    % Generate base U-Net graph (EncoderDepth = 4 -> bottleneck is 12x6)
    lgraph = unetLayers(input_size, 2, 'EncoderDepth', 4);

    % 1. Disable internal input normalization since X_tensor is already scaled to [0, 1]
    in_layer = imageInputLayer(input_size, 'Normalization', 'none', 'Name', 'input_tensor');
    lgraph = replaceLayer(lgraph, lgraph.Layers(1).Name, in_layer);

    % 2. Replace final 2-class softmax/classification layers with 1-channel conv + sigmoid
    % Find the final 1x1 convolution layer before Softmax
    layer_names = {lgraph.Layers.Name};
    
    % Remove pixelClassificationLayer if present
    for k = numel(lgraph.Layers):-1:1
        if isa(lgraph.Layers(k), 'nnet.cnn.layer.PixelClassificationLayer') || ...
           contains(lower(class(lgraph.Layers(k))), 'classification')
            lgraph = removeLayers(lgraph, lgraph.Layers(k).Name);
        end
    end

    % Locate Softmax layer and its preceding 1x1 Final Convolution layer
    softmax_idx = find(arrayfun(@(l) isa(l, 'nnet.cnn.layer.SoftmaxLayer'), lgraph.Layers), 1, 'last');
    if ~isempty(softmax_idx)
        softmax_name = lgraph.Layers(softmax_idx).Name;
        % Find the layer connected into softmax
        conn_idx = strcmp(lgraph.Connections.Destination, softmax_name);
        final_conv_name = lgraph.Connections.Source{conn_idx};
        
        % Replace 2-filter 1x1 conv with 1-filter 1x1 conv
        new_final_conv = convolution2dLayer(1, 1, 'Name', 'Final-Conv-1Ch', 'Padding', 'same');
        lgraph = replaceLayer(lgraph, final_conv_name, new_final_conv);
        
        % Replace Softmax with Sigmoid activation for binary probability map in [0, 1]
        sig_layer = sigmoidLayer('Name', ' sigmoid_out');
        lgraph = replaceLayer(lgraph, softmax_name, sig_layer);
    end

    % Convert layerGraph to modern dlnetwork object for trainnet
    net = dlnetwork(lgraph);
end

% =========================================================================
% DATASTORE READ FUNCTIONS
% =========================================================================

function data = read_pair_6ch(filt_filepath)
% READ_PAIR_6CH Loads filtered (*.mat) and corresponding noisy (*o.mat) files,
% concatenating them along the 3rd dimension into a [192 x 96 x 6] single tensor.

    [f_dir, base_name, ext] = fileparts(filt_filepath);
    noisy_filepath = fullfile(f_dir, [base_name, 'o', ext]);

    d_filt  = load(filt_filepath,  'X_tensor', 'Y_mask');
    d_noisy = load(noisy_filepath, 'X_tensor');

    % Concatenate: Channels 1-3 = Filtered, Channels 4-6 = Unfiltered Noisy
    X_6ch = cat(3, single(d_filt.X_tensor), single(d_noisy.X_tensor));
    
    % Convert logical mask [192x96] to single [192x96x1] for loss computation
    Y_single = single(d_filt.Y_mask > 0);
    
    data = {X_6ch, Y_single};
end

function data = read_single_3ch(filepath)
% READ_SINGLE_3CH Loads a single 3-channel tensor [192 x 96 x 3] and mask [192 x 96 x 1].

    d = load(filepath, 'X_tensor', 'Y_mask');
    X_3ch    = single(d.X_tensor);
    Y_single = single(d.Y_mask > 0);
    
    data = {X_3ch, Y_single};
end

% =========================================================================
% CUSTOM COMBINED LOSS FUNCTION (DICE + BINARY CROSS-ENTROPY)
% =========================================================================

function loss = dice_bce_loss(Y_pred, Y_true)
% DICE_BCE_LOSS Computes 0.5 * SoftDiceLoss + 0.5 * BinaryCrossEntropyLoss
% for severe foreground/background class imbalance (~1.5% trace vs 98.5% background).

    smooth_eps = 1e-5;
    
    % Clamp predictions slightly away from 0 and 1 for numerical stability in log()
    Y_pred_clamped = min(max(Y_pred, 1e-6), 1 - 1e-6);

    % 1. Binary Cross-Entropy Loss (averaged over all pixels and batch)
    bce_map  = -(Y_true .* log(Y_pred_clamped) + (1 - Y_true) .* log(1 - Y_pred_clamped));
    bce_loss = mean(bce_map, 'all');

    % 2. Soft Dice Loss (computed per sample across spatial dimensions 1 & 2, then averaged over batch)
    intersection = sum(Y_pred .* Y_true, [1, 2]);
    union_sum    = sum(Y_pred, [1, 2]) + sum(Y_true, [1, 2]);
    dice_score   = (2 .* intersection + smooth_eps) ./ (union_sum + smooth_eps);
    dice_loss    = mean(1 - dice_score, 'all');

    % Combined balanced loss
    loss = 0.5 * dice_loss + 0.5 * bce_loss;
end

% =========================================================================
% TRAINING OPTIONS HELPER
% =========================================================================

function options = get_training_options(dsVal, max_epochs, init_lr, batch_size, val_freq)
% GET_TRAINING_OPTIONS Configures trainingOptions for trainnet in MATLAB R2026b.

    options = trainingOptions('adam', ...
        'InitialLearnRate', init_lr, ...
        'LearnRateSchedule', 'piecewise', ...
        'LearnRateDropPeriod', max(5, floor(max_epochs * 0.5)), ...
        'LearnRateDropFactor', 0.2, ...
        'MaxEpochs', max_epochs, ...
        'MiniBatchSize', batch_size, ...
        'Shuffle', 'every-epoch', ...
        'ValidationData', dsVal, ...
        'ValidationFrequency', val_freq, ...
        'ValidationPatience', 8, ...  % Auto-stop if validation loss doesn't improve for 8 checks  
        'OutputNetwork', 'best-validation-loss', ...
        'ExecutionEnvironment', 'gpu', ... % 'ExecutionEnvironment', 'auto', ...
        'DispatchInBackground', true, ... % Asynchronous CPU batch prefetching
        'Plots', 'training-progress', ...
        'Verbose', true);
end