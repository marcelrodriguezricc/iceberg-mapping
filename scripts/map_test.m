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
survey = load('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/MB_Spireberg_2024-06-17_corrected.mat');
day = survey.day
grp   = day.groups(1);
shift = [grp.globalShiftX, grp.globalShiftY].';     % 2x1; or hard-code [-652000; -6295000]
nP    = numel(grp.passes);
cmap  = turbo(nP);             % one color per pass

figure
gx = geoaxes;
geobasemap(gx, 'satellite')
hold(gx, 'on')

allLat = [];  allLon = [];
Ereg = [];  Nreg = [];   % registered points (map_flag passes)
zMin = -20;  zMax = 0;   % depth window for box fit (m); Z is negative down
for p = 1:nP
    pass = grp.passes(p);
    pts  = pass.points;

    Rp = [pass.cos -pass.sin; pass.sin pass.cos];
    t  = [pass.tx; pass.ty];
    Ereg = [Ereg; pts.X];
    Nreg = [Nreg; pts.Y];
    XYloc  = [pts.X.'; pts.Y.'] + shift;         % to local frame
    XYorig = Rp.' * (XYloc - t) - shift;         % undo registration, back to UTM

    [lat, lon] = projinv(crs, XYorig(1,:).', XYorig(2,:).');

    geoscatter(gx, lat, lon, 6, cmap(p,:), 'filled', 'MarkerEdgeColor', 'none')

    allLat = [allLat; lat];  allLon = [allLon; lon];
end

% --- PCA-oriented bounding rectangle of registered points ---
[V, ~]  = eig(cov([Ereg Nreg]));             % eigenvectors, ascending eigenvalues
bestAng = atan2(V(2,end), V(1,end));         % major-axis angle

% Rotate all points into the box-aligned frame
q = [cos(bestAng) sin(bestAng); -sin(bestAng) cos(bestAng)] * [Ereg.'; Nreg.'];

% Extents (lo = 0, hi = 100 reproduces plain min/max)
lo = 1;  hi = 99;
b = [prctile(q(1,:),lo) prctile(q(1,:),hi) ...
     prctile(q(2,:),lo) prctile(q(2,:),hi)];
Rb   = [cos(bestAng) -sin(bestAng); sin(bestAng) cos(bestAng)];
box  = Rb * [b(1) b(2) b(2) b(1);
    b(3) b(3) b(4) b(4)];
boxC = mean(box, 2);

% --- Box and center in each pass's unregistered frame ---
boxRing = box(:, [1:end 1]);                 % closed ring, 2x5
for p = 1:nP
    pass = grp.passes(p);
    Rp = [pass.cos -pass.sin; pass.sin pass.cos];
    t  = [pass.tx; pass.ty];

    bOrig = Rp.' * (boxRing + shift - t) - shift;
    cOrig = Rp.' * (boxC    + shift - t) - shift;

    [latBp, lonBp] = projinv(crs, bOrig(1,:), bOrig(2,:));
    [latCp, lonCp] = projinv(crs, cOrig(1),   cOrig(2));

    geoplot(gx, latBp, lonBp, 'k-', 'LineWidth', 3)                    % dark halo
    geoplot(gx, latBp, lonBp, '-', 'Color', cmap(p,:), 'LineWidth', 1.5)
    geoscatter(gx, latCp, lonCp, 40, cmap(p,:), 'filled', 'MarkerEdgeColor', 'k')
end

[latB, lonB] = projinv(crs, box(1,[1:end 1]), box(2,[1:end 1]));
[latC, lonC] = projinv(crs, boxC(1), boxC(2));
geoplot(gx, latB, lonB, 'w-', 'LineWidth', 2)
geoscatter(gx, latC, lonC, 60, 'w', 'filled', 'MarkerEdgeColor', 'k')

colormap(gx, cmap)
clim(gx, [0.5 nP+0.5])
cb = colorbar(gx);
cb.Label.String = 'Pass';

pad = 0.002;
geolimits(gx, [min(allLat) max(allLat)] + [-pad pad], ...
              [min(allLon) max(allLon)] + [-pad pad])