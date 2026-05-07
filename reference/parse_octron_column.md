# Parse a column of mixed scalars and tuple-strings into a list of numeric vectors (one per row).

Vectorised: tuple entries are stripped of parentheses and split on `,`
in one shot, then converted with `as.numeric` (which trims whitespace).
Scalar entries are converted in bulk. NA entries map to `NA_real_`.

## Usage

``` r
parse_octron_column(col)
```
