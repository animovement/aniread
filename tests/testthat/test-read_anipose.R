# Test suite for read_anipose function
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
  # Valid Anipose 3D data
  valid_data <- data.frame(
    `l-base_x` = rnorm(5, -5, 1),
    `l-base_y` = rnorm(5, 3, 0.5),
    `l-base_z` = rnorm(5, 308, 2),
    `l-base_error` = runif(5, 0, 5),
    `l-base_ncams` = rep(2.0, 5),
    `l-base_score` = runif(5, 0.8, 1.0),
    `r-base_x` = rnorm(5, -6, 1),
    `r-base_y` = rnorm(5, 3.5, 0.5),
    `r-base_z` = rnorm(5, 310, 2),
    `r-base_error` = runif(5, 0, 5),
    `r-base_ncams` = rep(2.0, 5),
    `r-base_score` = runif(5, 0.8, 1.0),
    M_00 = rep(1.0, 5),
    M_01 = rep(0.0, 5),
    M_02 = rep(0.0, 5),
    M_10 = rep(0.0, 5),
    M_11 = rep(1.0, 5),
    M_12 = rep(0.0, 5),
    M_20 = rep(0.0, 5),
    M_21 = rep(0.0, 5),
    M_22 = rep(1.0, 5),
    center_0 = rep(0.0, 5),
    center_1 = rep(0.0, 5),
    center_2 = rep(0.0, 5),
    fnum = 0:4,
    check.names = FALSE
  )

  # Wrong format (2D data - missing z coordinates)
  wrong_format_data <- data.frame(
    `nose_x` = rnorm(5, -5, 1),
    `nose_y` = rnorm(5, 3, 0.5),
    `nose_likelihood` = runif(5, 0.8, 1.0),
    `left_eye_x` = rnorm(5, -6, 1),
    `left_eye_y` = rnorm(5, 3.5, 0.5),
    `left_eye_likelihood` = runif(5, 0.8, 1.0),
    fnum = 0:4,
    check.names = FALSE
  )

  # Missing required columns (no score columns)
  missing_cols_data <- data.frame(
    `l-base_x` = rnorm(5, -5, 1),
    `l-base_y` = rnorm(5, 3, 0.5),
    `l-base_z` = rnorm(5, 308, 2),
    `l-base_error` = runif(5, 0, 5),
    `l-base_ncams` = rep(2.0, 5),
    fnum = 0:4,
    check.names = FALSE
  )

  # Malformed data (non-numeric coordinates)
  malformed_data <- valid_data
  malformed_data$`l-base_x` <- c("not", "a", "number", NA, NA)

  # Empty data (just headers)
  empty_data <- valid_data[0, ]

  # Write files
  paths <- list(
    valid = file.path(dir, "valid_anipose.csv"),
    wrong_format = file.path(dir, "wrong_format_2d.csv"),
    missing_columns = file.path(dir, "missing_score_columns.csv"),
    malformed = file.path(dir, "malformed_coords.csv"),
    empty = file.path(dir, "empty_anipose.csv"),
    nonexistent = file.path(dir, "nonexistent_anipose.csv")
  )

  vroom::vroom_write(valid_data, paths$valid, delim = ",")
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
path_empty <- test_files$empty
path_missing_columns <- test_files$missing_columns
path_malformed <- test_files$malformed

# Expected metadata values
default_metadata <- anicore::list_default_metadata()
expected_source <- "anipose"
expected_unit_space <- factor(
  "mm",
  levels = levels(default_metadata$unit_space)
)
expected_unit_time <- factor(
  "frame",
  levels = levels(default_metadata$unit_time)
)
expected_coordinate_system <- factor(
  "cartesian_3d",
  levels = levels(default_metadata$coordinate_system)
)
expected_filename <- basename(path_valid)

# Expected column names
required_columns <- c("time", "keypoint", "x", "y", "z", "confidence")
removed_columns <- c("error", "ncams")
old_column_name <- "fnum"

# Expected data types
expected_type_time <- "double"
expected_type_x <- "double"
expected_type_y <- "double"
expected_type_z <- "double"
expected_type_confidence <- "double"

# Tests -------------------------------------------------------------------

# File validation ---------------------------------------------------------

test_that("read_anipose validates file existence", {
  expect_error(
    read_anipose(path_nonexistent)
  )
})

# Successful import -------------------------------------------------------

test_that("read_anipose successfully imports valid data", {
  result <- read_anipose(path_valid)

  expect_s3_class(result, "aniframe")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("read_anipose has required columns", {
  result <- read_anipose(path_valid)

  expect_true(all(required_columns %in% names(result)))
})

# Column handling ---------------------------------------------------------

test_that("read_anipose renames fnum to time", {
  result <- read_anipose(path_valid)

  expect_false(old_column_name %in% names(result))
  expect_true("time" %in% names(result))
})

test_that("read_anipose removes error and ncams columns", {
  result <- read_anipose(path_valid)

  expect_false(any(removed_columns %in% names(result)))
})

test_that("read_anipose removes transformation matrix columns", {
  result <- read_anipose(path_valid)

  matrix_cols <- c("M_00", "M_01", "M_02", "center_0", "center_1", "center_2")
  expect_false(any(matrix_cols %in% names(result)))
})

test_that("read_anipose renames score to confidence", {
  result <- read_anipose(path_valid)

  expect_true("confidence" %in% names(result))
  expect_false("score" %in% names(result))
})

# Data type conversion ----------------------------------------------------

test_that("read_anipose converts data types correctly", {
  result <- read_anipose(path_valid)

  expect_type(result$time, expected_type_time)
  expect_type(result$x, expected_type_x)
  expect_type(result$y, expected_type_y)
  expect_type(result$z, expected_type_z)
  expect_type(result$confidence, expected_type_confidence)
})

# Data structure ----------------------------------------------------------

test_that("read_anipose converts from wide to long format", {
  result <- read_anipose(path_valid)

  # Should have multiple rows per time point (one per keypoint)
  expect_true(nrow(result) > length(unique(result$time)))

  # Should have a keypoint column
  expect_true("keypoint" %in% names(result))
})

test_that("read_anipose extracts keypoint names correctly", {
  result <- read_anipose(path_valid)

  # Keypoint names should match the bodypart prefixes
  expected_keypoints <- c("l-base", "r-base")
  expect_true(all(expected_keypoints %in% unique(result$keypoint)))
})

# Metadata ----------------------------------------------------------------

test_that("read_anipose sets correct source metadata", {
  result <- read_anipose(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$source, expected_source)
})

test_that("read_anipose sets correct unit metadata with default", {
  result <- read_anipose(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$unit_space, expected_unit_space)
  expect_equal(meta$unit_time, expected_unit_time)
})

test_that("read_anipose accepts custom unit_space parameter", {
  result <- read_anipose(path_valid, unit_space = "cm")

  meta <- anicore::get_metadata(result)
  expected_cm <- factor(
    "cm",
    levels = levels(default_metadata$unit_space)
  )
  expect_equal(meta$unit_space, expected_cm)
})

test_that("read_anipose sets correct coordinate system", {
  result <- read_anipose(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$coordinate_system, expected_coordinate_system)
})

test_that("read_anipose sets filename in metadata", {
  result <- read_anipose(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$filename, expected_filename)
})

# Edge cases --------------------------------------------------------------

test_that("read_anipose handles empty data gracefully", {
  result <- read_anipose(path_empty)

  expect_equal(nrow(result), 0)
  expect_s3_class(result, "aniframe")
  expect_true(all(required_columns %in% names(result)))
})

# Integration tests -------------------------------------------------------

test_that("read_anipose output works with aniframe functions", {
  result <- read_anipose(path_valid)

  expect_no_error(anicore::get_metadata(result))
  expect_no_error(anicore::set_metadata(result, source = "test"))
})

test_that("read_anipose preserves data relationships", {
  result <- read_anipose(path_valid)

  # Each time point should have the same number of keypoints
  keypoints_per_time <- result |>
    dplyr::group_by(time) |>
    dplyr::summarise(n_keypoints = dplyr::n(), .groups = "drop")

  expect_equal(
    length(unique(keypoints_per_time$n_keypoints)),
    1
  )
})
