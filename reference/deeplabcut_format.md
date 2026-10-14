# Name the DeepLabCut layout a file was read as

The file type, then single- or multi-animal (a multi-animal file has an
`individuals` header level), then `_3d` for triangulated positions, e.g.
`"csv_multi_animal"` or `"h5_single_animal_3d"`.

## Usage

``` r
deeplabcut_format(path, points)
```

## Arguments

- path:

  Path to the file.

- points:

  The points read from it, as from
  [`read_deeplabcut_points()`](https://animovement.dev/aniread/reference/read_deeplabcut_points.md).

## Value

A string, one of
[`deeplabcut_formats()`](https://animovement.dev/aniread/reference/deeplabcut_formats.md).
