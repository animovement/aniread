# Tests for read_idtracker
#
# - Reads CSV exports that use the legacy `seconds` time column
# - Reads CSV exports that use the newer `time` time column (#60)
# - Probabilities CSV with either column name joins correctly
# - The h5 reader records the version, frame rate and frame height the file
#   carries, and leaves them NA when it does not (#146)

test_that("read_idtracker reads CSV with legacy `seconds` column", {
  trajectories <- test_path(
    "data/idtrackerai/trajectories_csv",
    "trajectories.csv"
  )
  probabilities <- test_path(
    "data/idtrackerai/trajectories_csv",
    "id_probabilities.csv"
  )

  result <- read_idtracker(
    trajectories,
    path_probabilities = probabilities
  )

  expect_s3_class(result, "anipoint")
  expect_true(all(
    c("time", "individual", "x", "y", "confidence") %in% names(result)
  ))
  expect_true(is.numeric(result$time))
})

test_that("read_idtracker reads CSV with renamed `time` column", {
  # Synthesise a tiny CSV in the newer format where idtracker.ai renamed
  # the leading column from `seconds` to `time` (issue #60).
  trajectories <- tempfile(fileext = ".csv")
  probabilities <- tempfile(fileext = ".csv")
  on.exit(unlink(c(trajectories, probabilities)), add = TRUE)

  writeLines(
    c(
      "time,x1,y1,x2,y2",
      "0.000,10.0,20.0,30.0,40.0",
      "0.036,11.0,21.0,31.0,41.0"
    ),
    trajectories
  )
  writeLines(
    c(
      "time,id_probabilities1,id_probabilities2",
      "0.000,1.0,1.0",
      "0.036,1.0,1.0"
    ),
    probabilities
  )

  result <- read_idtracker(
    trajectories,
    path_probabilities = probabilities
  )

  expect_s3_class(result, "anipoint")
  expect_true(all(
    c("time", "individual", "x", "y", "confidence") %in% names(result)
  ))
  expect_equal(sort(unique(result$time)), c(0.000, 0.036))
  expect_setequal(as.character(unique(result$individual)), c("1", "2"))
})

# What the h5 records besides the tracks (#146) ------------------------

# A minimal idtracker.ai h5: two individuals over three frames, with the
# given root attributes. idtracker.ai writes its scalars as attributes of
# the root group and its arrays as datasets.
write_idtracker_h5 <- function(attributes = list()) {
  path <- withr::local_tempfile(fileext = ".h5", .local_envir = parent.frame())
  rhdf5::h5createFile(path)
  trajectories <- array(as.numeric(c(10, 20, 30, 40)), dim = c(2, 2, 3))
  rhdf5::h5write(trajectories, path, "trajectories")
  rhdf5::h5write(array(1, dim = c(1, 2, 3)), path, "id_probabilities")
  file <- rhdf5::H5Fopen(path)
  for (name in names(attributes)) {
    rhdf5::h5writeAttribute(attributes[[name]], file, name, asScalar = TRUE)
  }
  rhdf5::H5Fclose(file)
  path
}

test_that("the h5 reader records the idtracker.ai version and frame rate", {
  skip_if_not_installed("rhdf5")
  path <- test_path("data/idtrackerai/trajectories.h5")
  data <- read_idtracker(path)

  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
  expect_equal(anicore::get_metadata(data, "sampling_rate"), 28)
  # time stays the frame number; the frame rate is what converts it.
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "frame")
  expect_equal(sort(unique(data$time)), 1:508)
})

test_that("read_dataset() records them too", {
  skip_if_not_installed("rhdf5")
  data <- read_dataset(test_path("data/idtrackerai/trajectories.h5"))

  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
  expect_equal(anicore::get_metadata(data, "sampling_rate"), 28)
})

test_that("the CSV export's time is in seconds, the h5's in frames (#148)", {
  csv <- read_idtracker(
    test_path("data/idtrackerai/trajectories_csv", "trajectories.csv")
  )
  raw <- utils::read.csv(
    test_path("data/idtrackerai/trajectories_csv", "trajectories.csv")
  )

  expect_equal(as.character(anicore::get_metadata(csv, "unit_time")), "s")
  expect_equal(sort(unique(csv$time)), raw$seconds)

  skip_if_not_installed("rhdf5")
  h5 <- read_idtracker(test_path("data/idtrackerai/trajectories.h5"))
  expect_equal(as.character(anicore::get_metadata(h5, "unit_time")), "frame")
})

test_that("the CSV export states the frame rate but not the version", {
  # Both are in attributes.json beside it, which the reader does not read.
  # The frame rate is also in trajectories.csv: one row per frame, timed
  # at the row number over the frame rate, rounded to 1 ms. The span
  # alone gives 28.0002; attributes.json says 28.
  data <- read_idtracker(
    test_path("data/idtrackerai/trajectories_csv", "trajectories.csv")
  )

  expect_true(is.na(anicore::get_metadata(data, "source_version")))
  expect_identical(anicore::get_metadata(data, "sampling_rate"), 28)
})

test_that("a CSV whose rows are not evenly timed leaves the rate NA", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "seconds,x1,y1",
      "0.000,10.0,20.0",
      "0.036,11.0,21.0",
      "0.100,12.0,22.0"
    ),
    path
  )

  data <- read_idtracker(path)
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
})

test_that("an h5 without the attributes still reads, leaving them NA", {
  skip_if_not_installed("rhdf5")
  data <- read_idtracker(write_idtracker_h5())

  expect_equal(nrow(data), 6L)
  expect_true(is.na(anicore::get_metadata(data, "source_version")))
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
  # With no height recorded, y is reflected around the furthest point.
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(y = 40))
})

test_that("attributes without a usable value are left NA", {
  skip_if_not_installed("rhdf5")
  recorded <- function(...) {
    data <- read_idtracker(write_idtracker_h5(list(...)))
    list(
      version = anicore::get_metadata(data, "source_version"),
      rate = anicore::get_metadata(data, "sampling_rate")
    )
  }
  unset <- list(version = NA_character_, rate = NA_real_)

  expect_equal(
    recorded(version = "6.1.0", frames_per_second = 29.97),
    list(version = "6.1.0", rate = 29.97)
  )
  expect_equal(recorded(version = "", frames_per_second = 0), unset)
  expect_equal(recorded(version = 6, frames_per_second = -1), unset)
  expect_equal(recorded(frames_per_second = "28"), unset)
  expect_equal(recorded(frames_per_second = NaN), unset)
})

test_that("the h5 reader reflects y around the frame height it records", {
  skip_if_not_installed("rhdf5")
  path <- write_idtracker_h5(list(height = 100L))

  data <- read_idtracker(path)
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(y = 100))
  expect_setequal(data$y, c(80, 60))

  # video_height still takes precedence over the file.
  data <- read_idtracker(path, video_height = 50)
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(y = 50))
})
