% Calculate custom colormap
customCmap = CustomColormap;

% Plot test data (replace this with your actual plot/pcolor/imagesc function)
imagesc([-180, 180]); % Test strip of values from -180 to 180

% Apply the created custom colormap to the current figure
colormap(customCmap);

% CRITICALLY IMPORTANT: strictly bind the colormap edges to your specific range!
% If you are using a MATLAB version older than R2022a, use caxis([-180, 180]); instead
clim([-180, 180]); 

% Display the colorbar on the side to verify the correct color mapping
colorbar;