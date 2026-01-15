# Tests for read_fasttrack()
#
# - Returns an aniframe
# - Has required columns (individual, keypoint, time, x, y, area)
# - Keypoints are head, centroid, and tail
# - Column types are correct
# - Correct number of rows (3x original due to keypoints)
# - Area is only non-NA for centroid keypoint
# - Metadata contains source and filename
# - Errors on invalid file path

path <- testthat::test_path("data/fasttrack/fasttrack-tracking.txt")

test_that("read_fasttrack returns an aniframe", {
  result <- read_fasttrack(path)
  expect_s3_class(result, "aniframe")
})

test_that("read_fasttrack has required columns", {
  result <- read_fasttrack(path)
  expect_true(all(
    c("individual", "keypoint", "time", "x", "y", "area") %in% names(result)
  ))
})

test_that("read_fasttrack has correct keypoints", {
  result <- read_fasttrack(path)
  keypoints <- levels(result$keypoint)
  expect_setequal(keypoints, c("head", "centroid", "tail"))
})

test_that("read_fasttrack column types are correct", {
  result <- read_fasttrack(path)
  expect_type(result$time, "double")
  expect_type(result$x, "double")

  expect_type(result$y, "double")
  expect_type(result$area, "double")
  expect_type(result$individual, "integer")
  expect_s3_class(result$keypoint, "factor")
})

test_that("read_fasttrack creates 3 rows per original row", {
  result <- read_fasttrack(path)
  original <- vroom::vroom(path, delim = "\t", show_col_types = FALSE)
  expect_equal(nrow(result), nrow(original) * 3)
})

test_that("read_fasttrack area is only present for centroid", {
  result <- read_fasttrack(path)

  centroid_area <- result |>
    dplyr::filter(keypoint == "centroid") |>
    dplyr::pull(area)
  expect_false(any(is.na(centroid_area)))

  other_area <- result |>
    dplyr::filter(keypoint != "centroid") |>
    dplyr::pull(area)
  expect_true(all(is.na(other_area)))
})

test_that("read_fasttrack populates metadata", {
  result <- read_fasttrack(path)
  meta <- aniframe::get_metadata(result)

  expect_equal(meta$source, "fasttrack")
  expect_equal(meta$filename, "fasttrack-tracking.txt")
})

test_that("read_fasttrack errors on invalid path", {
  expect_error(read_fasttrack("nonexistent_file.txt"))
})
