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
# Use withr for temp directory management
test_dir <- withr::local_tempdir()

create_test_files <- function(dir = test_dir) {
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
  vroom::vroom_write(
    valid_data_timestamps,
    paths$valid_with_timestamps,
    delim = ","
  )
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
default_metadata <- anicore::list_default_metadata()
expected_source <- "freemocap"
expected_unit_space <- factor(
  "mm",
  levels = levels(default_metadata$unit_space)
)
expected_unit_time_with_timestamps <- factor(
  "s",
  levels = levels(default_metadata$unit_time)
)
expected_unit_time_without_timestamps <- factor(
  "frame",
  levels = levels(default_metadata$unit_time)
)
expected_coordinate_system <- factor(
  "cartesian_3d",
  levels = levels(default_metadata$coordinate_system)
)
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
error_wrong_format <- "not a FreeMoCap"

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

  meta <- anicore::get_metadata(result)
  expect_equal(meta$source, expected_source)
})

test_that("read_freemocap sets correct unit metadata", {
  result <- read_freemocap(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$unit_space, expected_unit_space)
})

test_that("read_freemocap sets correct coordinate system", {
  result <- read_freemocap(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$coordinate_system, expected_coordinate_system)
})

test_that("read_freemocap sets filename in metadata", {
  result <- read_freemocap(path_valid)

  meta <- anicore::get_metadata(result)
  expect_equal(meta$filename, expected_filename)
})

# Special column handling -------------------------------------------------

test_that("read_freemocap handles timestamps when present", {
  result <- read_freemocap(path_with_timestamps)

  meta <- anicore::get_metadata(result)
  expect_true("start_datetime" %in% names(meta))
  expect_equal(meta$unit_time, expected_unit_time_with_timestamps)
  expect_false(timestamp_column %in% names(result))
})

test_that("read_freemocap handles missing timestamps", {
  result <- read_freemocap(path_without_timestamps)

  meta <- anicore::get_metadata(result)
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

  expect_no_error(anicore::get_metadata(result))
})

# Export layouts ----------------------------------------------------------
# FreeMoCap added a reprojection_error column to the tidy export at v1.8.0,
# so by_frame.csv exists in an 8- and a 9-column form. Both are read, and
# the layout that was parsed is recorded rather than inferred again later.

test_that("read_freemocap() reads the 9-column tidy export", {
  path <- system.file("extdata", "freemocap.csv", package = "aniread")
  data <- read_freemocap(path)

  expect_s3_class(data, "aniframe")
  expect_true("confidence" %in% names(data))
  expect_type(data$confidence, "double")
  # The raw error is mapped, not carried alongside.
  expect_false("reprojection_error" %in% names(data))
})

test_that("confidence inverts reprojection_error onto (0, 1]", {
  path <- system.file("extdata", "freemocap.csv", package = "aniread")
  raw <- vroom::vroom(path, show_col_types = FALSE)
  data <- read_freemocap(path)

  expect_true(all(data$confidence > 0 & data$confidence <= 1))

  # The mapping is invertible, so every original error comes back.
  # Compared as sets, because as_aniframe() reorders rows.
  recovered <- sort(1 / data$confidence - 1)
  expect_equal(recovered, sort(raw$reprojection_error), tolerance = 1e-9)
})

test_that("confidence decreases as reprojection error increases", {
  path <- withr::local_tempfile(fileext = ".csv")
  errors <- c(0, 0.5, 2, 10, 100)
  vroom::vroom_write(
    data.frame(
      frame = seq_along(errors) - 1L,
      timestamp = NA_character_,
      timestamp_by_camera = "{}",
      model = "mediapipe_body",
      keypoint = "nose",
      x = 1,
      y = 1,
      z = 1,
      reprojection_error = errors
    ),
    path,
    delim = ","
  )

  # One keypoint, so row order follows `time`, which follows `frame`.
  confidence <- read_freemocap(path)$confidence

  expect_equal(confidence, 1 / (1 + errors))
  expect_true(all(diff(confidence) < 0))
})

test_that("a zero reprojection error gives full confidence", {
  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(
    data.frame(
      frame = 0:1,
      timestamp = NA_character_,
      timestamp_by_camera = "{}",
      model = "mediapipe_body",
      keypoint = c("nose", "nose"),
      x = 1:2,
      y = 1:2,
      z = 1:2,
      reprojection_error = c(0, 1)
    ),
    path,
    delim = ","
  )

  expect_equal(read_freemocap(path)$confidence, c(1, 0.5))
})

test_that("read_freemocap() records which layout it read", {
  path_9col <- system.file("extdata", "freemocap.csv", package = "aniread")

  expect_equal(
    anicore::get_metadata(read_freemocap(path_9col))$source_format,
    "by_frame_9col"
  )
  expect_equal(
    anicore::get_metadata(read_freemocap(path_valid))$source_format,
    "by_frame_8col"
  )
})

test_that("the 8-column export gives all-NA confidence", {
  data <- read_freemocap(path_valid)

  expect_false("reprojection_error" %in% names(data))
  expect_true("confidence" %in% names(data))
  expect_true(all(is.na(data$confidence)))
  expect_equal(anicore::get_metadata(data)$source, "freemocap")
})

test_that("format = 'by_frame' reads a by_frame file", {
  path <- system.file("extdata", "freemocap.csv", package = "aniread")

  expect_s3_class(read_freemocap(path, format = "by_frame"), "aniframe")
  expect_error(read_freemocap(path, format = "nonsense"), "should be one of")
  # A valid layout name that does not match the file is a different error.
  expect_error(read_freemocap(path, format = "wide"), "not a FreeMoCap")
})

test_that("the by_trajectory export is read", {
  path <- system.file(
    "extdata",
    "freemocap_by_trajectory.csv",
    package = "aniread"
  )
  data <- read_freemocap(path)

  expect_s3_class(data, "aniframe")
  expect_equal(anicore::get_metadata(data)$source_format, "by_trajectory")
  expect_true(all(c("model", "keypoint", "x", "y", "z") %in% names(data)))
  expect_true(all(is.na(data$confidence)))
})

test_that("a per-model wide export is read", {
  path <- system.file("extdata", "freemocap_wide.csv", package = "aniread")
  data <- read_freemocap(path)

  expect_s3_class(data, "aniframe")
  expect_equal(anicore::get_metadata(data)$source_format, "wide")
  expect_setequal(as.character(unique(data$model)), "mediapipe_body")
  expect_true(all(is.na(data$confidence)))
})

test_that("detect_freemocap_format() distinguishes the four layouts", {
  tidy8 <- c(
    "frame",
    "timestamp",
    "timestamp_by_camera",
    "model",
    "keypoint",
    "x",
    "y",
    "z"
  )

  expect_equal(
    detect_freemocap_format(as.data.frame(setNames(
      rep(list(1), length(tidy8)),
      tidy8
    ))),
    "by_frame_8col"
  )
  expect_equal(
    detect_freemocap_format(as.data.frame(setNames(
      rep(list(1), length(tidy8) + 1),
      c(tidy8, "reprojection_error")
    ))),
    "by_frame_9col"
  )
  # by_trajectory has no frame column: the row position is the frame. It is
  # told from the wide files by the timestamps, which only it carries.
  expect_equal(
    detect_freemocap_format(
      data.frame(timestamp = NA, timestamp_by_camera = "{}", body_nose_x = 1)
    ),
    "by_trajectory"
  )
  expect_equal(detect_freemocap_format(data.frame(body_nose_x = 1)), "wide")
  expect_equal(detect_freemocap_format(data.frame(a = 1)), "unknown")
})

# Layout equivalence ------------------------------------------------------
# The point of parsing names the way FreeMoCap's own data saver does: one
# recording read through different layouts must give the same aniframe.

test_that("point names parse the way FreeMoCap parses them", {
  # Mirrors DataSaver._parse_keypoint_name(). The hands are the special case:
  # they share one model rather than becoming mediapipe_left / mediapipe_right.
  points <- c(
    "body_nose",
    "face_0000",
    "left_hand_0000",
    "right_hand_0012",
    "com_full"
  )

  expect_equal(
    parse_freemocap_model(points),
    c(
      "mediapipe_body",
      "mediapipe_face",
      "mediapipe_hand",
      "mediapipe_hand",
      "mediapipe_com"
    )
  )
  expect_equal(
    parse_freemocap_keypoint(points),
    c("nose", "0000", "left_0000", "right_0012", "full")
  )
})

test_that("a name with no underscore keeps the bare model", {
  expect_equal(parse_freemocap_model("nose"), "mediapipe")
  expect_equal(parse_freemocap_keypoint("nose"), "nose")
})

test_that("by_frame and by_trajectory agree on the same recording", {
  # Both fixtures are excerpts of the same v1.8.0 release asset, so every
  # keypoint they share must carry identical coordinates at the same frame.
  bf <- read_freemocap(
    system.file("extdata", "freemocap.csv", package = "aniread")
  )
  bt <- read_freemocap(
    system.file(
      "extdata",
      "freemocap_by_trajectory.csv",
      package = "aniread"
    )
  )

  key <- function(d) {
    data.frame(
      time = as.numeric(d$time),
      model = as.character(d$model),
      keypoint = as.character(d$keypoint),
      x = d$x,
      y = d$y,
      z = d$z
    )
  }
  joined <- merge(
    key(bf),
    key(bt),
    by = c("time", "model", "keypoint"),
    suffixes = c("_bf", "_bt")
  )

  expect_gt(nrow(joined), 0)
  expect_equal(joined$x_bf, joined$x_bt, tolerance = 1e-9)
  expect_equal(joined$y_bf, joined$y_bt, tolerance = 1e-9)
  expect_equal(joined$z_bf, joined$z_bt, tolerance = 1e-9)
})

test_that("frames count from zero in every layout", {
  for (f in c(
    "freemocap.csv",
    "freemocap_by_trajectory.csv",
    "freemocap_wide.csv"
  )) {
    data <- read_freemocap(system.file("extdata", f, package = "aniread"))
    expect_equal(min(as.numeric(data$time)), 0, info = f)
  }
})

# Error messages ----------------------------------------------------------
# The point of naming the layout that was found is that it tells you what to
# do next. Each layout gets its own wording, so each needs exercising.

test_that("a layout mismatch names the layout the file actually is", {
  ex <- function(f) system.file("extdata", f, package = "aniread")

  expect_error(
    read_freemocap(ex("freemocap_by_trajectory.csv"), format = "by_frame"),
    "by_trajectory export"
  )
  expect_error(
    read_freemocap(ex("freemocap_wide.csv"), format = "by_frame"),
    "per-model wide export"
  )
  expect_error(
    read_freemocap(ex("freemocap.csv"), format = "wide"),
    "9-column by_frame export"
  )
  # path_valid is the 8-column form, built at the top of this file.
  expect_error(
    read_freemocap(path_valid, format = "wide"),
    "8-column by_frame export"
  )
})

test_that("describe_freemocap_format() falls back for an unknown layout", {
  expect_match(
    describe_freemocap_format("unknown"),
    "not a layout this reader recognises"
  )
})
