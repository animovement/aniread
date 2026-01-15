# Tests for read_deeplabcut functions
#
# Testing:
# - read_deeplabcut(): file validation, dispatch by extension, metadata
# - read_deeplabcut_csv(): auto-detection of multi-animal format
# - read_deeplabcut_csv_single(): correct parsing and output structure
# - read_deeplabcut_csv_multi(): correct parsing for multi-animal data
# - read_deeplabcut_h5(): H5 file reading (requires rhdf5)
# - parse_dlc_pickle(): pickle string parsing for single/multi-animal

# --- Setup ---
# Download H5 sample data once at the start
h5_path <- get_sample_data("deeplabcut")

# --- Fixtures ---
fixture_path <- function(filename) {
  test_path("data", "deeplabcut", filename)
}

# --- read_deeplabcut() ---

test_that("read_deeplabcut rejects invalid file extensions", {
  expect_error(
    read_deeplabcut("data.txt")
  )
  expect_error(
    read_deeplabcut("data.xlsx")
  )
})

test_that("read_deeplabcut rejects non-existent files", {
  expect_error(
    read_deeplabcut("nonexistent.csv")
  )
})

test_that("read_deeplabcut returns an aniframe", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))

  expect_s3_class(result, "aniframe")
})

test_that("read_deeplabcut sets correct metadata", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))
  meta <- aniframe::get_metadata(result)

  expect_equal(meta$source, "deeplabcut")
  expect_equal(meta$filename, "mouse_single.csv")
})

test_that("read_deeplabcut dispatches to CSV reader for .csv files", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))

  expect_s3_class(result, "aniframe")
  expect_true("time" %in% names(result))
})

test_that("read_deeplabcut dispatches to H5 reader for .h5 files", {
  skip_if_not_installed("rhdf5")

  result <- read_deeplabcut(h5_path)

  expect_s3_class(result, "aniframe")
  expect_true("time" %in% names(result))
})

# --- read_deeplabcut_csv() ---

test_that("read_deeplabcut_csv auto-detects single-animal format", {
  result <- read_deeplabcut_csv(fixture_path("mouse_single.csv"))

  expect_false("individual" %in% names(result))
})

test_that("read_deeplabcut_csv auto-detects multi-animal format", {
  result <- read_deeplabcut_csv(fixture_path("mouse_multi.csv"))

  expect_true("individual" %in% names(result))
})

test_that("read_deeplabcut_csv respects multianimal argument", {
  result <- read_deeplabcut_csv(
    fixture_path("mouse_single.csv"),
    multianimal = FALSE
  )

  expect_false("individual" %in% names(result))
})

# --- read_deeplabcut_csv_single() ---

test_that("read_deeplabcut_csv_single returns expected columns", {
  result <- read_deeplabcut_csv_single(fixture_path("mouse_single.csv"))
  expected_cols <- c("time", "keypoint", "x", "y", "confidence")

  expect_true(all(expected_cols %in% names(result)))
  expect_false("individual" %in% names(result))
})

test_that("read_deeplabcut_csv_single has factor keypoint column", {
  result <- read_deeplabcut_csv_single(fixture_path("mouse_single.csv"))

  expect_s3_class(result$keypoint, "factor")
})

test_that("read_deeplabcut_csv_single parses coordinates as numeric", {
  result <- read_deeplabcut_csv_single(fixture_path("mouse_single.csv"))

  expect_type(result$x, "double")
  expect_type(result$y, "double")
  expect_type(result$confidence, "double")
})

# --- read_deeplabcut_csv_multi() ---

test_that("read_deeplabcut_csv_multi returns expected columns", {
  result <- read_deeplabcut_csv_multi(fixture_path("mouse_multi.csv"))
  expected_cols <- c("time", "individual", "keypoint", "x", "y", "confidence")

  expect_true(all(expected_cols %in% names(result)))
})

test_that("read_deeplabcut_csv_multi has factor individual column", {
  result <- read_deeplabcut_csv_multi(fixture_path("mouse_multi.csv"))

  expect_true("individual" %in% names(result))
  expect_s3_class(result$individual, "factor")
})

test_that("read_deeplabcut_csv_multi has factor keypoint column", {
  result <- read_deeplabcut_csv_multi(fixture_path("mouse_multi.csv"))

  expect_s3_class(result$keypoint, "factor")
})

test_that("read_deeplabcut_csv_multi parses coordinates as numeric", {
  result <- read_deeplabcut_csv_multi(fixture_path("mouse_multi.csv"))

  expect_type(result$x, "double")
  expect_type(result$y, "double")
  expect_type(result$confidence, "double")
})

# --- read_deeplabcut_h5() ---

test_that("read_deeplabcut_h5 returns expected columns for single-animal", {
  skip_if_not_installed("rhdf5")

  result <- read_deeplabcut_h5(h5_path)
  expected_cols <- c("time", "keypoint", "x", "y", "confidence")

  expect_true(all(expected_cols %in% names(result)))
})

test_that("read_deeplabcut_h5 parses coordinates as numeric", {
  skip_if_not_installed("rhdf5")

  result <- read_deeplabcut_h5(h5_path)

  expect_type(result$x, "double")
  expect_type(result$y, "double")
  expect_type(result$confidence, "double")
})

# --- parse_dlc_pickle() ---

test_that("parse_dlc_pickle returns tibble with expected columns (single)", {
  pickle_str <- paste0(
    "Vscorer\n",
    "Vbodypart1\nVx\nVy\nVlikelihood\n",
    "Vbodypart2\nVx\nVy\nVlikelihood"
  )

  result <- parse_dlc_pickle(pickle_str, multianimal = FALSE)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("bodypart", "coord"))
})

test_that("parse_dlc_pickle extracts correct bodyparts (single)", {
  pickle_str <- paste0(
    "Vscorer\n",
    "Vnose\nVx\nVy\nVlikelihood\n",
    "Vtail\nVx\nVy\nVlikelihood"
  )

  result <- parse_dlc_pickle(pickle_str, multianimal = FALSE)

  expect_true("nose" %in% result$bodypart)
  expect_true("tail" %in% result$bodypart)
})

test_that("parse_dlc_pickle extracts correct coords (single)", {
  pickle_str <- "Vscorer\nVnose\nVx\nVy\nVlikelihood"

  result <- parse_dlc_pickle(pickle_str, multianimal = FALSE)

  expect_equal(result$coord, c("x", "y", "likelihood"))
})

test_that("parse_dlc_pickle returns tibble with expected columns (multi)", {
  pickle_str <- paste0(
    "Vscorer\n",
    "Vindividual1\nVbodypart1\nVx\nVy\nVlikelihood\n",
    "Vbodypart2\nVx\nVy\nVlikelihood\n",
    "Vindividual2\nVbodypart1\nVx\nVy\nVlikelihood\n",
    "Vbodypart2\nVx\nVy\nVlikelihood"
  )

  result <- parse_dlc_pickle(pickle_str, multianimal = TRUE)

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("individual", "bodypart", "coord"))
})

# --- Integration tests ---

test_that("single-animal CSV and H5 produce consistent column names", {
  skip_if_not_installed("rhdf5")

  csv_result <- read_deeplabcut(fixture_path("mouse_single.csv"))
  h5_result <- read_deeplabcut(h5_path)

  # Both should have the same column structure
  # (though h5 single-animal may not have individual column)
  shared_cols <- c("time", "keypoint", "x", "y", "confidence")
  expect_true(all(shared_cols %in% names(csv_result)))
  expect_true(all(shared_cols %in% names(h5_result)))
})

test_that("output is valid aniframe with required columns", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))

  # aniframes need time, x, y at minimum
  expect_true("time" %in% names(result))
  expect_true("x" %in% names(result))
  expect_true("y" %in% names(result))
})

test_that("multi-animal output has multiple individuals", {
  result <- read_deeplabcut(fixture_path("mouse_multi.csv"))

  n_individuals <- length(unique(result$individual))
  expect_gt(n_individuals, 1)
})
