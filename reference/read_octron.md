# Read Octron Segmentation Data

Reads CSV files exported from Octron video segmentation software. The
function parses the metadata header and returns tracking data as an
aniframe with centroid positions, bounding box corners, and shape
descriptors. Octron stores positions in image (top-left) coordinates;
the reader reflects y so the returned aniframe is in the conventional
`bottom_left` origin. The frame height is read from the CSV header
(`video_height:`) by default.

## Usage

``` r
read_octron(
  path,
  keep_bbox = FALSE,
  video_height = NULL,
  method = c("weighted", "largest", "segments")
)
```

## Arguments

- path:

  Path to the Octron CSV file.

- keep_bbox:

  Keep bounding box coordinates? Default FALSE.

- video_height:

  Optional numeric height of the source video frame in pixels. Overrides
  the value parsed from the CSV header when both are available.

- method:

  Strategy for resolving frames where Octron emitted multiple mask
  segments per track. One of:

  - `"weighted"` (default): area-weighted mean across all segments per
    row. `area` becomes the sum of segment areas; `orientation` falls
    back to `"largest"` (circular quantity, weighted mean is undefined).

  - `"largest"`: take values from the single largest segment per row.

  - `"segments"`: expand each multi-segment row into one row per
    segment, adding a `segment` identity variable. Segments are not
    matched across frames, so filtering on `segment` is generally not
    meaningful.

  When the source CSV contains no tuple-valued rows, all three methods
  produce identical numeric output.

## Value

An aniframe

## Details

Newer Octron exports (\>= the multi-blob handling in [OCTRON-GUI
\#63](https://github.com/OCTRON-tracking/OCTRON-GUI/issues/63)) may emit
per-segment columns as tuple-strings, e.g. `"(120.5, 85.3)"`, when YOLO
detects multiple disconnected mask segments belonging to the same track
in a single frame. The `method` argument controls how those rows are
reduced to scalar values, or whether they are expanded into one row per
segment.
