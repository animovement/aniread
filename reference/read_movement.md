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
