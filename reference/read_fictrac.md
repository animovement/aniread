# Read projected FicTrac data

This helper loads a FicTrac `*.dat` file, keeps the timestamp, the 2‑D
fictive path and the animal's heading, converts the timestamps to
seconds, and returns the result as an anipoint. FicTrac's "integrated
animal heading" (the direction the animal faces) becomes `yaw` and is
declared as the frame's orientation, in radians from `x` toward `y`.
FicTrac's movement direction is the direction of travel, derivable from
the path, and is not kept. If the physical ball radius is supplied, the
positions are scaled accordingly and the spatial unit metadata is set.

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

An anipoint with columns `time`, `x`, `y` and `yaw`. Metadata includes
the source (`"fictrac"`), original filename, sampling rate, time unit
(`"s"`), space unit (either `"none"` or the value of
`unit_ball_radius`), and a Cartesian 2‑D coordinate system. `time` is in
seconds from the first row; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

FicTrac 2 has written three layouts, told apart by their number of
columns. Columns 1 to 21 are the same in all of them; the rest hold
timestamps:

- **23 columns** (FicTrac 2.0 to 2.02): 22 is the timestamp, 23 the
  sequence counter. `time` is taken from the timestamp, which is the
  position in the video file (ms) or the frame capture time (ms).

- **24 columns** (untagged versions from July 2019, before 2.03): 22 is
  the frame capture time in ms since midnight, 23 the sequence counter,
  24 the time since the last frame (ms). `time` is taken from column 22.

- **25 columns** (FicTrac 2.03 onward): 22 is the timestamp, 23 the
  sequence counter, 24 the time since the last frame, 25 the "alt.
  timestamp", the frame capture time in ms since midnight. `time` is
  taken from column 25.

`time` counts in seconds from the first row. A time in ms since midnight
starts again from zero at midnight, so where it drops by more than
twelve hours from one row to the next, the reader takes it as having
passed midnight and adds a day from there on. A recording that crosses
midnight therefore keeps running forward rather than jumping back.

## Examples

``` r
if (FALSE) { # \dontrun{
# Assuming you have a FicTrac file called "fly1.dat"
traj <- read_fictrac("fly1.dat", ball_radius = 0.5, unit_ball_radius = "cm")
head(traj)
} # }
```
