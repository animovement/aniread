# Tests for read_octron
#
# - Returns an aniframe object
# - Contains expected columns after transformation
# - Column renaming works correctly (track_id -> individual, etc.)
# - Pivot creates three keypoints: centroid, bbox_min, bbox_max
# - Shape descriptors (area, eccentricity, solidity, orientation) are NA for bbox rows
# - Shape descriptors are present for centroid rows
# - bbox_area and other descriptors are kept as centroid-only columns
# - keep_bbox = FALSE (default) filters out bbox rows
# - keep_bbox = TRUE keeps all keypoint rows
# - Row count is correct for both keep_bbox settings
# - Metadata is set correctly (source, filename)
# - Handles invalid file path
# - Newer format (bytetrack, no shape descriptors) is also supported

test_that("read_octron returns an aniframe with correct structure", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path)

  expect_s3_class(result, "aniframe")
  expect_named(
    result,
    c(
      "track",
      "time",
      "label",
      "confidence",
      "keypoint",
      "x",
      "y",
      "bbox_area",
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

  expect_true("track" %in% names(result))
  expect_true("time" %in% names(result))
  expect_true("x" %in% names(result))
  expect_true("y" %in% names(result))

  expect_false("track_id" %in% names(result))
  expect_false("frame_idx" %in% names(result))
  expect_false("pos_x" %in% names(result))
  expect_false("pos_y" %in% names(result))
  expect_false("frame_counter" %in% names(result))
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

test_that("read_octron reflects to bottom_left using header video_height", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path)
  metadata <- aniframe::get_metadata(result)

  expect_equal(as.character(metadata$origin), "bottom_left")
  expect_true(is.finite(metadata$y_height))
  expect_true(metadata$y_height >= max(result$y, na.rm = TRUE))
})

test_that("read_octron `video_height` overrides the CSV header value", {
  path <- test_path("data/octron", "octron_sample.csv")
  default <- read_octron(path)
  override <- read_octron(path, video_height = 9999)

  default_meta <- aniframe::get_metadata(default)
  override_meta <- aniframe::get_metadata(override)

  expect_equal(override_meta$y_height, 9999)
  # Same x, shifted y by the difference between the two heights.
  shift <- 9999 - default_meta$y_height
  expect_equal(override$y, default$y + shift)
})

test_that("invalid file path raises error", {
  expect_error(read_octron("nonexistent_file.csv"))
})

# Tests for newer Octron format (bytetrack, no shape descriptors, has bbox_aspect_ratio)
test_that("read_octron handles newer format without shape descriptors", {
  path <- test_path("data/octron", "octron_sample_bytetrack.csv")
  result <- read_octron(path)

  expect_s3_class(result, "aniframe")
  expect_named(
    result,
    c(
      "track",
      "time",
      "label",
      "confidence",
      "keypoint",
      "x",
      "y",
      "bbox_area",
      "bbox_aspect_ratio"
    ),
    ignore.order = TRUE
  )
})

test_that("newer format: bbox_area and bbox_aspect_ratio are NA for bbox rows", {
  path <- test_path("data/octron", "octron_sample_bytetrack.csv")
  result <- read_octron(path, keep_bbox = TRUE)

  centroid_rows <- result[result$keypoint == "centroid", ]
  bbox_rows <- result[result$keypoint != "centroid", ]

  expect_false(any(is.na(centroid_rows$bbox_area)))
  expect_false(any(is.na(centroid_rows$bbox_aspect_ratio)))
  expect_true(all(is.na(bbox_rows$bbox_area)))
  expect_true(all(is.na(bbox_rows$bbox_aspect_ratio)))
})

test_that("newer format: row count is correct", {
  path <- test_path("data/octron", "octron_sample_bytetrack.csv")

  result_no_bbox <- read_octron(path, keep_bbox = FALSE)
  result_with_bbox <- read_octron(path, keep_bbox = TRUE)

  expect_equal(nrow(result_with_bbox), nrow(result_no_bbox) * 3)
})
