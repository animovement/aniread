# Parse DLC pickle string to extract column order

Parse DLC pickle string to extract column order

## Usage

``` r
parse_dlc_pickle(pickle_str, multianimal = FALSE)
```

## Arguments

- pickle_str:

  The values_block_0_kind attribute string

- multianimal:

  Whether this is a multi-animal dataset

## Value

A tibble with bodypart, coord columns (and individual if multi-animal)
