function pass = makePass(filePath, s7kFile, tx, ty, sin, cos, map_flag)
% Build one pass struct from a point-cloud ASCII file
% filePath - Absolute path to .txt point cloud file on drive
% s7kFile - Name of the raw s7kFile from which the pass originated
% tx - X component of registration transformation
% ty - Y-component of registration transformation
% sinRot - Sin component of registration transformation
% cosRot - Cos component of registration transformation
% map_flag - boolean, 0 = usable for motion correction only,
% 1 = viable for mapping of small scale features 

    % Load .txt file
    M = readmatrix(filePath);
    
    % Drop RGB columns automatically created by Cloud Compare
    M(:,4:6) = [];

    % Convert Unix time to Datetime and undo scaling imposed by Cloud
    % Compare
    dt = datetime(M(:,4)*1000, 'ConvertFrom', 'posixtime'); 

    % Establish start and end times
    pass.startTime = min(dt);
    pass.endTime = max(dt);

    % Store user-entered parameters
    pass.s7kFile = s7kFile;
    pass.tx = tx;
    pass.ty = ty;
    pass.sin = sin;
    pass.cos = cos;
    pass.map_flag = map_flag;

    % Include per-point parameters from .txt file
    pass.points = table(dt, M(:,1), M(:,2), M(:,3), M(:,5), M(:,6), M(:,7), ...
        M(:,8), M(:,9), M(:,10), M(:,11), M(:,12), M(:,13), ...
        'VariableNames', {'DateTime','X','Y','Z','Intensity', ...
        'UncertaintyHorizontal','UncertaintyVertical', ...
        'VesselHeading','VesselPitch','VesselRoll','VesselX','VesselY','VesselZ'});
end

function group = makeGroup(passes, groupNumber, globalX, globalY, mergedX, mergedY)

    % Sort passes temporally from earliest to latest
    [~, idx] = sort([passes.startTime]);
    P = passes(idx);

    % Get number of passes
    n = numel(P);

    % Determine position of full iceberg centroid at each pass by applying
    % transformation matrix from each pass to fully registered iceberg
    % centroid
    C = [mergedX; mergedY];

    % Get iceberg position for each pass by applying inverse
    % transform from registration to merged point cloud centroid
    for p = 1:n % For each pass...

        % Get transform variables
        s  = P(p).sin;
        c  = P(p).cos;
        tx = P(p).tx;
        ty = P(p).ty;

        % Establish inverse transformation matrix
        Ti = [ c  -s  tx
              s  c  ty
               0  0  1];

        % Apply to centroid
        ci = Ti \ [C; 1];

        % Undo CloudCompare global shift from all points
        P(p).position = ci(1:2).' - [globalX globalY];
        P(p).points.X = P(p).points.X - globalX;
        P(p).points.Y = P(p).points.Y - globalY;
    end

    % Derive average linear and angular velocities
    pos = vertcat(P.position); % Get position of each pass
    ang = atan2([P.sin].', [P.cos].'); % Determine angle of rotation from transform sin and cos
    tmid = [P.startTime].' + ([P.endTime].' - [P.startTime].')/2; % Get midpoint time of each pass
    vel = nan(n,2); % Initialize velocity field
    angVel = nan(n,1); % Initialize angular velocity field
    for p = 2:n % For each pass, starting at second element...
            dt = seconds(tmid(p) - tmid(p-1)); % Change in time between consecutive pass midpoints
            vel(p,:) = (pos(p,:) - pos(p-1,:)) / dt; % Derive linear velocity
            angVel(p) = (ang(p) - ang(p-1)) / dt;; % Derive angular velocity
    end
    for p = 1:n % Store per-pass velocities
            P(p).avgVelocity = vel(p,:);
            P(p).avgAngularVelocity = angVel(p);
    end

    % Store group number
    group.groupNumber = groupNumber;
    
    % Get start and end times from pass tables and store
    group.startTime = min([P.startTime]);
    group.endTime = max([P.endTime]);
    
    % Calculate duration and store
    group.duration = seconds(group.endTime - group.startTime);
    
    % Determine average group position as mean of all pass positions
    group.avgPosition = mean(pos,1);
    
    % Average linear and angular velocities as net displacement / rotation over duration
    group.avgVelocity = (pos(n,:) - pos(1,:)) / group.duration;
    group.avgAngularVelocity = (ang(n) - ang(1)) / group.duration;

    % Store passes
    group.passes = P;
end

function day = makeDay(groups, surveyName, savePath)
% Compile group structs into a day/survey and save it.
% groups - struct array of groups (any order; sorted by time here)
% surveyName - manually entered.
% savePath - full path incl. filename, e.g. 'C:\data\survey.mat'

    % Sort groups temorally from earliest to latest
    [~, idx] = sort([groups.startTime]);
    G = groups(idx);

    % Initialize arrays for position, as well as linear and angular
    % velocities
    allPos = [];  allVel = [];  allAng = [];
    for k = 1:numel(G)
        allPos = [allPos; vertcat(G(k).passes.position)];
        allVel = [allVel; vertcat(G(k).passes.avgVelocity)];
        allAng = [allAng; vertcat(G(k).passes.avgAngularVelocity)];
    end

    % Store parameters
    day.surveyName = surveyName;

    % Get day start and end times from groups
    day.startTime = min([G.startTime]);
    day.endTime = max([G.endTime]);

    % Derive average day position, linear and angular velocities
    day.avgPosition = mean(allPos,1);
    day.avgVelocity = mean(allVel(~isnan(allVel(:,1)),:),1);
    day.avgAngularVelocity = mean(allAng(~isnan(allAng)));
    
    % Store groups
    day.groups = G;

    % Save to drive
    save(savePath, 'day');
end