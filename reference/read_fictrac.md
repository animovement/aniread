# Read projected FicTrac data

This helper loads a FicTrac `*.dat` file, keeps only the timestamp and
2‑D position columns, converts the timestamps to seconds, and returns
the result as an **aniframe** object. If the physical ball radius is
supplied, the positions are scaled accordingly and the spatial unit
metadata is set.

## Usage

``` r
read_fictrac(path, ball_radius = NULL, unit_ball_radius = "cm")
```

## Arguments

- path:

  Character. Path to the FicTrac `*.dat` file.

- ball_radius:

  Numeric (optional). Physical radius of the tracking ball. When
  supplied the `x` and `y` coordinates are multiplied by this value.

- unit_ball_radius:

  Character. Unit of `ball_radius` (e.g., `"cm"` or `"mm"`). Defaults to
  `"cm"`. Ignored when `ball_radius` is `NULL`.

## Value

An **aniframe** object with columns `time`, `x`, and `y`. Metadata
includes the source (`"fictrac"`), original filename, sampling rate,
time unit (`"s"`), space unit (either `"none"` or the value of
`unit_ball_radius`), and a Cartesian 2‑D coordinate system.

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming you have a FicTrac file called "fly1.dat"
traj <- read_fictrac("fly1.dat", ball_radius = 0.5, unit_ball_radius = "cm")
head(traj)
} # }
```
