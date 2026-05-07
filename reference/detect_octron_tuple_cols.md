# Detect columns that contain tuple-strings (e.g. "(120.5, 85.3)")

Walks each character column once with a fast `is.na` + `startsWith` bulk
pass and stops at the first hit. Avoids
[`stats::na.omit`](https://rdrr.io/r/stats/na.fail.html), which
allocates a `na.action` attribute over every NA index — measurable on a
1.85M-row file with ~60 character columns.

## Usage

``` r
detect_octron_tuple_cols(data)
```
