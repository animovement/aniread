# Read a DataFrame stored in pandas' "fixed" format

Each block of columns has its values in `<key>/block<k>_values` and its
labels as a MultiIndex: per level, the unique values in
`block<k>_items_level<i>` and the codes into them in
`block<k>_items_label<i>`. The frame index is `<key>/axis1`.

## Usage

``` r
read_pandas_fixed(path, key, attrs)
```

## Arguments

- path:

  Path to the `.h5` file.

- key:

  The HDF key of the DataFrame.

- attrs:

  The attributes of the group at `key`.

## Value

A list of `columns`, a data frame with one row per kept column and one
column per level; `values`, a frames-by-columns matrix; and `index`, the
frame index.
