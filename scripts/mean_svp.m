% Build a mean Sound Velocity Profile (SVP) from a CTD struct and write it
% out in CARIS .svp format (read natively by QPS Qimera)

% 1. Files to edit
matFile = '/Users/marcel/Desktop/iceberg-motion/data/2024-06-15/svp/060701_20240615_2018';
outFile = '/Users/marcel/Desktop/iceberg-motion/data/2024-06-15/mean_svp.svp';

% 2. Load and grab the struct
S = load(matFile);
ctd = S.ctd;

% 3. Depth and sound velocity
depth = ctd.depth(:);
svel = ctd.svel;

% 4. Mean sound velocity across the 11 casts
svel_mean = mean(svel, 2, 'omitnan');

% 5. Clean: drop NaNs, sort ascending by depth, remove duplicate depths
good = ~isnan(depth) & ~isnan(svel_mean);
depth = depth(good);
svel_mean = svel_mean(good);

[depth, ia] = unique(depth);
svel_mean = svel_mean(ia);

% 6. Representative position + time for the section header
lat = mean(ctd.lat, 'omitnan');
lon = mean(ctd.lon, 'omitnan');

% Convert to datetime from MATLAB datenum
tnum = mean(ctd.time, 'omitnan');
t = datetime(tnum, 'ConvertFrom', 'datenum');
disp("Header timestamp resolves to: " + string(t))

% 7. Build the CARIS section-header strings
yearStr = sprintf('%04d-%03d', year(t), day(t, 'dayofyear'));  % YYYY-DDD
timeStr = datestr(t, 'HH:MM:SS');
latStr = deg2dms(lat, false); % DD:MM:SS
lonStr = deg2dms(lon, true); % DDD:MM:SS
[fid, msg] = fopen(outFile, 'w');
if fid < 0, error('Could not open %s for writing: %s', outFile, msg); end

% 8. Write the .svp file
[~, base, ext] = fileparts(outFile);
fid = fopen(outFile, 'w');
if fid < 0, error('Could not open %s for writing.', outFile); end
fprintf(fid, '[SVP_VERSION_2]\n');
fprintf(fid, '%s%s\n', base, ext);
fprintf(fid, 'Section %s %s %s %s spireberg mean profile\n', ...
        yearStr, timeStr, latStr, lonStr);
fprintf(fid, '%.2f %.2f\n', [depth, svel_mean].');
fclose(fid);
fprintf('Wrote %d depth/speed points to %s\n', numel(depth), outFile);

% 9. Quick sanity plot
figure;
plot(svel_mean, depth, '-');
set(gca, 'YDir', 'reverse');
xlabel('Sound speed (m s^{-1})');
ylabel('Depth (m)');
title('Mean SVP across 11 casts');
grid on;

% Local helper: signed decimal degrees -> D:M:S string
function s = deg2dms(x, isLon)
    neg = x < 0;  x = abs(x);
    d   = floor(x);
    m   = floor((x - d) * 60);
    sec = round((x - d - m/60) * 3600);
    if sec == 60, sec = 0; m = m + 1; end
    if m   == 60, m = 0;   d = d + 1; end
    if isLon
        s = sprintf('%03d:%02d:%02d', d, m, sec);
    else
        s = sprintf('%02d:%02d:%02d', d, m, sec);
    end
    if neg, s = ['-' s]; end
end