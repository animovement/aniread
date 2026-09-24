# Read centroid tracking data from Bonsai

Read a Bonsai data frame. Bonsai centroid coordinates come from
camera/video pipelines that use image (top-left) origin; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin. Bonsai workflows are user-defined and the output CSV does not
record video resolution, so pass `video_height` to get an accurate flip
— otherwise `max(y)` is used as a fallback.

When the workflow records the blob's `Orientation`, it is kept as
`orientation_axis`: the angle of the blob's long axis, in radians from
`x` toward `y`, in `(-pi/2, pi/2]`. It is axial — the blob has no front
— so it is not declared as the frame's orientation (a `yaw`), and it is
turned with `y` when y is reflected.

## Usage

``` r
read_bonsai(path, video_height = NULL)
```

## Arguments

- path:

  Path to a Bonsai data file

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

a movement dataframe

## Examples

``` r
path <- system.file("extdata", "bonsai.csv", package = "aniread")
read_bonsai(path)
#> # Individuals: NA
#> # Keypoints:   centroid
#>    individual keypoint   time     x      y confidence orientation_axis
#>    <fct>      <fct>     <dbl> <dbl>  <dbl>      <dbl>            <dbl>
#>  1 NA         centroid 0       153.  0.828         NA          -0.0356
#>  2 NA         centroid 0.0234  153. 49.6           NA          -0.213 
#>  3 NA         centroid 0.0554  153. 50.4           NA          -0.220 
#>  4 NA         centroid 0.0859  153. 48.7           NA          -0.207 
#>  5 NA         centroid 0.117   153. 40.9           NA          -0.176 
#>  6 NA         centroid 0.162   153. 40.0           NA          -0.191 
#>  7 NA         centroid 0.194   154.  0.666         NA          -0.0296
#>  8 NA         centroid 0.226   153.  0.583         NA          -0.0365
#>  9 NA         centroid 0.260   153.  0             NA          -0.0344
#> 10 NA         centroid 0.292   154.  0.281         NA          -0.0344
```
