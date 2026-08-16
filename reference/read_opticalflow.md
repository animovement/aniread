# Read optical flow sensor file

Read a single optical flow sensor file.

Time is returned on an **absolute** scale (epoch seconds when the time
column is a datetime, otherwise the raw device clock scaled to seconds).
Choosing an origin is left to the caller: with two sensors, the offset
between the files is the only thing
[`join_trackball_files()`](http://animovement.dev/aniread/reference/join_trackball_files.md)
has to align them on, so zeroing each file to its own start here would
destroy it.

## Usage

``` r
read_opticalflow(path, col_time, col_dx, col_dy, quiet = TRUE)
```

## Arguments

- path:

  Path to the file.

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

- quiet:

  If `TRUE` (default), suppresses informational messages such as the
  count of malformed rows dropped from each file.

## Value

A data frame with columns `time`, `dx` and `dy`, carrying a
`start_datetime` attribute. The attribute is `NA` when the time column
was not a real clock, which is also how the caller detects a
sensor-local device counter.
