# Compute the area-weighted mean across segments per row.

Vectorised via `rowsum`. Rows whose `values_list` and `areas_list` have
different segment counts trigger a single summarised warning and fall
back to the arithmetic mean of the value vector - protecting callers
from the silent recycling that would otherwise occur in `v * a`. Falls
back to the arithmetic mean when areas are absent or sum to 0.

## Usage

``` r
resolve_weighted(values_list, areas_list, .warn_mismatch = TRUE)
```
