# Write aniframe data to inTRACKtive CSV format

Converts an aniframe to the CSV format required by inTRACKtive for
browser-based interactive visualization of tracking data. The function
creates unique integer track identifiers from combinations of the
aniframe's identity keys, and writes the lineage of dividing tracks.

## Usage

``` r
write_intracktive(data, filename, quiet = FALSE)
```

## Arguments

- data:

  An aniframe containing tracking data with required columns `time`,
  `x`, and `y`. Optional columns are `z` for 3D data and `parent` for
  lineage (see Details).

- filename:

  File path to write the CSV.

- quiet:

  Suppress messages. TRUE/FALSE. Defaults to FALSE.

## Value

Returns the input data unchanged.

## Details

inTRACKtive requires tracking data with a unique integer `track_id` for
each tracked object. This function numbers the tracks from 1, one for
each combination of the aniframe's identity keys
([`anicore::get_keys()`](https://animovement.dev/anicore/reference/get_keys.html)),
such as `individual` and `keypoint`, or `track` and `keypoint` for a
frame read by
[`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md).

The output format includes:

- `track_id`: Integer identifier for each unique track

- `t`: Time values (renamed from `time`)

- `x`, `y`: Spatial coordinates

- `z`: Optional third dimension if present

- `parent_track_id`: Only when `data` has a `parent` column, as
  [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  gives a frame with dividing tracks. `parent` names the `track` a track
  divided from, and `parent_track_id` is that track's `track_id` (with
  the same values of the other keys), so inTRACKtive draws the lineage.
  A track with no parent gets `-1`, inTRACKtive's value for one, as does
  a track whose parent is not in `data` (with a warning). Without a
  `parent` column the column is left out, which inTRACKtive reads as no
  divisions.

inTRACKtive reads `t` as whole frames counted from 0. `time` is written
as it is, so a frame whose time is in seconds or minutes should be
converted to frames first.

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
