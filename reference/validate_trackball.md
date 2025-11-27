# Validate trackball files

The validator ensures that:

- A valid setup is given.

- A valid number of files are provided.

- Identical suffixes when tewo files are given.

## Usage

``` r
validate_trackball(paths, setup, col_time)
```

## Arguments

- paths:

  Path to the file(s).

- setup:

  Experimental setup used. Expects either "of_free", "of_fixed" or
  "fictrac".

- col_time:

  Column which contains time
