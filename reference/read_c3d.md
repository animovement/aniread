# Read a C3D motion capture file

Reads a C3D file and returns the data as an aniframe with associated
metadata including source software, units, and sampling rate.

## Usage

``` r
read_c3d(path)
```

## Arguments

- path:

  Path to a `.c3d` file.

  C3D numbers frames from 1, and a file's header records the frame of
  the recording its first frame is, which is not frame 1 when the
  recording was trimmed. `time` is in seconds from the first frame of
  the recording, so a file that starts at frame 1 starts at `time = 0`,
  and one trimmed to start at frame 705 of a 200 Hz recording starts at
  3.52 s. A recording longer than 65535 frames records its first frame
  in the `TRIAL` group's `ACTUAL_START_FIELD` parameter instead, which
  is used when it is there.

## Value

An aniframe with columns `time`, `keypoint`, `x`, `y`, and `z`. Metadata
includes source software, filename, time/space units, and sampling rate.
`time` is in seconds, with the first frame of the recording at 0; see
"Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## See also

[`c3dr::c3d_read()`](https://docs.ropensci.org/c3dr/reference/c3d_read.html)
for lower-level C3D access.
