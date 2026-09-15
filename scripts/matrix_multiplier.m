% When a previously registered point cloud is split and using the
% "cc_split_by_unixtime.py" script in Cloud Compare, the transformation
% matrix is lost. This tool combines the original transformation matrix and
% any subsequent transformations of split point clouds for a total
% transform by matrix multiplication.

T1 = [0.980167  0.198173  0  -195.267776
    -0.198173  0.980167  0  140.318069
    0         0         1    0
    0         0         0    1];

T2 = [0.997063 -0.076593  0  45.235291
    0.076693 0.997063  0   -57.953739
    0         0         1    0
    0         0         0    1];

T_total = T2 * T1;

disp(T_total)