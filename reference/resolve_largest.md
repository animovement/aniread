# Pick the value of the segment with the largest area per row.

Vectorised. When a row's `areas_list` length differs from its
`values_list` length, the area vector is padded with `NA` (or truncated)
to align - so out-of-range indices can never be picked.

## Usage

``` r
resolve_largest(values_list, areas_list)
```
