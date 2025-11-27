# Read Anipose 3D pose estimation data

Reads CSV files output by Anipose's 3D triangulation pipeline and
converts them into aniframe format. The function handles the pivot from
wide format (one column per keypoint-coordinate combination) to long
format with separate rows for each keypoint at each time point.

## Usage

``` r
read_anipose(path, unit_space = "mm")
```

## Arguments

- path:

  Character string specifying the path to an Anipose CSV file. Typically
  these are found in the `pose-3d` directory of your Anipose output.

- unit_space:

  Character string specifying the spatial units of the coordinates. This
  should match the units you used for your calibration board dimensions
  (e.g., "mm", "cm", "m"). Default is "mm".

## Value

An aniframe (tibble) with the following columns:

- `time`: Frame number

- `keypoint`: Name of the tracked body part

- `x`, `y`, `z`: 3D coordinates in the specified units

- `confidence`: Mean detection confidence across cameras (0-1 scale)

The aniframe includes metadata about the data source, filename, spatial
units, and coordinate system.

## Anipose Data Structure

Anipose outputs CSV files with columns like `bodypart_x`, `bodypart_y`,
`bodypart_z`, `bodypart_error`, `bodypart_ncams`, and `bodypart_score`
for each tracked keypoint. The coordinates are in whatever units you
specified for your calibration board dimensions.

## Examples

``` r
if (FALSE) { # \dontrun{
# Read anipose data with default millimeter units
pose_data <- read_anipose("path/to/pose-3d/trial001.csv")

# Read with centimeter units
pose_data <- read_anipose("path/to/pose-3d/trial001.csv", unit_space = "cm")
} # }

```
