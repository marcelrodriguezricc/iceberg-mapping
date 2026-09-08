% View the structure of the saved motion (displacement/yaw) .mat file

mat_dir = "/Users/marcel/Desktop/iceberg-motion/outputs/deploy_20240615_194448/MB";

% ─── Find the most recent motion_spireberg_*.mat file in the directory ──
mat_files = dir(fullfile(mat_dir, "motion_spireberg_*.mat"));

if isempty(mat_files)
    error("No matching motion .mat file found in %s", mat_dir);
end

[~, idx] = max([mat_files.datenum]);
mat_path = fullfile(mat_files(idx).folder, mat_files(idx).name);

fprintf("Loading: %s\n\n", mat_path);
loaded = load(mat_path);

% ─── Top-level variables in the file ────────────────────────────────────
disp("Top-level variables:");
disp(fieldnames(loaded));

% ─── Inspect the 'passData' struct ──────────────────────────────────────
if isfield(loaded, "passData")
    passData = loaded.passData;
    passNames = fieldnames(passData);

    fprintf("\n'passData' contains %d passes:\n", numel(passNames));
    disp(passNames);

    fprintf("\nFields per pass:\n");
    disp(fieldnames(passData.(passNames{1})));

    fprintf("\n--- Full values per pass ---\n");
    for i = 1:numel(passNames)
        name = passNames{i};
        p = passData.(name);
        fprintf("%-18s dx=%8.2f  dy=%8.2f  total=%8.2f  yaw=%7.2f  rms=%6.3f  overlap=%3d%%  [%s -> %s]\n", ...
            name, p.dx, p.dy, p.total, p.yaw, p.rms, p.overlap, p.start_time, p.end_time);
    end
else
    fprintf("\nNo 'passData' field found. Available fields:\n");
    disp(fieldnames(loaded));
end