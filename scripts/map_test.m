% Set area of interest center and radius
aoi_lat =  dms2degrees([56 46 28.63]); % Latitude
aoi_lon = -dms2degrees([132 29 55.46]); % Longitude
r = 3000; % Radius

% Establish CRS
crs = projcrs(6337);
disp(crs.Name)

% Generate bounding box extents
[x0, y0] = projfwd(crs, aoi_lat, aoi_lon); 
[latLim, lonLim] = projinv(crs, x0 + [-r r], y0 + [-r r]);

[latP, lonP] = projinv(crs, x0, y0); 

% Define rectangle
L     = 800;          % Length along local x (m)
W     = 400;          % Width along local y (m)
theta = deg2rad(30);  % Rotation, CCW from east

% Generate corners
xc = [-L/2,  L/2,  L/2, -L/2];
yc = [-W/2, -W/2,  W/2,  W/2];

% Rotate corners
R  = [cos(theta) -sin(theta);
    sin(theta)  cos(theta)];

% Translate to AOI center
EN = R * [xc; yc] + [x0; y0];
E = EN(1, [1:end 1]);
N = EN(2, [1:end 1]);
[latR, lonR] = projinv(crs, E, N);

% Load the struct
survey = load('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-14/MB_Spireberg_2024-06-14_corrected.mat');
day = survey.day
pts = day.groups(1).passes(1).points;
E = [pts.X]'; 
N = [pts.Y]';
[latPts, lonPts] = projinv(crs, E, N);

% Map
figure
gx = geoaxes; % Display lat/lon coordinates on map
geobasemap(gx, 'satellite') % Determine basemap
% geoplot(gx, latR, lonR, 'y-', 'LineWidth', 2, 'DisplayName', 'Test box')
geoscatter(gx, latPts, lonPts, 6, 'c', 'filled', 'MarkerEdgeColor', 'none')
% geolimits(gx, latLim, lonLim) % Bounding box limits
pad = 0.002;   % degrees
geolimits(gx, [min(latPts) max(latPts)] + [-pad pad], ...
    [min(lonPts) max(lonPts)] + [-pad pad])
hold(gx, 'on') % Retain plot