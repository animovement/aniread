# Detect whether a numeric clock is in microseconds

A device clock in microseconds ticks in the thousands between samples,
so the median positive step separates it from a clock already in
seconds. Zero-length steps (duplicated timestamps) and `NA`s are
excluded: with enough repeats the plain median is 0, microseconds are
never detected, and the resulting time groups explode.

## Usage

``` r
detect_time_divisor(t)
```

## Arguments

- t:

  Numeric timestamps.

## Value

`1e6` for a microsecond clock, otherwise `1`.
