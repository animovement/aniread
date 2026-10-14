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
metadata. `time` is the column as it is in the file; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
for the convention the other readers follow.

## Examples

``` r
# A small file with columns named the tracker's way
path <- tempfile(fileext = ".csv")
write.csv(
  data.frame(
    frame = c(1, 2, 3, 1, 2),
    pos_x = c(0.1, 0.4, 0.9, 2.0, 2.2),
    pos_y = c(1.0, 1.2, 1.1, 0.5, 0.7),
    track_id = c(1, 1, 1, 2, 2),
    trial_num = 1
  ),
  path,
  row.names = FALSE
)

# Simple case: rename columns to standard names, use defaults
read_custom(path, cols = c(time = "frame", x = "pos_x", y = "pos_y"))
#> # Keypoints: centroid
#>   keypoint  time     x     y
#>   <fct>    <dbl> <dbl> <dbl>
#> 1 centroid     1   0.1   1  
#> 2 centroid     1   2     0.5
#> 3 centroid     2   0.4   1.2
#> 4 centroid     2   2.2   0.7
#> 5 centroid     3   0.9   1.1

# With identity variable
read_custom(
  path,
  cols = c(track = "track_id", time = "frame", x = "pos_x", y = "pos_y"),
  variables_what = "track"
)
#> # Tracks: 1, 2
#>   track  time     x     y
#>   <int> <dbl> <dbl> <dbl>
#> 1     1     1   0.1   1  
#> 2     1     2   0.4   1.2
#> 3     1     3   0.9   1.1
#> 4     2     1   2     0.5
#> 5     2     2   2.2   0.7

# Full specification with trials
read_custom(
  path,
  cols = c(
    id = "track_id",
    trial = "trial_num",
    frame = "frame",
    x = "pos_x",
    y = "pos_y"
  ),
  variables_what = "id",
  variables_when = "trial",
  index = "frame"
)
#> # Ids:    1, 2
#> # Trials: 1
#>      id trial frame     x     y
#>   <int> <int> <dbl> <dbl> <dbl>
#> 1     1     1     1   0.1   1  
#> 2     1     1     2   0.4   1.2
#> 3     1     1     3   0.9   1.1
#> 4     2     1     1   2     0.5
#> 5     2     1     2   2.2   0.7

# Using column positions
read_custom(path, cols = c(time = 1, x = 2, y = 3))
#> # Keypoints: centroid
#>   keypoint  time     x     y
#>   <fct>    <dbl> <dbl> <dbl>
#> 1 centroid     1   0.1   1  
#> 2 centroid     1   2     0.5
#> 3 centroid     2   0.4   1.2
#> 4 centroid     2   2.2   0.7
#> 5 centroid     3   0.9   1.1
```
