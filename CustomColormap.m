% Create custom colormap for polarization ionograms

function customCmap = CustomColormap()

    % 1. Define the phase nodal points (in degrees)
    % We use a micro-offset near zero (-0.001 and 0.001) to create a sharp color transition
    nodes = [-180, -90, -0.001, 0.001, 90, 180];
    
    % 2. Define colors for each nodal point in RGB format [R, G, B] (from 0 to 1)
    palePink = [1.00, 0.75, 0.80]; 
    darkRed  = [0.60, 0.00, 0.00]; 
    paleBlue = [0.75, 0.85, 1.00]; 
    darkBlue = [0.00, 0.00, 0.60]; 
    
    % Matrix of reference colors corresponding to the nodal points
    nodeColors = [
        palePink; % -180
        darkRed;  % -90
        palePink; % -0.001 (just before 0)
        paleBlue; %  0.001 (right after 0)
        darkBlue; % +90
        paleBlue  % +180
        ];
    
    % 3. Create a 256-level scale (standard colormap size)
    xq = linspace(-180, 180, 256);
    
    % 4. Calculate smooth transitions between the reference points using interpolation
    customCmap = interp1(nodes, nodeColors, xq);

end