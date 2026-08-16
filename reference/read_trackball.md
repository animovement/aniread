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
  (numeric). **With two sensors, this must be a clock the two sensors
  share.** In a Bonsai capture that is the PC datetime (column 4), not
  the per-board device counter (column 3), whose origin is sensor-local
  and therefore cannot be used to cross-reference the two files. A
  warning is emitted if `col_time` resolves to a non-datetime column
  with two sensors.

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

  If `TRUE` (default), suppresses informational messages such as the
  count of malformed rows dropped from each file.

## Value

a movement dataframe

## Details

Raw Bonsai optical-flow captures are headerless CSV files, optionally
preceded by a single line of serial-port junk, with the layout
`dx, dy, device_clock_us, pc_datetime, interval_s`. Address their
columns by number (`col_dx = 1`, `col_dy = 2`, `col_time = 4`).

Such captures are not gap-free: on this rig the COM port emits no row
while the ball is still, so multi-second gaps are normal. Readings are
integrated into `1 / sampling_rate` windows, and windows containing no
reading are filled with zero motion so the returned time grid is regular
regardless of the gaps in the input. Note that this treats a missing
sample as *no motion*, which is a property of this logger rather than of
optical flow in general; a sensor that drops samples for other reasons
would need its gaps treated as missing data instead.

With two sensors the output covers only the intersection of the two
recordings - readings from before the second sensor started, or after
the first stopped, are discarded rather than zero-filled. `time = 0` is
the first shared sample, and the `start_datetime` metadata is the
wall-clock instant of that sample.
