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

  expect_s3_class(data, "aniframe")
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
