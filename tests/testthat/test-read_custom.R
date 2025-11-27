# Test suite for read_custom function
#
# Tests cover:
# - File validation (existence, readability)
# - Successful data import
# - Column selection and renaming with character names
# - Column selection and renaming with numeric indices
# - aniframe conversion and column additions
# - Metadata assignment
# - Error handling for invalid inputs (missing columns, out of bounds indices)
# - Edge cases (empty data, additional columns)

# Helper function ---------------------------------------------------------

create_test_files <- function(dir = tempdir()) {
  # Valid data with standard column names
  valid_data <- data.frame(
    time = 0:9,
    x = rnorm(10, 0, 1),
    y = rnorm(10, 0, 1),
    z = rnorm(10, 0, 1),
    id = rep(1:2, each = 5)
  )

  # Valid data with custom column names
  custom_names_data <- data.frame(
    frame = 0:9,
    pos_x = rnorm(10, 0, 1),
    pos_y = rnorm(10, 0, 1),
    subject = rep(c("A", "B"), each = 5)
  )

  # Data with missing columns
  missing_cols_data <- data.frame(
    time = 0:9,
    x = rnorm(10, 0, 1)
    # Missing y column
  )

  # Empty data (just headers)
  empty_data <- valid_data[0, ]

  # Write files
  paths <- list(
    valid = file.path(dir, "valid_test_file.csv"),
    custom_names = file.path(dir, "custom_names.csv"),
    missing_columns = file.path(dir, "missing_columns.csv"),
    empty = file.path(dir, "empty_file.csv"),
    nonexistent = file.path(dir, "nonexistent_file.csv")
  )

  vroom::vroom_write(valid_data, paths$valid, delim = ",")
  vroom::vroom_write(custom_names_data, paths$custom_names, delim = ",")
  vroom::vroom_write(missing_cols_data, paths$missing_columns, delim = ",")
  vroom::vroom_write(empty_data, paths$empty, delim = ",")

  paths
}

# Parameters --------------------------------------------------------------

# Generate test files
test_files <- create_test_files()

# File paths
path_valid <- test_files$valid
path_custom_names <- test_files$custom_names
path_nonexistent <- test_files$nonexistent
path_empty <- test_files$empty
path_missing_columns <- test_files$missing_columns

# Expected column names (after as_aniframe adds standard columns)
required_base_columns <- c("time", "x", "y")
aniframe_added_columns <- c("individual", "keypoint", "confidence")

# Expected data types
expected_type_time <- "double"
expected_type_x <- "double"
expected_type_y <- "double"

# Tests -------------------------------------------------------------------

# File validation ---------------------------------------------------------

test_that("read_custom validates file existence", {
  expect_error(
    read_custom(path_nonexistent, cols = c(time = "time", x = "x", y = "y"))
  )
})

test_that("read_custom requires cols argument", {
  expect_error(
    read_custom(path_valid),
    'argument "cols" is missing'
  )
})

# Successful import -------------------------------------------------------

test_that("read_custom successfully imports valid data", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_s3_class(result, "aniframe")
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("read_custom has required columns", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_true(all(required_base_columns %in% names(result)))
})

test_that("read_custom adds standard aniframe columns", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_true(all(aniframe_added_columns %in% names(result)))
})

# Column handling with character names ------------------------------------

test_that("read_custom selects and renames columns with character names", {
  result <- read_custom(
    path_custom_names,
    cols = c(time = "frame", x = "pos_x", y = "pos_y")
  )

  expect_true(all(c("time", "x", "y") %in% names(result)))
  expect_false("frame" %in% names(result))
  expect_false("pos_x" %in% names(result))
  expect_false("pos_y" %in% names(result))
})

test_that("read_custom keeps only specified columns with character names", {
  result <- read_custom(
    path_custom_names,
    cols = c(time = "frame", x = "pos_x", y = "pos_y")
  )

  # Should have the 3 specified columns plus aniframe-added columns
  expect_false("subject" %in% names(result))
  expect_true(all(c("time", "x", "y") %in% names(result)))
})

# Column handling with numeric indices ------------------------------------

test_that("read_custom selects and renames columns with numeric indices", {
  result <- read_custom(
    path_custom_names,
    cols = c(time = 1, x = 2, y = 3)
  )

  expect_true(all(c("time", "x", "y") %in% names(result)))
})

test_that("read_custom handles numeric indices correctly", {
  result <- read_custom(
    path_valid,
    cols = c(time = 1, x = 2, y = 3)
  )

  expect_s3_class(result, "aniframe")
  expect_true(all(c("time", "x", "y") %in% names(result)))
})

# Data type conversion ----------------------------------------------------

test_that("read_custom preserves correct data types", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_type(result$time, expected_type_time)
  expect_type(result$x, expected_type_x)
  expect_type(result$y, expected_type_y)
})

test_that("read_custom converts aniframe columns to correct types", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_s3_class(result$individual, "factor")
  expect_s3_class(result$keypoint, "factor")
  expect_type(result$confidence, "double")
})

# Metadata ----------------------------------------------------------------

test_that("read_custom sets custom metadata", {
  custom_meta <- list(source = "custom_source", unit_space = "m")
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y"),
    metadata = custom_meta
  )

  meta <- aniframe::get_metadata(result)
  expect_equal(meta$source, "custom_source")
})

test_that("read_custom works with empty metadata list", {
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y"),
    metadata = list()
  )

  expect_s3_class(result, "aniframe")
  expect_no_error(aniframe::get_metadata(result))
})

test_that("read_custom sets coordinate system metadata", {
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y", z = "z")
  )

  meta <- aniframe::get_metadata(result)
  expect_s3_class(meta$coordinate_system, "factor")
})

# Error handling ----------------------------------------------------------

test_that("read_custom errors when specified columns don't exist", {
  expect_error(
    read_custom(
      path_valid,
      cols = c(time = "nonexistent_col", x = "x", y = "y")
    )
  )
})

test_that("read_custom errors when numeric index is out of bounds", {
  expect_error(
    read_custom(
      path_valid,
      cols = c(time = 1, x = 2, y = 999)
    )
  )
})

# Edge cases --------------------------------------------------------------

test_that("read_custom handles empty data gracefully", {
  result <- read_custom(
    path_empty,
    cols = c(time = "time", x = "x", y = "y")
  )

  expect_equal(nrow(result), 0)
  expect_s3_class(result, "aniframe")
  expect_true(all(required_base_columns %in% names(result)))
})

test_that("read_custom works with additional columns beyond required", {
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y", z = "z", id = "id")
  )

  # Should have 5 specified + 3 aniframe-added columns
  expect_true(all(c("time", "x", "y", "z", "id") %in% names(result)))
  expect_true(all(aniframe_added_columns %in% names(result)))
})

test_that("read_custom maintains column order", {
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y", z = "z")
  )

  # Standard columns should come first according to as_aniframe
  first_cols <- names(result)[1:6]
  expect_true("time" %in% first_cols)
  expect_true("x" %in% first_cols)
  expect_true("y" %in% first_cols)
  expect_true("z" %in% first_cols)
})

# Integration tests -------------------------------------------------------

test_that("read_custom output works with aniframe functions", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_no_error(aniframe::get_metadata(result))
  expect_s3_class(result, "aniframe")
})

test_that("read_custom output is grouped correctly", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  # as_aniframe groups by individual and keypoint if present
  expect_true(dplyr::is_grouped_df(result))
})
