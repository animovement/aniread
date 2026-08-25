# Read idtracker.ai data

idtracker.ai stores trajectories in image (top-left) coordinates; the
reader reflects y so the returned aniframe is in the conventional
`bottom_left` origin. For h5 files the frame height is read directly
from the `/height` dataset. CSV exports do not include the frame height,
so pass `video_height` explicitly to get an accurate flip (otherwise
`max(y)` is used as a fallback).

## Usage

``` r
read_idtracker(
  path,
  path_probabilities = NULL,
  version = 6,
  video_height = NULL
)
```

## Arguments

- path:

  Path to an idtracker.ai data frame

- path_probabilities:

  Path to a csv file with probabilities. Only needed if you are reading
  csv files as they are included in h5 files.

- version:

  idtracker.ai version. Currently only v6 output is implemented

- video_height:

  Optional numeric height of the source video frame in pixels. Overrides
  the value read from the h5 file when both are available.

## Value

a movement dataframe

## Examples

``` r
path <- system.file("extdata", "idtracker.csv", package = "aniread")
read_idtracker(path)
#> # Individuals: 1, 2, 3, 4, 5, 6, 7, 8
#> # Keypoints:   centroid
#>    individual keypoint  time     x     y
#>    <fct>      <fct>    <dbl> <dbl> <dbl>
#>  1 1          centroid 0      853.  216.
#>  2 1          centroid 0.036  851.  211.
#>  3 1          centroid 0.071  850.  208.
#>  4 1          centroid 0.107  849.  203.
#>  5 1          centroid 0.143  848.  200.
#>  6 1          centroid 0.179  847.  196.
#>  7 1          centroid 0.214  846.  192.
#>  8 1          centroid 0.25   846.  189.
#>  9 1          centroid 0.286  846.  186.
#> 10 1          centroid 0.321  845.  183.
#> # ℹ 70 more rows
```
