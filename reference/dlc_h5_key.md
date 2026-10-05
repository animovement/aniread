# The HDF key a DeepLabCut h5 keeps its DataFrame under

The HDF key a DeepLabCut h5 keeps its DataFrame under

## Usage

``` r
dlc_h5_key(path)
```

## Arguments

- path:

  Path to an `.h5` file.

## Value

`"df_with_missing"` or `"tracks"`, whichever is a group at the root of
the file, or `NA` when neither is. SLEAP's analysis files have a
`tracks` dataset rather than a group.
