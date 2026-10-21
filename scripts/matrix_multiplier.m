% When a previously registered point cloud is split and using the
% "cc_split_by_unixtime.py" script in Cloud Compare, the transformation
% matrix is lost. This tool combines the original transformation matrix and
% any subsequent transformations of split point clouds for a total
% transform by matrix multiplication.

T1 = [0.982744  0.184973  0  -189.560760
    -0.184973  0.982744  0  127.179611
    0         0         1    0
    0         0         0    1];

T2 = [0.941287 -0.337606  0  252.323761
    0.337606 0.941287  0   -230.732346
    0         0         1    0
    0         0         0    1];

T_total = T2 * T1;

disp(T_total)