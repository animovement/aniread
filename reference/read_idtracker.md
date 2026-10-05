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
  video_height = NULL,
  format = c("auto", "h5", "csv", "csv_tidy", "parquet")
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
  the value read from the h5 or Parquet file when both are available.

- format:

  Which idtracker.ai export `path` is: `"h5"`, the CSV export (`"csv"`,
  `trajectories.csv`), the tidy CSV export (`"csv_tidy"`,
  `trajectories_tidy.csv`) or `"parquet"`. The default, `"auto"`, tells
  them apart by the suffix and, for a CSV, by its header. Which one was
  read is recorded in the `source_format` metadata field.

## Value

a movement dataframe. The first frame of the video is at `time = 0`, in
frames or in seconds; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

An h5 file also records, as attributes of its root, how the recording
was tracked, and the reader keeps what has a place in the metadata:

- `version`, the idtracker.ai version that tracked it, becomes the
  `source_version` metadata field.

- `frames_per_second`, the frame rate of the video, becomes the
  `sampling_rate` metadata field. `time` stays the frame number, counted
  from 0 as idtracker.ai counts frames, so `unit_time` is still
  `"frame"`; the frame rate is what converts it to seconds.

- `height`, the height of the video frame, is what y is reflected
  around, unless `video_height` is given. A `height` dataset is used
  when there is no such attribute.

- `width`, the width of the video frame, written by newer releases,
  becomes the x extent in the `axis_extents` metadata field.

- `identities_labels`, the names of the identities, which can be changed
  in idtracker.ai's validator, name the individuals. idtracker.ai writes
  `"1"`, `"2"`, ... when none were set, which are also the names used
  when the file has no usable labels (one distinct, non-empty label per
  individual).

`source_version` and `sampling_rate` stay `NA` when the file does not
record them, and no x extent is recorded without a `width`.

The CSV export keeps these in a separate `attributes.json` rather than
in `trajectories.csv`, and the reader does not read it, so a frame read
from the CSV has no `source_version`; set it with
[`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html).
Its time column (`seconds`, or `time` in newer releases) is the time in
seconds, so `unit_time` is `"s"`, where a frame read from the h5 has
`"frame"`. The time column still states the frame rate: idtracker.ai
writes one row per frame, with the time as the row number divided by the
frame rate, rounded to 1 ms. The reader takes the rate from the rows
over the time they span, or the whole number nearest to it when that
fits every row as well, and sets it as `sampling_rate`. It is left `NA`
when the times are not evenly spaced.

When idtracker.ai could not read the video's frame rate, it writes the
CSV export without a time column, and `frames_per_second` as `null` in
`attributes.json`. `time` is then the frame number, the row counted from
0 as the h5 reader counts frames, `unit_time` is `"frame"`, and
`sampling_rate` is `NA`. Set the rate with
[`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html)
if you know it.

## Tidy CSV and Parquet exports

idtracker.ai 6.0.13 added a Parquet export, `trajectories.parquet`, and
6.0.14 a tidy CSV export, `trajectories_tidy.csv`. Both hold one row per
frame and individual, with the columns `frame`, `time`, `individual`,
`x`, `y` and `probability`, and are written only when asked for in
`TRAJECTORIES_FORMATS` (or by
`idtrackerai_format --formats csv_tidy parquet`).

- The Parquet file stores the attributes the h5 keeps (`version`,
  `frames_per_second`, `height`, `width`, `identities_labels`, ...) as
  JSON in its own metadata, and the reader uses them as it does the
  h5's.

- The tidy CSV keeps them in `attributes_tidy.json` beside it, which the
  reader reads when it is there, since idtracker.ai writes the two
  together as one export.

`frame` and `individual` count from 0. Individuals are numbered from 1,
as the h5 reader numbers them, and named by `identities_labels` where
those are usable. `probability` becomes `confidence`. When the frame
rate is known, `time` is the file's time in seconds, which is the frame
over the frame rate, as the CSV export times its rows, with `unit_time`
`"s"` and the frame rate as `sampling_rate`. When idtracker.ai could not
read the frame rate it still writes a `time` column, but as the frame
over 1, so `time` is then the frame, counted from 0, with `unit_time`
`"frame"` and `sampling_rate` `NA`. Without `attributes_tidy.json`, a
tidy CSV whose `time` equals its `frame` in every row is read as one
without a frame rate, and otherwise the rate is taken from the two
columns, as for the CSV export.

## Examples

``` r
path <- system.file("extdata", "idtracker.csv", package = "aniread")
read_idtracker(path)
#> # Individuals:   1, 2, 3, 4, 5, 6, 7, 8
#> # Keypoints:     centroid
#> # Sampling rate: 28 Hz
#> # Time:          00:00:00.000 to 00:00:00.321
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
