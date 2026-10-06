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

An aniframe. `time` is movement's `time` coordinate, with the first
frame of the video at 0; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

The movement package stores pose estimation data in a specific
netCDF/HDF5 structure with datasets for individuals, keypoints, position
coordinates, confidence scores, and time. This function reads that
structure and reshapes it into a tidy aniframe format. The underlying
tracking software outputs image (top-left) coordinates, so the reader
reflects y to `bottom_left` before returning.

Since version 0.17.0, movement names the dimensions `individual` and
`keypoint`; files saved by earlier versions name them `individuals` and
`keypoints`. Both read the same way.

The axes are taken from the file's `space` coordinate, so a 2D dataset
gives `x` and `y` and a 3D one `x`, `y` and `z`. The `confidence`
variable becomes the `confidence` column. movement stores it either for
each point, with dimensions (`time`, `keypoint`, `individual`), or for
each individual, with dimensions (`time`, `individual`); a
per-individual score is repeated for every keypoint of that individual.

Only poses datasets are read. A bounding boxes dataset (`ds_type`
`"bboxes"`) or a multi-view dataset, which has a further `view`
dimension, is an error.

The file's root attributes describe the recording, and the reader keeps
what has a place in the metadata:

- `source_software` becomes `source`, and the name of `source_file`
  becomes `filename`. A file without `source_file` (a dataset movement
  built from arrays rather than loaded from a file) takes the name of
  the file read.

- `time_unit` becomes `unit_time`. movement writes `"seconds"` when it
  was given the frame rate and `"frames"` when it was not; these become
  `"s"` and `"frame"`.

- `fps` becomes `sampling_rate`. movement writes it only when it was
  given one, so a file whose time is in frames leaves `sampling_rate`
  `NA`. Set it with
  [`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html)
  if you know it.

## Examples

``` r
# Two mice tracked with SLEAP, saved by movement with an fps of 50
path <- system.file("extdata", "movement.nc", package = "aniread")
read_movement(path)
#> # Individuals:   1, 2
#> # Keypoints:     Nose, EarLeft, EarRight, Neck, BodyUpper, BodyLower, TailBase
#> # Sampling rate: 50 Hz
#> # Time:          00:00:00.000 to 00:00:00.060
#>    individual keypoint  time     x     y confidence
#>    <fct>      <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 1          Nose      0     796.  169.      0.929
#>  2 1          Nose      0.02  785.  173.      0.872
#>  3 1          Nose      0.04  776.  176.      0.830
#>  4 1          Nose      0.06  765.  178.      0.882
#>  5 1          EarLeft   0     813.  160.      0.918
#>  6 1          EarLeft   0.02  804.  161.      0.918
#>  7 1          EarLeft   0.04  796.  164.      0.861
#>  8 1          EarLeft   0.06  781.  165.      0.904
#>  9 1          EarRight  0     817.  176.      0.942
#> 10 1          EarRight  0.02  809.  177.      0.900
#> # ℹ 46 more rows
```
