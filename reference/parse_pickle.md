# Read a protocol 0 pickle

PyTables stores the Python objects pandas keeps as HDF5 attributes as
protocol 0 pickles: lists, tuples and dicts of strings, integers and
`None`. This reads that subset, without Python. Lists and tuples become
unnamed lists, dicts named lists, `None` `NULL`.

## Usage

``` r
parse_pickle(x)
```

## Arguments

- x:

  A pickle, as a single string.

## Value

The unpickled object.
