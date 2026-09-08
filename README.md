# Iceberg Mapping

![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![MATLAB](https://img.shields.io/badge/MATLAB-R2026a-0076A8?logo=mathworks&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

This repository contains the scripts necessary to reproduce the point cloud data products, which model the surface of an iceberg derived from raw multibeam sonar soundings. The iceberg, dubbed Spireberg, calved from LeConte Glacier, Alaska in June of 2024 during a research cruise. Surveys were conducted by the Ice Ocean Interactions Observatory at Oregon State University College's for Ocean, Earth, and Atmospheric Sciences, using a NORBIT Winghead Multibeam Echosounder deployed from a robotic uncrewed surface vessel named Polly. Complimentary data of the water column and local micro-scale hydrodyanmics gathered by other sensors on Polly and Meltstake platform (see [J. D. Nash et al., "Turbulent Dynamics of Buoyant Melt Plumes Adjacent Near-Vertical Glacier Ice," Geophysical Research Letters, vol. 51, no. 9, e2024GL108790, 2024.](https://agupubs.onlinelibrary.wiley.com/doi/full/10.1029/2024GL108790)) were also used in the correction and registration process.

## Process

The process for deriving the data products from the raw sounding files can be divided into three main steps each performed in a separate software program — correction of raw sounding files using vessel measurements and CTD-derived sound velocity profile using QPS Qimera — registration for motion distortion correction, more manual cleaning, and algorithmic de-noising done using Cloud Compare — and packaging of the data product and derivation of quantities pertinent to analysis in MATLAB — each consisting of several specific sub-steps detailed below:

### Initial Cleaning / Correction (QPS Qimera)

1. Load raw soundings from Winghead .s7k files
    - TODO: HOST RAW SOUNDING FILES SOMEWHERE AND POINT TO THEM HERE, INCLUDE NOTE ON COORDINATE REF SYSTEM
2. Apply vessel corrections using Vessel Editor tool from physical measurements
    - TODO: INCLUDE MEASUREMENTS IN REPO AND POINT TO TJEM HERE
3. Generate SVP from raw CTD data using `mean_svp.m` (`iceberg-mapping/scripts/mean_svp.m`) and apply corrections
    - TODO: HOST RAW CTD FILES SOMEWHERE AND POINT TO THEM HERE, FIND OUT WHAT SVP TOOL IS CALLED
4. Apply local filters for each separate .s7k file based on observations of data in Swath editor tool for the following:
    - Depth band (to exclude noise from surface reflection and seafloor)
    - Distance high-pass (to exclude proximal noise from sonar and platform)
    - Amplitude high-pass (to exclude low-amplitude soundings and artifacts not reflective of iceberg surface)
5. Manual cleaning in Swath Editor, liberally removing noise and artifacts to refine iceberg surface
6. Removal of obvious melange, seafloor, and artifacts in 3D and Slice editors
7. Export soundings as ASCII files with the following parameters:
    - TODO: LIST PARAMETERS HERE
8. Convert datetime to unix time using the `dt_to_unix.ipynb` script (`iceberg-mapping/scrips/dt_to_unix.ipynb`) for processing in Cloud Compare
9. Discern where there are breaks between passes, and organize sequences of passes completed without a significant time-lapse in between into separate groups

### Fine Cleaning and Motion Correction (Cloud Compare)

1. Visualize points as a multicolor gradient symbolizing unix time in order to discern where motion distortion has occurred from a single surface being measured multiple times within a pass, and copy and paste the `cc_split_by_unixtime.py` script (`iceberg-mapping/scrips/cc_split_by_unixtime.py`) into Cloud Compare's Python API tool with the pass selected in order to split the pass by the time where the distortion began
    - These can now be considered two separate passes which will be corrected by separate registration processes
2. For each group of passes, register each pass to the one preceding it in time — first using a rough manual alignment, then using Cloud Compare's registration tool — and merge them together to give the next pass more points for which to reference
    - The first point cloud's position will be used as the basis for mapping and will not be registered
    - The first point cloud will be used as the basis to understand the motion of the iceberg based on the transformation matrix resulting from the registration process
    - If subsequent passes do not share common surfaces, skip and come back when there are common surfaces in the merged point cloud to reference
    - Estimate the overlap percentage by using contextual clues through observation of common features between the point clouds and the QPS Qimera survey map
    - Constrain registration and manual alignment to X-Y translation and Z rotation
    - Where common features are sparse or registration obviously fails, set both pass point clouds to visualize the Intensity scalar field, and use visible scalar field as a weight for registration
3. After registering all passes within a group, omit passes which are particularly noisy and do not contribute to the clarity of surface features, run one of the automatic noise removal algorithms if necessary, and do a final manual fine-cleaning of obvious artifacts
4. After omitting noisy passes and cleaning, perform a second registration with only satisfactory passes
5. Export cleaned and registered passes as individual comma-separated ASCII files into separate files by group

### Package Data Product (MATLAB)

1. Use the `package_product` script (`iceberg-mapping/scrips/package_product.m`) to package discrete passes into a struct containing the entire day of survey data
- The hierarchy of the struct is such that a day consists of several groups, a group several passes (passes contain the point cloud table)
- The script derives quantities pertaining to the iceberg's motion such as average position, as well as linear and rotational velocity at the day, group, and pass level
- The user is required to manually input the transformation data from the Cloud Compare registration process for each pass, as well as input other metadata such as the .s7k file each pass originated from, group numbers, etc.

## Setup

```bash
conda create -n iceberg-mapping python=3.11
conda activate iceberg-mapping
pip install -r requirements.txt
python -m ipykernel install --user --name iceberg-mapping --display-name "iceberg-mapping"
```

## License

This project is licensed under the [MIT License](LICENSE).