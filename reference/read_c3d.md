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

## Value

An aniframe with columns `time`, `keypoint`, `x`, `y`, and `z`. Metadata
includes source software, filename, time/space units, and sampling rate.
Time is 0-indexed (in frames).

## See also

[`c3dr::c3d_read()`](https://docs.ropensci.org/c3dr/reference/c3d_read.html)
for lower-level C3D access.
