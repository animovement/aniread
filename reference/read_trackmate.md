# Read TrackMate XML into an aniframe

Parses a TrackMate XML file and returns spot data from filtered tracks
as an aniframe. TrackMate stores spot coordinates in image (top-left)
coordinates; the reader reflects y so the returned aniframe is in the
conventional `bottom_left` origin. The frame height is read from
`Settings/ImageData` in the XML by default: `height` is in pixels and
`pixelheight` in `spatialunits`, so their product is the height in the
unit of the positions. Without a `pixelheight`, `height` is used as it
is.

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

  Optional numeric height of the source frame in the spatial unit
  reported by the XML. Overrides the height read from
  `Settings/ImageData` when both are available.

## Value

An aniframe with columns including `time`, `track`, `keypoint`,
`parent`, `x`, `y`, `z` and `frame`.

## Details

Each track is identified in `track` by the name TrackMate gave it.
TrackMate names tracks `Track_0`, `Track_1`, ..., and the column already
says they are tracks, so a name of that form becomes its number alone:
`Track_12` is read as `12`. A name you gave a track in TrackMate,
anything not of the form `Track_<number>`, is kept as written. Each
track's name is read on its own, so a file in which you renamed some
tracks gives, say, `0`, `2` and `Cell A`. The numeric `TRACK_ID` is used
instead when any track has no name, or, with a warning, when two tracks
would get the same id (such as a track you renamed `3` beside
`Track_3`). The levels of `track` are the numbers in numeric order, `2`
before `10`, followed by any names sorted as text (capitals first, in
every locale).

A track that divides, as a cell lineage does, holds more than one spot
in a frame from its first division on, which a frame keyed by `track`
and `time` cannot hold. Such a track is split into its branches, each
the stretch of the track between divisions, and each branch becomes a
track of its own. The `parent` column records the lineage, as cell
tracking does (the `P` of the Cell Tracking Challenge's `res_track.txt`,
Ultrack's `parent_track_id`): it holds the id of the track a track
divided from, and is `NA` for a track that did not divide from another,
so for every track of a file without divisions. The branch before the
first division keeps the track's id. The other branches are numbered on
from the largest number that identifies any track in the file, by
`TRACK_ID` or by name, so a new id never names another track you can see
in TrackMate. They are numbered track by track, in the order of the
tracks' ids, and within a track by the frame they start in, then by the
id of the track they divided from, so sisters are numbered together,
then by x and y. A daughter starts at its first spot after the division,
so nothing is measured across it. A track whose branches also merge, or
whose spots share a frame in any other way, is left whole, with a
warning about the duplicate track-frame combinations. A split or merge
that never puts two spots in one frame, as when a link skips a frame
beside another that does not, needs no splitting.

`parent` is not an identity key: the keys are `track` and `keypoint`. It
is a factor with the same levels as `track`, so its values match the ids
in `track`. One row per track gives the lineage, as the Cell Tracking
Challenge's `L B E P` table (label, first and last time, parent). The
frame is grouped by its keys, so drop to a plain tibble first:

    data |>
      dplyr::as_tibble() |>
      dplyr::summarise(
        start = min(time),
        end = max(time),
        parent = dplyr::first(parent),
        .by = track
      )

The XML also records how the image was calibrated, and the reader keeps
what has a place in the metadata:

- `timeunits` and `spatialunits`, from the `Model` element, become
  `unit_time` and `unit_space`. TrackMate takes them from the image's
  calibration in ImageJ, where they are free text, so the usual
  spellings are recognised: `"sec"`, `"msec"`, `"min"`, `"frame"` and so
  on for time, `"pixel"`, `"micron"`, `"um"` (with or without the micro
  sign), `"mm"` and so on for space. A unit with no equivalent in
  anicore (days or inches, say) becomes `"unknown"` or `"none"`, with a
  warning, rather than stopping the read. A blank spatial unit, which
  TrackMate writes for an image whose length unit is a space, is read as
  pixels when the pixel size in `Settings/ImageData` is 1 or not
  recorded, as ImageJ calls an image with no length unit `"pixel"`. With
  any other pixel size the positions are scaled by a unit nobody named,
  so it becomes `"none"` with a warning.

- `timeinterval`, from `Settings/ImageData`, is the time between frames
  in `timeunits`. Its reciprocal, converted to Hz, becomes
  `sampling_rate`. It stays `NA` when the interval is missing or not
  positive, or when the time unit is frames or not recognised.

- `version`, from the root element, is the TrackMate version that wrote
  the file and becomes `source_version`.

TrackMate cannot tell an uncalibrated image from one calibrated at one
second per frame. An image with no time calibration has a frame interval
of 0, which TrackMate replaces with 1, and ImageJ's default time unit is
`"sec"`. A file with `timeunits = "sec"` and `timeinterval = 1` may
therefore really count frames, in which case `time` is the frame number
and the 1 Hz `sampling_rate` is not the camera's. If you know the real
rate, set it with
[`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html).

## Examples

``` r
# A cell that divides into tracks 1 and 2, whose parent is track 0
path <- system.file("extdata", "trackmate.xml", package = "aniread")
data <- read_trackmate(path)
#> ✔ Loaded 7 spots from 3 tracks.
data
#> # Tracks:        0, 1, 2
#> # Keypoints:     centroid
#> # Sampling rate: 0.008333333 Hz
#> # Time:          00:12:00 to 00:20:00
#>   track keypoint  time     x     y parent
#>   <fct> <fct>    <dbl> <dbl> <dbl> <fct> 
#> 1 0     centroid    12  30.0  15.4 NA    
#> 2 0     centroid    14  29.7  16.0 NA    
#> 3 0     centroid    16  23.1  16.3 NA    
#> 4 1     centroid    18  22.6  19.5 0     
#> 5 1     centroid    20  21.8  21.3 0     
#> 6 2     centroid    18  24.6  13.9 0     
#> 7 2     centroid    20  25.3  13.0 0     

# The lineage: one row per track, with the track it divided from
data |>
  dplyr::as_tibble() |>
  dplyr::summarise(
    start = min(time),
    end = max(time),
    parent = dplyr::first(parent),
    .by = track
  )
#> # A tibble: 3 × 4
#>   track start   end parent
#>   <fct> <dbl> <dbl> <fct> 
#> 1 0        12    16 NA    
#> 2 1        18    20 0     
#> 3 2        18    20 0     
```
