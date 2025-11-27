# Read a custom file format

Reads a file and selects/renames specified columns to create an
aniframe.

## Usage

``` r
read_custom(path, cols, metadata = list())
```

## Arguments

- path:

  Character string specifying the path to the file to read.

- cols:

  A named vector specifying which columns to keep and how to rename
  them, e.g. `c(time = "time", x = "x", y = "y")`. Names should be the
  desired output column names, and values can be either the original
  column names (as characters) or column positions (as integers, e.g.
  `c(time = 1, x = 2, y = 3)`). .

- metadata:

  A list of metadata to attach to the resulting aniframe. Default is an
  empty list. To see which metadata fields can be set, see
  aniframe::default_metadata().

## Value

An aniframe with the selected and renamed columns, and attached
metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
# Using column names
read_custom("data.csv", cols = c(time = "frame", x = "pos_x", y = "pos_y"))

# Using column positions
read_custom("data.csv", cols = c(time = 1, x = 2, y = 3))
} # }
```
