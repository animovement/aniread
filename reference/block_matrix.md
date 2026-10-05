# Arrange one block of values as frames by columns

Arrange one block of values as frames by columns

## Usage

``` r
block_matrix(values, n_frames)
```

## Arguments

- values:

  A block as rhdf5 reads it: columns by frames, or a vector when the
  block has a single column.

- n_frames:

  Number of frames.

## Value

A numeric matrix with one row per frame.
