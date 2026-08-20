# Format detectors

One predicate per supported format, each returning `TRUE` when the file
at `path` was written by that source software. See
[`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
for the contract they follow and how they are dispatched.

## Usage

``` r
detect_animalta_file(path)

detect_anipose_file(path)

detect_bonsai_file(path)

detect_boris_file(path)

detect_freemocap_file(path)

detect_octron_file(path)

detect_trex_file(path)

detect_fasttrack_file(path)

detect_fictrac_file(path)

detect_trackball_file(path)

detect_deeplabcut_file(path)

detect_lightningpose_file(path)

detect_idtrackerai_file(path)

detect_sleap_file(path)

detect_movement_file(path)

detect_trackmate_file(path)

detect_c3d_file(path)

detect_aniframe_file(path)
```

## Arguments

- path:

  Path to the file.

## Value

`TRUE` when the file matches the format, otherwise `FALSE`.
