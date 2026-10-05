# Read a DeepLabCut csv file

The header rows are the column levels, each named in the first column;
the data rows follow, with the frame index in the first column.

## Usage

``` r
read_deeplabcut_csv(path)
```

## Arguments

- path:

  Path to a DeepLabCut `.csv` file.

## Value

A list of `columns`, a data frame with one row per kept column and one
column per level; `values`, a frames-by-columns matrix; and `index`, the
frame index.
