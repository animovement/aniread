# Fill empty time bins with zero motion

The COM port emits no row while the ball is still, so binned data has
holes. Back-fill them with zeros so the returned time grid is regular.
Used by both the one- and two-sensor paths, which would otherwise
disagree on the grid for the same gappy input.

## Usage

``` r
fill_missing_time_groups(data, zero_cols)
```

## Arguments

- data:

  Binned data with a `time_group` column.

- zero_cols:

  Columns to set to zero in the inserted rows.
