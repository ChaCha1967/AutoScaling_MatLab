function [img_vert, f_ob_map, p_ob_map] = cadi_warp_oblique_matrix( ...
    img_ob, f_ob_vec, p_ob_vec, f_vert_grid, h_vert_grid, D_km, mode_str, k_corr, is_half_path)
% CADI_WARP_OBLIQUE_MATRIX Transforms a 2D oblique ionogram matrix (in dB) into
% an equivalent vertical ionogram matrix at the path midpoint using inverse
% coordinate mapping (Breit-Tuve and Martyn's equivalence theorems).
%
% Inputs:
%   img_ob       : [N_p x N_f] 2D matrix of oblique signal intensity (dB)
%   f_ob_vec     : [1 x N_f] frequency vector of the oblique ionogram (MHz)
%   p_ob_vec     : [N_p x 1] group path vector of the oblique ionogram (km)
%   f_vert_grid  : [1 x M_f] target frequency vector for equivalent vertical ionogram (MHz)
%                  (e.g., your standard 96-point CADI f_grid)
%   h_vert_grid  : [M_h x 1] target virtual height vector for vertical ionogram (km)
%                  (e.g., your standard 192-point CADI h_grid, 90 to 550 km)
%   D_km         : Great-circle ground distance between Tx and Rx (km), e.g., 530.0
%   mode_str     : 'spherical' (default) or 'flat'
%   k_corr       : Spherical ionosphere curvature correction factor (default = 1.08)
%   is_half_path : Boolean flag. Set true if p_ob_vec represents half-path R' = P'/2
%                  (like standard vertical height scale), false if total path P' (default = true)
%
% Outputs:
%   img_vert     : [M_h x M_f] transformed equivalent vertical ionogram matrix (dB)
%   f_ob_map     : [M_h x M_f] lookup matrix of oblique frequencies (MHz)
%   p_ob_map     : [M_h x M_f] lookup matrix of oblique group paths (km)

if nargin < 7 || isempty(mode_str),     mode_str = 'spherical'; end
if nargin < 8 || isempty(k_corr),       k_corr = 1.08;          end
if nargin < 9 || isempty(is_half_path), is_half_path = true;    end

R_E = 6371.2; % Mean Earth radius (km)

% Ensure vectors have proper orientation for meshgrid
f_ob_vec    = double(f_ob_vec(:)');
p_ob_vec    = double(p_ob_vec(:));
f_vert_grid = double(f_vert_grid(:)');
h_vert_grid = double(h_vert_grid(:));

% Create 2D target grid (F_V: [M_h x M_f], H_V: [M_h x M_f])
[F_V, H_V] = meshgrid(f_vert_grid, h_vert_grid);

if strcmpi(mode_str, 'flat')
    % -----------------------------------------------------------------
    % 1. FLAT EARTH BACKWARD MAPPING
    % -----------------------------------------------------------------
    % Half group path L = sqrt((D/2)^2 + h'_v^2)
    L_half = sqrt((0.5 * D_km)^2 + H_V.^2);

    % Cosine of incidence angle: cos(phi0) = h'_v / L_half
    cos_phi0 = H_V ./ L_half;

    % Required oblique frequency: f_ob = f_v / cos(phi0)
    f_ob_map = F_V ./ max(1e-4, cos_phi0);
else
    % -----------------------------------------------------------------
    % 2. SPHERICAL EARTH BACKWARD MAPPING
    % -----------------------------------------------------------------
    theta  = D_km / (2.0 * R_E);
    sin_th = sin(theta);
    cos_th = cos(theta);

    % Geocentric radius to virtual reflection point at midpoint
    r_v = R_E + H_V;

    % Half group path L from law of cosines in spherical triangle (R_E, r_v, theta)
    L_half = sqrt(R_E^2 + r_v.^2 - 2.0 .* R_E .* r_v .* cos_th);

    % Sine of angle of incidence phi0 at reflection layer: sin(phi0) = R_E * sin(theta) / L_half
    sin_phi0 = (R_E * sin_th) ./ L_half;

    % Modified secant law factor: cos_eff = sqrt(1 - (k * sin(phi0))^2)
    cos_eff = sqrt(max(1e-4, 1.0 - (k_corr .* sin_phi0).^2));

    % Required oblique frequency: f_ob = f_v / cos_eff
    f_ob_map = F_V ./ cos_eff;
end

% Convert half-path L_half to match the vertical axis convention of img_ob
if is_half_path
    p_ob_map = L_half;        % Axis is apparent range R' = P'/2 = c*tau/2 (km)
else
    p_ob_map = 2.0 .* L_half; % Axis is total group path P' = c*tau (km)
end

% ---------------------------------------------------------------------
% 3. 2D INTERPOLATION ONTO EQUIVALENT VERTICAL GRID
% ---------------------------------------------------------------------
[F_OB_GRID, P_OB_GRID] = meshgrid(f_ob_vec, p_ob_vec);

% Use linear interpolation in dB space; fill out-of-bounds regions with minimum noise floor
fill_val = min(double(img_ob(:)));
img_vert = interp2(F_OB_GRID, P_OB_GRID, double(img_ob), f_ob_map, p_ob_map, 'linear', fill_val);

% Mask out regions where k * sin(phi0) >= 1 (beyond horizon / non-physical reflection)
if ~strcmpi(mode_str, 'flat')
    non_phys = (k_corr .* sin_phi0) >= 0.995;
    img_vert(non_phys) = fill_val;
end
end