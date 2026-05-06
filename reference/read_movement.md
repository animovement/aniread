# Read data exported from the movement Python package

Imports pose estimation data from netCDF/HDF5 files created by the
[movement](https://movement.neuroinformatics.dev/) Python package.

## Usage

``` r
read_movement(path, video_height = NULL)
```

## Arguments

- path:

  Path to an HDF5 file (`.nc` or `.h5`) exported from movement.

- video_height:

  Optional numeric height of the source video frame in pixels. movement
  does not currently store this in the netCDF attributes, so without it
  `max(y)` is used as a fallback when reflecting to `bottom_left`.

## Value

An aniframe

## Details

The movement package stores pose estimation data in a specific
netCDF/HDF5 structure with datasets for individuals, keypoints, position
coordinates, confidence scores, and time. This function reads that
structure and reshapes it into a tidy aniframe format. The underlying
tracking software outputs image (top-left) coordinates, so the reader
reflects y to `bottom_left` before returning.
