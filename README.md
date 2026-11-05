# AutoScaling_MatLab

**README.md**                               This file with description of scripts and functions

**CADI_data_format.txt**                    Description of CADI ionogram format


## ADDITIONAL SCRIPRS

**CADI_site_mtrx.m**                        Returns a structure containing station-specific configuration parameters for CADI ionosonde sites, including geographic coordinates, geophysical constants, antenna polarities, spacings, azimuths, and phase corrections. 

**CustomColormap.m**                        Create custom colormap for polarization ionograms

**parse_polan_file_synced.m**               Parses text-based POLAN output files (.pol), extracts session headers, input virtual heights, peak characteristics (foF2, hmF2), real heights, and calculation coefficients, and saves the structured data into a .mat file.

**sync_cadi_data.m**                        Script to synchronize and extract matching .pol and .md2.gz files Includes hierarchical scanning, dual logging, and a final summary table

**run_cadi_evaluate_model.m**               run cadi_evaluate_model() function

**run_cadi_evaluate_model_profile.m**       run cadi_evaluate_model_profile() function

**run_cadi_train_unet.m**                   run cadi_train_unet() function

**run_cadi_visualize_from_mat.m**           run cadi_visualize_from_mat() function

**run_parse_polan_synced.m**                Batch processes all .pol files in the given directory tree Extracts data to .mat. If plot_flag == 1, also generates and saves PNG plots

**run_pol.m**                               run run_parse_polan_synced() function


## READING & PROCESSING CADI RAW DATA (md2)

**CADI_data_iono_reader_mtrx.m**            Function [CADI Data Reader] for extraction of all ionograms existed in md2 file as a structure and in addition prepare matrices for selected ionograms contained in in md2 file and save extracted data as *_ion.mat file

**CADI_process_iono_mtrx.m**                Script that use CADI_data_iono_reader_mtrx() for reading and plotting ionograms using CADI data (*.md2 file) extracting all ionograms existed in md2 file as a structure and in addition prepare matrices for selected ionograms contained in in md2 file

**CADI_process_iono_mtrx_station_year.m**   Script that use CADI_data_iono_reader_mtrx() for reading and plotting one year of ionograms using CADI data (*.md2 file) extracting all ionograms existed in md2 files  as a structure and in addition prepare matrices for selected ionograms contained in in md2 file

**remove_cadi_interference.m**              Removes vertical noise lines from CADI ionograms. The input M_raw must be the original numerical matrix in dB (no NaNs).

**remove_cadi_interference_v2.m**           Removes solid and dashed vertical noise lines V2 (default function for ionogram filtering)


## PROCESSING CADI DATA TOGETHER WITH DAVIS'S PROFILES from *.pol FILES

**CADI_remove_ion_mat_pol_station_year.m**  Scans a directory to synchronize and clean up data archives by identifying and deleting orphaned/asynchronous .pol and minute .mat files that lack corresponding pairs, ensuring archive integrity.

**update_pol_records_from_text.m**          Scans PolPath for *.pol files, extracts ScaleHt and SlabT, finds paired *_pol.mat files, updates records. Peak to include foF2, hmF2, ScaleHt, SlabT, and saves them back. Failures are logged to pol_update_fail.log in the root of PolPath.

**Plot_CADI_ion_im2PNG.m**                  Batch processes CADI ionosphere data files (*_ion.mat) and files with scaled and real-height (POLAN) ionospheric profiles (*.pol) provided by David and converted to (*_pol.mat), applies multi-antenna interference filtering and phase analysis, saves processed matrices back to files, and exports comprehensive 20-panel diagnostic ionogram plots with profiles as high-resolution PNG images.

**cadi_visualize_from_mat.m**               Batch visualizes unified CADI dataset *.mat files across a directory tree using pre-initialized graphics handles for maximum rendering speed, saving output figures as *.png files alongside the source *.mat files.

**cadi_visualize_from_mat_single.m**        Visualizes generated CADI dataset samples from unified .mat files on a 3-panel professional figure with logarithmic frequency axis, high-contrast modes, full bounding boxes, and enlarged typography.


## POLAN MATLAB CODE PORTED FROM FORTRAN & COMPARE DAVID'S REAL HEIGHT PROFILE WITH MATLAB POLAN CALCULATION

**polan_fortran_exact.m**                   Exact 1-to-1 line-by-line MATLAB translation of Titheridge's Fortran-77 POLAN source files: polan.f, polsin.f, polsub.f, and polmis.f.

**batch_validate_polan.m**                  Performs batch processing, validation, and comparative analysis of ionospheric POLAN inversion results against reference dataset files (`*_pol.mat`).  

* Recursive Search & Organization:  Recursively scans the input directory (`InPath`) for all `*_pol.mat` files, replicating the folder structure in the output directory (`OutPath`).  
* Batch Processing & MATLAB POLAN Execution: Extracts virtual ionospheric heights and reference parameters from each file, runs the MATLAB POLAN exact inversion algorithm, and computes critical parameters ($f_oF2$, $h_mF2$, Scale Height, and Slab Thickness).  
* Comparative Visualization: Utilizes a single reusable figure window to render and export individual verification PNG plots for every session, featuring virtual input traces, reference real heights, MATLAB inversion profiles, and an embedded summary text box.  
* Consolidated Logging: Compiles all valid inversion structures and records into a single consolidated `log.mat` file stored at the root of the output directory.  
* Statistical Evaluation & Metrics: Automatically computes error metrics (MAE and RMSE) for key ionospheric parameters and generates a multi-panel evaluation figure containing error distribution histograms and equal-axis regression scatter plots against reference data.

**cadi_compare_with_david_mat.m**           Performs cross-validation of the CADI automated processing pipeline results against David's reference manual scaling dataset (*_pol.mat files) Computes quantitative error metrics for matched sessions:  

* Bias (mean error / systematic shift)  
* MAE (Mean Absolute Error)  
* RMSE (Root Mean Square Error)  
* R (Pearson correlation coefficient)  

Visualization: Generates a 2x2 panel of regression scatter plots for foF2, hmF2, ScaleHt, and SlabT featuring an ideal 1:1 line, a linear fit line, and computed metrics in the titles, exporting the final figure to a PNG file

**run_cadi_compare_with_david_mat.m**      Run cadi_compare_with_david_mat() with diary logging


## PREPARE DATA FOR TRAINING, TRAINING, EVALUATIONG, VISUALIZING

**process_cadi_pair.m**                     Loads a pair of CADI _ion.mat and _pol.mat files, resamples/pads them to a standardized 3-channel tensor (192x96x3) and binary logical mask (192x96), extracts virtual/real profiles and F2 peak parameters from POLAN records.

**cadi_out_pair2mat.m**                     Batch processes CADI ionogram and polarization files, saving all required tensors, masks, grids, real profiles and peaks into unified .mat files requited for net training purposes

**cadi_train_unet.m**                       Trains a U-Net deep learning model in MATLAB R2026b using trainnet for ionogram O-mode trace segmentation.

**cadi_evaluate_model.m**                   Evaluates the trained U-Net model on the held-out 10% test split (use trained *.mat file)

**cadi_evaluate_model_profile.m**           Evaluates the trained U-Net model on the held-out test split, extracts predicted virtual ionospheric profiles from masks (top, center, or bottom edge), compares them against David's reference virtual profiles (david_pts_virtual), and computes height error metrics (use trained *.mat file).

**cadi_visualize_pair_from_mat.m**          Script to visually inspect generated CADI dataset pairs on a 4-panel figure. Prompts the user to select a tensor file (*_tns3.mat) and automatically finds its companion mask file (*_lbl.png).

## PROCESSING ANY RAW CADI *.md2 FILES (INCLUDING NOT SCALED BY DAVID) USING U-NET TRAINED NETWORK

**cadi_stage1_md2_to_mat**                  Stage 1 of the CADI pipeline: Scans, unzips (.gz to .md2 without deleting), filters by datetime range, and extracts raw ionogram matrices into *_ion.mat files using CADI_data_iono_reader_mtrx.

**cadi_stage2_filter_and_tensors**          Stage 2 of the CADI pipeline: Scans minute *_ion.mat files within the specified datetime range, applies multi-antenna interference filtering, constructs the 17-layer ion_dat matrix, generates standardized U-Net input tensors, and appends them to the files.

**cadi_stage3_unet_virtual_profile**       Stage 3 of the CADI pipeline: Loads the trained U-Net model, runs batched inference on *_ion.mat files, extracts virtual height profile ScaleV_unet and foF2_unet, and appends results.

**cadi_stage4_polan_inversion**            Stage 4 of the CADI pipeline: Loads the U-Net extracted virtual height profile ScaleV_unet, runs Titheridge's POLAN real-height inversion, and appends ScaleR_polan and polanRes.

**cadi_stage5_plot_20panel**               Stage 5 of the CADI pipeline: Generates and exports comprehensive 20-panel diagnostic ionogram plots with overlaid thin black lines for U-Net virtual profiles and POLAN real-height profiles as PNGs.

**cadi_stage5_plot**                       Stage 5 (Variant 2) of the CADI pipeline: Generates and exports to PNG 20-panel diagnostic ionogram plots including cropped U-Net 6-channel tensor visualizations in the 5th column and NE/SW polarization histograms in Row 4 (Cols 1-2).

**cadi_run_pipeline**                      Master wrapper script to execute all stages of the CADI processing, inversion, and visualization pipeline sequentially with English console and file logging in the root of outBaseDir.

**run_cadi_run_pipeline**                  MASTER EXECUTION SCRIPT FOR CADI PROCESSING PIPELINE  This script sets up the paths, station parameters, time windows, and executes the complete 5-stage CADI pipeline using cadi_run_pipelin

## 

