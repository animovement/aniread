# Read a DeepLabCut h5 file

Reads the pandas DataFrame under the key `df_with_missing` (predictions)
or `tracks` (stitched tracklets), stored in pandas' "table" format, as
DeepLabCut writes it, or its "fixed" format, as pandas writes by
default.

## Usage

``` r
read_deeplabcut_h5(path)
```

## Arguments

- path:

  Path to a DeepLabCut `.h5` file.

## Value

A list of `columns`, a data frame with one row per kept column and one
column per level; `values`, a frames-by-columns matrix; and `index`, the
frame index.
