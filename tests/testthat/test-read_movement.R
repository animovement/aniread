# Tests for read_movement()
#
# - Returns an aniframe
# - Has required columns (individual, keypoint, time, x, y)
# - Column types are correct
# - Metadata is populated
# - Errors on invalid file path
# - Errors on wrong file extension
# - Reads files saved with and without an fps: time_unit "seconds" and
#   "frames", sampling_rate from fps or NA
# - Keeps confidence, matched to the right individual, keypoint and frame
# - Reads the axes from `space`, so a 3D file reads as cartesian_3d

# Wrap the sample-data download so a failure (offline, slow GIN server,
# etc.) doesn't error out the whole test file — tests that need the file
# skip individually below.
path <- tryCatch(
  get_sample_data("movement", cache_dir = test_cache_dir(), quiet = TRUE),
  error = function(e) NULL
)

test_that("read_movement returns an aniframe", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  expect_s3_class(result, "anipoint")
})

test_that("read_movement has required columns", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  expect_true(all(
    c("individual", "keypoint", "time", "x", "y") %in% names(result)
  ))
})

test_that("read_movement column types are correct", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  expect_type(result$time, "double")
  expect_type(result$x, "double")
  expect_type(result$y, "double")
})

test_that("read_movement populates metadata", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  meta <- anicore::get_metadata(result)

  expect_false(is.null(meta$source))
  expect_false(is.null(meta$filename))
  expect_false(is.null(meta$unit_time))
  expect_false(is.null(meta$unit_space))
  expect_false(is.null(meta$sampling_rate))
})

test_that("read_movement errors on invalid path", {
  expect_error(read_movement("nonexistent_file.h5"))
})

test_that("read_movement errors on wrong file extension", {
  tmp <- tempfile(fileext = ".csv")
  file.create(tmp)
  on.exit(unlink(tmp))

  expect_error(read_movement(tmp))
})

# Fixtures cut from the movement sample above: its first 4 frames, with the
# root attributes movement writes. `two-mice_seconds.nc` was saved with an fps
# (time in seconds, `fps = 50`); `two-mice_frames.nc` without one (time in
# frames, no `fps` attribute).
movement_fixture <- function(file) {
  testthat::test_path("data", "movement", file)
}

test_that("read_movement reads a file saved with an fps", {
  result <- read_movement(movement_fixture("two-mice_seconds.nc"))
  meta <- anicore::get_metadata(result)

  expect_s3_class(result, "anipoint")
  expect_equal(as.character(meta$unit_time), "s")
  expect_equal(meta$sampling_rate, 50)
  expect_equal(meta$source, "SLEAP")
  expect_equal(meta$filename, "SLEAP_two-mice_octagon.analysis.h5")
  expect_equal(sort(unique(result$time)), c(0, 0.02, 0.04, 0.06))
})

test_that("read_movement reads a file saved without an fps", {
  result <- read_movement(movement_fixture("two-mice_frames.nc"))
  meta <- anicore::get_metadata(result)

  expect_s3_class(result, "anipoint")
  expect_equal(as.character(meta$unit_time), "frame")
  expect_true(is.na(meta$sampling_rate))
  expect_length(meta$sampling_rate, 1)
  expect_equal(sort(unique(result$time)), 0:3)
})

test_that("movement time units map onto anicore's", {
  expect_equal(movement_unit_time("seconds"), "s")
  expect_equal(movement_unit_time("frames"), "frame")
  expect_equal(movement_unit_time(array("frames", 1)), "frame")
  expect_equal(movement_unit_time(NULL), "unknown")
  expect_equal(movement_unit_time(NA_character_), "unknown")
  expect_warning(
    expect_equal(movement_unit_time("hours"), "unknown"),
    "has no equivalent in anicore"
  )
})

test_that("movement fps becomes a sampling rate only when positive", {
  expect_equal(movement_sampling_rate(50), 50)
  expect_equal(movement_sampling_rate(array(29.97, 1)), 29.97)
  expect_true(is.na(movement_sampling_rate(NULL)))
  expect_true(is.na(movement_sampling_rate(0)))
  expect_true(is.na(movement_sampling_rate(-1)))
  expect_true(is.na(movement_sampling_rate(NaN)))
  expect_true(is.na(movement_sampling_rate("abc")))
})

test_that("read_movement keeps confidence for each point", {
  path <- movement_fixture("two-mice_seconds.nc")
  result <- read_movement(path)
  raw_x <- rhdf5::h5read(path, "position")
  raw_confidence <- rhdf5::h5read(path, "confidence")
  individuals <- as.vector(rhdf5::h5read(path, "individuals"))
  keypoints <- as.vector(rhdf5::h5read(path, "keypoints"))

  expect_true("confidence" %in% names(result))
  expect_type(result$confidence, "double")
  expect_false(all(is.na(result$confidence)))
  # Second individual, third keypoint, fourth frame
  row <- result[
    result$individual == individuals[[2]] &
      result$keypoint == keypoints[[3]] &
      result$time == 0.06,
  ]
  expect_equal(nrow(row), 1)
  expect_equal(row$x, raw_x[2, 3, 1, 4])
  expect_equal(row$confidence, raw_confidence[2, 3, 4])
})

test_that("read_movement reads the axes from space, so 3D files read", {
  # Values encode their position: 1000 * individual + 100 * keypoint +
  # 10 * axis + frame, and confidence (100 * individual + 10 * keypoint +
  # frame) / 1000
  result <- read_movement(movement_fixture("synthetic_3d.nc"))

  expect_true(all(c("x", "y", "z", "confidence") %in% names(result)))
  expect_equal(nrow(result), 2 * 2 * 3)
  expect_equal(
    as.character(anicore::get_metadata(result, "coordinate_system")),
    "cartesian_3d"
  )
  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_equal(anicore::get_metadata(result, "sampling_rate"), 10)

  row <- result[
    result$individual == "bee2" &
      result$keypoint == "head" &
      result$time == 0.2,
  ]
  expect_equal(nrow(row), 1)
  expect_equal(row$x, 2000 + 100 + 10 + 3)
  expect_equal(row$z, 2000 + 100 + 30 + 3)
  expect_equal(row$confidence, (200 + 10 + 3) / 1000)
  # y is reflected around the largest y, 2223 (bee2, tail, frame 3)
  expect_equal(row$y, 2223 - (2000 + 100 + 20 + 3))
})
