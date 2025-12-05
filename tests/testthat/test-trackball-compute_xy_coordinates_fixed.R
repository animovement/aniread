# Tests for compute_xy_coordinates_fixed
#
# - Renames time_group to time
# - Averages x_1 and x_2 for sensor_dx (two sensors)
# - Uses y_1 for sensor_dy
# - Calculates angle from ball_calibration
# - Calculates angle from ball_diameter and distance_scale
# - Errors when calibration params missing
# - Calculates dx as sensor_dy * cos(d_angle)
# - Calculates dy as sensor_dy * sin(d_angle)
# - Calculates x and y as cumulative sums
# - Handles single sensor case

test_that("compute_xy_coordinates_fixed renames time_group to time", {
  data <- data.frame(
    time_group = c(0, 1, 2),
    x_1 = 0,
    y_1 = 0,
    x_2 = 0,
    y_2 = 0
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_true("time" %in% names(result))
  expect_false("time_group" %in% names(result))
  expect_equal(result$time, c(0, 1, 2))
})

test_that("compute_xy_coordinates_fixed averages x_1 and x_2 for sensor_dx", {
  data <- data.frame(
    time_group = 0,
    x_1 = 100,
    y_1 = 0,
    x_2 = 200,
    y_2 = 0
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_equal(result$sensor_dx, 150)
})

test_that("compute_xy_coordinates_fixed uses y_1 for sensor_dy", {
  data <- data.frame(
    time_group = 0,
    x_1 = 0,
    y_1 = 50,
    x_2 = 0,
    y_2 = 999
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_equal(result$sensor_dy, 50)
})

test_that("compute_xy_coordinates_fixed calculates angle from ball_calibration", {
  # ball_calibration = counts for one full rotation
  # d_angle = (sensor_dx / ball_calibration) * 2 * pi
  data <- data.frame(
    time_group = 0,
    x_1 = 250,
    y_1 = 0,
    x_2 = 250,
    y_2 = 0
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  # sensor_dx = 250, d_angle = (250 / 1000) * 2 * pi = 0.25 * 2 * pi = pi/2
  expect_equal(result$d_angle, pi / 2)
})

test_that("compute_xy_coordinates_fixed calculates angle from ball_diameter and distance_scale", {
  # d_angle = (sensor_dx / (ball_diameter * pi * distance_scale)) * 2 * pi
  # Full rotation = ball_diameter * pi * distance_scale counts
  data <- data.frame(
    time_group = 0,
    x_1 = 100,
    y_1 = 0,
    x_2 = 100,
    y_2 = 0
  )

  ball_diameter <- 50
  distance_scale <- 10
  # Full rotation counts = 50 * pi * 10 = 500 * pi
  # sensor_dx = 100
  # d_angle = (100 / (500 * pi)) * 2 * pi = 200 / 500 = 0.4

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = NULL,
    ball_diameter = ball_diameter,
    distance_scale = distance_scale
  )

  expected_angle <- (100 / (ball_diameter * pi * distance_scale)) * 2 * pi
  expect_equal(result$d_angle, expected_angle)
})

test_that("compute_xy_coordinates_fixed errors when calibration params missing", {
  data <- data.frame(
    time_group = 0,
    x_1 = 0,
    y_1 = 0,
    x_2 = 0,
    y_2 = 0
  )

  expect_error(
    compute_xy_coordinates_fixed(
      data,
      n_sensors = 2,
      ball_calibration = NULL,
      ball_diameter = NULL,
      distance_scale = NULL
    )
  )

  # Also error if only ball_diameter provided
  expect_error(
    compute_xy_coordinates_fixed(
      data,
      n_sensors = 2,
      ball_calibration = NULL,
      ball_diameter = 50,
      distance_scale = NULL
    )
  )
})

test_that("compute_xy_coordinates_fixed calculates dx and dy with trigonometry", {
  # No rotation (d_angle = 0): dx = sensor_dy, dy = 0
  data <- data.frame(
    time_group = 0,
    x_1 = 0,
    y_1 = 100,
    x_2 = 0,
    y_2 = 0
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_equal(result$dx, 100 * cos(0))
  expect_equal(result$dy, 100 * sin(0))
  expect_equal(result$dx, 100)
  expect_equal(result$dy, 0)
})

test_that("compute_xy_coordinates_fixed calculates dx and dy at 90 degrees", {
  # Quarter rotation (d_angle = pi/2): dx = 0, dy = sensor_dy
  data <- data.frame(
    time_group = 0,
    x_1 = 250,
    y_1 = 100,
    x_2 = 250,
    y_2 = 0
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_equal(result$d_angle, pi / 2)
  expect_equal(result$dx, 100 * cos(pi / 2), tolerance = 1e-10)
  expect_equal(result$dy, 100 * sin(pi / 2), tolerance = 1e-10)
})

test_that("compute_xy_coordinates_fixed calculates x and y as cumulative sums", {
  # No rotation, just forward movement
  data <- data.frame(
    time_group = c(0, 1, 2, 3),
    x_1 = 0,
    y_1 = c(10, 20, 30, 40),
    x_2 = 0,
    y_2 = 0
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 2,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_equal(result$x, c(10, 30, 60, 100))
  expect_equal(result$y, c(0, 0, 0, 0))
})

test_that("compute_xy_coordinates_fixed works with single sensor", {
  # Single sensor data has different column structure
  # This data comes from read_opticalflow, not join_trackball_files
  # So it has time, dx, dy columns instead of time_group, x_1, y_1, etc.
  data <- data.frame(
    time_group = c(0, 1, 2),
    x_1 = c(0, 250, 0),
    y_1 = c(100, 100, 100)
  )

  result <- compute_xy_coordinates_fixed(
    data,
    n_sensors = 1,
    ball_calibration = 1000,
    ball_diameter = NULL,
    distance_scale = NULL
  )

  expect_true("time" %in% names(result))
  expect_true("x" %in% names(result))
  expect_true("y" %in% names(result))

  # First step: no rotation, forward 100
  # Second step: 90 degree turn, forward 100 (now in y direction)
  # Third step: no rotation, forward 100 (still in y direction)
  expect_equal(result$d_angle[1], 0)
  expect_equal(result$d_angle[2], pi / 2)
  expect_equal(result$d_angle[3], 0)
})
