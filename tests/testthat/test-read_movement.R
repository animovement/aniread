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
# - Reads both dimension names: `individual`/`keypoint` (movement 0.17.0 and
#   later) and `individuals`/`keypoints` (earlier versions) (#167)
# - Repeats a per-individual confidence for each keypoint
# - Names the file read when it has no `source_file`
# - Errors clearly on bboxes, multi-view and non-movement files

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

expect_movement_3d <- function(result) {
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
}

test_that("read_movement reads the axes from space, so 3D files read", {
  # Values encode their position: 1000 * individual + 100 * keypoint +
  # 10 * axis + frame, and confidence (100 * individual + 10 * keypoint +
  # frame) / 1000. `synthetic_3d.nc` has the plural dimension names,
  # `synthetic_3d_singular.nc` the singular ones and movement's `log`
  # attribute on `position`.
  for (file in c("synthetic_3d.nc", "synthetic_3d_singular.nc")) {
    expect_movement_3d(read_movement(movement_fixture(file)))
  }
})

# Fixtures with movement's current dimension names, `individual` and
# `keypoint` (#167). Written by movement 0.17.0 itself (`load_poses.from_numpy()`
# or `load_bboxes.from_numpy()`, then xarray's `to_netcdf()`), so the layout
# and root attributes are movement's own:
#
# - `two-mice_seconds_singular.nc`, `two-mice_frames_singular.nc`: the first 4
#   frames of SWC GIN's `poses/MOVE_two-mice_octagon.analysis.nc` (movement
#   sample data, CC BY 4.0, shared by Niko Sirmpilatze, Sainsbury Wellcome
#   Centre), saved with `fps = 50` and without an fps. `source_file` is cut
#   to its file name.
# - `two-mice_seconds_plural.nc`: the same 4 frames saved by movement 0.16.0,
#   the last release with the plural names `individuals` and `keypoints`.
# - `synthetic_3d_singular.nc`: `synthetic_3d.nc` above, passed through
#   `filter_by_confidence(threshold = 0)` so `position` carries a `log`.
# - `individual-confidence_singular.nc`: 2D, with `confidence` per
#   individual, dimensions (time, individual), values (100 * individual +
#   frame) / 1000, and no `source_file`. movement 0.17.0 accepts this shape
#   but `from_numpy()` cannot build it, so the variable was replaced with
#   xarray.
# - `bboxes_singular.nc`: a 3-frame bounding boxes dataset.
# - `multiview_singular.nc`: the previous 2D dataset for two views,
#   concatenated along `view` as `load_multiview_dataset()` does.

test_that("read_movement reads movement's singular dimension names (#167)", {
  singular <- read_movement(movement_fixture("two-mice_seconds_singular.nc"))
  plural <- read_movement(movement_fixture("two-mice_seconds_plural.nc"))
  meta <- anicore::get_metadata(singular)

  expect_s3_class(singular, "anipoint")
  expect_equal(singular, plural)
  expect_equal(
    as.data.frame(singular),
    as.data.frame(read_movement(movement_fixture("two-mice_seconds.nc")))
  )
  expect_setequal(
    unique(singular$keypoint),
    c(
      "Nose",
      "EarLeft",
      "EarRight",
      "Neck",
      "BodyUpper",
      "BodyLower",
      "TailBase"
    )
  )
  expect_equal(meta$source, "SLEAP")
  expect_equal(meta$filename, "SLEAP_two-mice_octagon.analysis.h5")
  expect_equal(meta$sampling_rate, 50)
})

test_that("read_movement reads a singular-name file saved without an fps", {
  result <- read_movement(movement_fixture("two-mice_frames_singular.nc"))
  meta <- anicore::get_metadata(result)

  expect_equal(as.character(meta$unit_time), "frame")
  expect_true(is.na(meta$sampling_rate))
  expect_equal(sort(unique(result$time)), 0:3)
})

test_that("read_movement repeats a per-individual confidence for each keypoint", {
  result <- read_movement(movement_fixture("individual-confidence_singular.nc"))

  expect_equal(nrow(result), 2 * 2 * 3)
  for (kp in c("head", "tail")) {
    row <- result[
      result$individual == "bee2" & result$keypoint == kp & result$time == 0.2,
    ]
    expect_equal(row$confidence, (200 + 3) / 1000)
  }
  expect_equal(
    result$confidence,
    (100 *
      as.integer(sub("bee", "", result$individual)) +
      round(result$time * 10) +
      1) /
      1000
  )
})

test_that("read_movement names the file read when there is no source_file", {
  result <- read_movement(movement_fixture("individual-confidence_singular.nc"))
  meta <- anicore::get_metadata(result)

  expect_equal(meta$filename, "individual-confidence_singular.nc")
  expect_equal(meta$source, "Anipose")
})

test_that("read_movement errors clearly on datasets it cannot read", {
  expect_error(
    read_movement(movement_fixture("bboxes_singular.nc")),
    "bounding boxes dataset",
    class = "rlang_error"
  )
  expect_error(
    read_movement(movement_fixture("multiview_singular.nc")),
    "single-view movement poses dataset"
  )
  expect_error(
    read_movement(test_path("data", "idtrackerai", "trajectories.h5")),
    "does not hold a movement poses dataset"
  )
  expect_error(
    movement_point_confidence(array(0, c(3, 3)), c(2L, 2L), 3L),
    "unexpected dimensions"
  )
})

test_that("movement's sample data reads in both layouts (#167)", {
  # The default is SWC GIN's MOVE_two-mice_octagon.analysis.nc (CC BY 4.0),
  # saved by movement 0.17.0 or later; "legacy-plural" is the same recording
  # saved before the rename.
  skip_if_no_network()
  skip_if_not_installed("rhdf5")
  current <- get_sample_data(
    "movement",
    cache_dir = test_cache_dir(),
    quiet = TRUE
  )
  legacy <- get_sample_data(
    "movement",
    dataset = "legacy-plural",
    cache_dir = test_cache_dir(),
    quiet = TRUE
  )

  expect_true("individual" %in% rhdf5::h5ls(current)$name)
  expect_true("individuals" %in% rhdf5::h5ls(legacy)$name)
  rhdf5::h5closeAll()
  expect_identical(detect_source(current), "movement")
  expect_identical(detect_source(legacy), "movement")

  result <- read_movement(current)
  expect_equal(nrow(result), 9000 * 7 * 2)
  expect_equal(anicore::get_metadata(result, "sampling_rate"), 50)
  expect_equal(result, read_movement(legacy))
})
