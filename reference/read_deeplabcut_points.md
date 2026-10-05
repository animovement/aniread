# Read the points of a DeepLabCut file into long format

Read the points of a DeepLabCut file into long format

## Usage

``` r
read_deeplabcut_points(path)
```

## Arguments

- path:

  Path to a DeepLabCut `.csv` or `.h5` file.

## Value

A tibble with `time`, `individual` (multi-animal files only),
`keypoint`, `x`, `y`, `z` (3D files only) and `confidence`.
