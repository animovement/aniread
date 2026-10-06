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

  An aniframe containing tracking data with its index (usually `time`)
  and `x` and `y`. Optional columns are `z` for 3D data, `parent` for
  lineage and `frame` for recorded frame numbers (see Details).

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

- `t`: The frame number of each row, counted from 0 (see below)

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

inTRACKtive reads `t` as whole frames counted from 0, so the index is
written in frames, as
[`anicore::convert_unit_time()`](https://animovement.dev/anicore/reference/convert_unit_time.html)
gives them with `"frame"`:

- A frame whose `unit_time` is `"frame"` is written as it is. Its times
  must be whole numbers.

- A frame whose time is in another unit, such as seconds or minutes, is
  converted to frames with its `sampling_rate`, so that the frame at
  time 0 is `t = 0`: at 30 Hz, times of 0, 1/30 and 2/30 seconds are
  written as 0, 1 and 2. A frame with a column named `frame` holding the
  recorded frame numbers, as
  [`anicore::set_index()`](https://animovement.dev/anicore/reference/set_index.html)
  keeps them, is written with those.

The writer stops rather than write frame numbers it would have to
invent: when the time is not in frames and no `sampling_rate` is
declared, or when the times are not regularly spaced at that rate.
Declare the rate with `anicore::set_metadata(data, sampling_rate = )`,
or keep the recorded frame numbers in a column named `frame`. `data`
itself is not changed.

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
