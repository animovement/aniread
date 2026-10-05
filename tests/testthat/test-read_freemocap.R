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

  expect_s3_class(result, "anipoint")
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
  expect_true("start_datetime" %in% names(meta$time))
  expect_equal(meta$unit_time, expected_unit_time_with_timestamps)
  expect_false(timestamp_column %in% names(result))
})

test_that("read_freemocap handles missing timestamps", {
  result <- read_freemocap(path_without_timestamps)

  meta <- anicore::get_metadata(result)
  expect_true("start_datetime" %in% names(meta$time))
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
  expect_s3_class(result, "anipoint")
})

# Integration tests -------------------------------------------------------

test_that("read_freemocap output works with aniframe functions", {
  result <- read_freemocap(path_valid)

  expect_no_error(anicore::get_metadata(result))
})

# Export layouts ----------------------------------------------------------
# FreeMoCap added a reprojection_error column to the tidy export at v1.7.4,
# so by_frame.csv exists in an 8- and a 9-column form. Both are read, and
# the layout that was parsed is recorded rather than inferred again later.

test_that("read_freemocap() reads the 9-column tidy export", {
  path <- system.file("extdata", "freemocap.csv", package = "aniread")
  data <- read_freemocap(path)

  expect_s3_class(data, "anipoint")
  expect_true("confidence" %in% names(data))
  expect_type(data$confidence, "double")
  # The raw error is mapped, not carried alongside.
  expect_false("reprojection_error" %in% names(data))
})

test_that("confidence inverts reprojection_error onto (0, 1]", {
  path <- system.file("extdata", "freemocap.csv", package = "aniread")
  raw <- vroom::vroom(path, show_col_types = FALSE)
  data <- read_freemocap(path)

  # FreeMoCap gives the centres of mass no reprojection error.
  expect_equal(is.na(data$confidence), data$model == "mediapipe_com")
  expect_true(all(data$confidence > 0 & data$confidence <= 1, na.rm = TRUE))

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

  expect_s3_class(read_freemocap(path, format = "by_frame"), "anipoint")
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

  expect_s3_class(data, "anipoint")
  expect_equal(anicore::get_metadata(data)$source_format, "by_trajectory")
  expect_true(all(c("model", "keypoint", "x", "y", "z") %in% names(data)))
  expect_true(all(is.na(data$confidence)))
})

test_that("a per-model wide export is read", {
  path <- system.file("extdata", "freemocap_wide.csv", package = "aniread")
  data <- read_freemocap(path)

  expect_s3_class(data, "anipoint")
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
  # FreeMoCap v1.8.2's DataSaver wrote both from one recording, so every
  # keypoint must carry identical coordinates at the same frame.
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

  # Every point is in both.
  expect_equal(nrow(joined), nrow(bf))
  expect_equal(nrow(joined), nrow(bt))
  expect_equal(joined$x_bf, joined$x_bt, tolerance = 1e-9)
  expect_equal(joined$y_bf, joined$y_bt, tolerance = 1e-9)
  expect_equal(joined$z_bf, joined$z_bt, tolerance = 1e-9)

  # The per-model wide file the DataLoader read them from holds the body.
  wide <- read_freemocap(
    system.file("extdata", "freemocap_wide.csv", package = "aniread")
  )
  body <- key(bf)[bf$model == "mediapipe_body", ]
  body <- body[order(body$keypoint, body$time), ]
  wide <- key(wide)[order(wide$keypoint, wide$time), ]
  rownames(body) <- rownames(wide) <- NULL
  expect_equal(wide, body)
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

# FreeMoCap v1.8 ----------------------------------------------------------
# A 9-column by_frame.csv written by v1.8.2's own DataSaver.save_to_tidy_csv()
# from synthetic positions; see data/freemocap/README.md for its origin.

test_that("a by_frame.csv from FreeMoCap v1.8's writer is read", {
  path <- test_path("data", "freemocap", "v1.8", "recording_by_frame.csv")
  raw <- vroom::vroom(path, show_col_types = FALSE)
  data <- read_freemocap(path)
  meta <- anicore::get_metadata(data)

  expect_equal(meta$source_format, "by_frame_9col")
  expect_equal(as.character(meta$unit_time), "frame")
  expect_setequal(
    as.character(unique(data$model)),
    c("mediapipe_body", "mediapipe_com", "mediapipe_hand", "mediapipe_face")
  )
  # The face keypoints are numbered; they stay text, not the number 0.
  expect_true("0000" %in% as.character(data$keypoint))
  # Centres of mass carry no reprojection error, so no confidence.
  com <- data[data$model == "mediapipe_com", ]
  expect_true(all(is.na(com$confidence)))
  expect_equal(
    sort(1 / data$confidence[!is.na(data$confidence)] - 1),
    sort(raw$reprojection_error[!is.na(raw$reprojection_error)]),
    tolerance = 1e-9
  )
})

# FreeMoCap v1.7 ----------------------------------------------------------
# An 8-column by_frame.csv written by v1.7.3's own DataSaver from the same
# synthetic recording as inst/extdata/freemocap.csv; see
# data/freemocap/README.md for its origin.

test_that("a by_frame.csv from FreeMoCap v1.7's writer is read", {
  path <- test_path("data", "freemocap", "v1.7", "recording_by_frame.csv")
  data <- read_freemocap(path)
  meta <- anicore::get_metadata(data)

  expect_equal(meta$source_format, "by_frame_8col")
  expect_equal(as.character(meta$unit_time), "frame")
  expect_true(all(is.na(data$confidence)))

  # The same positions as v1.8.2's 9-column file of the same recording
  v18 <- read_freemocap(
    system.file("extdata", "freemocap.csv", package = "aniread")
  )
  plain <- function(d) {
    d <- as.data.frame(d)[c("time", "model", "keypoint", "x", "y", "z")]
    d$model <- as.character(d$model)
    d$keypoint <- as.character(d$keypoint)
    d
  }
  expect_equal(plain(data), plain(v18))
})

test_that("numbered keypoints stay text in a file of only those", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "frame,timestamp,timestamp_by_camera,model,keypoint,x,y,z,reprojection_error",
      "0,,{},mediapipe_face,0000,1,2,3,0.5",
      "0,,{},mediapipe_face,0001,1,2,3,0.5"
    ),
    path
  )

  expect_setequal(
    as.character(read_freemocap(path)$keypoint),
    c("0000", "0001")
  )
})

# FreeMoCap v2 ------------------------------------------------------------
# Written by skellyforge's own writers from synthetic positions: RTMPose, body
# and left hand, three frames. See data/freemocap/README.md for the origin.

v2_csv <- function() {
  system.file("extdata", "freemocap_v2.csv", package = "aniread")
}
v2_file <- function(...) test_path("data", "freemocap", "v2", ...)

as_plain <- function(d) {
  d <- as.data.frame(d)
  d$model <- as.character(d$model)
  d$keypoint <- as.character(d$keypoint)
  d <- d[c("time", "model", "keypoint", "x", "y", "z", "confidence")]
  d <- d[order(d$model, d$keypoint, d$time), ]
  rownames(d) <- NULL
  d
}

test_that("the v2 tidy export is read", {
  data <- read_freemocap(v2_csv())
  meta <- anicore::get_metadata(data)

  expect_s3_class(data, "anipoint")
  expect_equal(meta$source, "freemocap")
  expect_equal(meta$source_format, "v2_by_frame")
  expect_equal(as.character(meta$unit_time), "frame")
  expect_equal(as.character(meta$unit_space), "mm")
  expect_true(is.na(meta$sampling_rate))
  expect_equal(sort(unique(as.numeric(data$time))), c(0, 1, 2))
  expect_false(any(c("trajectory", "reprojection_error") %in% names(data)))
  # skellyforge's main pipeline attaches no reprojection error.
  expect_true(all(is.na(data$confidence)))
})

test_that("v2 models are named as v1 names them", {
  data <- read_freemocap(v2_csv())

  expect_setequal(
    as.character(unique(data$model)),
    c("rtmpose_body", "rtmpose_left_hand", "rtmpose_com")
  )
})

test_that("each v2 keypoint is read once per frame, from 3d_xyz", {
  raw <- vroom::vroom(v2_csv(), show_col_types = FALSE)
  data <- read_freemocap(v2_csv())

  body <- as_plain(data[data$model == "rtmpose_body", ])
  expected <- raw[raw$model == "rtmpose.body" & raw$trajectory == "3d_xyz", ]
  expected <- expected[order(expected$keypoint, expected$frame), ]

  expect_equal(nrow(body), nrow(expected))
  expect_equal(body$keypoint, expected$keypoint)
  expect_equal(body$x, expected$x)
  expect_equal(body$z, expected$z)
})

test_that("the v2 centres of mass are keypoints of their own model", {
  raw <- vroom::vroom(v2_csv(), show_col_types = FALSE)
  data <- read_freemocap(v2_csv())
  com <- data[data$model == "rtmpose_com", ]

  com_raw <- raw[grepl("center_of_mass", raw$trajectory), ]
  expect_equal(nrow(com), nrow(com_raw))
  expect_setequal(as.character(unique(com$keypoint)), unique(com_raw$keypoint))
  expect_true("total_body_center_of_mass" %in% as.character(com$keypoint))
})

test_that("trajectory = 'rigid_3d_xyz' reads the rigid positions", {
  raw <- vroom::vroom(v2_csv(), show_col_types = FALSE)

  expect_message(
    data <- read_freemocap(v2_csv(), trajectory = "rigid_3d_xyz"),
    "rtmpose_left_hand"
  )
  expect_equal(anicore::get_metadata(data)$source_format, "v2_by_frame")

  body <- as_plain(data[data$model == "rtmpose_body", ])
  rigid <- raw[
    raw$model == "rtmpose.body" & raw$trajectory == "rigid_3d_xyz",
  ]
  rigid <- rigid[order(rigid$keypoint, rigid$frame), ]
  expect_equal(body$x, rigid$x)

  # The hand has no rigid version, so it keeps its 3d_xyz rather than
  # vanishing from the frame.
  hand_default <- as_plain(read_freemocap(v2_csv())) |>
    dplyr::filter(.data$model == "rtmpose_left_hand")
  hand_rigid <- as_plain(data) |>
    dplyr::filter(.data$model == "rtmpose_left_hand")
  expect_equal(hand_rigid, hand_default)
})

test_that("trajectory is validated, and ignored with a warning elsewhere", {
  expect_error(
    read_freemocap(v2_csv(), trajectory = "2d_xy"),
    "should be one of"
  )
  path <- system.file("extdata", "freemocap.csv", package = "aniread")
  expect_warning(
    data <- read_freemocap(path, trajectory = "rigid_3d_xyz"),
    "ignored"
  )
  expect_equal(anicore::get_metadata(data)$source_format, "by_frame_9col")
})

test_that("a v2 reprojection error becomes confidence", {
  raw <- vroom::vroom(v2_csv(), show_col_types = FALSE)
  raw$reprojection_error <- seq_len(nrow(raw)) / 10
  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(raw, path, delim = ",")

  data <- read_freemocap(path)
  kept <- raw[raw$trajectory != "rigid_3d_xyz", ]
  expect_equal(
    sort(1 / data$confidence - 1),
    sort(kept$reprojection_error),
    tolerance = 1e-9
  )
})

test_that("the v2 Parquet export reads as the CSV does", {
  skip_if_not_installed("arrow")
  data <- read_freemocap(v2_file("freemocap_data_by_frame.parquet"))

  expect_equal(anicore::get_metadata(data)$source_format, "v2_by_frame")
  expect_equal(as_plain(data), as_plain(read_freemocap(v2_csv())))
})

test_that("the v2 per-trajectory files are read, with the model from the name", {
  cases <- list(
    rtmpose_body_3d_xyz.csv = "rtmpose_body",
    rtmpose_body_rigid_3d_xyz.csv = "rtmpose_body",
    rtmpose_left_hand_3d_xyz.csv = "rtmpose_left_hand",
    rtmpose_body_total_body_center_of_mass.csv = "rtmpose_com",
    rtmpose_body_segment_center_of_mass.csv = "rtmpose_com"
  )
  for (f in names(cases)) {
    data <- read_freemocap(v2_file(f))
    expect_equal(
      anicore::get_metadata(data)$source_format,
      "v2_trajectory",
      info = f
    )
    expect_equal(as.character(unique(data$model)), cases[[f]], info = f)
    expect_true(all(is.na(data$confidence)), info = f)
  }
})

test_that("v2's tidy and per-trajectory files agree on the same recording", {
  # The point of naming models the same way in both: the per-trajectory
  # files, stacked, are the tidy export read with the same trajectory.
  stack <- function(files) {
    dplyr::bind_rows(lapply(files, \(f) as_plain(read_freemocap(v2_file(f)))))
  }
  com <- c(
    "rtmpose_body_total_body_center_of_mass.csv",
    "rtmpose_body_segment_center_of_mass.csv",
    "rtmpose_left_hand_3d_xyz.csv"
  )

  expect_equal(
    as_plain(stack(c("rtmpose_body_3d_xyz.csv", com))),
    as_plain(read_freemocap(v2_csv()))
  )
  expect_equal(
    as_plain(stack(c("rtmpose_body_rigid_3d_xyz.csv", com))),
    as_plain(suppressMessages(
      read_freemocap(v2_csv(), trajectory = "rigid_3d_xyz")
    ))
  )
})

test_that("a v2 per-trajectory file under another name keeps its stem", {
  path <- file.path(withr::local_tempdir(), "my_points.csv")
  file.copy(v2_file("rtmpose_body_3d_xyz.csv"), path)

  expect_equal(
    as.character(unique(read_freemocap(path)$model)),
    "my_points"
  )
})

test_that("v2 files are not mistaken for v1's of the same name", {
  # v2's per-trajectory files reuse v1's per-model names, but are long rather
  # than wide; the layout is read from the columns, not the name.
  path <- file.path(withr::local_tempdir(), "mediapipe_body_3d_xyz.csv")
  file.copy(v2_file("rtmpose_body_3d_xyz.csv"), path)

  expect_equal(
    anicore::get_metadata(read_freemocap(path))$source_format,
    "v2_trajectory"
  )
  expect_error(
    read_freemocap(path, format = "wide"),
    "v2 per-trajectory export"
  )
  expect_error(
    read_freemocap(v2_csv(), format = "by_frame"),
    "v2 freemocap_data_by_frame export"
  )
  expect_s3_class(
    read_freemocap(v2_csv(), format = "v2_by_frame"),
    "anipoint"
  )
})

test_that("detect_freemocap_format() recognises the v2 layouts", {
  cols <- function(...) {
    nm <- c(...)
    as.data.frame(setNames(rep(list(1), length(nm)), nm))
  }

  expect_equal(
    detect_freemocap_format(cols(
      "frame",
      "keypoint",
      "x",
      "y",
      "z",
      "model",
      "trajectory",
      "reprojection_error"
    )),
    "v2_by_frame"
  )
  expect_equal(
    detect_freemocap_format(cols("frame", "keypoint", "x", "y", "z")),
    "v2_trajectory"
  )
})

test_that("v2 model names map as documented", {
  expect_equal(
    freemocap_v2_model(c("mediapipe.body", "rtmpose.left_hand")),
    c("mediapipe_body", "rtmpose_left_hand")
  )
  expect_equal(
    freemocap_v2_com_model(c("mediapipe.body", "rtmpose.face", "bare")),
    c("mediapipe_com", "rtmpose_face_com", "bare_com")
  )
  expect_identical(freemocap_v2_com_model(character(0)), character(0))
})
