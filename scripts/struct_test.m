% View the structure of a saved pass point cloud .mat file

mat_dir = "/Users/marcel/Desktop/iceberg-motion/outputs/deploy_20240615_194448/MB";

% ─── Find the most recent MB_spireberg_*_cleaned.mat file in the directory ──
mat_files = dir(fullfile(mat_dir, "MB_spireberg_*_cleaned.mat"));

if isempty(mat_files)
    error("No matching .mat file found in %s", mat_dir);
end

[~, idx] = max([mat_files.datenum]);
mat_path = fullfile(mat_files(idx).folder, mat_files(idx).name);

fprintf("Loading: %s\n\n", mat_path);
loaded = load(mat_path);

% ─── Top-level variables in the file ────────────────────────────────────
disp("Top-level variables:");
disp(fieldnames(loaded));

% ─── Inspect the 'passes' struct array ──────────────────────────────────
if isfield(loaded, "passes")
    passes = loaded.passes;

    fprintf("\n'passes' is a 1x%d struct array with fields:\n", numel(passes));
    disp(fieldnames(passes));

    fprintf("\n--- Pass 1 summary ---\n");
    fprintf("name: %s\n", passes(1).name);
    fprintf("data: table with %d rows, %d columns\n", ...
        size(passes(1).data, 1), size(passes(1).data, 2));

    disp("Column names in data table:");
    disp(passes(1).data.Properties.VariableNames);

    fprintf("\nFirst few rows of pass 1 data:\n");
    disp(head(passes(1).data));

    fprintf("\nAll pass names:\n");
    for i = 1:numel(passes)
        fprintf("  [%d] %s (%d rows)\n", i, passes(i).name, size(passes(i).data, 1));
    end
end