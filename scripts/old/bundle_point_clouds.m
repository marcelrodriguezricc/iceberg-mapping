% Bundle per-pass point cloud CSVs into a 1xN struct array and save as .mat

in_dir = "/Users/marcel/Desktop/iceberg-motion/data/2024-06-14/motion_corrected";
out_dir = "/Users/marcel/Desktop/iceberg-motion/outputs/deploy_20240615_194448/MB";

if ~exist(out_dir, "dir")
    mkdir(out_dir);
end

csv_files = dir(fullfile(in_dir, "*.csv"));
[~, sort_idx] = sort({csv_files.name});
csv_files = csv_files(sort_idx);

n_passes = numel(csv_files);
passes = repmat(struct("name", "", "data", table()), 1, n_passes);

for i = 1:n_passes
    csv_path = fullfile(csv_files(i).folder, csv_files(i).name);
    data = readtable(csv_path);

    % ─── Rename columns by position: 1-3 -> Footprint X/Y/Z, 4 -> DateTime
    oldNames = data.Properties.VariableNames(1:4);
    newNames = {'FootprintX', 'FootprintY', 'FootprintZ', 'DateTime'};
    data = renamevars(data, oldNames, newNames);

    % Convert DateTime column from unix time to datetime
    data.DateTime = datetime(data.DateTime, 'ConvertFrom', 'posixtime');

    % Move DateTime to be the first column
    data = movevars(data, 'DateTime', 'Before', 'FootprintX');

    passes(i).name = csv_files(i).name;
    passes(i).data = data;
end

% ─── Determine earliest DateTime across all passes for filename ────────
earliestTime = passes(1).data.DateTime(1);
for i = 1:n_passes
    passMin = min(passes(i).data.DateTime);
    if passMin < earliestTime
        earliestTime = passMin;
    end
end

dateStr = datestr(earliestTime, 'yyyymmdd');
timeStr = datestr(earliestTime, 'HHMMSS');

out_file = fullfile(out_dir, sprintf('MB_spireberg_%s_%s_corrected.mat', dateStr, timeStr));

% ─── Save ────────────────────────────────────────────────────────────────
save(out_file, 'passes');

fprintf('Saved: %s\n', out_file);