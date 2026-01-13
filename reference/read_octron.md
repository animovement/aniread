# Read Octron Segmentation Data

Reads CSV files exported from Octron video segmentation software. The
function parses the metadata header and returns tracking data as an
aniframe with centroid positions, bounding box corners, and shape
descriptors.

## Usage

``` r
read_octron(path, keep_bbox = FALSE)
```

## Arguments

- path:

  Path to the Octron CSV file.

- keep_bbox:

  Keep bounding box coordinates? Default FALSE.

## Value

An aniframe
