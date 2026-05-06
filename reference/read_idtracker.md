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
