# Read optical flow sensor file

Read optical flow sensor data.

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
  (numeric).

- col_dx:

  Column name for x-axis values

- col_dy:

  Column name for y-axis values

- quiet:

  If `TRUE` (default), suppresses most warning messages.
