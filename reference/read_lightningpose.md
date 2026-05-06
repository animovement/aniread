# Read LightningPose data

Read csv files from LightningPose (LP). Like DeepLabCut, the source is
in image (top-left) coordinates and the reader reflects y to
`bottom_left`.

## Usage

``` r
read_lightningpose(path, video_height = NULL)
```

## Arguments

- path:

  Path to a LightningPose data file

- video_height:

  Optional numeric height of the source video frame in pixels. Falls
  back to `max(y)` when not supplied.

## Value

an aniframe
