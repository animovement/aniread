# Read SLEAP data

SLEAP stores predictions in image (top-left) coordinates; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin. SLEAP's analysis h5 export does not include the source video
resolution, so pass `video_height` to get an accurate flip — otherwise
`max(y)` is used as a fallback.

## Usage

``` r
read_sleap(path, video_height = NULL)
```

## Arguments

- path:

  A SLEAP analysis data frame in HDF5 (.h5) format

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

a movement dataframe
