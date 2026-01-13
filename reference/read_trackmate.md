# Read TrackMate XML into an aniframe

Parses a TrackMate XML file and returns spot data from filtered tracks
as an aniframe.

## Usage

``` r
read_trackmate(path, slim = TRUE)
```

## Arguments

- path:

  Path to the TrackMate XML file.

- slim:

  If TRUE, return only essential columns (default TRUE).

## Value

An aniframe with columns including time, x, y, z, frame, and track_id.
