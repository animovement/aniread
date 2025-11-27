# Read optical flow sensor file

Read optical flow sensor data.

## Usage

``` r
read_opticalflow(path, col_time, verbose = FALSE)
```

## Arguments

- path:

  Path to the file.

- col_time:

  Which column contains the information about time. Can be specified
  either by the column number (numeric) or the name of the column if it
  has one (character). Should either be a datetime (POSIXt) or seconds
  (numeric).

- verbose:

  If `FALSE` (default), suppress most warning messages.
