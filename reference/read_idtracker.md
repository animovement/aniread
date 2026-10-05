# Read idtracker.ai data

idtracker.ai stores trajectories in image (top-left) coordinates; the
reader reflects y so the returned aniframe is in the conventional
`bottom_left` origin. For h5 files the frame height is read from the
file, as described below. CSV exports do not include the frame height,
so pass `video_height` explicitly to get an accurate flip (otherwise
`max(y)` is used as a fallback).

## Usage

``` r
read_idtracker(
  path,
  path_probabilities = NULL,
  version = 6,
  video_height = NULL
)
```

## Arguments

- path:

  Path to an idtracker.ai data frame

- path_probabilities:

  Path to a csv file with probabilities. Only needed if you are reading
  csv files as they are included in h5 files.

- version:

  idtracker.ai version. Currently only v6 output is implemented

- video_height:

  Optional numeric height of the source video frame in pixels. Overrides
  the value read from the h5 file when both are available.

## Value

a movement dataframe

## Details

An h5 file also records, as attributes of its root, how the recording
was tracked, and the reader keeps what has a place in the metadata:

- `version`, the idtracker.ai version that tracked it, becomes the
  `source_version` metadata field.

- `frames_per_second`, the frame rate of the video, becomes the
  `sampling_rate` metadata field. `time` stays the frame number counted
  from 1, so `unit_time` is still `"frame"`; the frame rate is what
  converts it to seconds.

- `height`, the height of the video frame, is what y is reflected
  around, unless `video_height` is given. A `height` dataset is used
  when there is no such attribute.

Both fields stay `NA` when the file does not record them. The CSV export
keeps these in a separate `attributes.json` rather than in
`trajectories.csv`, so a frame read from the CSV has neither
`source_version` nor `sampling_rate`; set them with
[`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html).

## Examples

``` r
path <- system.file("extdata", "idtracker.csv", package = "aniread")
read_idtracker(path)
#> # Individuals: 1, 2, 3, 4, 5, 6, 7, 8
#> # Keypoints:   centroid
#>    individual keypoint  time     x     y
#>    <fct>      <fct>    <dbl> <dbl> <dbl>
#>  1 1          centroid 0      853.  216.
#>  2 1          centroid 0.036  851.  211.
#>  3 1          centroid 0.071  850.  208.
#>  4 1          centroid 0.107  849.  203.
#>  5 1          centroid 0.143  848.  200.
#>  6 1          centroid 0.179  847.  196.
#>  7 1          centroid 0.214  846.  192.
#>  8 1          centroid 0.25   846.  189.
#>  9 1          centroid 0.286  846.  186.
#> 10 1          centroid 0.321  845.  183.
#> # ℹ 70 more rows
```
