# Tests for read_sleap

test_that("read_sleap rejects a CSV that is not a SLEAP export", {
  # This used to be the "we hope to support SLEAP CSV soon" stopgap (#87).
  tmp <- withr::local_tempfile(fileext = ".csv")
  writeLines("placeholder", tmp)

  expect_error(read_sleap(tmp), "not a SLEAP analysis CSV")
})

test_that("read_sleap rejects unsupported extensions", {
  expect_error(read_sleap("nonexistent.txt"))
})

# The CSV export ---------------------------------------------------------
# SLEAP's analysis CSV: one row per instance, with columns track, frame_idx,
# instance.score and a .x/.y/.score triple per node. See #87.

sleap_csv <- function() {
  test_path("data/sleap/SLEAP_three-mice_Aeon_mixed-labels.analysis.csv")
}

test_that("read_sleap() reads the analysis CSV", {
  data <- read_sleap(sleap_csv())

  expect_s3_class(data, "anipoint")
  expect_equal(anicore::get_metadata(data)$source, "sleap")
  expect_equal(anicore::get_metadata(data)$source_format, "csv")
  expect_true(all(
    c("time", "individual", "keypoint", "x", "y", "confidence") %in%
      names(data)
  ))
})

test_that("node names come from the columns, not a fixed list", {
  data <- read_sleap(sleap_csv())

  expect_setequal(levels(data$keypoint), "centroid")
})

test_that("instance.score does not become a keypoint", {
  # It scores the whole instance rather than a node, and the h5 reader takes
  # confidence from the per-node scores.
  data <- read_sleap(sleap_csv())

  expect_false("instance" %in% levels(data$keypoint))
})

test_that("confidence comes from the per-node score", {
  data <- read_sleap(sleap_csv())
  raw <- vroom::vroom(sleap_csv(), show_col_types = FALSE) |> suppressMessages()

  expect_equal(
    sort(data$confidence[!is.na(data$confidence)]),
    sort(raw[["centroid.score"]])
  )
})

test_that("the CSV and the h5 of one recording read the same", {
  # The strongest check available: both exports describe the same 20 frames
  # of the same three tracks. video_height is supplied to both, because the
  # max(y) fallback would otherwise reflect them around different extents.
  base <- "data/sleap/SLEAP_three-mice_Aeon_mixed-labels.analysis"
  h5 <- read_sleap(test_path(paste0(base, ".h5")), video_height = 1080)
  csv <- read_sleap(test_path(paste0(base, ".csv")), video_height = 1080)

  h5 <- h5[h5$time <= max(csv$time), ]
  key <- function(d) {
    d <- d[order(d$time, d$individual, d$keypoint), ]
    data.frame(
      time = as.numeric(d$time),
      individual = as.character(d$individual),
      keypoint = as.character(d$keypoint),
      x = d$x,
      y = d$y,
      confidence = d$confidence
    )
  }
  a <- key(h5)
  b <- key(csv)

  expect_equal(nrow(a), nrow(b))
  # Identities included: both exports name the tracks SLEAP recorded.
  expect_equal(a$individual, b$individual)
  expect_equal(a$keypoint, b$keypoint)
  expect_equal(a$x, b$x, tolerance = 1e-8)
  expect_equal(a$y, b$y, tolerance = 1e-8)
  expect_equal(a$confidence, b$confidence, tolerance = 1e-8)
})

test_that("time counts from 1, as it does for the h5", {
  data <- read_sleap(sleap_csv())
  raw <- vroom::vroom(sleap_csv(), show_col_types = FALSE) |> suppressMessages()

  expect_equal(min(data$time), min(raw$frame_idx) + 1)
})

test_that("a frame with no instance comes back as NA, not absent", {
  # The CSV holds a row per instance, so an undetected instance has no row.
  raw <- vroom::vroom(sleap_csv(), show_col_types = FALSE) |> suppressMessages()
  trimmed <- raw[!(raw$track == raw$track[[1]] & raw$frame_idx == 5), ]

  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(trimmed, path, delim = ",")

  data <- read_sleap(path)
  gap <- data[data$individual == raw$track[[1]] & data$time == 6, ]

  expect_equal(nrow(gap), 1)
  expect_true(is.na(gap$x))
})

test_that("a CSV without the SLEAP columns is rejected by name", {
  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(data.frame(a = 1, b = 2), path, delim = ",")

  expect_error(read_sleap(path), "not a SLEAP analysis CSV")
})

test_that("get_supported_sources() advertises both SLEAP suffixes", {
  sleap <- get_supported_sources()[get_supported_sources()$source == "sleap", ]

  expect_setequal(sleap$suffix[[1]], c("h5", "csv"))
})

test_that("the h5 reader uses the track names SLEAP recorded", {
  path <- test_path("data/sleap/SLEAP_three-mice_Aeon_mixed-labels.analysis.h5")
  data <- read_sleap(path)
  track_names <- as.vector(rhdf5::h5read(path, "track_names"))

  expect_setequal(levels(data$individual), track_names)
})

test_that("a recording with no tracks falls back to positional names", {
  # SLEAP writes no track_names for a single untracked instance, so there is
  # nothing to name it with.
  path <- test_path("data/sleap/SLEAP_single-mouse_EPM.analysis.h5")
  expect_length(as.vector(rhdf5::h5read(path, "track_names")), 0)

  expect_setequal(levels(read_sleap(path)$individual), "individual1")
})

# What the h5 carries besides the tracks (#143) --------------------------

# A minimal analysis .h5: one track of two nodes over three frames, with
# the skeleton and provenance record written only when given.
write_sleap_h5 <- function(edges = NULL, provenance = NULL) {
  path <- withr::local_tempfile(fileext = ".h5", .local_envir = parent.frame())
  rhdf5::h5createFile(path)
  rhdf5::h5write(c("head", "tail"), path, "node_names")
  rhdf5::h5write("mouse", path, "track_names")
  rhdf5::h5write(array(as.numeric(1:12), dim = c(3, 2, 2, 1)), path, "tracks")
  rhdf5::h5write(array(0.9, dim = c(3, 2, 1)), path, "point_scores")
  if (!is.null(edges)) {
    rhdf5::h5write(edges, path, "edge_inds")
  }
  if (!is.null(provenance)) {
    rhdf5::h5write(provenance, path, "provenance")
  }
  path
}

test_that("the h5 reader attaches the skeleton read_structure() reads", {
  skip_if_not_installed("rhdf5")
  path <- test_path("data/sleap/SLEAP_single-mouse_EPM.analysis.h5")
  data <- read_sleap(path)
  skeleton <- read_structure(path)

  expect_named(anicore::get_structure(data), "keypoint")
  attached <- anicore::get_structure(data, "keypoint")
  expect_equal(attached$points, skeleton$points)
  expect_equal(attached$segments, skeleton$segments)
  expect_equal(attached$variable, "keypoint")
  expect_setequal(attached$points, levels(data$keypoint))
})

test_that("the h5 reader records the SLEAP version that tracked it", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("jsonlite")
  path <- test_path("data/sleap/SLEAP_single-mouse_EPM.analysis.h5")
  data <- read_sleap(path)

  expect_equal(anicore::get_metadata(data, "source_version"), "1.3.1")
  # The provenance timestamps say when tracking ran, not when the video was
  # recorded.
  expect_true(is.na(anicore::get_metadata(data, "start_datetime")))
})

test_that("read_dataset() keeps the skeleton and version too", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("jsonlite")
  path <- test_path("data/sleap/SLEAP_single-mouse_EPM.analysis.h5")
  data <- read_dataset(path)

  expect_equal(
    anicore::get_structure(data, "keypoint")$segments,
    read_structure(path)$segments
  )
  expect_equal(anicore::get_metadata(data, "source_version"), "1.3.1")
})

test_that("an h5 without edges or a version still reads", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("jsonlite")
  # SLEAP wrote this one with empty edges and an empty provenance record.
  path <- test_path("data/sleap/SLEAP_three-mice_Aeon_mixed-labels.analysis.h5")
  data <- read_sleap(path)

  attached <- anicore::get_structure(data, "keypoint")
  expect_equal(attached$points, "centroid")
  expect_equal(nrow(attached$segments), 0L)
  expect_true(is.na(anicore::get_metadata(data, "source_version")))
})

test_that("an h5 with no provenance record at all still reads", {
  skip_if_not_installed("rhdf5")
  path <- write_sleap_h5(edges = matrix(c(0L, 1L), nrow = 2))
  data <- read_sleap(path)

  expect_equal(nrow(data), 6L)
  expect_true(is.na(anicore::get_metadata(data, "source_version")))
  attached <- anicore::get_structure(data, "keypoint")
  expect_equal(attached$segments$from, "head")
  expect_equal(attached$segments$to, "tail")
})

test_that("a provenance record without a usable version leaves it NA", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("jsonlite")
  version_of <- function(provenance) {
    path <- write_sleap_h5(provenance = provenance)
    anicore::get_metadata(read_sleap(path), "source_version")
  }

  expect_equal(version_of('{"sleap_version": "1.4.1"}'), "1.4.1")
  expect_true(is.na(version_of("not json")))
  expect_true(is.na(version_of('["a", "list"]')))
  expect_true(is.na(version_of('"1.4.1"')))
  expect_true(is.na(version_of('{"sleap_version": ""}')))
  expect_true(is.na(version_of('{"sleap_version": 1}')))
})

test_that("the CSV export reads without a structure or version", {
  data <- read_sleap(sleap_csv())

  expect_length(anicore::get_structure(data), 0L)
  expect_true(is.na(anicore::get_metadata(data, "source_version")))
})

test_that("attaching the skeleton again replaces the one the reader attached", {
  # The guides on animovement.dev attach read_structure() after reading.
  skip_if_not_installed("rhdf5")
  path <- test_path("data/sleap/SLEAP_single-mouse_EPM.analysis.h5")
  data <- read_sleap(path)

  expect_no_warning(again <- anicore::set_structure(data, read_structure(path)))
  expect_equal(anicore::get_structure(again), anicore::get_structure(data))
})
