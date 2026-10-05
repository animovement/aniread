# Name the column levels of a DeepLabCut header

Name the column levels of a DeepLabCut header

## Usage

``` r
dlc_columns(levels, level_names)
```

## Arguments

- levels:

  List of character vectors, one per level, each with one element per
  column.

- level_names:

  The level names pandas stored, or `NULL`/`NA` where it stored none.
  DeepLabCut's own order is assumed then.

## Value

A data frame with one row per column and one column per level.
