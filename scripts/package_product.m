% ----- Packaging Functions -----

function pass = makePass(filePath, s7kFile, tx, ty, sin, cos, map_flag)
% Build one pass struct from a point-cloud ASCII file
% filePath - Absolute path to .txt point cloud file on drive
% s7kFile - Name of the raw .s7k file from which the pass originated
% tx, ty - Translation components of registration transformation
% sin, cos - Rotation components of registration transformation
% map_flag - 0 = motion correction only, 1 = viable for small-scale mapping

    % Load .txt file and drop CloudCompare RGB columns
    M = readmatrix(filePath); % Load dataset
    M(:,4:6) = []; % Drop CloudCompare RGB columns

    % Convert Unix time to datetime
    dt = datetime(M(:,4)*1000, 'ConvertFrom', 'posixtime'); % Format conversion

    % Create table containing start/end timestamps and duration of pass
    pass.time = timeTable(min(dt), max(dt), 'pass'); % Create table with start timestamp, end timestamp, and duration

    % Store user entered parameters
    pass.s7kFile = s7kFile; % Origin .s7k file of raw soundings for pass
    pass.map_flag = map_flag; % Flag which denotes whether pass is satisfactory for use in small-scale morphological analysis

    % Store registration transform matrix values into table with metadata
    pass.reg = table(tx, ty, sin, cos, 'VariableNames', {'tx','ty','sin','cos'});
    pass.reg.Properties.VariableUnits = {'m', 'm', '', ''};
    pass.reg.Properties.VariableDescriptions = { ...
        'X (easting) translation, CloudCompare local (shifted) frame', ...
        'Y (northing) translation, CloudCompare local (shifted) frame', ...
        'Sine of rotation angle about Z (CCW positive)', ...
        'Cosine of rotation angle about Z (CCW positive)'};
    pass.reg.Properties.Description = ...
        'Rigid 2D registration of pass to merged cloud: x_reg = R*x + t, R = [cos -sin; sin cos]';

    % Combine other per-point data into tables and include metadata
    pass.points = table(dt, M(:,1:3), M(:,5), M(:,6:7), M(:,8:10), M(:,11:13), ...
        'VariableNames', {'DateTime','XYZ','Intensity', ...
                          'Uncertainty','VesselAttitude','VesselXYZ'});
    pass.points.Properties.VariableUnits = {'UTC', 'm', 'counts', 'm', 'deg', 'm'};
    pass.points.Properties.VariableDescriptions = { ...
        'Sounding timestamp', ...
        '[Easting Northing Elevation], NAD83(2011)/UTM 8N + NAVD88; registered frame', ...
        'Backscatter intensity', ...
        '[Horizontal Vertical] total propagated uncertainty', ...
        '[Heading Pitch Roll] of vessel at ping time', ...
        '[Easting Northing Elevation] of vessel reference point'};
    pass.points.Properties.Description = ...
        'Registered MBES soundings for one pass, exported from CloudCompare';

    % Include metadata descriptions of pass-level fields
    pass.meta.time = 'One-row table: pass Start, End, Duration';
    pass.meta.s7kFile = 'Raw Teledyne .s7k file the pass was extracted from';
    pass.meta.map_flag = '0 = motion correction only; 1 = viable for small-scale morphology mapping';
    pass.meta.reg = 'One-row table: registration tx, ty, sin, cos';
    pass.meta.points = 'Per-sounding table; see Properties for units/descriptions';
end

function group = makeGroup(passes, groupNumber, shiftX, shiftY, centX, centY)
% Compile pass structs into a group.
% passes - Struct array of passes (any order; sorted by time here)
% groupNumber - Group index
% shiftX/Y - CloudCompare global shift (m)
% centX/Y - Merged-cloud centroid in CloudCompare local (shifted) frame (m)

    % Sort passes temporally from earliest to latest
    [~, idx] = sort(arrayfun(@(q) q.time.Start, passes)); % Sort by start time
    P = passes(idx); % Import passes
    n = numel(P); % Number of passes

    % Merged-cloud centroid (local frame)
    C = [centX; centY];

    pos = nan(n,2); % Initialize position array

    % For each pass...
    for p = 1:n 

        % Get registration transformation matrix values
        s  = P(p).reg.sin;  c  = P(p).reg.cos;
        tx = P(p).reg.tx;   ty = P(p).reg.ty;

        % Inverse transform on merged centroid to iceberg position at this pass
        Ti = [c -s tx; s c ty; 0 0 1]; % Compile transform matrix from values
        ci = Ti \ [C; 1]; % Apply to centroid
        pos(p,:) = ci(1:2).' - [shiftX shiftY]; % Apply global shift

        % Inverse transform on all points to pre-registration coordinates
        XY  = P(p).points.XYZ(:,1:2).' + [shiftX; shiftY]; % Unapply global shift
        XYo = [c s; -s c] * (XY - [tx; ty]); % Inverse transform
        XYo = XYo.' - [shiftX shiftY]; % Reapply global shift

        % Store original points in table and include metadata
        P(p).points.origXYZ = [XYo, P(p).points.XYZ(:,3)];
        P(p).points.Properties.VariableUnits{'origXYZ'} = 'm';
        P(p).points.Properties.VariableDescriptions{'origXYZ'} = ...
            ['[Easting Northing Elevation], NAD83(2011)/UTM 8N + NAVD88; ' ...
             'original (pre-registration) position'];
    end

    % Get rotation angle, as well as start, end, and midpoint times
    ang  = atan2(arrayfun(@(q) q.reg.sin, P), arrayfun(@(q) q.reg.cos, P)).';
    t0   = arrayfun(@(q) q.time.Start, P).';
    t1   = arrayfun(@(q) q.time.End,   P).';
    tmid = t0 + (t1 - t0)/2;

    % Derive per-pass velocities relative to previous pass
    vel = nan(n,2);  angVel = nan(n,1);
    for p = 2:n
        dt = seconds(tmid(p) - tmid(p-1)); % Change in time between midpoint of current pass and previous pass
        vel(p,:) = (pos(p,:) - pos(p-1,:)) / dt; % Linear velocity
        angVel(p) = (ang(p) - ang(p-1)) / dt; % Angular velocity
    end

    % Store per-pass motion as a table with metadata
    for p = 1:n
        P(p).motion = motionTable(pos(p,:), vel(p,:), angVel(p), ...
            'Iceberg centroid position at this pass', ...
            'Velocity since previous pass (NaN for first pass)', ...
            'Yaw rate since previous pass (NaN for first pass)', ...
            'Pass iceberg motion');
        P(p).meta.motion = 'One-row table: Position, Velocity, AngularVelocity';
    end

    % Group-level fields
    group.groupNumber = groupNumber; % Group index
    group.time = timeTable(min(t0), max(t1), 'group'); % Time table
    group.globalShift = [shiftX, shiftY]; % Global shift from CloudCompare

    % Derive motion for group and store
    durS = seconds(group.time.Duration);
    group.motion = motionTable(mean(pos,1), ...
        (pos(n,:) - pos(1,:)) / durS, (ang(n) - ang(1)) / durS, ...
        'Mean iceberg centroid position over passes', ...
        'Net displacement / group duration', ...
        'Net yaw change / group duration', ...
        'Group iceberg motion');

    % Group metadata
    group.meta.groupNumber = 'Group index within survey day';
    group.meta.time        = 'One-row table: group Start, End, Duration';
    group.meta.globalShift = '[X Y] CloudCompare global shift, m (local = true UTM + shift)';
    group.meta.motion      = 'One-row table: Position, Velocity, AngularVelocity';
    group.meta.passes      = 'Struct array of passes, sorted by start time';

    % Store passes in group
    group.passes = P;
end


function day = makeDay(groups, surveyName, savePath)
% Compile group structs into a day/survey and save it.
% groups - Struct array of groups (any order; sorted by time here)
% surveyName - User chosen name for survey, should follow format: MB_Spireberg_YYYY-MM-DD_corrected
% savePath - Full path including filename for saving

    % Sort groups
    [~, idx] = sort(arrayfun(@(g) g.time.Start, groups));
    G = groups(idx);

    % Gather per-pass motion from all groups and check for validity for averaging
    M = {}; % Initialize array
    for k = 1:numel(G)
        M = [M, arrayfun(@(q) q.motion, G(k).passes, 'UniformOutput', false)]; % Return tables as array
    end
    allMot = vertcat(M{:}); % Unpack into seperate args
    okV = ~isnan(allMot.Velocity(:,1)); % Check linear velocity validity for averaging
    okA = ~isnan(allMot.AngularVelocity); % Check angular velocity for averaging

    % Store day-level fields
    day.surveyName = surveyName;
    day.time = timeTable(min(arrayfun(@(g) g.time.Start, G)), ...
                         max(arrayfun(@(g) g.time.End,   G)), 'survey day');
    day.motion = motionTable(mean(allMot.Position, 1), ...
        mean(allMot.Velocity(okV,:), 1), mean(allMot.AngularVelocity(okA)), ...
        'Mean iceberg centroid position over all passes', ...
        'Mean of per-pass velocities', ...
        'Mean of per-pass yaw rates', ...
        'Survey-day iceberg motion');
    day.meta.surveyName = 'Survey identifier';
    day.meta.time = 'One-row table: day Start, End, Duration';
    day.meta.motion = 'One-row table: Position, Velocity, AngularVelocity';
    day.meta.groups = 'Struct array of groups, sorted by start time';

    % Store groups in day
    day.groups = G;

    % Save to drive
    save(savePath, 'day');
end


% ----- Helper Functions -----

% Compile timestamp table with metadata
function T = timeTable(t0, t1, what)
    T = table(t0, t1, t1 - t0, 'VariableNames', {'Start','End','Duration'});
    T.Properties.VariableUnits = {'UTC', 'UTC', 'hh:mm:ss'};
    T.Properties.VariableDescriptions = { ...
        ['Start of ' what], ['End of ' what], ['Duration of ' what]};
    T.Properties.Description = [what ' start, end, and duration'];
end

% Compile motion table with metadata
function T = motionTable(pos, vel, angVel, posDesc, velDesc, angDesc, desc)
    T = table(pos, vel, angVel, ...
        'VariableNames', {'Position','Velocity','AngularVelocity'});
    T.Properties.VariableUnits = {'m', 'm/s', 'rad/s'};
    T.Properties.VariableDescriptions = { ...
        ['[Easting Northing], NAD83(2011)/UTM 8N; ' posDesc], ...
        ['[vE vN]; ' velDesc], ...
        ['CCW positive; ' angDesc]};
    T.Properties.Description = desc;
end