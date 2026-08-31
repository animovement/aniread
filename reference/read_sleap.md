# Read SLEAP data

Reads either of SLEAP's analysis exports: the HDF5 file, or the CSV with
columns `track`, `frame_idx`, `instance.score` and a `.x`/`.y`/`.score`
triple per node.

## Usage

``` r
read_sleap(path, video_height = NULL)
```

## Arguments

- path:

  A SLEAP analysis file, either HDF5 (`.h5`) or CSV.

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

a movement dataframe

## Details

SLEAP stores predictions in image (top-left) coordinates; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin. Neither export includes the source video resolution, so pass
`video_height` to get an accurate flip — otherwise `max(y)` is used as a
fallback.

`individual` is the track name SLEAP recorded, from either export. A
recording with no tracks - a single unnamed instance, or predictions
that were never tracked - has no names to use, and falls back to
`individual1`, `individual2`, and so on.
