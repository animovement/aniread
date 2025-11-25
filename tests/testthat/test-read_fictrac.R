# tests/testthat/test-read_fictrac.R

# Helper function to create test FicTrac data matching actual format
create_test_fictrac_file <- function(path, n_rows = 100, start_time = 53854352) {
  # Create realistic FicTrac data matching the actual format
  # FicTrac data is comma-space separated

  data <- data.frame(
    frame = 0:(n_rows - 1),  # Starts at 0, not 1
    delta_rot_cam_x = rnorm(n_rows, 0, 0.001),
    delta_rot_cam_y = rnorm(n_rows, 0, 0.001),
    delta_rot_cam_z = rnorm(n_rows, 0, 0.0005),
    delta_rot_error = seq(4000, 2200, length.out = n_rows),
    delta_rot_lab_x = rnorm(n_rows, 0, 0.001),
    delta_rot_lab_y = rnorm(n_rows, 0, 0.0005),
    delta_rot_lab_z = rnorm(n_rows, 0, 0.0005),
    abs_rot_cam_x = cumsum(rnorm(n_rows, 0, 0.001)),
    abs_rot_cam_y = cumsum(rnorm(n_rows, 0, 0.001)),
    abs_rot_cam_z = cumsum(rnorm(n_rows, 0, 0.0005)),
    abs_rot_lab_x = rnorm(n_rows, 1.787, 0.001),
    abs_rot_lab_y = rnorm(n_rows, 1.795, 0.001),
    abs_rot_lab_z = rnorm(n_rows, -0.641, 0.001),
    pos_x = cumsum(rnorm(n_rows, 0, 0.001)),
    pos_y = cumsum(rnorm(n_rows, 0, 0.001)),
    heading = rnorm(n_rows, 0, 0.1),
    direction = rnorm(n_rows, 3, 2),
    speed = abs(rnorm(n_rows, 0.001, 0.0005)),
    movement_x = rnorm(n_rows, 0, 0.001),
    movement_y = rnorm(n_rows, 0, 0.001),
    timestamp = seq(11196284, length.out = n_rows, by = 7),
    seq_num = 0:(n_rows - 1),
    delta_timestamp = round(rnorm(n_rows, 7, 0.1), 3),
    alt_timestamp = seq(start_time, length.out = n_rows, by = 7)
  )

  # Write with comma-space separation (matching actual FicTrac format)
  write.table(data, path,
              sep = ", ",
              row.names = FALSE,
              col.names = FALSE,
              quote = FALSE)

  return(invisible(path))
}

test_that("read_fictrac basic functionality works", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file, n_rows = 50)

  result <- read_fictrac(temp_file)

  # Check structure
  expect_s3_class(result, "aniframe")
  expect_s3_class(result, "tbl_df")

  # Check columns
  # expect_named(result, c("time", "x", "y"))
  expect_equal(nrow(result), 50)

  # Check data types
  expect_type(result$time, "double")
  expect_type(result$x, "double")
  expect_type(result$y, "double")
})

test_that("read_fictrac time conversion is correct", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file, n_rows = 10, start_time = 1000)
  result <- read_fictrac(temp_file)

  # First time point should be 0 (relative to start)
  expect_equal(result$time[1], 0)

  # Time should be in seconds (converted from ms)
  # With ~7ms intervals, last point should be ~0.063s
  expect_gt(result$time[10], 0.05)
  expect_lt(result$time[10], 0.08)

  # Time should be monotonically increasing
  expect_true(all(diff(result$time) >= 0))
})

test_that("read_fictrac ball_radius conversion works", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file, n_rows = 20)

  # Read without conversion
  result_radians <- read_fictrac(temp_file, ball_radius = NULL)

  # Read with conversion
  ball_radius <- 5  # cm
  result_cm <- read_fictrac(temp_file, ball_radius = ball_radius)

  # Check that positions are scaled correctly
  expect_equal(result_cm$x, result_radians$x * ball_radius)
  expect_equal(result_cm$y, result_radians$y * ball_radius)

  # Check metadata
  meta_radians <- aniframe::get_metadata(result_radians)
  meta_cm <- aniframe::get_metadata(result_cm)

  expect_equal(meta_radians$unit_space, factor("none", levels = levels(aniframe::default_metadata()$unit_space)))
  expect_equal(meta_cm$unit_space, factor("cm", levels = levels(aniframe::default_metadata()$unit_space)))
})

test_that("read_fictrac unit_ball_radius parameter works", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file)

  # Test different units
  result_mm <- read_fictrac(temp_file, ball_radius = 50, unit_ball_radius = "mm")
  result_m <- read_fictrac(temp_file, ball_radius = 0.05, unit_ball_radius = "m")

  meta_mm <- aniframe::get_metadata(result_mm)
  meta_m <- aniframe::get_metadata(result_m)

  expect_equal(meta_mm$unit_space,  factor("mm", levels = levels(aniframe::default_metadata()$unit_space)))
  expect_equal(meta_m$unit_space,  factor("m", levels = levels(aniframe::default_metadata()$unit_space)))
})

test_that("read_fictrac metadata is correctly set", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file, n_rows = 100)
  result <- read_fictrac(temp_file)

  meta <- aniframe::get_metadata(result)

  # Check all metadata fields
  expect_equal(meta$source, "fictrac")
  expect_equal(meta$filename, basename(temp_file))
  expect_type(meta$sampling_rate, "double")
  expect_equal(meta$unit_space,  factor("none", levels = levels(aniframe::default_metadata()$unit_space)))
  expect_equal(meta$unit_time,  factor("s", levels = levels(aniframe::default_metadata()$unit_time)))
  expect_equal(meta$coordinate_system, factor("cartesian_2d", levels = levels(aniframe::default_metadata()$coordinate_system)))

  # Sampling rate should be reasonable (inverse of median dt)
  # With ~7ms intervals, should be ~142.86 Hz
  expect_gt(meta$sampling_rate, 100)
  expect_lt(meta$sampling_rate, 200)
})

test_that("read_fictrac sampling rate calculation is robust to variable intervals", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  # Create data with some variable frame intervals
  n_rows <- 100
  delta_times <- c(7, 7, 7, 14, 7, 7, 21, rep(7, n_rows - 7))
  alt_timestamps <- cumsum(c(53854352, delta_times[-length(delta_times)]))

  data <- data.frame(
    frame = 0:(n_rows - 1),
    delta_rot_cam_x = rnorm(n_rows, 0, 0.001),
    delta_rot_cam_y = rnorm(n_rows, 0, 0.001),
    delta_rot_cam_z = rnorm(n_rows, 0, 0.0005),
    delta_rot_error = seq(4000, 2200, length.out = n_rows),
    delta_rot_lab_x = rnorm(n_rows, 0, 0.001),
    delta_rot_lab_y = rnorm(n_rows, 0, 0.0005),
    delta_rot_lab_z = rnorm(n_rows, 0, 0.0005),
    abs_rot_cam_x = cumsum(rnorm(n_rows, 0, 0.001)),
    abs_rot_cam_y = cumsum(rnorm(n_rows, 0, 0.001)),
    abs_rot_cam_z = cumsum(rnorm(n_rows, 0, 0.0005)),
    abs_rot_lab_x = rnorm(n_rows, 1.787, 0.001),
    abs_rot_lab_y = rnorm(n_rows, 1.795, 0.001),
    abs_rot_lab_z = rnorm(n_rows, -0.641, 0.001),
    pos_x = cumsum(rnorm(n_rows, 0, 0.001)),
    pos_y = cumsum(rnorm(n_rows, 0, 0.001)),
    heading = rnorm(n_rows, 0, 0.1),
    direction = rnorm(n_rows, 3, 2),
    speed = abs(rnorm(n_rows, 0.001, 0.0005)),
    movement_x = rnorm(n_rows, 0, 0.001),
    movement_y = rnorm(n_rows, 0, 0.001),
    timestamp = seq(11196284, length.out = n_rows, by = 7),
    seq_num = 0:(n_rows - 1),
    delta_timestamp = delta_times,
    alt_timestamp = alt_timestamps
  )

  write.table(data, temp_file,
              sep = ", ",
              row.names = FALSE,
              col.names = FALSE,
              quote = FALSE)

  result <- read_fictrac(temp_file)
  meta <- aniframe::get_metadata(result)

  # Should use median (7ms), so occasional long intervals don't affect it
  expect_type(meta$sampling_rate, "double")
  expect_gt(meta$sampling_rate, 100)
  expect_lt(meta$sampling_rate, 200)
})

test_that("read_fictrac handles actual FicTrac format correctly", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  # Write a few lines from actual FicTrac data
  fictrac_lines <- c(
    "0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1.785263, 1.793943, -0.638146, 0, 0, 0, -0, 0, 0, 0, 11196284.736, 0, 0, 53854352.112",
    "1, 0.00091298698689807, 0.0010795545492487, -1.0145606798888e-06, 4054.1974248927, 0.0010870209360836, 0.00070569762347681, -0.00056512002363872, 0.00091298698689807, 0.0010795545492487, -1.0145606798888e-06, 1.7865336863531, 1.7946416386178, -0.6382169943872, 0.00070600473514233, -0.0010868214772053, 0.00056512002363872, 5.288203955636, 0.0012960029518735, 0.00070569762347681, -0.0010870209360836, 11196290.507, 1, 5.7709999997169, 53854357.881",
    "2, -0.00021061215364476, -0.00076847048380153, 0.00044358056253763, 3997.1427853193, -0.00075343271515879, -0.00046433050251188, -0.0002200100165078, 0.0007021357003666, 0.00031128647692244, 0.00044280300843229, 1.7862673260681, 1.7936937682421, -0.63843300202622, 0.00024116567808164, -0.00033370241629699, 0.00078513004014651, 2.1231052906689, 0.00088502184822437, 0.00024136712096493, -0.00033358822092478, 11196297.421, 2, 6.9140000008047, 53854364.796"
  )

  writeLines(fictrac_lines, temp_file)

  result <- read_fictrac(temp_file)

  # Should have 3 rows
  expect_equal(nrow(result), 3)

  # Check first row (frame 0)
  expect_equal(result$time[1], 0)
  expect_equal(result$x[1], 0)
  expect_equal(result$y[1], 0)

  # Check second row has actual position values
  expect_equal(result$x[2], 0.00070600473514233, tolerance = 1e-10)
  expect_equal(result$y[2], -0.0010868214772053, tolerance = 1e-10)

  # Time should be in seconds from start
  expect_equal(result$time[2], (53854357.881 - 53854352.112) / 1000, tolerance = 1e-6)
})

test_that("read_fictrac preserves position precision", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  # Create data with specific known position values
  n_rows <- 10
  known_x <- seq(0.001, 0.010, length.out = n_rows)
  known_y <- seq(-0.005, 0.005, length.out = n_rows)

  data <- data.frame(
    frame = 0:(n_rows - 1),
    delta_rot_cam_x = rep(0, n_rows),
    delta_rot_cam_y = rep(0, n_rows),
    delta_rot_cam_z = rep(0, n_rows),
    delta_rot_error = rep(3000, n_rows),
    delta_rot_lab_x = rep(0, n_rows),
    delta_rot_lab_y = rep(0, n_rows),
    delta_rot_lab_z = rep(0, n_rows),
    abs_rot_cam_x = rep(0, n_rows),
    abs_rot_cam_y = rep(0, n_rows),
    abs_rot_cam_z = rep(0, n_rows),
    abs_rot_lab_x = rep(1.787, n_rows),
    abs_rot_lab_y = rep(1.795, n_rows),
    abs_rot_lab_z = rep(-0.641, n_rows),
    pos_x = known_x,
    pos_y = known_y,
    heading = rep(0, n_rows),
    direction = rep(0, n_rows),
    speed = rep(0.001, n_rows),
    movement_x = rep(0, n_rows),
    movement_y = rep(0, n_rows),
    timestamp = seq(11196284, length.out = n_rows, by = 10),
    seq_num = 0:(n_rows - 1),
    delta_timestamp = rep(10, n_rows),
    alt_timestamp = seq(53854352, length.out = n_rows, by = 10)
  )

  write.table(data, temp_file,
              sep = ", ",
              row.names = FALSE,
              col.names = FALSE,
              quote = FALSE)

  result <- read_fictrac(temp_file)

  # Check that x and y values match (within floating point tolerance)
  expect_equal(result$x, known_x, tolerance = 1e-10)
  expect_equal(result$y, known_y, tolerance = 1e-10)
})

test_that("read_fictrac with ball_radius gives correct physical units", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  # Create simple data with known radian values
  data <- data.frame(
    frame = 0:4,
    delta_rot_cam_x = rep(0, 5),
    delta_rot_cam_y = rep(0, 5),
    delta_rot_cam_z = rep(0, 5),
    delta_rot_error = rep(3000, 5),
    delta_rot_lab_x = rep(0, 5),
    delta_rot_lab_y = rep(0, 5),
    delta_rot_lab_z = rep(0, 5),
    abs_rot_cam_x = rep(0, 5),
    abs_rot_cam_y = rep(0, 5),
    abs_rot_cam_z = rep(0, 5),
    abs_rot_lab_x = rep(1.787, 5),
    abs_rot_lab_y = rep(1.795, 5),
    abs_rot_lab_z = rep(-0.641, 5),
    pos_x = c(0, 0.1, 0.2, 0.3, 0.4),  # radians
    pos_y = c(0, 0, 0.1, 0.2, 0.3),    # radians
    heading = rep(0, 5),
    direction = rep(0, 5),
    speed = rep(0.001, 5),
    movement_x = rep(0, 5),
    movement_y = rep(0, 5),
    timestamp = seq(11196284, length.out = 5, by = 10),
    seq_num = 0:4,
    delta_timestamp = rep(10, 5),
    alt_timestamp = seq(53854352, length.out = 5, by = 10)
  )

  write.table(data, temp_file,
              sep = ", ",
              row.names = FALSE,
              col.names = FALSE,
              quote = FALSE)

  # Read with 5cm radius
  result <- read_fictrac(temp_file, ball_radius = 5, unit_ball_radius = "cm")

  # 0.1 radians * 5 cm = 0.5 cm
  expect_equal(result$x[2], 0.5, tolerance = 1e-10)
  # 0.2 radians * 5 cm = 1.0 cm
  expect_equal(result$x[3], 1.0, tolerance = 1e-10)

  # Check metadata
  meta <- aniframe::get_metadata(result)
  expect_equal(meta$unit_space, factor("cm", levels = levels(aniframe::default_metadata()$unit_space)))
})

test_that("read_fictrac handles empty file gracefully", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  file.create(temp_file)

  # vroom should handle this, but it might return 0 rows
  expect_error(
    read_fictrac(temp_file)
  )
})

test_that("read_fictrac handles single row file", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file, n_rows = 1)

  # With single row, diff() will return length 0
  # This should either work or give a clear error
  result <- suppressWarnings(read_fictrac(temp_file))

  expect_equal(nrow(result), 1)

  # Sampling rate should be NA or handle gracefully
  meta <- aniframe::get_metadata(result)
  expect_true(is.na(meta$sampling_rate) || is.numeric(meta$sampling_rate))
})

test_that("read_fictrac handles scientific notation correctly", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  # Create data with scientific notation (like actual FicTrac output)
  fictrac_lines <- c(
    "0, 1.0145606798888e-06, -2.5e-07, 3.14159e-05, 4000, 0, 0, 0, 0, 0, 0, 1.787, 1.795, -0.641, 1.5e-04, -2.3e-04, 0, 3, 0.001, 0, 0, 11196284.736, 0, 7, 53854352.112",
    "1, -1.5e-06, 2.7e-07, -4.2e-05, 3900, 0, 0, 0, 0, 0, 0, 1.787, 1.795, -0.641, 3.0e-04, -4.6e-04, 0, 3, 0.001, 0, 0, 11196291.736, 1, 7, 53854359.112"
  )

  writeLines(fictrac_lines, temp_file)

  result <- read_fictrac(temp_file)

  # Should correctly parse scientific notation
  expect_equal(nrow(result), 2)
  expect_equal(result$x[1], 1.5e-04, tolerance = 1e-10)
  expect_equal(result$y[1], -2.3e-04, tolerance = 1e-10)
})

test_that("read_fictrac column selection is correct", {
  temp_file <- tempfile(fileext = ".dat")
  on.exit(unlink(temp_file))

  create_test_fictrac_file(temp_file, n_rows = 10)

  result <- read_fictrac(temp_file)

  # Should have 6 columns: individual, keypoint, time, x, y, confidence
  expect_equal(ncol(result), 6)
  # expect_named(result, c("time", "x", "y"))

  # All other 22 columns should be dropped
})
