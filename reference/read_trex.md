# Read TRex Movement Tracking Data

Reads and formats movement tracking data exported from TRex (Walter &
Couzin, 2021). TRex is a software for tracking animal movement in
videos, which exports coordinate data in CSV format. This function
processes these files into a standardized movement data format.

## Usage

``` r
read_trex(path)
```

## Arguments

- path:

  Character string specifying the path to a TRex CSV file. The file
  should contain columns for:

  - time

  - x and y coordinates for tracked points (e.g., x_head, y_head)

  - x and y coordinates for centroid (x_number_wcentroid_cm,
    y_number_wcentroid_cm)

## Value

A data frame containing movement data with the following columns:

- `time`: Time values from the tracking

- `individual`: Factor (set to NA, as TRex tracks one individual)

- `keypoint`: Factor identifying tracked points (e.g., "head",
  "centroid")

- `x`: x-coordinates in centimeters

- `y`: y-coordinates in centimeters

- `confidence`: Numeric confidence values (set to NA as TRex doesn't
  provide these)

## Details

The function performs several processing steps:

1.  Validates the input file format (must be CSV)

2.  Reads the data using vroom for efficient processing

3.  Cleans column names to a consistent format

4.  Restructures the data from wide to long format

5.  Initializes metadata fields required for movement data

## References

Walter, T., & Couzin, I. D. (2021). TRex, a fast multi-animal tracking
system with markerless identification, and 2D estimation of posture and
visual fields. eLife, 10, e64000.

## See also

- TRex software: https://trex.run

## Examples

``` r
if (FALSE) { # \dontrun{
# Read a TRex CSV file
data <- read_trex("path/to/trex_export.csv")
} # }
```
