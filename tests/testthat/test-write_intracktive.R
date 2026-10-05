# Tests:
# - Creates track_id from all grouping columns
# - Creates track_id from subset of grouping columns
# - Includes z column when present
# - Excludes z column when absent
# - Renames time to t
# - Writes correct column order to file
# - Errors when no grouping columns are present
# - Emits a "Wrote inTRACKtive CSV" message when not quiet
# - Numbers tracks by the frame's identity keys, so a TrackMate frame's
#   `track` key is respected
# - Writes TrackMate lineage as parent_track_id, -1 for roots (two fixtures)
# - Writes -1 for every track of a TrackMate frame with no divisions
# - Keeps each keypoint's lineage within that keypoint
# - Leaves parent_track_id out when there is no `parent` column
# - Warns and writes -1 for a parent that is not in the data
# - Errors on a `parent` column without a `track` key

test_that("creates track_id from all grouping columns", {
  data <- anicore::anipoint(
    session = c(1, 1, 2, 2),
    trial = c(1, 1, 1, 1),
    model = c("a", "a", "a", "a"),
    individual = c(1, 1, 2, 2),
    keypoint = c("nose", "nose", "nose", "nose"),
    time = c(0, 1, 0, 1),
    x = c(10, 11, 20, 21),
    y = c(5, 6, 7, 8)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(unique(result$track_id), c(1, 2))
  expect_equal(nrow(result), 4)

  unlink(temp_file)
})

test_that("creates track_id from subset of grouping columns", {
  data <- anicore::anipoint(
    individual = c(1, 1, 2, 2),
    keypoint = c("nose", "nose", "tail", "tail"),
    time = c(0, 1, 0, 1),
    x = c(10, 11, 20, 21),
    y = c(5, 6, 7, 8)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(unique(result$track_id), c(1, 2))

  unlink(temp_file)
})

test_that("includes z column when present", {
  data <- anicore::anipoint(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6),
    z = c(2, 3)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_true("z" %in% names(result))
  expect_equal(result$z, c(2, 3))

  unlink(temp_file)
})

test_that("excludes z column when absent", {
  data <- anicore::anipoint(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_false("z" %in% names(result))

  unlink(temp_file)
})

test_that("renames time to t", {
  data <- anicore::anipoint(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_true("t" %in% names(result))
  expect_false("time" %in% names(result))
  expect_equal(result$t, c(0, 1))

  unlink(temp_file)
})


test_that("writes correct column order to file", {
  data <- anicore::anipoint(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6),
    z = c(2, 3)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(names(result), c("track_id", "t", "x", "y", "z"))

  unlink(temp_file)
})

test_that("errors when no grouping columns are present", {
  data <- dplyr::tibble(time = c(0, 1), x = c(10, 11), y = c(5, 6))
  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  expect_error(
    write_intracktive(data, temp_file, quiet = TRUE),
    "No grouping columns"
  )
})

test_that("emits a success message when not quiet", {
  data <- anicore::anipoint(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )
  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  expect_message(
    write_intracktive(data, temp_file, quiet = FALSE),
    "Wrote inTRACKtive CSV"
  )
})

# TrackMate frames, from the fixtures of read_trackmate()'s tests
# (data/trackmate/README.md), written and read back
write_read_trackmate <- function(fixture) {
  data <- suppressMessages(
    read_trackmate(test_path("data", "trackmate", fixture))
  )
  temp_file <- tempfile(fileext = ".csv")
  withr::defer(unlink(temp_file), envir = parent.frame())
  write_intracktive(data, temp_file, quiet = TRUE)
  list(
    data = data,
    result = vroom::vroom(temp_file, show_col_types = FALSE)
  )
}

# One row per written track
written_tracks <- function(result) {
  dplyr::distinct(result, .data$track_id, .data$parent_track_id) |>
    dplyr::arrange(.data$track_id)
}

test_that("numbers tracks by the identity keys, including a track key", {
  written <- write_read_trackmate("CelegansEarly_MIP_trimmed.xml")

  expect_true("track" %in% anicore::get_keys(written$data))
  # One track_id per TrackMate track, numbered in the order of its levels
  expect_equal(
    dplyr::n_distinct(written$result$track_id),
    nlevels(written$data$track)
  )
  expect_equal(
    written$result$track_id,
    as.integer(factor(written$data$track))
  )
})

test_that("writes TrackMate lineage as parent_track_id", {
  # Tracks 0 and 2 each divide, into 3 and 4, and 5 and 6, which are written
  # as track_ids 1 to 6
  written <- write_read_trackmate("CelegansEarly_MIP_trimmed.xml")
  expect_equal(
    names(written$result),
    c("track_id", "t", "x", "y", "parent_track_id")
  )
  expect_equal(
    written_tracks(written$result),
    dplyr::tibble(track_id = 1:6, parent_track_id = c(-1, -1, 1, 1, 2, 2)),
    ignore_attr = TRUE
  )

  # A lineage that divides three times: 0 into 1 and 2, which divide into 3
  # and 4, and 5 and 6
  written <- write_read_trackmate("trpL_150310-11_trimmed.xml")
  expect_equal(
    written_tracks(written$result),
    dplyr::tibble(
      track_id = 1:7,
      parent_track_id = c(-1, 1, 1, 2, 2, 3, 3)
    ),
    ignore_attr = TRUE
  )
})

test_that("writes -1 for every track of a frame without divisions", {
  written <- write_read_trackmate("crop_1_60_ManualCuration_trimmed.xml")
  expect_equal(unique(written$result$parent_track_id), -1)
  expect_equal(sort(unique(written$result$track_id)), c(1, 2))
})

test_that("keeps each keypoint's lineage within that keypoint", {
  data <- anicore::anipoint(
    track = rep(c("a", "b"), each = 2),
    keypoint = rep(c("head", "tail"), times = 2),
    time = c(0, 0, 1, 1),
    x = 1:4,
    y = 1:4,
    parent = c(NA, NA, "a", "a")
  )

  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  write_intracktive(data, temp_file, quiet = TRUE)
  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  # Tracks are numbered a/head 1, a/tail 2, b/head 3, b/tail 4
  expect_equal(result$track_id, c(1, 2, 3, 4))
  expect_equal(result$parent_track_id, c(-1, -1, 1, 2))
})

test_that("leaves parent_track_id out without a parent column", {
  data <- anicore::anipoint(
    track = c("a", "b"),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )

  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  write_intracktive(data, temp_file, quiet = TRUE)
  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(names(result), c("track_id", "t", "x", "y"))
  expect_equal(result$track_id, c(1, 2))
})

test_that("warns and writes -1 for a parent that is not in the data", {
  data <- suppressMessages(read_trackmate(
    test_path("data", "trackmate", "CelegansEarly_MIP_trimmed.xml")
  ))
  # Drop track 0, the parent of 3 and 4
  data <- dplyr::filter(data, .data$track != "0")

  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  expect_warning(
    write_intracktive(data, temp_file, quiet = TRUE),
    "not tracks in"
  )
  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  # Tracks 2 to 6 are written as 1 to 5; 3 and 4 lost their parent
  expect_equal(
    written_tracks(result),
    dplyr::tibble(track_id = 1:5, parent_track_id = c(-1, -1, -1, 1, 1)),
    ignore_attr = TRUE
  )
})

test_that("errors on a parent column without a track key", {
  data <- anicore::anipoint(
    individual = c(1, 2),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6),
    parent = c(NA, "1")
  )

  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  expect_error(
    write_intracktive(data, temp_file, quiet = TRUE),
    "no .*track.* key"
  )
})
