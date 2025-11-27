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
  ball_calibration = NULL,
  ball_diameter = NULL,
  distance_scale = NULL,
  distance_unit = NULL,
  verbose = FALSE
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

- ball_calibration:

  When running an `of_fixed` experiment, you may (but it is not
  necessary) provide a calibration factor. This factor is the number
  recorded after a 360 degree spin. You can use the
  `calibrate_trackball` function to get this number. Alternatively,
  provide the `ball_diameter` and a `distance_scale` (e.g. mouse dpcm).

- ball_diameter:

  When running a `of_fixed` experiment, the ball diameter is needed
  together with either `ball_calibration` or `distance_scale`.

- distance_scale:

  If using computer mice, you might be getting unit-less data out.
  However, computer mice have a factor called "dots-per-cm", which you
  can use to convert your estimates into centimeters.

- distance_unit:

  Which unit should be used. If `distance_scale` is also used, the unit
  will be for the scaled data. E.g. for trackball data with optical flow
  sensors, you can use the mouse dots-per-cm (dpcm) of 394 by setting
  `distance_unit = "cm"` and `distance_scale = 394`.

- verbose:

  If `FALSE` (default), suppress most warning messages.

## Value

a movement dataframe
