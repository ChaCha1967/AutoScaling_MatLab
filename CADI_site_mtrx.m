% Set parameters for selected station

% % % % INFO FROM IDL CADI_SITE.PRO
% % % ; NAME:
% % % ;       CADI_SITE
% % % ; PURPOSE:
% % % ;       Returns site-specific information on CADI configuration.
% % % ; CALLING SEQUENCE:
% % % ;       Result = CADI_SITE( SITE_CODE, CANTIME )
% % % ; INPUTS:
% % % ;       SITE_CODE = Scalar string. The three-character site code. Case is
% % % ;          ignored. Valid values are: EUR GIL R_L R_B. Mandatory.
% % % ;       CANTIME = Scalar long: CANOPUS time for which configuration is required.
% % % ;          Mandatory.
% % % ; OUTPUTS:
% % % ;       Result = Structure containing information on CADI site at given time.
% % % ;          The fields of Result are:
% % % ;
% % % ;       CODE is three-letter site code.
% % % ;
% % % ;       TIME is the CANOPUS date/time to which the site description refers.
% % % ;
% % % ;       NAME is the full name of the site.
% % % ;
% % % ;       GDLON is the geodetic latitude of the site, in radians positive north.
% % % ;
% % % ;       GDLAT  is the geodetic longitude of the site, in radians positive east.
% % % ;
% % % ;       SITE.ANTENNAX(0..3) hold, for antennas E W N S, the indices into the
% % % ;       sequence of I/Q byte pairs in the data files. Nominally 0 1 2 3.
% % % ;
% % % ;       SITE.POLARITY(0..3) (integer) hold polarities for antennas E W N S:
% % % ;       1=nominal, -1=inverted. For a non-nominal pair (an overhead echo gives
% % % ;       a pi phase difference), set one to 1 and the other to -1, though in
% % % ;       practice we usually don't know which is the inverted antenna of the
% % % ;       pair.
% % % ;
% % % ;       SITE.SEPARATION(0..1) hold antenna separations in metres for pairs EW,
% % % ;       NS.
% % % ;
% % % ;       AZIMUTH is the orientation of the antenna array measured in radians
% % % ;       from true north toward east.
% % % ;
% % % ; MODIFICATION HISTORY:
% % % ;       Ian Grant, UWO: Written before 19 Oct 1994.
% % % ;       Updates to site configurations are commented in the code.
% % % ;       JMacDougall, 12June1995 added phasecorrection
% % % ;       JMD, 5may00, added Vietnam

function [siteStruct] = CADI_site_mtrx(sStation)

% Initialize structures to store records
siteStruct = struct();

% Nominal settings for any station
antennax = [0 1 2 3]; % E W N S
polarity = [1 1 1 1];
phasecorrectionNS = 0.0;
phasecorrectionEW = 0.0;

% select Station
switch sStation
  
    % Case Hall Beach
    case 'HA'
        code = 'HAL';
        name = 'Hall B';
        gdlon = -81.257*pi/180; % 2-digit "geographic" from handout
        gdlat = 68.767*pi/180;   %
        magdip = 71.3;      % hould be -ve??
        gyrofreq = 1.17;    %     
        polarity = [1, -1, 1, -1]; %
        separation = [21.0, 21.0]; %
        azimuth = 0.0*pi/180; %
        phasecorrectionNS = 0.0; % 0 deg
        phasecorrectionEW = 0.0; % 0 deg


    % Temporarely set default parameters as Hall Beach
    otherwise
        code = 'HAL';
        name = 'Hall B';
        gdlon = -81.257*pi/180; % 2-digit "geographic" from handout
        gdlat = 68.767*pi/180;   %
        magdip = 71.3;      % hould be -ve??
        gyrofreq = 1.17;    %     
        polarity = [1, -1, 1, -1]; %
        separation = [21.0, 21.0]; %
        azimuth = 0.0*pi/180; %
        phasecorrectionNS = 0.0; % 0 deg
        phasecorrectionEW = 0.0; % 0 deg

end

% Fill siteStructure fields
siteStruct.code = code;
siteStruct.name = name;
siteStruct.gdlon = gdlon; 
siteStruct.gdlat = gdlat;
siteStruct.magdip = magdip;
siteStruct.gyrofreq = gyrofreq;     
siteStruct.antennax = antennax;
siteStruct.polarity = polarity;
siteStruct.separation = separation;
siteStruct.azimuth = azimuth;
siteStruct.phasecorrectionNS = phasecorrectionNS;
siteStruct.phasecorrectionEW = phasecorrectionEW;