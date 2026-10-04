# Read SLEAP data

Reads either of SLEAP's analysis exports: the HDF5 file, or the CSV with
columns `track`, `frame_idx`, `instance.score` and a `.x`/`.y`/`.score`
triple per node.

## Usage

``` r
read_sleap(path, video_height = NULL)
```

## Arguments

- path:

  A SLEAP analysis file, either HDF5 (`.h5`) or CSV.

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

a movement dataframe

## Details

SLEAP stores predictions in image (top-left) coordinates; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin. Neither export includes the source video resolution, so pass
`video_height` to get an accurate flip — otherwise `max(y)` is used as a
fallback.

`individual` is the track name SLEAP recorded, from either export. A
recording with no tracks - a single unnamed instance, or predictions
that were never tracked - has no names to use, and falls back to
`individual1`, `individual2`, and so on.

The `.h5` also carries the skeleton the recording was tracked with and a
record of the run, and both are kept:

- The skeleton is attached as the frame's `keypoint` structure, read as
  [`read_structure_sleap()`](https://animovement.dev/aniread/reference/read_structure.md)
  reads it: the nodes become points and the body edges segments. A file
  written without edges gives points alone.

- The SLEAP version that ran the tracking, from the file's `provenance`
  record, becomes the `source_version` metadata field. It stays `NA`
  when the file has no such record.

The CSV carries neither, so a frame read from it has no structure and no
`source_version`. Attach one with
[`read_structure()`](https://animovement.dev/aniread/reference/read_structure.md)
and
[`anicore::set_structure()`](https://animovement.dev/anicore/reference/structures.html).
