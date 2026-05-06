# Read centroid tracking data from Bonsai

Read a Bonsai data frame. Bonsai centroid coordinates come from
camera/video pipelines that use image (top-left) origin; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin. Bonsai workflows are user-defined and the output CSV does not
record video resolution, so pass `video_height` to get an accurate flip
— otherwise `max(y)` is used as a fallback.

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
