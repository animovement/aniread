# Read data exported from the movement Python package

Imports pose estimation data from netCDF/HDF5 files created by the
[movement](https://movement.neuroinformatics.dev/) Python package.

## Usage

``` r
read_movement(path)
```

## Arguments

- path:

  Path to an HDF5 file (`.nc` or `.h5`) exported from movement.

## Value

An aniframe

## Details

The movement package stores pose estimation data in a specific
netCDF/HDF5 structure with datasets for individuals, keypoints, position
coordinates, confidence scores, and time. This function reads that
structure and reshapes it into a tidy aniframe format.
