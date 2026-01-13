# Test suite for read_custom function
#
# Tests cover:
# - File validation (existence, readability)
# - Successful data import
# - Column selection and renaming with character names
# - Column selection and renaming with numeric indices
# - aniframe conversion
# - Metadata assignment
# - Variables specification (what, when, where)
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

  # Data with trials
  trial_data <- data.frame(
    id = rep(1:2, each = 10),
    trial = rep(1:2, each = 5, times = 2),
    frame = rep(1:5, 4),
    x = rnorm(20, 0, 1),
    y = rnorm(20, 0, 1)
  )

  # Empty data (just headers)
  empty_data <- valid_data[0, ]

  # Write files
  paths <- list(
    valid = file.path(dir, "valid_test_file.csv"),
    custom_names = file.path(dir, "custom_names.csv"),
    trial = file.path(dir, "trial_data.csv"),
    empty = file.path(dir, "empty_file.csv"),
    nonexistent = file.path(dir, "nonexistent_file.csv")
  )

  vroom::vroom_write(valid_data, paths$valid, delim = ",")
  vroom::vroom_write(custom_names_data, paths$custom_names, delim = ",")
  vroom::vroom_write(trial_data, paths$trial, delim = ",")
  vroom::vroom_write(empty_data, paths$empty, delim = ",")

  paths
}

# Parameters --------------------------------------------------------------

# Generate test files
test_files <- create_test_files()

# File paths
path_valid <- test_files$valid
path_custom_names <- test_files$custom_names
path_trial <- test_files$trial
path_nonexistent <- test_files$nonexistent
path_empty <- test_files$empty

# Expected column names
required_base_columns <- c("time", "x", "y")

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

# Variables specification -------------------------------------------------

test_that("read_custom respects variables_what", {
  result <- read_custom(
    path_valid,
    cols = c(individual = "id", time = "time", x = "x", y = "y"),
    variables_what = "individual"
  )

  expect_true("individual" %in% dplyr::group_vars(result))
  expect_equal(aniframe::get_metadata(result)$variables_what, "individual")
})

test_that("read_custom respects variables_when", {
  result <- read_custom(
    path_trial,
    cols = c(id = "id", trial = "trial", time = "frame", x = "x", y = "y"),
    variables_what = "id",
    variables_when = c("trial", "time")
  )

  expect_equal(
    aniframe::get_metadata(result)$variables_when,
    c("trial", "time")
  )
  expect_true("trial" %in% dplyr::group_vars(result))
  expect_false("time" %in% dplyr::group_vars(result))
})

test_that("read_custom respects variables_where", {
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y", z = "z"),
    variables_where = c("x", "y", "z")
  )

  expect_equal(aniframe::get_metadata(result)$variables_where, c("x", "y", "z"))
  expect_equal(
    as.character(aniframe::get_metadata(result)$coordinate_system),
    "cartesian_3d"
  )
})

test_that("read_custom works with renamed temporal column", {
  result <- read_custom(
    path_custom_names,
    cols = c(time = "frame", x = "pos_x", y = "pos_y")
  )

  expect_s3_class(result, "aniframe")
  expect_equal(aniframe::get_metadata(result)$variables_when, "time")
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
    cols = c(time = "time", x = "x", y = "y", z = "z"),
    variables_where = c("x", "y", "z")
  )

  meta <- aniframe::get_metadata(result)
  expect_equal(as.character(meta$coordinate_system), "cartesian_3d")
})

test_that("read_custom stores variables in metadata", {
  result <- read_custom(
    path_valid,
    cols = c(individual = "id", time = "time", x = "x", y = "y"),
    variables_what = "individual",
    variables_when = "time",
    variables_where = c("x", "y")
  )

  meta <- aniframe::get_metadata(result)
  expect_equal(meta$variables_what, "individual")
  expect_equal(meta$variables_when, "time")
  expect_equal(meta$variables_where, c("x", "y"))
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

test_that("read_custom errors when no spatial variables found", {
  expect_error(
    read_custom(
      path_valid,
      cols = c(time = "time", value = "id")
    ),
    "No spatial variables found"
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
    cols = c(time = "time", x = "x", y = "y", z = "z", id = "id"),
    variables_where = c("x", "y", "z")
  )

  expect_true(all(c("time", "x", "y", "z", "id") %in% names(result)))
})

test_that("read_custom maintains column order", {
  result <- read_custom(
    path_valid,
    cols = c(time = "time", x = "x", y = "y", z = "z"),
    variables_where = c("x", "y", "z")
  )

  # Columns should be ordered: when, where, rest
  expect_equal(names(result), c("keypoint", "time", "x", "y", "z"))
})

# Integration tests -------------------------------------------------------

test_that("read_custom output works with aniframe functions", {
  result <- read_custom(path_valid, cols = c(time = "time", x = "x", y = "y"))

  expect_no_error(aniframe::get_metadata(result))
  expect_s3_class(result, "aniframe")
})


test_that("read_custom output is grouped when identity variables specified", {
  result <- read_custom(
    path_valid,
    cols = c(individual = "id", time = "time", x = "x", y = "y"),
    variables_what = "individual"
  )

  expect_true(dplyr::is_grouped_df(result))
  expect_true("individual" %in% dplyr::group_vars(result))
})
