# Write aniframe data to inTRACKtive CSV format

Converts an aniframe to the CSV format required by inTRACKtive for
browser-based interactive visualization of tracking data. The function
creates unique integer track identifiers from combinations of grouping
columns present in the data.

## Usage

``` r
write_intracktive(data, filename, quiet = FALSE)
```

## Arguments

- data:

  An aniframe containing tracking data with required columns `time`,
  `x`, and `y`. Optional columns include `z` for 3D data and grouping
  columns (`session`, `trial`, `model`, `individual`, `keypoint`).

- filename:

  File path to write the CSV.

- quiet:

  Suppress messages. TRUE/FALSE. Defaults to FALSE.

## Value

Returns the input data unchanged.

## Details

inTRACKtive requires tracking data with a unique integer `track_id` for
each tracked object. This function automatically generates track IDs
from any combination of aniframe grouping columns that are present in
the data.

The output format includes:

- `track_id`: Integer identifier for each unique track

- `t`: Time values (renamed from `time`)

- `x`, `y`: Spatial coordinates

- `z`: Optional third dimension if present

The resulting CSV can be converted to inTRACKtive's Zarr format using
their command-line tools or Python package.

## References

Huijben, T.A.P.M., Anderson, A.G., Sweet, A. et al. (2025). inTRACKtive:
a web-based tool for interactive cell tracking visualization. Nature
Methods.

## Examples

``` r
if (FALSE) { # \dontrun{
# Write aniframe to inTRACKtive CSV
write_intracktive(my_data, "tracks.csv")

# Get formatted data without writing
formatted <- write_intracktive(my_data)
} # }
```
