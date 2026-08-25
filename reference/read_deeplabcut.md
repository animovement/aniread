# Read DeepLabCut data

Read files from DeepLabCut (DLC) in either csv or h5 format. DeepLabCut
stores predictions in image (top-left) coordinates; the reader reflects
y so the returned aniframe is in the conventional `bottom_left` origin.
DLC's csv/h5 exports do not contain the source video resolution (it
lives in the project's `config.yaml`), so pass `video_height` to get an
accurate flip — otherwise `max(y)` is used as a fallback.

## Usage

``` r
read_deeplabcut(path, video_height = NULL)
```

## Arguments

- path:

  Path to a DeepLabCut data file

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

an aniframe

## Examples

``` r
path <- system.file("extdata", "deeplabcut.csv", package = "aniread")
read_deeplabcut(path)
#> # Keypoints: head, stinger
#>    keypoint  time     x     y confidence
#>    <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 head         0 1086.  7.05     0.0531
#>  2 head         1 1086.  7.00     0.0353
#>  3 head         2 1086.  6.74     0.0171
#>  4 head         3 1085.  5.96     0.238 
#>  5 head         4 1085.  6.06     0.502 
#>  6 head         5 1085.  6.01     0.510 
#>  7 head         6 1085.  5.77     0.835 
#>  8 head         7 1084.  4.83     0.662 
#>  9 head         8 1084.  4.90     0.461 
#> 10 head         9 1084.  3.85     0.934 
#> 11 stinger      0 1084.  7.24     0.0737
#> 12 stinger      1 1083.  7.09     0.0329
#> 13 stinger      2 1083.  6.94     0.0102
#> 14 stinger      3 1082.  2.87     0.173 
#> 15 stinger      4 1079.  1.34     0.269 
#> 16 stinger      5 1078.  1.65     0.284 
#> 17 stinger      6 1077.  1.25     0.802 
#> 18 stinger      7 1076.  1.75     0.621 
#> 19 stinger      8 1076.  2.13     0.351 
#> 20 stinger      9 1076.  0        0.942 
```
