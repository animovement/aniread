# Read TRex Movement Tracking Data

Reads movement tracking data exported from TRex (Walter & Couzin, 2021),
from either of its two exports.

The `.npz` export is TRex's native one: a zip of `.npy` arrays, one file
per tracked individual, so a whole recording is a vector of paths. It
carries the pose keypoints, a per-frame detection probability, the
identity, and the recording's frame rate and frame size. The CSV export
carries the centroid and midline of a single individual and none of that
metadata, so several columns come back `NA`.

## Usage

``` r
read_trex(path, format = c("auto", "csv", "npz"), video_height = NULL)
```

## Arguments

- path:

  Character string specifying the path to a TRex CSV file. The file
  should contain columns for:

  - time

  - x and y coordinates for tracked points (e.g., x_head, y_head)

  - x and y coordinates for centroid (x_number_wcentroid_cm,
    y_number_wcentroid_cm)

- format:

  Which export to read. `"auto"` (default) reads it from the file: the
  `.npz` export is a zip of `.npy` arrays, the CSV export is not.

- video_height:

  Optional numeric height of the source video frame in the same spatial
  units as the tracking output (TRex defaults to centimetres). The
  `.npz` export records this as `video_size` and it is used
  automatically; TRex's CSV export does not, so without it `max(y)` is
  used as a fallback when reflecting to `bottom_left`.

## Value

A data frame containing movement data with the following columns:

- `time`: Time values from the tracking

- `individual`: Factor. The identity TRex assigned, from the `.npz`
  export; `NA` from the CSV export, which does not record it

- `keypoint`: Factor identifying tracked points (e.g., "head",
  "centroid")

- `x`: x-coordinates in centimeters

- `y`: y-coordinates in centimeters

- `confidence`: Numeric. TRex's per-frame `detection_p` from the `.npz`
  export; `NA` from the CSV export, which does not record it

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
# TRex's native export: one .npz per tracked individual
path <- system.file("extdata", "trex_id3.npz", package = "aniread")
read_trex(path)
#> # Individuals:   3
#> # Keypoints:     centroid, pose0, pose1
#> # Sampling rate: 30 Hz
#> # Time:          00:00:00.000 to 00:00:00.133
#>    individual keypoint   time     x     y confidence
#>    <fct>      <fct>     <dbl> <dbl> <dbl>      <dbl>
#>  1 3          centroid 0       10    28        0.900
#>  2 3          centroid 0.0333  10.5  27.5      0.850
#>  3 3          centroid 0.0667  NA    NA       NA    
#>  4 3          centroid 0.100   11.5  26.5      0.800
#>  5 3          centroid 0.133   12    26        0.950
#>  6 3          pose0    0       10    28        0.900
#>  7 3          pose0    0.0333  10.5  27.5      0.850
#>  8 3          pose0    0.0667  NA    NA       NA    
#>  9 3          pose0    0.100   11.5  26.5      0.800
#> 10 3          pose0    0.133   12    26        0.950
#> 11 3          pose1    0       11    27        0.900
#> 12 3          pose1    0.0333  11.5  26.5      0.850
#> 13 3          pose1    0.0667  NA    NA       NA    
#> 14 3          pose1    0.100   12.5  25.5      0.800
#> 15 3          pose1    0.133   13    25        0.950

if (FALSE) { # \dontrun{
# A whole recording is the vector of paths get_sample_data() returns
read_trex(get_sample_data("trex"))
} # }
```
