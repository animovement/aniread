# Get calibration values for trackball data

Reads a calibration recording and computes calibration values. Spin the
ball a known number of times in one direction while recording.

## Usage

``` r
calibrate_trackball(
  path,
  ball_diameter,
  ball_rotations,
  col_dx = "x",
  col_dy = "y"
)
```

## Arguments

- path:

  Path to calibration CSV file.

- ball_diameter:

  Diameter of the trackball in desired output units (e.g., mm or cm).

- ball_rotations:

  Number of complete rotations performed.

- col_dx:

  Column name for x-axis values.

- col_dy:

  Column name for y-axis values.

## Value

A list with two elements:

- `counts_per_rotation`: Sensor counts per full rotation (for
  `ball_calibration` in `read_trackball`).

- `calibration_factor`: Distance per sensor count (for
  `set_unit_space`).
