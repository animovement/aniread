# Read a DataFrame stored in pandas' "table" format

The values sit in a compound dataset `<key>/table`, one field per block
of columns. The column labels of each block are a pickled list of tuples
in the block's `_kind` attribute, and the level names a pickled dict in
the group's `info` attribute.

## Usage

``` r
read_pandas_table(path, key, attrs)
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
