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

- `time`: Frame number, Anipose's `fnum`, with the first frame of the
  video at 0; see "Time" in
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)

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

## References

- Karashchuk, P., Rupp, K. L., Dickinson, E. S., Walling-Bell, S.,
  Sanders, E., Azim, E., Brunton, B. W., & Tuthill, J. C. (2021).
  Anipose: A toolkit for robust markerless 3D pose estimation. *Cell
  Reports*, 36(13), 109730.
  [doi:10.1016/j.celrep.2021.109730](https://doi.org/10.1016/j.celrep.2021.109730)
  .

## Examples

``` r
path <- system.file("extdata", "anipose.csv", package = "aniread")

# Read anipose data with default millimeter units
read_anipose(path)
#> # Keypoints: l-base, r-base
#>    keypoint  time     x     y     z confidence
#>    <fct>    <dbl> <dbl> <dbl> <dbl>      <dbl>
#>  1 l-base       0 -5.63  2.59  311.      0.934
#>  2 l-base       1 -4.82  3.24  309.      0.959
#>  3 l-base       2 -5.84  3.37  307.      0.822
#>  4 l-base       3 -3.40  3.29  304.      0.945
#>  5 l-base       4 -4.67  2.85  310.      0.882
#>  6 r-base       0 -5.08  3.47  313.      0.978
#>  7 r-base       1 -5.22  3.42  310.      0.973
#>  8 r-base       2 -5.92  2.76  311.      0.878
#>  9 r-base       3 -7.99  3.26  310.      0.955
#> 10 r-base       4 -5.38  3.71  307.      0.992

# Read with centimeter units
read_anipose(path, unit_space = "cm")
#> # Keypoints: l-base, r-base
#>    keypoint  time     x     y     z confidence
#>    <fct>    <dbl> <dbl> <dbl> <dbl>      <dbl>
#>  1 l-base       0 -5.63  2.59  311.      0.934
#>  2 l-base       1 -4.82  3.24  309.      0.959
#>  3 l-base       2 -5.84  3.37  307.      0.822
#>  4 l-base       3 -3.40  3.29  304.      0.945
#>  5 l-base       4 -4.67  2.85  310.      0.882
#>  6 r-base       0 -5.08  3.47  313.      0.978
#>  7 r-base       1 -5.22  3.42  310.      0.973
#>  8 r-base       2 -5.92  2.76  311.      0.878
#>  9 r-base       3 -7.99  3.26  310.      0.955
#> 10 r-base       4 -5.38  3.71  307.      0.992

```
