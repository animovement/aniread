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
# - Reflects to bottom_left using header `video_height`
# - `video_height` argument overrides the CSV header value
# - method = "weighted" area-weights multi-segment rows
# - method = "largest" picks the largest segment
# - method = "segments" expands tuples into separate rows
# - method defaults to "weighted"
# - Rejects unknown `method` values
# - Scalar-only files are identical across methods
# - method = "segments" still works on scalar-only files
# - Internal resolvers (parse_octron_column / resolve_largest /
#   resolve_weighted) handle their NA / empty / sum-zero edge cases
# - Resolves tuples when no `area` column is present (bytetrack-flavoured)
# - parse_octron_column handles whitespace, length-3 tuples, mixed
#   scalar/tuple in the same column, all in a single vectorised pass
# - resolve_weighted warns once per call and falls back to the arithmetic
#   mean when a row's value/area segment counts disagree (replaces R's
#   silent recycling warning)
# - `properties` argument selects which scikit-image / Octron region
#   properties to read; "all" matches the original behaviour, NULL skips
#   them entirely, a character vector picks a subset, and unknown names
#   warn instead of erroring
# - method = "weighted" auto-includes `area` when the user omitted it
#   (with an info note) since the weighted mean is undefined otherwise

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

# Tests for multi-segment frames (#67) — Octron emits tuple-strings like
# "(120.5, 85.3)" in per-segment columns when YOLO detects multiple
# disconnected mask blobs for the same track in one frame.

# Helper: write a tiny Octron-style CSV with one multi-segment row.
# Row 1 (frame_idx=1) has two segments with areas (800, 200), so:
#   weighted weights = (0.8, 0.2)
#   largest idx = 1 (the segment with area 800)
write_octron_multi_fixture <- function() {
  path <- tempfile(fileext = ".csv")
  writeLines(
    c(
      "video_name: test_multi.mp4",
      "frame_count: 3",
      "frame_count_analyzed: 3",
      "video_height: 1000",
      "video_width: 1000",
      "created_at: 2025-10-04 09:06:31",
      "frame_counter,frame_idx,track_id,label,confidence,pos_x,pos_y,bbox_area,bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,area,eccentricity,solidity,orientation",
      "0,0,1,worm,0.9,100.0,200.0,1000.0,80.0,120.0,180.0,220.0,500.0,0.5,0.9,-0.4",
      paste0(
        '1,1,1,worm,0.85,',
        '"(150.0, 200.0)","(250.0, 300.0)",',
        '"(2000.0, 1000.0)",',
        '"(120.0, 180.0)","(180.0, 220.0)","(220.0, 280.0)","(280.0, 320.0)",',
        '"(800.0, 200.0)","(0.4, 0.6)","(0.85, 0.9)","(-0.3, 0.5)"'
      ),
      "2,2,1,worm,0.92,300.0,400.0,1200.0,280.0,320.0,380.0,420.0,600.0,0.55,0.88,-0.2"
    ),
    path
  )
  path
}

test_that("read_octron(method = 'weighted') area-weights multi-segment rows", {
  path <- write_octron_multi_fixture()
  on.exit(unlink(path), add = TRUE)

  result <- read_octron(path, method = "weighted")

  # 3 rows, one per frame, all centroid
  expect_equal(nrow(result), 3)
  expect_equal(unique(result$keypoint), factor("centroid"))
  expect_type(result$x, "double")
  expect_type(result$y, "double")

  # Multi-segment row resolves to the area-weighted mean.
  # weights = (800, 200) / 1000 = (0.8, 0.2)
  multi <- result[result$time == 1, ]
  expect_equal(multi$x, 150 * 0.8 + 200 * 0.2)
  # y is reflected: video_height (1000) - resolved_y
  expect_equal(multi$y, 1000 - (250 * 0.8 + 300 * 0.2))
  # area becomes the SUM of segment areas under "weighted"
  expect_equal(multi$area, 1000)
  expect_equal(multi$eccentricity, 0.4 * 0.8 + 0.6 * 0.2)
  expect_equal(multi$solidity, 0.85 * 0.8 + 0.9 * 0.2)
  # orientation is special-cased to "largest" (circular quantity)
  expect_equal(multi$orientation, -0.3)

  # Scalar rows pass through unchanged (modulo y reflection).
  scalar <- result[result$time == 0, ]
  expect_equal(scalar$x, 100)
  expect_equal(scalar$y, 1000 - 200)
  expect_equal(scalar$area, 500)
})

test_that("read_octron(method = 'largest') picks the largest segment", {
  path <- write_octron_multi_fixture()
  on.exit(unlink(path), add = TRUE)

  result <- read_octron(path, method = "largest")
  expect_equal(nrow(result), 3)

  multi <- result[result$time == 1, ]
  # Segment 1 has area 800 (the larger), so all values come from index 1.
  expect_equal(multi$x, 150)
  expect_equal(multi$y, 1000 - 250)
  expect_equal(multi$area, 800)
  expect_equal(multi$eccentricity, 0.4)
  expect_equal(multi$solidity, 0.85)
  expect_equal(multi$orientation, -0.3)
})

test_that("read_octron(method = 'segments') expands tuples into separate rows", {
  path <- write_octron_multi_fixture()
  on.exit(unlink(path), add = TRUE)

  result <- read_octron(path, method = "segments")

  # Row layout: frame 0 -> 1 row, frame 1 -> 2 rows, frame 2 -> 1 row.
  expect_equal(nrow(result), 4)
  expect_true("segment" %in% names(result))
  expect_s3_class(result$segment, "factor")

  # The two segments at frame 1 expose the original per-segment values.
  multi <- result[result$time == 1, ]
  expect_equal(nrow(multi), 2)
  expect_setequal(multi$x, c(150, 200))
  expect_setequal(multi$y, c(1000 - 250, 1000 - 300))
  expect_setequal(multi$area, c(800, 200))
  expect_setequal(multi$eccentricity, c(0.4, 0.6))
})

test_that("read_octron `method` defaults to 'weighted'", {
  path <- write_octron_multi_fixture()
  on.exit(unlink(path), add = TRUE)

  expect_equal(read_octron(path), read_octron(path, method = "weighted"))
})

test_that("read_octron rejects unknown `method` values", {
  path <- write_octron_multi_fixture()
  on.exit(unlink(path), add = TRUE)

  expect_error(read_octron(path, method = "raw"))
  expect_error(read_octron(path, method = "median"))
})

test_that("read_octron handles scalar-only files identically across methods", {
  path <- test_path("data/octron", "octron_sample.csv")

  weighted <- read_octron(path, method = "weighted")
  largest <- read_octron(path, method = "largest")

  expect_equal(weighted$x, largest$x)
  expect_equal(weighted$y, largest$y)
  expect_equal(weighted$area, largest$area)
})

test_that("read_octron(method = 'segments') still works on scalar-only files", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(path, method = "segments")

  expect_true("segment" %in% names(result))
  # Every row from a scalar file gets segment = 1
  expect_equal(unique(as.character(result$segment)), "1")
})

# --- Edge cases for the internal tuple resolvers ---

test_that("parse_octron_column passes numeric columns through as a list", {
  expect_equal(parse_octron_column(c(1, 2, 3)), list(1, 2, 3))
})

test_that("parse_octron_column converts NA character entries to NA_real_", {
  result <- parse_octron_column(c("(1.0, 2.0)", NA_character_, "3.0"))
  expect_equal(result[[1]], c(1, 2))
  expect_true(is.na(result[[2]]))
  expect_equal(result[[3]], 3)
})

test_that("resolve_largest returns NA when every segment value is NA", {
  out <- resolve_largest(
    list(c(NA_real_, NA_real_)),
    list(c(1, 2))
  )
  expect_true(is.na(out))
})

test_that("resolve_largest defaults to the first segment when all areas are NA", {
  # which.max() returns integer(0) on an all-NA vector — code falls back to idx 1.
  out <- resolve_largest(
    list(c(10, 20)),
    list(c(NA_real_, NA_real_))
  )
  expect_equal(out, 10)
})

test_that("resolve_weighted returns NA when every segment value is NA", {
  out <- resolve_weighted(
    list(c(NA_real_, NA_real_)),
    list(c(1, 2))
  )
  expect_true(is.na(out))
})

test_that("resolve_weighted falls back to arithmetic mean when areas sum to 0", {
  out <- resolve_weighted(list(c(10, 20)), list(c(0, 0)))
  expect_equal(out, 15)
})

test_that("read_octron resolves tuples when no `area` column is present", {
  # Bytetrack-flavoured Octron exports omit the `area` column; the
  # resolver falls back to equal weights (arithmetic mean for `weighted`,
  # first segment for `largest`).
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  writeLines(
    c(
      "video_name: test.mp4",
      "frame_count: 2",
      "frame_count_analyzed: 2",
      "video_height: 1000",
      "video_width: 1000",
      "created_at: 2025-10-04 09:06:31",
      "frame_counter,frame_idx,track_id,label,pos_x,pos_y,bbox_area,bbox_aspect_ratio,bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,confidence",
      "0,0,1,worm,100.0,200.0,1000.0,0.5,80.0,120.0,180.0,220.0,0.9",
      paste0(
        "1,1,1,worm,",
        '"(150.0, 250.0)","(300.0, 350.0)",',
        "2000.0,0.6,140.0,260.0,290.0,360.0,0.85"
      )
    ),
    path
  )

  weighted <- read_octron(path, method = "weighted")
  largest <- read_octron(path, method = "largest")

  expect_equal(nrow(weighted), 2)
  multi_w <- weighted[weighted$time == 1, ]
  expect_equal(multi_w$x, mean(c(150, 250)))
  expect_equal(multi_w$y, 1000 - mean(c(300, 350)))

  multi_l <- largest[largest$time == 1, ]
  expect_equal(multi_l$x, 150)
  expect_equal(multi_l$y, 1000 - 300)
})

# --- Vectorised parser / resolver coverage ---

test_that("parse_octron_column trims whitespace and handles length-3 tuples", {
  result <- parse_octron_column(c("( 1 , 2 , 3 )", "(4.5)", " 7.0 "))
  expect_equal(result[[1]], c(1, 2, 3))
  expect_equal(result[[2]], 4.5)
  expect_equal(result[[3]], 7)
})

test_that("parse_octron_column handles a mix of scalar, tuple, and NA in one call", {
  col <- c("1.0", "(2.0, 3.0)", NA_character_, "(4.0, 5.0, 6.0)", "7.0")
  result <- parse_octron_column(col)
  expect_length(result, 5)
  expect_equal(result[[1]], 1)
  expect_equal(result[[2]], c(2, 3))
  expect_true(is.na(result[[3]]) && length(result[[3]]) == 1L)
  expect_equal(result[[4]], c(4, 5, 6))
  expect_equal(result[[5]], 7)
})

test_that("parse_octron_column returns an empty list for an empty input", {
  expect_equal(parse_octron_column(character(0)), list())
})

test_that("resolve_weighted warns once and falls back to mean on segment-count mismatch", {
  # Row 1: matched, weighted average = 12.
  # Row 2: 3 values vs 2 areas -> mismatch -> mean(5,6,7) = 6.
  # Row 3: matched scalar -> 100.
  expect_warning(
    out <- resolve_weighted(
      list(c(10, 20), c(5, 6, 7), 100),
      list(c(800, 200), c(8, 9), 50)
    ),
    "differing segment counts"
  )
  expect_equal(out, c(12, 6, 100))
})

test_that("resolve_weighted does not warn when all rows have matching segment counts", {
  expect_no_warning(
    out <- resolve_weighted(
      list(c(10, 20), 5),
      list(c(800, 200), 1)
    )
  )
  expect_equal(out, c(12, 5))
})

test_that("resolve_largest realigns when value/area segment counts disagree", {
  # Areas longer than values: extra areas are ignored.
  expect_equal(
    resolve_largest(list(c(10, 20)), list(c(1, 2, 3))),
    20
  )
  # Areas shorter than values: missing areas are NA, so the surviving
  # non-NA area wins (idx 1).
  expect_equal(
    resolve_largest(list(c(10, 20, 30)), list(1)),
    10
  )
})

test_that("resolve_weighted preserves per-row NA handling on partial NAs", {
  # sum(c(NA, 20) * c(800, 200), na.rm = TRUE) / sum(c(800, 200)) = 4
  expect_equal(
    resolve_weighted(list(c(NA, 20)), list(c(800, 200))),
    4
  )
})

test_that("read_octron warns and falls back to mean on a segment-count mismatch", {
  # Row 1 (frame 1) has area with 2 segments but pos_x/pos_y/eccentricity
  # with 3 segments — exactly the case that previously emitted opaque
  # `longer object length is not a multiple of shorter object length`
  # warnings from the implicit `v * a` recycling.
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  writeLines(
    c(
      "video_name: test_mismatch.mp4",
      "frame_count: 2",
      "frame_count_analyzed: 2",
      "video_height: 1000",
      "video_width: 1000",
      "created_at: 2026-05-07 00:00:00",
      "frame_counter,frame_idx,track_id,label,confidence,pos_x,pos_y,bbox_area,bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,area,eccentricity,solidity,orientation",
      "0,0,1,worm,0.9,100.0,200.0,1000.0,80.0,120.0,180.0,220.0,500.0,0.5,0.9,-0.4",
      paste0(
        '1,1,1,worm,0.85,',
        # 3 segments for pos_x / pos_y / eccentricity, but only 2 for area:
        '"(100.0, 200.0, 300.0)","(100.0, 200.0, 300.0)",',
        '"(2000.0, 1000.0)",',
        '"(120.0, 180.0)","(180.0, 220.0)","(220.0, 280.0)","(280.0, 320.0)",',
        '"(800.0, 200.0)","(0.4, 0.6, 0.8)","(0.85, 0.9)","(-0.3, 0.5)"'
      )
    ),
    path
  )

  warns <- character()
  result <- withCallingHandlers(
    read_octron(path, method = "weighted"),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  # The user's bug: pre-fix, `v * a` recycling produced opaque
  # `longer object length is not a multiple of shorter` warnings.
  # Post-fix: a single summarised "differing segment counts" warning
  # per affected column, with a clean fallback to the arithmetic mean.
  expect_true(any(grepl("differing segment counts", warns)))
  expect_false(any(grepl("longer object length", warns)))

  multi <- result[result$time == 1, ]
  # mismatched columns fall back to the arithmetic mean of values:
  expect_equal(multi$x, mean(c(100, 200, 300)))
  # y is reflected: video_height (1000) - resolved_y
  expect_equal(multi$y, 1000 - mean(c(100, 200, 300)))
  expect_equal(multi$eccentricity, mean(c(0.4, 0.6, 0.8)))
  # `solidity` (2 segments) still matches `area` (2 segments) so it stays
  # on the weighted-average path: (0.85*800 + 0.9*200) / 1000 = 0.86.
  expect_equal(multi$solidity, 0.86)
  # `area` always sums under method = "weighted":
  expect_equal(multi$area, 1000)
})

# --- `properties` argument ---

test_that("read_octron `properties = 'all'` matches the prior default", {
  path <- test_path("data/octron", "octron_sample.csv")
  default <- read_octron(path)
  explicit <- read_octron(path, properties = "all")
  expect_equal(default, explicit)
})

test_that("read_octron `properties = NULL` drops every region property", {
  path <- test_path("data/octron", "octron_sample.csv")
  # method = "largest" so we don't trigger the `area`-auto-include branch.
  result <- read_octron(path, method = "largest", properties = NULL)
  expect_named(
    result,
    c("track", "time", "label", "confidence", "keypoint", "x", "y"),
    ignore.order = TRUE
  )
})

test_that("read_octron `properties = c(...)` reads only the listed columns", {
  path <- test_path("data/octron", "octron_sample.csv")
  result <- read_octron(
    path,
    method = "largest",
    properties = c("area", "orientation")
  )
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
      "area",
      "orientation"
    ),
    ignore.order = TRUE
  )
})

test_that("read_octron warns on unknown `properties` and ignores them", {
  path <- test_path("data/octron", "octron_sample.csv")
  expect_warning(
    result <- read_octron(
      path,
      method = "largest",
      properties = c("area", "not_a_real_property")
    ),
    "Unknown"
  )
  expect_true("area" %in% names(result))
  expect_false("not_a_real_property" %in% names(result))
})

test_that("read_octron rejects non-character `properties`", {
  path <- test_path("data/octron", "octron_sample.csv")
  expect_error(read_octron(path, properties = 1L))
  expect_error(read_octron(path, properties = TRUE))
})

test_that("read_octron auto-includes `area` for method = 'weighted'", {
  path <- test_path("data/octron", "octron_sample.csv")
  expect_message(
    result <- read_octron(
      path,
      method = "weighted",
      properties = c("eccentricity")
    ),
    "Including.*area"
  )
  expect_true("area" %in% names(result))
  expect_true("eccentricity" %in% names(result))
})

test_that("read_octron does not auto-include `area` when method = 'largest'", {
  path <- test_path("data/octron", "octron_sample.csv")
  expect_no_message(
    result <- read_octron(
      path,
      method = "largest",
      properties = c("eccentricity")
    )
  )
  expect_false("area" %in% names(result))
  expect_true("eccentricity" %in% names(result))
})

test_that("read_octron normalises hyphens to underscores in property names", {
  # Octron emits scikit-image property expansions like `moments_hu-0`.
  # We rename those to `moments_hu_0` so they're addressable as bare
  # identifiers in the returned aniframe.
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  writeLines(
    c(
      "video_name: t.mp4",
      "frame_count: 1",
      "frame_count_analyzed: 1",
      "video_height: 1000",
      "video_width: 1000",
      "created_at: 2026",
      paste0(
        "frame_counter,frame_idx,track_id,label,confidence,",
        "pos_x,pos_y,bbox_area,bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,",
        "moments_hu-0,moments_hu-1,moments_hu-2"
      ),
      "0,0,1,worm,0.9,100,200,1000,80,120,180,220,0.1,0.2,0.3"
    ),
    path
  )
  result <- read_octron(path, method = "largest")
  expect_true("moments_hu_0" %in% names(result))
  expect_true("moments_hu_1" %in% names(result))
  expect_false(any(grepl("-", names(result))))
  # And the user can request them by their underscored names:
  picked <- read_octron(path, method = "largest", properties = "moments_hu_0")
  expect_true("moments_hu_0" %in% names(picked))
  expect_false("moments_hu_1" %in% names(picked))
})
