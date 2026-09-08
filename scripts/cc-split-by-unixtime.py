"""
CloudCompare Python Runtime script.
Splits the selected point cloud into two clouds at a UnixTime threshold
"""

import pycc

THRESHOLD = 1718645.39561485

CC = pycc.GetInstance()
cloud = CC.getSelectedEntities()[0]
sf = cloud.getScalarField(0)
n = cloud.size()

before_idx = [i for i in range(n) if sf.getValue(i) < THRESHOLD]
after_idx = [i for i in range(n) if sf.getValue(i) >= THRESHOLD]


def build_subset(indices, name):
    out = pycc.ccPointCloud(name)
    out.reserve(len(indices))
    for i in indices:
        out.addPoint(cloud.getPoint(i))

    for sf_idx in range(cloud.getNumberOfScalarFields()):
        src_sf = cloud.getScalarField(sf_idx)
        new_sf = out.getScalarField(out.addScalarField(cloud.getScalarFieldName(sf_idx)))
        for new_i, i in enumerate(indices):
            new_sf.setValue(new_i, src_sf.getValue(i))
        new_sf.computeMinAndMax()

    out.setCurrentDisplayedScalarField(0)
    CC.addToDB(out)


if before_idx:
    build_subset(before_idx, f"{cloud.getName()}_before")
if after_idx:
    build_subset(after_idx, f"{cloud.getName()}_after")

CC.updateUI()