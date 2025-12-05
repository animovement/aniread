# Tests for calibrate_trackball
#
# - Returns a list with counts_per_rotation and calibration_factor
# - Correctly calculates counts_per_rotation
# - Correctly calculates calibration_factor
# - Uses axis with maximum movement
# - Respects custom column names
# - Handles negative sensor values (reverse rotation)

test_that("calibrate_trackball returns list with expected elements", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(
    data.frame(x = c(100, 100, 100), y = c(0, 0, 0)),
    path,
    row.names = FALSE
  )

  result <- calibrate_trackball(path, ball_diameter = 50, ball_rotations = 1)

  expect_type(result, "list")
  expect_named(result, c("counts_per_rotation", "calibration_factor"))
})

test_that("calibrate_trackball correctly calculates counts_per_rotation", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(
    data.frame(x = c(100, 100, 100), y = c(0, 0, 0)),
    path,
    row.names = FALSE
  )

  result <- calibrate_trackball(path, ball_diameter = 50, ball_rotations = 1)
  expect_equal(result$counts_per_rotation, 300)

  result <- calibrate_trackball(path, ball_diameter = 50, ball_rotations = 3)
  expect_equal(result$counts_per_rotation, 100)
})

test_that("calibrate_trackball correctly calculates calibration_factor", {
  path <- withr::local_tempfile(fileext = ".csv")
  # 1000 counts for 2 rotations of a ball with diameter 100
  # circumference = pi * 100 = 314.159...
  # counts_per_rotation = 500
  # calibration_factor = 314.159 / 500 = 0.628...
  write.csv(
    data.frame(x = rep(100, 10), y = rep(0, 10)),
    path,
    row.names = FALSE
  )

  result <- calibrate_trackball(path, ball_diameter = 100, ball_rotations = 2)

  expected_circumference <- pi * 100
  expected_counts_per_rotation <- 1000 / 2
  expected_calibration_factor <- expected_circumference /
    expected_counts_per_rotation

  expect_equal(result$calibration_factor, expected_calibration_factor)
})

test_that("calibrate_trackball uses axis with maximum movement", {
  path_x <- withr::local_tempfile(fileext = ".csv")
  path_y <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(x = c(500, 500), y = c(10, 10)),
    path_x,
    row.names = FALSE
  )
  write.csv(
    data.frame(x = c(10, 10), y = c(500, 500)),
    path_y,
    row.names = FALSE
  )

  result_x <- calibrate_trackball(
    path_x,
    ball_diameter = 50,
    ball_rotations = 1
  )
  result_y <- calibrate_trackball(
    path_y,
    ball_diameter = 50,
    ball_rotations = 1
  )

  expect_equal(result_x$counts_per_rotation, 1000)
  expect_equal(result_y$counts_per_rotation, 1000)
})

test_that("calibrate_trackball respects custom column names", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(data.frame(dx = c(100, 100), dy = c(0, 0)), path, row.names = FALSE)

  result <- calibrate_trackball(
    path,
    ball_diameter = 50,
    ball_rotations = 1,
    col_dx = "dx",
    col_dy = "dy"
  )

  expect_equal(result$counts_per_rotation, 200)
})

test_that("calibrate_trackball handles negative sensor values", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(
    data.frame(x = c(-100, -100, -100), y = c(0, 0, 0)),
    path,
    row.names = FALSE
  )

  result <- calibrate_trackball(path, ball_diameter = 50, ball_rotations = 1)

  expect_equal(result$counts_per_rotation, 300)
})
