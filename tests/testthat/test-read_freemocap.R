# Test suite for read_freemocap function
#
# Tests cover:
# - File validation (existence, readability, correct format)
# - Successful data import
# - Column structure and renaming
# - Data type conversion
# - aniframe conversion
# - Metadata assignment (source, units, coordinate system, etc.)
# - Special column handling (timestamps, IDs, etc.)
# - Error handling for invalid inputs
# - Edge cases (empty data, missing columns, malformed data)

# Helper function ---------------------------------------------------------

create_test_files <- function(dir = tempdir()) {
  # Valid data without timestamps
  valid_data <- data.frame(
    frame = rep(0:2, each = 3),
    timestamp = NA_character_,
    timestamp_by_camera = "{}",
    model = "mediapipe_body",
    keypoint = rep(c("nose", "left_eye", "right_eye"), 3),
    x = rnorm(9, -200, 50),
    y = rnorm(9, -600, 50),
    z = rnorm(9, 1600, 50)
  )

  # Valid data with timestamps
  valid_data_timestamps <- valid_data
  valid_data_timestamps$timestamp <- as.POSIXct("2024-01-01 12:00:00") +
    rep(0:2, each = 3) * 0.033

  # Wrong format (too many columns - non-tidy format)
  wrong_format_data <- data.frame(
    frame = 0:2,
    timestamp = NA_character_,
    extra_col_1 = 1:3,
    extra_col_2 = 1:3,
    extra_col_3 = 1:3,
    extra_col_4 = 1:3,
    extra_col_5 = 1:3,
    extra_col_6 = 1:3,
    extra_col_7 = 1:3,
    extra_col_8 = 1:3,
    extra_col_9 = 1:3
  )

  # Missing required columns
  missing_cols_data <- data.frame(
    frame = 0:2,
    timestamp = NA_character_,
    model = "mediapipe_body",
    keypoint = c("nose", "left_eye", "right_eye")
    # Missing x, y, z columns
  )

  # Malformed data (non-numeric coordinates)
  malformed_data <- valid_data
  malformed_data$x <- c("not", "a", "number", rep(NA, 6))

  # Empty data (just headers)
  empty_data <- valid_data[0, ]

  # Write files
  paths <- list(
    valid = file.path(dir, "valid_test_file.csv"),
    valid_with_timestamps = file.path(dir, "file_with_timestamps.csv"),
    wrong_format = file.path(dir, "wrong_format.csv"),
    missing_columns = file.path(dir, "missing_columns.csv"),
    malformed = file.path(dir, "malformed_data.csv"),
    empty = file.path(dir, "empty_file.csv"),
    nonexistent = file.path(dir, "nonexistent_file.csv")
  )

  vroom::vroom_write(valid_data, paths$valid, delim = ",")
  vroom::vroom_write(valid_data_timestamps, paths$valid_with_timestamps, delim = ",")
  vroom::vroom_write(wrong_format_data, paths$wrong_format, delim = ",")
  vroom::vroom_write(missing_cols_data, paths$missing_columns, delim = ",")
  vroom::vroom_write(malformed_data, paths$malformed, delim = ",")
  vroom::vroom_write(empty_data, paths$empty, delim = ",")

  paths
}

# Parameters --------------------------------------------------------------

# Generate test files
test_files <- create_test_files()

# File paths
path_valid <- test_files$valid
path_nonexistent <- test_files$nonexistent
path_wrong_format <- test_files$wrong_format
path_with_timestamps <- test_files$valid_with_timestamps
path_without_timestamps <- test_files$valid
path_empty <- test_files$empty
path_missing_columns <- test_files$missing_columns
path_malformed <- test_files$malformed

# Expected metadata values
default_metadata <- aniframe::default_metadata()
expected_source <- "freemocap"
expected_unit_space <- factor("mm", levels = levels(default_metadata$unit_space))
expected_unit_time_with_timestamps <- factor("s", levels = levels(default_metadata$unit_time))
expected_unit_time_without_timestamps <- factor("frame", levels = levels(default_metadata$unit_time))
expected_coordinate_system <- factor("cartesian_3d", levels = levels(default_metadata$coordinate_system))
expected_filename <- basename(path_valid)

# Expected column names
required_columns <- c("time", "x", "y")
removed_columns <- c("timestamp_by_camera", "timestamp")
old_column_name <- "frame"
timestamp_column <- "timestamp"

# Expected data types
expected_type_time <- "double"
expected_type_x <- "double"
expected_type_y <- "double"

# Expected error messages/patterns
error_wrong_format <- "only support FreeMoCap data in tidy format"

# Tests -------------------------------------------------------------------

# File validation ---------------------------------------------------------

test_that("read_freemocap validates file existence", {
  expect_error(
    read_freemocap(path_nonexistent)
  )
})

test_that("read_freemocap rejects incorrect file format", {
  expect_error(
    read_freemocap(path_wrong_format),
    error_wrong_format
  )
})

# Successful import -------------------------------------------------------

test_that("read_freemocap successfully imports valid data", {
  result <- read_freemocap(path_valid)

  expect_s3_class(result, "aniframe")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("read_freemocap has required columns", {
  result <- read_freemocap(path_valid)

  expect_true(all(required_columns %in% names(result)))
})

# Column handling ---------------------------------------------------------

test_that("read_freemocap renames columns correctly", {
  result <- read_freemocap(path_valid)

  expect_false(old_column_name %in% names(result))
  expect_true("time" %in% names(result))
})

test_that("read_freemocap removes unnecessary columns", {
  result <- read_freemocap(path_valid)

  expect_false(any(removed_columns %in% names(result)))
})

# Data type conversion ----------------------------------------------------

test_that("read_freemocap converts data types correctly", {
  result <- read_freemocap(path_valid)

  expect_type(result$time, expected_type_time)
  expect_type(result$x, expected_type_x)
  expect_type(result$y, expected_type_y)
})

# Metadata ----------------------------------------------------------------

test_that("read_freemocap sets correct source metadata", {
  result <- read_freemocap(path_valid)

  meta <- aniframe::get_metadata(result)
  expect_equal(meta$source, expected_source)
})

test_that("read_freemocap sets correct unit metadata", {
  result <- read_freemocap(path_valid)

  meta <- aniframe::get_metadata(result)
  expect_equal(meta$unit_space, expected_unit_space)
})

test_that("read_freemocap sets correct coordinate system", {
  result <- read_freemocap(path_valid)

  meta <- aniframe::get_metadata(result)
  expect_equal(meta$coordinate_system, expected_coordinate_system)
})

test_that("read_freemocap sets filename in metadata", {
  result <- read_freemocap(path_valid)

  meta <- aniframe::get_metadata(result)
  expect_equal(meta$filename, expected_filename)
})

# Special column handling -------------------------------------------------

test_that("read_freemocap handles timestamps when present", {
  result <- read_freemocap(path_with_timestamps)

  meta <- aniframe::get_metadata(result)
  expect_true("start_datetime" %in% names(meta))
  expect_equal(meta$unit_time, expected_unit_time_with_timestamps)
  expect_false(timestamp_column %in% names(result))
})

test_that("read_freemocap handles missing timestamps", {
  result <- read_freemocap(path_without_timestamps)

  meta <- aniframe::get_metadata(result)
  expect_true("start_datetime" %in% names(meta))
  expect_equal(meta$unit_time, expected_unit_time_without_timestamps)
})

test_that("read_freemocap converts elapsed time correctly", {
  result <- read_freemocap(path_with_timestamps)

  # First time point should be 0
  expect_equal(min(result$time), 0)
  # Time should be numeric (seconds)
  expect_type(result$time, "double")
})

# Edge cases --------------------------------------------------------------

test_that("read_freemocap handles empty data gracefully", {
  result <- read_freemocap(path_empty)
  expect_equal(nrow(result), 0)
  expect_s3_class(result, "aniframe")
})

# Integration tests -------------------------------------------------------

test_that("read_freemocap output works with aniframe functions", {
  result <- read_freemocap(path_valid)

  expect_no_error(aniframe::get_metadata(result))
})
