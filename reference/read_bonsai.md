# Read centroid tracking data from Bonsai

Read a Bonsai data frame. Bonsai centroid coordinates come from
camera/video pipelines that use image (top-left) origin; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin.

Bonsai workflows are user-defined, so what the CSV records about the
video depends on the workflow. When it writes the image alongside the
centroid, every row carries the image's `Size.Width` and `Size.Height`.
When all the images in the file have the same size, that is the frame
size: y is reflected around its height, and its width and height are
recorded as the `axis_extents` of x and y. Otherwise pass
`video_height`, or the largest `y` is used as the height and no extent
is recorded for x.

When the workflow records the blob's `Orientation`, it is kept as
`orientation_axis`: the angle of the blob's long axis, in radians from
`x` toward `y`, in `(-pi/2, pi/2]`. It is axial — the blob has no front
— so it is not declared as the frame's orientation (a `yaw`), and it is
turned with `y` when y is reflected.

`time` is the seconds elapsed since the first `Timestamp`, so
`unit_time` is `"s"`, and the first `Timestamp` itself is kept as
`start_datetime`. `sampling_rate` is left `NA`. A Bonsai `Timestamp` is
the time the software received each frame, not when the camera captured
it, so the intervals between rows vary from frame to frame and do not
state the camera's rate. If you know it, set it with
[`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html).

## Usage

``` r
read_bonsai(path, video_height = NULL)
```

## Arguments

- path:

  Path to a Bonsai data file

- video_height:

  Optional numeric height of the source video frame in pixels. Takes
  precedence over the height the file records.

## Value

a movement dataframe

## Examples

``` r
path <- system.file("extdata", "bonsai.csv", package = "aniread")
read_bonsai(path)
#> # Individuals: NA
#> # Keypoints:   centroid
#> # Time:        2024-10-07 09:44:40.613 to 2024-10-07 09:44:40.905
#>    individual keypoint   time     x     y confidence orientation_axis
#>    <fct>      <fct>     <dbl> <dbl> <dbl>      <dbl>            <dbl>
#>  1 NA         centroid 0       153.  258.         NA          -0.0356
#>  2 NA         centroid 0.0234  153.  307.         NA          -0.213 
#>  3 NA         centroid 0.0554  153.  308.         NA          -0.220 
#>  4 NA         centroid 0.0859  153.  306.         NA          -0.207 
#>  5 NA         centroid 0.117   153.  298.         NA          -0.176 
#>  6 NA         centroid 0.162   153.  297.         NA          -0.191 
#>  7 NA         centroid 0.194   154.  258.         NA          -0.0296
#>  8 NA         centroid 0.226   153.  258.         NA          -0.0365
#>  9 NA         centroid 0.260   153.  257.         NA          -0.0344
#> 10 NA         centroid 0.292   154.  257.         NA          -0.0344
```
