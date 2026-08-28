# Read a custom file format

Reads a file and selects/renames specified columns to create an
aniframe.

## Usage

``` r
read_custom(
  path,
  cols,
  variables_what = NULL,
  variables_when = NULL,
  variables_where = NULL,
  index = NULL,
  metadata = list()
)
```

## Arguments

- path:

  Character string specifying the path to the file to read.

- cols:

  A named vector specifying which columns to keep and how to rename
  them, e.g. `c(time = "time", x = "x", y = "y")`. Names should be the
  desired output column names, and values can be either the original
  column names (as characters) or column positions (as integers, e.g.
  `c(time = 1, x = 2, y = 3)`).

- variables_what:

  Character vector of identity columns that together define a unique
  entity. Uses aniframe defaults if NULL.

- variables_when:

  Character vector of temporal columns that together define a unique
  timepoint. Uses aniframe defaults if NULL.

- variables_where:

  Character vector of spatial columns that together define position. If
  NULL, detected from data.

- index:

  Length-one character vector naming the column the frame is indexed by
  – the position of each row within its temporal context. If `NULL` (the
  default), `"time"`. It is never a grouping variable, and is declared
  separately from `variables_when`.

- metadata:

  A list of metadata to attach to the resulting aniframe. Default is an
  empty list.

## Value

An aniframe with the selected and renamed columns, and attached
metadata.

## Examples

``` r
if (FALSE) { # \dontrun{
# Simple case: rename columns to standard names, use defaults
read_custom("data.csv", cols = c(time = "frame", x = "pos_x", y = "pos_y"))

# With identity variable
read_custom(
  "data.csv",
  cols = c(track = "track_id", time = "frame", x = "pos_x", y = "pos_y"),
  variables_what = "track"
)

# Full specification with trials
read_custom(
  "data.csv",
  cols = c(
    id = "animal_id",
    trial = "trial_num",
    frame = "frame_idx",
    x = "x_coord",
    y = "y_coord"
  ),
  variables_what = "id",
  variables_when = "trial",
  index = "frame"
)

# Using column positions
read_custom("data.csv", cols = c(time = 1, x = 2, y = 3))
} # }
```
