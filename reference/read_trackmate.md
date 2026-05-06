# Read TrackMate XML into an aniframe

Parses a TrackMate XML file and returns spot data from filtered tracks
as an aniframe. TrackMate stores spot coordinates in image (top-left)
coordinates; the reader reflects y so the returned aniframe is in the
conventional `bottom_left` origin. The frame height is read from
`Settings/ImageData/@height` in the XML by default.

## Usage

``` r
read_trackmate(path, slim = TRUE, video_height = NULL)
```

## Arguments

- path:

  Path to the TrackMate XML file.

- slim:

  If TRUE, return only essential columns (default TRUE).

- video_height:

  Optional numeric height of the source frame in the units reported by
  the XML. Overrides the value parsed from `Settings/ImageData/@height`
  when both are available.

## Value

An aniframe with columns including time, x, y, z, frame, and track_id.
