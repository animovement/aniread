# Tests for read_trackball
#
# - Integration test: of_free with two sensors
# - Integration test: of_fixed with two sensors
# - Integration test: of_fixed with one sensor
# - Output has keypoint column set to centroid
# - Output is aniframe with correct columns
# - Metadata is set correctly
# - Time is converted from time_group to seconds
# - Respects custom column names
# - Errors on non-csv files
# - Errors on non-existent files
# - of_free produces correct square path
# - of_fixed produces correct square path

# The fixtures below use a plain numeric time column. `read_trackball()` cannot
# verify that such a column is a clock the two sensors share, so two-sensor
# reads warn. That warning is asserted in its own test; muffle it here so these
# tests stay focused on what they actually check.
read_trackball_quiet <- function(...) {
  withCallingHandlers(
    read_trackball(...),
    aniread_sensor_local_clock = function(w) invokeRestart("muffleWarning")
  )
}

test_that("read_trackball works with of_free setup and two sensors", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = c(1, 2, 3), y = c(10, 20, 30)),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = c(4, 5, 6), y = c(40, 50, 60)),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_free",
    sampling_rate = 10
  )

  expect_s3_class(result, "aniframe")
  expect_true(all(c("time", "x", "y", "keypoint") %in% names(result)))
})

test_that("read_trackball works with of_fixed setup and two sensors", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = c(0, 0, 0), y = c(10, 20, 30)),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = c(0, 0, 0), y = c(10, 20, 30)),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_fixed",
    sampling_rate = 10,
    counts_per_rotation = 1000
  )

  expect_s3_class(result, "aniframe")
  expect_true(all(c("time", "x", "y", "keypoint") %in% names(result)))
})

test_that("read_trackball works with of_fixed setup and one sensor", {
  path <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = c(0, 0, 0), y = c(10, 20, 30)),
    path,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = path,
    setup = "of_fixed",
    sampling_rate = 10,
    counts_per_rotation = 1000
  )

  expect_s3_class(result, "aniframe")
  expect_true(all(c("time", "x", "y", "keypoint") %in% names(result)))
})

test_that("read_trackball output has keypoint column set to centroid", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = 1, y = 1),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = 1, y = 1),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_free",
    sampling_rate = 10
  )

  expect_true(all(result$keypoint == "centroid"))
})

test_that("read_trackball sets metadata correctly", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = 1, y = 1),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(time = c(0, 0.1, 0.2), x = 1, y = 1),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_free",
    sampling_rate = 60
  )

  metadata <- aniframe::get_metadata(result)
  expect_equal(metadata$sampling_rate, 60)
})

test_that("read_trackball converts time_group to seconds using sampling_rate", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  # Create data spanning 1 second at 10Hz
  write.csv(
    data.frame(time = seq(0, 1, by = 0.05), x = 1, y = 1),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(time = seq(0, 1, by = 0.05), x = 1, y = 1),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_free",
    sampling_rate = 10
  )

  # Time should be in seconds, with steps of 1/sampling_rate = 0.1
  time_diffs <- diff(result$time)
  expect_true(all(abs(time_diffs - 0.1) < 0.01))
})

test_that("read_trackball respects custom column names", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  write.csv(
    data.frame(timestamp = c(0, 0.1, 0.2), dx = 1, dy = 1),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(timestamp = c(0, 0.1, 0.2), dx = 1, dy = 1),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_free",
    sampling_rate = 10,
    col_time = "timestamp",
    col_dx = "dx",
    col_dy = "dy"
  )

  expect_s3_class(result, "aniframe")
})

test_that("read_trackball errors on non-csv files", {
  path <- withr::local_tempfile(fileext = ".txt")
  writeLines("test", path)

  expect_error(
    read_trackball(
      paths = path,
      setup = "of_fixed",
      sampling_rate = 10,
      counts_per_rotation = 1000
    )
  )
})

test_that("read_trackball errors on non-existent files", {
  expect_error(
    read_trackball(
      paths = "nonexistent.csv",
      setup = "of_free",
      sampling_rate = 10
    )
  )
})

test_that("read_trackball of_free produces correct square path", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  # For of_free: sensor 1's y becomes dx, sensor 2's y becomes dy
  # dx <- c(0, 1, 0, -2, 0, 1) → x = cumsum = c(0, 1, 1, -1, -1, 0)
  # dy <- c(1, 0, -2, 0, 2, 0) → y = cumsum = c(1, 1, -1, -1, 1, 1)

  write.csv(
    data.frame(
      time = c(0, 1, 2, 3, 4, 5),
      x = 0,
      y = c(0, 1, 0, -2, 0, 1)
    ),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(
      time = c(0, 1, 2, 3, 4, 5),
      x = 0,
      y = c(1, 0, -2, 0, 2, 0)
    ),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_free",
    sampling_rate = 1
  )

  expect_equal(result$x, c(0, 1, 1, -1, -1, 0))
  expect_equal(result$y, c(1, 1, -1, -1, 1, 1))
  expect_equal(result$time, c(0, 1, 2, 3, 4, 5))
})

test_that("read_trackball of_fixed produces correct square path", {
  path1 <- withr::local_tempfile(fileext = ".csv")
  path2 <- withr::local_tempfile(fileext = ".csv")

  # For of_fixed:
  # sensor_dx = (x_1 + x_2) / 2 → rotation
  # sensor_dy = y_1 → forward movement
  # d_angle = (sensor_dx / counts_per_rotation) * 2 * pi
  # dx = sensor_dy * cos(d_angle)
  # dy = sensor_dy * sin(d_angle)
  #
  # Target: dx = c(0, 1, 0, -2, 0, 1), dy = c(1, 0, -2, 0, 2, 0)
  # x = cumsum(dx) = c(0, 1, 1, -1, -1, 0)
  # y = cumsum(dy) = c(1, 1, -1, -1, 1, 1)
  #
  # Working backwards with counts_per_rotation = 1000:
  # d_angle = atan2(dy, dx)
  # sensor_dy = sqrt(dx^2 + dy^2)
  # sensor_dx = d_angle / (2 * pi) * counts_per_rotation
  #
  # Step 0: dx=0, dy=1 → angle=pi/2, dist=1 → sensor_dx=250, sensor_dy=1
  # Step 1: dx=1, dy=0 → angle=0, dist=1 → sensor_dx=0, sensor_dy=1
  # Step 2: dx=0, dy=-2 → angle=-pi/2, dist=2 → sensor_dx=-250, sensor_dy=2
  # Step 3: dx=-2, dy=0 → angle=pi, dist=2 → sensor_dx=500, sensor_dy=2
  # Step 4: dx=0, dy=2 → angle=pi/2, dist=2 → sensor_dx=250, sensor_dy=2
  # Step 5: dx=1, dy=0 → angle=0, dist=1 → sensor_dx=0, sensor_dy=1

  sensor_dx <- c(250, 0, -250, 500, 250, 0)
  sensor_dy <- c(1, 1, 2, 2, 2, 1)

  # sensor_dx = (x_1 + x_2) / 2, so use same value for both
  write.csv(
    data.frame(
      time = c(0, 1, 2, 3, 4, 5),
      x = sensor_dx,
      y = sensor_dy
    ),
    path1,
    row.names = FALSE
  )
  write.csv(
    data.frame(
      time = c(0, 1, 2, 3, 4, 5),
      x = sensor_dx,
      y = 6
    ),
    path2,
    row.names = FALSE
  )

  result <- read_trackball_quiet(
    paths = c(path1, path2),
    setup = "of_fixed",
    sampling_rate = 1,
    counts_per_rotation = 1000
  )

  expect_equal(result$x, c(0, 1, 1, -1, -1, 0), tolerance = 1e-10)
  expect_equal(result$y, c(1, 1, -1, -1, 1, 1), tolerance = 1e-10)
  expect_equal(result$time, c(0, 1, 2, 3, 4, 5))
})
