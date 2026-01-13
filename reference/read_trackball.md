# Read trackball data

Read trackball data from a variety of setups and configurations.

## Usage

``` r
read_trackball(
  paths,
  setup = c("of_free", "of_fixed"),
  sampling_rate,
  col_time = "time",
  col_dx = "x",
  col_dy = "y",
  counts_per_rotation = NULL,
  ball_diameter = NULL,
  dots_per_cm = NULL,
  quiet = TRUE
)
```

## Arguments

- paths:

  Two file paths, one for each sensor (although one is allowed for a
  fixed setup, `of_fixed`).

- setup:

  Which type of experimental setup was used. Expects either `of_free` or
  `of_fixed`.

- sampling_rate:

  Sampling rate tells the function how long time it should integrate
  over. A sampling rate of 60(Hz) will mean windows of 1/60 sec are used
  to integrate over.

- col_time:

  Which column contains the information about time. Can be specified
  either by the column number (numeric) or the name of the column if it
  has one (character). Should either be a datetime (POSIXt) or seconds
  (numeric).

- col_dx:

  Column name for x-axis values

- col_dy:

  Column name for y-axis values

- counts_per_rotation:

  For `of_fixed` setup: the sensor count for a full 360 degree rotation.
  Can be obtained using
  [`calibrate_trackball()`](http://animovement.dev/aniread/reference/calibrate_trackball.md).

- ball_diameter:

  For `of_fixed` setup: the ball diameter (in same units as desired
  output). Required if using `dots_per_cm` instead of
  `counts_per_rotation`.

- dots_per_cm:

  For `of_fixed` setup: sensor dots-per-cm. Use with `ball_diameter` as
  an alternative to `counts_per_rotation`.

- quiet:

  If `TRUE` (default), suppresses most warning messages.

## Value

a movement dataframe
