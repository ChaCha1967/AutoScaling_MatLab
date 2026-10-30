function pipelineReport = cadi_run_pipeline(inBaseDir, outBaseDir, sStation, startDT, endDT, runStages, stageOpts)
% CADI_RUN_PIPELINE Master wrapper script to execute all stages of the CADI 
% processing, inversion, and visualization pipeline sequentially with English logging.
%
% Stage 5 Plot Variants (stageOpts.stage5.plotVariant):
%   - 'new' / 'avt' / 'tensor' / 2  : Calls cadi_stage5_plot (default suffix: '_ion_avt.png')
%   - 'old' / 'avr' / '20panel' / 1 : Calls cadi_stage5_plot_20panel (default suffix: '_ion_avr.png')
%   - 'both' / 3                    : Calls both Stage 5 plotting scripts sequentially

if nargin < 6 || isempty(runStages), runStages = [1, 2, 3, 4, 5]; end
if nargin < 7 || isempty(stageOpts), stageOpts = struct(); end

fprintf('============================================================\n');
fprintf('   CADI AUTOMATED PROCESSING PIPELINE START                 \n');
fprintf('============================================================\n');
fprintf('Station    : %s\n', sStation);
fprintf('Time Range : %s to %s\n', datestr(datetime(startDT(1:6))), datestr(datetime(endDT(1:6))));
fprintf('Stages     : %s\n', num2str(runStages));

pipelineTimer = tic;
pipelineReport = struct();

ifismember = @(arr, val) any(arr == val);

% Stage 1: MD2 Unpacking & Raw Data Extraction
if ifismember(runStages, 1)
    opts1 = getFieldOrDefault(stageOpts, 'stage1', struct());
    pipelineReport.stage1 = cadi_stage1_md2_to_mat(inBaseDir, outBaseDir, sStation, startDT, endDT, opts1);
end

% Stage 2: Interference Filtering & Tensor Construction
if ifismember(runStages, 2)
    opts2 = getFieldOrDefault(stageOpts, 'stage2', struct());
    pipelineReport.stage2 = cadi_stage2_filter_and_tensors(outBaseDir, sStation, startDT, endDT, opts2);
end

% Stage 3: U-Net Inference & Virtual Profile Extraction
if ifismember(runStages, 3)
    opts3 = getFieldOrDefault(stageOpts, 'stage3', struct());
    pipelineReport.stage3 = cadi_stage3_unet_virtual_profile(outBaseDir, sStation, startDT, endDT, opts3);
end

% Stage 4: POLAN Real-Height Profile Inversion
if ifismember(runStages, 4)
    opts4 = getFieldOrDefault(stageOpts, 'stage4', struct());
    pipelineReport.stage4 = cadi_stage4_polan_inversion(outBaseDir, sStation, startDT, endDT, opts4);
end

% Stage 5: 20-Panel Diagnostic Plot Export (Selectable Variant)
if ifismember(runStages, 5)
    opts5 = getFieldOrDefault(stageOpts, 'stage5', struct());
    plotVariant = getFieldOrDefault(opts5, 'plotVariant', 'new');

    if isnumeric(plotVariant)
        if plotVariant == 1
            variantStr = 'old';
        elseif plotVariant == 3
            variantStr = 'both';
        else
            variantStr = 'new';
        end
    else
        variantStr = lower(char(plotVariant));
    end

    switch variantStr
        case {'old', 'avr', '20panel'}
            if ~isfield(opts5, 'suffix') || isempty(opts5.suffix)
                opts5.suffix = '_ion_avr.png';
            end
            pipelineReport.stage5 = cadi_stage5_plot_20panel(outBaseDir, sStation, startDT, endDT, opts5);

        case {'new', 'avt', 'tensor'}
            if ~isfield(opts5, 'suffix') || isempty(opts5.suffix)
                opts5.suffix = '_ion_avt.png';
            end
            pipelineReport.stage5 = cadi_stage5_plot(outBaseDir, sStation, startDT, endDT, opts5);

        case 'both'
            opts5_old = opts5;
            opts5_old.suffix = '_ion_avr.png';
            repOld = cadi_stage5_plot_20panel(outBaseDir, sStation, startDT, endDT, opts5_old);

            opts5_new = opts5;
            opts5_new.suffix = '_ion_avt.png';
            repNew = cadi_stage5_plot(outBaseDir, sStation, startDT, endDT, opts5_new);

            pipelineReport.stage5 = repNew;
            pipelineReport.stage5_old = repOld;
            pipelineReport.stage5_new = repNew;
            pipelineReport.stage5.processedCount = repOld.processedCount + repNew.processedCount;

        otherwise
            error('Unknown Stage 5 plotVariant: %s. Use ''new'' (''avt''), ''old'' (''avr''), or ''both''.', variantStr);
    end
end

totalElapsed = toc(pipelineTimer);
pipelineReport.totalElapsedTimeSec = totalElapsed;

fprintf('\n============================================================\n');
fprintf('   CADI AUTOMATED PIPELINE COMPLETED SUCCESSFULLY           \n');
fprintf('   Total Execution Time : %.2f seconds                      \n', totalElapsed);
fprintf('============================================================\n');
end

function val = getFieldOrDefault(structObj, fieldName, defaultVal)
if isfield(structObj, fieldName) && ~isempty(structObj.(fieldName))
    val = structObj.(fieldName);
else
    val = defaultVal;
end
end