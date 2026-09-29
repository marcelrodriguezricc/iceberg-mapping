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

function group = makeGroup(passes, groupNumber, globalX, globalY, shiftX, shiftY)

    % Sort passes temporally from earliest to latest
    [~, idx] = sort([passes.startTime]);
    P = passes(idx);

    % Get number of passes
    n = numel(P);

    % Determine position of full iceberg centroid at each pass by applying
    % transformation matrix from each pass to fully registered iceberg
    % centroid
    C = [shiftX; shiftY];

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

        % Reapply global shift to get position in easting/northing
        P(p).position = ci(1:2).' + [globalX globalY];
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

% Group 1
% Pass args: path to PC, s7k File Name, tx, ty, sin, cos
% Group args: passes array, group number, centroid x, centroid y
P(1) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_00.txt', '20240617_172402.s7k', 0, 0, 0, 1, 1);
P(2) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/correction-only/pass_01_00.txt', '20240617_173518.s7k', -26.116341, 22.991117, -0.041437, 0.999141, 0);
P(3) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/correction-only/pass_01_01.txt', '20240617_173518.s7k', -81.957932, 105.637543, -0.150002, 0.988686, 0);
P(4) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_01_02.txt', '20240617_173518.s7k', -136.721527, 170.918900, -0.233743, 0.972299, 1);
P(5) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_02_00.txt', '20240617_174711_1.s7k', -164.757248, 238.790314, -0.307364, 0.951592, 1);
P(6) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/correction-only/pass_02_01.txt', '20240617_174711_1.s7k', -134.863678, 160.151749, -0.225321, 0.974285, 0);
P(7) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_04_00.txt', '20240617_180119.s7k', -206.4074, 246.8656, -0.3152, 0.957568, 1);
P(8) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_04_01.txt', '20240617_180119.s7k', -128.2288, 60.1821, -0.1177, 0.9930, 1);
P(9) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_04_02.txt', '20240617_180119.s7k', -58.3734, -43.0215, 0.0057, 1.0000, 1);
P(10) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_04_03.txt', '20240617_180119.s7k', -91.2840, -3.1934, -0.0465, 0.9989, 1);
P(11) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_05_00_00.txt', '20240617_180706.s7k', -305.1284, 805.8258, -0.7397, 0.6730, 1);
P(12) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_05_00_01.txt', '20240617_180706.s7k', -160.2064, 66.9961, -0.1224, 0.9925, 1);
P(13) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_05_00_02.txt', '20240617_180706.s7k', -115.7883, -5.2453, -0.0419, 0.9991, 1);
P(14) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/mapping/pass_05_00_03.txt', '20240617_180706.s7k', -122.4259, 2.6330, -0.0532, 0.9986, 1);
P(15) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-1/correction-only/pass_05_01.txt', '20240617_180706.s7k', -58.950417, -90.781677, 0.055917, 0.998435, 0);
G(1) = makeGroup(P, 1, 653000.00, 6295000.00, 768.794, 593.083);

% Group 2
P2(1) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_06.txt','20240617_181729.s7k', 0, 0, 0, 1, 0);
P2(2) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/mapping/pass_07.txt','20240617_181843.s7k', 133.208786, -166.068527, 0.198181, 0.980167, 1);
P2(3) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/mapping/pass_08.txt','20240617_182203.s7k', 52.507992, -94.705215, 0.108995, 0.994043, 1);
P2(4) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_09.txt','20240617_182827.s7k', 166.793911, -242.041031, 0.275499, 0.961302, 0);
P2(5) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_10.txt','20240617_183608.s7k', -15.682268, -99.933907, 0.086301, 0.996270, 0);
P2(6) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_11.txt','20240617_184012.s7k', 41.109844, -192.927200, 0.179962, 0.983674, 0);
P2(7) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_12.txt','20240617_184330_1.s7k', -151.594833, 35.011856, -0.063580, 0.997977, 0);
P2(8) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_13.txt','20240617_184330_2.s7k', -165.484665, 51.515533, -0.085403, 0.996346, 0);
P2(9) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_14.txt','20240617_184756.s7k', -60.311115, -135.398117, 0.094120, 0.995562, 0);
P2(10) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-2/correction-only/pass_15.txt','20240617_185236.s7k', -272.191101, 190.442993, -0.217461, 0.976070, 0);
G(2) = makeGroup(P2, 2, 653000.00, 6295000.00, 892.766, 633.638);

% Group 3
P3(1) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-3/mapping/pass_16.txt', '20240617_192429.s7k', 0, 0, 0, 1, 1);
P3(2) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-3/mapping/pass_17.txt', '20240617_192720.s7k', -136.146667, 203.236633, -0.165721, 0.986173, 1);
P3(3) = makePass('/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/registered/group-3/mapping/pass_18.txt', '20240617_194609.s7k', 3.679151, -265.764709, 0.118808, 0.992917, 1);
G(3) = makeGroup(P3, 3, 653000.00, 6295000.00, 1231.26, 840.957); 

% Day
makeDay(G, 'MB_Spireberg_2024-06-17_corrected', '/Users/marcel/Desktop/iceberg-mapping/data/2024-06-17/MB_Spireberg_2024-06-17_corrected');