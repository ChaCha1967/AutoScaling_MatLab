function [f_vert, h_virt_vert, phi0_deg] = oblique_to_vertical(f_ob, p_group, D_km, mode_str, k_corr)
% OBLIQUE_TO_VERTICAL Converts an oblique ionogram trace (f_ob, P') into an
% equivalent vertical ionogram trace (f_vert, h'_vert) using Breit-Tuve and
% Martyn's equivalence theorems.
%
% Inputs:
%   f_ob     : [Nx1] vector of oblique sounding frequencies (MHz)
%   p_group  : [Nx1] vector of measured oblique group paths P' (km)
%              (Note: if input is time delay tau in ms, pass p_group = tau_ms * 299.792458)
%   D_km     : Great-circle ground distance between Tx and Rx (km)
%              - Fredericton to Boston : ~530 km
%              - Resolute Bay to Eureka: ~622 km
%   mode_str : 'flat' (Flat Earth approximation) or 'spherical' (Spherical Earth, default)
%   k_corr   : Curvature correction factor k for Martyn's secant law in spherical
%              ionosphere (default = 1.08 for D = 500-700 km; 1.0 = pure secant law)
%
% Outputs:
%   f_vert      : [Mx1] equivalent vertical sounding frequencies (MHz), sorted
%   h_virt_vert : [Mx1] equivalent vertical virtual heights h'_v (km)
%   phi0_deg    : [Mx1] angle of incidence at the reflection layer (degrees)

if nargin < 4 || isempty(mode_str)
    mode_str = 'spherical';
end
if nargin < 5 || isempty(k_corr)
    if strcmpi(mode_str, 'flat')
        k_corr = 1.0;
    else
        k_corr = 1.08;
    end
end

R_E = 6371.2; % Mean Earth radius (km)

% Filter out non-physical points where group path P' <= ground distance D
valid = ~isnan(f_ob) & ~isnan(p_group) & (p_group > D_km + 2.0);
f_ob    = double(f_ob(valid));
p_group = double(p_group(valid));

if strcmpi(mode_str, 'flat')
    % -----------------------------------------------------------------
    % 1A. FLAT EARTH APPROXIMATION
    % -----------------------------------------------------------------
    % Equivalent vertical virtual height from right triangle (D/2, h'_v, P'/2)
    h_v = 0.5 .* sqrt(p_group.^2 - D_km^2);

    % Angle of incidence phi0 at the ionosphere
    sin_phi0 = D_km ./ p_group;
    cos_phi0 = sqrt(max(0.0, 1.0 - sin_phi0.^2));

    % Martyn's cosine law: f_v = f_ob * cos(phi0)
    f_v = f_ob .* cos_phi0;
else
    % -----------------------------------------------------------------
    % 1B. SPHERICAL EARTH + MODIFIED SECANT LAW
    % -----------------------------------------------------------------
    % Half central angle theta (radians)
    theta = D_km / (2.0 * R_E);
    sin_th = sin(theta);
    cos_th = cos(theta);

    % Half group path L = P' / 2
    L = 0.5 .* p_group;

    % Radius to virtual reflection point r_v from spherical triangle:
    % L^2 = R_E^2 + r_v^2 - 2*R_E*r_v*cos(theta)  =>  (r_v - R_E*cos(theta))^2 = L^2 - R_E^2*sin^2(theta)
    r_v = R_E * cos_th + sqrt(max(0.0, L.^2 - (R_E * sin_th)^2));
    h_v = r_v - R_E;

    % Sine of angle of incidence phi0 at the virtual reflection height r_v
    % Law of sines in triangle (R_E, r_v, L): sin(phi0) / R_E = sin(theta) / L
    sin_phi0 = (R_E * sin_th) ./ L;
    cos_phi0 = sqrt(max(0.0, 1.0 - (k_corr .* sin_phi0).^2));

    % Equivalent vertical frequency
    f_v = f_ob .* cos_phi0;
end

phi0_deg = rad2deg(asin(min(1.0, sin_phi0)));

% Sort by equivalent vertical frequency (keep lower ray up to the MUF nose)
[~, idx_max_f] = max(f_ob);
f_v      = f_v(1:idx_max_f);
h_v      = h_v(1:idx_max_f);
phi0_deg = phi0_deg(1:idx_max_f);

[f_vert, sort_idx] = sort(f_v(:), 'ascend');
h_virt_vert        = h_v(sort_idx);
phi0_deg           = phi0_deg(sort_idx);
end