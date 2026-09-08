function pass = makePass(filePath, s7kFile, tx, ty, sinRot, cosRot)
% Build one pass struct from a point-cloud ASCII file
% filePath - Absolute path to .txt point cloud file on drive
% s7kFile - Name of the raw s7kFile from which the pass originated
% tx - X component of registration transformation
% ty - Y-component of registration transformation
% sinRot - Sin component of registration transformation
% cosRot - Cos component of registration transformation

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
    pass.zRot = atan2(sinRot, cosRot);

    % To find average position, find the centroid of the iceberg by
    % finding the mean of all points and undoing the registration
    c = mean([M(:,1), M(:,2)]);
    Rinv = [cosd(pass.zRot) sind(pass.zRot); -sind(pass.zRot) cosd(pass.zRot)];
    pass.position = (Rinv * (c - [tx ty]).').';

    % Include per-point parameters from .txt file
    pass.points = table(dt, M(:,1), M(:,2), M(:,3), M(:,5), M(:,6), M(:,7), ...
        M(:,8), M(:,9), M(:,10), M(:,11), M(:,12), M(:,13), ...
        'VariableNames', {'DateTime','X','Y','Z','Intensity', ...
        'UncertaintyHorizontal','UncertaintyVertical', ...
        'VesselHeading','VesselPitch','VesselRoll','VesselX','VesselY','VesselZ'});
end

function group = makeGroup(passes, groupNumber)
% Compile pass structs into a group
% A group is a sequence of passes made without a large break in time between
% passes - struct array of passes (any order; sorted by time here)
% group number - should be sequenced by time across survey day
% Group start/end come from the passes
% Pass and group angular velocities are derived here

    % Sort passes temporally from earliest to latest
    [~, idx] = sort([passes.startTime]);
    P = passes(idx);

    % Derive average linear and angular velocities
    n = numel(P); % Get number of passes
    pos = vertcat(P.position); % Get position of each pass
    rot = [P.zRot].'; % Get rotation of each pass
    tmid = [P.startTime].' + ([P.endTime].' - [P.startTime].')/2; % Get midpoint time of each pass
    vel = nan(n,2); % Initialize velocity field
    angVel = nan(n,1); % Initialize angular velocity field
    for p = 2:n % For each pass, starting at second element,
        dt = seconds(tmid(p) - tmid(p-1)); % Get change in time between midpoint of first and last passes
        vel(p,:) = (pos(p,:) - pos(p-1,:)) / dt; % Derive linear velocity
        angVel(p) = (rot(p) - rot(p-1)) / dt; % Derive angular velocity
    end
    for p = 1:n % For each pass, starting at first element
        P(p).avgVelocity = vel(p,:); % Store linear velocity
        P(p).avgAngularVelocity = angVel(p); % Store angular velocity
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

    % Average linear and angular velocities as net displacement and
    % rotation divided by group duration
    group.avgVelocit = (pos(n,:) - pos(1,:)) / group.duration;
    group.avgAngularVelocity = (rot(n) - rot(1)) / group.duration;

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

% Group 1 Example:
P(1) = makePass('/Users/marcel/Desktop/iceberg-motion/data/2024-06-17/registered/group-1/pass_00.txt','20240617_172402.s7k', 0, 0, 0, 0);
P(2) = makePass('/Users/marcel/Desktop/iceberg-motion/data/2024-06-17/registered/group-1/pass_01_02.txt','20240617_173158.s7k', -136.721527, 170.918900, -0.233743, 0.972299);
G(1) = makeGroup(P, 1);

% Group 2 Example:
P2(1) = makePass('/Users/marcel/Desktop/iceberg-motion/data/2024-06-17/registered/group-1/pass_00.txt','20240617_172402.s7k', 0, 0, 0, 0);
P2(2) = makePass('/Users/marcel/Desktop/iceberg-motion/data/2024-06-17/registered/group-1/pass_01_02.txt','20240617_173158.s7k', -136.721527, 170.918900, -0.233743, 0.972299);
G(2) = makeGroup(P2, 1);

% Day Example:
makeDay(G, 'MB_Spireberg_2024-06-17_corrected', '/Users/marcel/Desktop/iceberg-motion/data/2024-06-17');