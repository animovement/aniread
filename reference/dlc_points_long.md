# Turn DeepLabCut's wide layout into one row per point and frame

Turn DeepLabCut's wide layout into one row per point and frame

## Usage

``` r
dlc_points_long(wide)
```

## Arguments

- wide:

  A list of `columns`, `values` and `index`, as from
  [`read_deeplabcut_csv()`](https://animovement.dev/aniread/reference/read_deeplabcut_csv.md)
  or
  [`read_deeplabcut_h5()`](https://animovement.dev/aniread/reference/read_deeplabcut_h5.md).

## Value

A tibble with `time`, `individual` (when the header has an `individuals`
level), `keypoint`, `x`, `y`, `z` (when present) and `confidence`, which
is `NA` when the file has no likelihood.
