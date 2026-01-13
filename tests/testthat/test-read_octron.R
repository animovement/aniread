# Tests for read_octron
#
# - Returns an aniframe object
# - Contains expected columns after transformation
# - Column renaming works correctly (track_id -> individual, etc.)
# - Pivot creates three keypoints: centroid, bbox_min, bbox_max
# - Shape descriptors (area, eccentricity, solidity, orientation) are NA for bbox rows
# - Shape descriptors are present for centroid rows
# - keep_bbox = FALSE (default) filters out bbox rows
# - keep_bbox = TRUE keeps all keypoint rows
# - Row count is correct for both keep_bbox settings
# - Metadata is set correctly (source, filename)
# - Handles invalid file path

test_that("read_octron returns an aniframe with correct structure", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path)

  expect_s3_class(result, "aniframe")
  expect_named(
    result,
    c(
      "individual",
      "time",
      "label",
      "confidence",
      "keypoint",
      "x",
      "y",
      "area",
      "eccentricity",
      "solidity",
      "orientation"
    ),
    ignore.order = TRUE
  )
})

test_that("column renaming works correctly", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path, keep_bbox = TRUE)

  expect_true("individual" %in% names(result))
  expect_true("time" %in% names(result))
  expect_true("x" %in% names(result))
  expect_true("y" %in% names(result))

  expect_false("track_id" %in% names(result))
  expect_false("frame_idx" %in% names(result))
  expect_false("pos_x" %in% names(result))
  expect_false("pos_y" %in% names(result))
  expect_false("frame_counter" %in% names(result))
  expect_false("bbox_area" %in% names(result))
})

test_that("pivot creates three keypoints", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path, keep_bbox = TRUE)

  keypoints <- unique(result$keypoint)
  expect_setequal(keypoints, c("centroid", "bbox_min", "bbox_max"))
})

test_that("shape descriptors are NA for bbox rows only", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path, keep_bbox = TRUE)

  centroid_rows <- result[result$keypoint == "centroid", ]
  bbox_rows <- result[result$keypoint != "centroid", ]

  # Centroid rows should have values

  expect_false(any(is.na(centroid_rows$area)))
  expect_false(any(is.na(centroid_rows$eccentricity)))
  expect_false(any(is.na(centroid_rows$solidity)))
  expect_false(any(is.na(centroid_rows$orientation)))

  # Bbox rows should be NA
  expect_true(all(is.na(bbox_rows$area)))
  expect_true(all(is.na(bbox_rows$eccentricity)))
  expect_true(all(is.na(bbox_rows$solidity)))
  expect_true(all(is.na(bbox_rows$orientation)))
})

test_that("keep_bbox = FALSE filters out bbox rows", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path, keep_bbox = FALSE)

  expect_equal(unique(result$keypoint), factor("centroid"))
  expect_false("bbox_min" %in% result$keypoint)
  expect_false("bbox_max" %in% result$keypoint)
})

test_that("keep_bbox = TRUE keeps all keypoint rows", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path, keep_bbox = TRUE)

  keypoints <- unique(result$keypoint)
  expect_length(keypoints, 3)
  expect_true("bbox_min" %in% keypoints)
  expect_true("bbox_max" %in% keypoints)
})

test_that("row count is correct for keep_bbox settings", {
  path <- test_path("data/octron", "octron_sample.csv")

  result_no_bbox <- read_octron(path, keep_bbox = FALSE)
  result_with_bbox <- read_octron(path, keep_bbox = TRUE)

  # With bbox should have 3x as many rows (centroid + bbox_min + bbox_max)
  expect_equal(nrow(result_with_bbox), nrow(result_no_bbox) * 3)
})

test_that("metadata is set correctly", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path)

  metadata <- aniframe::get_metadata(result)
  expect_equal(metadata$source, "octron")
  expect_equal(metadata$filename, "octron_sample.csv")
})

test_that("invalid file path raises error", {
  expect_error(read_octron("nonexistent_file.csv"))
})
