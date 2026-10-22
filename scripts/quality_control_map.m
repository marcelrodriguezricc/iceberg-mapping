% ===== Global =====

% Establish coordinate reference system and print to console
crs = projcrs(6337);
disp(crs.Name)

% Load survey day dataset
survey = load('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/MB_Spireberg_2024-06-17_corrected.mat');
day = survey.day;

% User variables
pad  = 0.002; % Map padding around point cloud extents
lo = 1;  hi = 99; % Bounding box fit percentiles (lo = 0 hi = 100 gives true min/max)

% For each group in the day...
for g = 1:numel(day.groups)

    % Load group and get pertinent data
    grp = day.groups(g); % Load current group
    shift = grp.globalShift.'; % Load CloudCompare global shift
    nP = numel(grp.passes); % Get number of passes in group

    % Generate map symbology and surrounds based on group
    cmap  = turbo(nP);
    tag   = sprintf('%s - Group %d', day.surveyName, grp.groupNumber);

    % ===== Figure 1: unregistered clouds + transformed boxes =====

    % Generate figure
    figure('Name', [tag ' - Unregistered']) % Initialize figure
    gx = geoaxes; % Lat/lon axes
    geobasemap(gx, 'satellite') % Basemap
    hold(gx, 'on') % Keep figure open while others are loaded
    title(gx, [tag ': Unregistered Passes'], 'Interpreter', 'none') % Tag

    % Initialize lat/lon arrays
    allLat = [];  allLon = [];
    E = [];  N = [];

    % For each pass...
    for p = 1:nP

        % Get points table
        pts = grp.passes(p).points;

        % Retrieve X and Y coords of all points
        E = [E; pts.XYZ(1)]; % Easting
        N = [N; pts.XYZ(2)]; % Northing

        % Plot all points and populate lat/lon arrays
        [lat, lon] = projinv(crs, pts.origXYZ(:,1), pts.origXYZ(:,2));
        geoscatter(gx, lat, lon, 6, cmap(p,:), 'filled', 'MarkerEdgeColor', 'none')
        allLat = [allLat; lat];  allLon = [allLon; lon];
    end

    % PCA-oriented bounding rectangle of registered points:
    % The major axis is the icebergs longest axis
    % Minor axis is perpendicular to it
    % Align rectangle to axes and size it to points extent along each
    [V, ~]  = eig(cov([E N])); % Generate covariance matrix and find the eigenvectors to establish principle axes
    bestAng = atan2(V(2,end), V(1,end)); % Get angle of the major eigenvector from N and E components
    q = [cos(bestAng) sin(bestAng); -sin(bestAng) cos(bestAng)] * [Ereg.'; Nreg.']; % Rotate points into box-aligned frame
    b = [prctile(q(1,:),lo) prctile(q(1,:),hi) ...
         prctile(q(2,:),lo) prctile(q(2,:),hi)]; % Use percentile spread to find the furthest extents
    Rb = [cos(bestAng) -sin(bestAng); sin(bestAng) cos(bestAng)]; % Rotate back to map frame
    box = Rb * [b(1) b(2) b(2) b(1); % Apply rotation to box corners
                 b(3) b(3) b(4) b(4)];
    boxC = mean(box, 2); % Get box center

    % Draw box and center in each pass's unregistered frame
    boxRing = box(:, [1:end 1]);
    for p = 1:nP % For each pass...
        reg = grp.passes(p).reg; % Get registration transform values
        Rp = [reg.cos -reg.sin; reg.sin reg.cos]; % Angular transform
        t = [reg.tx; reg.ty]; % Linear transform

        % Apply linear/angular transform with shift removed the reapply shift
        bOrig = Rp.' * (boxRing + shift - t) - shift; % Box edges
        cOrig = Rp.' * (boxC + shift - t) - shift; % Box centroid

        % Convert N/E of box components to Lat/Lon
        [latBp, lonBp] = projinv(crs, bOrig(1,:), bOrig(2,:));
        [latCp, lonCp] = projinv(crs, cOrig(1),   cOrig(2));

        % Plot to figure
        geoplot(gx, latBp, lonBp, 'k-', 'LineWidth', 3)
        geoplot(gx, latBp, lonBp, '-', 'Color', cmap(p,:), 'LineWidth', 1.5)
        geoscatter(gx, latCp, lonCp, 40, cmap(p,:), 'filled', 'MarkerEdgeColor', 'k')
    end

    % Symbolize by pass
    colormap(gx, cmap) % Set color gradient
    clim(gx, [0.5 nP+0.5]) % Bin by pass
    cb = colorbar(gx); % Set colorbar
    cb.Label.String = 'Pass'; % Label colorbar

    % Set map extents based on point cloud extents with padding
    geolimits(gx, [min(allLat) max(allLat)] + [-pad pad], ... 
                  [min(allLon) max(allLon)] + [-pad pad])

    % ===== Figure 2: registered clouds + vessel tracks (berg-fixed frame) =====
    
    % Generate figure
    figure('Name', [tag ' - Registered']) % Initializer figure
    gx2 = geoaxes; % Lat/lon axes
    geobasemap(gx2, 'satellite') % Basemap
    hold(gx2, 'on') % Keep figure open while others are loaded
    title(gx2, [tag ': registered passes + vessel tracks'], 'Interpreter', 'none') % Tag


    % Map registered points
    latM = [];  lonM = []; % Initialize lat/lon arrays
    for p = 1:nP % For each pass...
        XYZ = grp.passes(p).points.XYZ; % Get coordinates for all points
        [latP, lonP] = projinv(crs, XYZ(:,1), XYZ(:,2)); % Convert to lat/lon
        geoscatter(gx2, latP, lonP, 4, cmap(p,:), 'filled', ... % Map points
                   'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.5)
        latM = [latM; latP];  lonM = [lonM; lonP]; % Store arrays
    end

    % Map vessel trajectories
    allLatV = [];  allLonV = []; % Initialize lat/lon arrays
    for p = 1:nP % For each pass...
        pts = grp.passes(p).points; % Get points table
        reg = grp.passes(p).reg; % Get table of registration transform values
        Rp = [reg.cos -reg.sin; reg.sin reg.cos]; % Store rotation values
        t = [reg.tx; reg.ty]; % Store linear transform values
        [~, iu] = unique(pts.DateTime); % Disregard repeated values (points in the same swath)
        V = pts.VesselXYZ(iu, 1:2).'; % Get vessel coordinates for each swath
        Vreg = Rp * (V + shift) + t - shift; % Apply registration transform to vessel coordinates
        [latV, lonV] = projinv(crs, Vreg(1,:), Vreg(2,:)); % Convert to lat/lon
        
        % Add to map
        geoplot(gx2, latV, lonV, 'k-', 'LineWidth', 3)
        geoplot(gx2, latV, lonV, '-', 'Color', cmap(p,:), 'LineWidth', 1.5)
        geoscatter(gx2, latV(1), lonV(1), 30, cmap(p,:), 'filled', 'MarkerEdgeColor', 'w')
        allLatV = [allLatV; latV(:)];  allLonV = [allLonV; lonV(:)]; % Store all points in array
    end

    % Symbolize by pass
    colormap(gx2, cmap) % Set color gradient
    clim(gx2, [0.5 nP+0.5]) % Bin by pass
    cb2 = colorbar(gx2); % Set colorbar
    cb2.Label.String = 'Pass'; % Label colorbar

    % Set map extents based on point cloud extents with padding
    latAll = [latM; allLatV];  lonAll = [lonM; allLonV];
    geolimits(gx2, [min(latAll) max(latAll)] + [-pad pad], ...
                   [min(lonAll) max(lonAll)] + [-pad pad])
end