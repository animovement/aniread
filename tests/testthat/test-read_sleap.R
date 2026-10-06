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

test_that("time is frame_idx, counted from 0 as it is for the h5 (#150)", {
  data <- read_sleap(sleap_csv())
  raw <- vroom::vroom(sleap_csv(), show_col_types = FALSE) |> suppressMessages()

  expect_equal(sort(unique(data$time)), sort(unique(raw$frame_idx)))
  expect_equal(min(data$time), 0)
})

test_that("a frame with no instance comes back as NA, not absent", {
  # The CSV holds a row per instance, so an undetected instance has no row.
  raw <- vroom::vroom(sleap_csv(), show_col_types = FALSE) |> suppressMessages()
  trimmed <- raw[!(raw$track == raw$track[[1]] & raw$frame_idx == 5), ]

  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(trimmed, path, delim = ",")

  data <- read_sleap(path)
  gap <- data[data$individual == raw$track[[1]] & data$time == 5, ]

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

# Exports written by sleap-io (#170) --------------------------------------
# SLEAP writes its analysis exports through sleap-io from SLEAP 1.6.3 on.
# The fixtures below were written by sleap-io 0.9.2 (BSD-3-Clause) from two
# of its own BSD-3-Clause test files, in tests/data/slp at tag v0.9.2:
#
# * SLEAP_two-flies_sleap-io.*: predictions_1.2.7_provenance_and_tracking.slp
#   cut to frames 0 to 5 of a video declared 9 frames long, with track_1
#   removed from frame 3. Two tracks, 13 nodes, and a provenance record of
#   SLEAP 1.2.7. Written with save_csv(), and save_analysis_h5() with
#   preset = "matlab" and preset = "standard".
# * SLEAP_untracked-pair_sleap-io.*: centered_pair_predictions.slp cut to
#   frames 0 to 2, with every track removed, only the first instance kept in
#   frame 1, and an empty provenance record. Written with save_csv(), and
#   save_analysis_h5() with custom axes (track_dim = 0, frame_dim = 1,
#   xy_dim = 2, node_dim = 3).
#
# Files SLEAP wrote itself, from github.com/talmolab/sleap (Clear BSD):
#
# * SLEAP_small-robot_legacy.analysis.h5: tests/data/hdf5_format_v1/
#   small_robot.000_small_robot_3_frame.analysis.h5, unchanged.
# * SLEAP_minimal-instance_legacy.analysis.csv: tests/data/csv_format/
#   minimal_instance.000_centered_pair_low_quality.analysis.csv, unchanged.
# * SLEAP_docs-example_no-scores.analysis.h5: the docs example
#   docs/notebooks/analysis_example/predictions.analysis.h5 (branch main),
#   which predates the score datasets, cut to its first 5 frames with h5py.
#   Its four datasets and their layout are otherwise unchanged.

sleap_fixture <- function(name) {
  test_path("data/sleap", name)
}

# One row per time, individual and keypoint, for comparing two reads.
sleap_rows <- function(d) {
  d <- d[order(d$time, as.character(d$individual), as.character(d$keypoint)), ]
  data.frame(
    time = as.numeric(d$time),
    individual = as.character(d$individual),
    keypoint = as.character(d$keypoint),
    x = d$x,
    y = d$y,
    confidence = d$confidence
  )
}

test_that("both sleap-io presets read the same", {
  skip_if_not_installed("rhdf5")
  matlab <- read_sleap(sleap_fixture(
    "SLEAP_two-flies_sleap-io.matlab.analysis.h5"
  ))
  standard <- read_sleap(
    sleap_fixture("SLEAP_two-flies_sleap-io.standard.analysis.h5")
  )

  expect_equal(
    rhdf5::h5readAttributes(
      sleap_fixture("SLEAP_two-flies_sleap-io.standard.analysis.h5"),
      "/"
    )$preset,
    "standard"
  )
  expect_equal(sleap_rows(standard), sleap_rows(matlab))
})

test_that("a sleap-io h5 reads as its CSV does", {
  skip_if_not_installed("rhdf5")
  base <- "SLEAP_two-flies_sleap-io"
  h5 <- read_sleap(
    sleap_fixture(paste0(base, ".standard.analysis.h5")),
    video_height = 1024
  )
  csv <- read_sleap(
    sleap_fixture(paste0(base, ".analysis.csv")),
    video_height = 1024
  )

  a <- sleap_rows(h5[h5$time <= max(csv$time), ])
  b <- sleap_rows(csv)
  expect_equal(a, b)
  expect_setequal(b$individual, c("track_0", "track_1"))
})

test_that("the sleap-io CSV's sorted columns are matched by name", {
  path <- sleap_fixture("SLEAP_two-flies_sleap-io.analysis.csv")
  raw <- vroom::vroom(path, show_col_types = FALSE) |> suppressMessages()
  # sleap-io sorts the nodes by name, with .score before .x and .y.
  expect_equal(
    names(raw)[4:9],
    c(
      "abdomen.score",
      "abdomen.x",
      "abdomen.y",
      "eyeL.score",
      "eyeL.x",
      "eyeL.y"
    )
  )

  data <- read_sleap(path, video_height = 1024)
  head <- data[data$keypoint == "head", ]
  head <- head[order(head$time, head$individual), ]
  head <- head[!is.na(head$x), ]
  raw <- raw[order(raw$frame_idx, raw$track), ]

  expect_equal(head$x, raw[["head.x"]])
  expect_equal(head$confidence, raw[["head.score"]])
})

test_that("the frame axis of a sleap-io h5 runs to the end of the video", {
  skip_if_not_installed("rhdf5")
  # Six labelled frames of a nine-frame video: the last three come back as
  # NA rows, one per track and node, as undetected frames always have.
  data <- read_sleap(sleap_fixture(
    "SLEAP_two-flies_sleap-io.matlab.analysis.h5"
  ))

  expect_equal(nrow(data), 9L * 2L * 13L)
  expect_equal(range(data$time), c(0, 8))
  expect_true(all(is.na(data$x[data$time > 5])))
  expect_true(all(is.na(data$confidence[data$time > 5])))
  # track_1 was not detected in frame 3.
  gap <- data[data$time == 3, ]
  expect_true(all(is.na(gap$x[gap$individual == "track_1"])))
  expect_false(all(is.na(gap$x[gap$individual == "track_0"])))
})

test_that("custom axes are read from the dims attribute", {
  skip_if_not_installed("rhdf5")
  path <- sleap_fixture("SLEAP_untracked-pair_sleap-io.custom.analysis.h5")
  expect_equal(
    rhdf5::h5readAttributes(path, "tracks")$dims,
    '["track", "frame", "xy", "node"]'
  )
  h5 <- read_sleap(path, video_height = 1024)
  csv <- read_sleap(
    sleap_fixture("SLEAP_untracked-pair_sleap-io.analysis.csv"),
    video_height = 1024
  )

  # sleap-io names the instances of an untracked recording track_0, track_1
  # in the h5, and the reader keeps them; the CSV leaves track empty, and
  # its rows are numbered in the same order.
  expect_setequal(levels(h5$individual), c("track_0", "track_1"))
  expect_setequal(levels(csv$individual), c("individual1", "individual2"))
  h5$individual <- factor(
    h5$individual,
    levels = c("track_0", "track_1"),
    labels = c("individual1", "individual2")
  )
  expect_equal(sleap_rows(h5), sleap_rows(csv))
  # Only one fly was kept in frame 1.
  expect_true(all(is.na(csv$x[
    csv$time == 1 & csv$individual == "individual2"
  ])))
})

test_that("the first frame of the video reads as time 0 (#150)", {
  skip_if_not_installed("rhdf5")
  # sleap-io writes the frame axis from the video's frame 0, and the CSV
  # gives frame_idx; frame 0 is labelled in this recording.
  csv_path <- sleap_fixture("SLEAP_two-flies_sleap-io.analysis.csv")
  raw <- vroom::vroom(csv_path, show_col_types = FALSE) |> suppressMessages()
  expect_equal(min(raw$frame_idx), 0)

  for (name in c(
    "SLEAP_two-flies_sleap-io.matlab.analysis.h5",
    "SLEAP_two-flies_sleap-io.standard.analysis.h5",
    "SLEAP_two-flies_sleap-io.analysis.csv"
  )) {
    data <- read_sleap(sleap_fixture(name), video_height = 1024)
    first <- data[data$time == 0 & data$keypoint == "head", ]
    first <- first[order(first$individual), ]
    expect_equal(min(data$time), 0, info = name)
    expect_equal(
      first$x,
      raw[["head.x"]][raw$frame_idx == 0][order(raw$track[raw$frame_idx == 0])],
      info = name
    )
  }
})

test_that("a dims attribute that names other axes is rejected", {
  skip_if_not_installed("rhdf5")
  path <- write_sleap_h5()
  rhdf5::h5writeAttribute(
    '["track", "xy", "node", "time"]',
    rhdf5::H5Dopen(rhdf5::H5Fopen(path), "tracks"),
    "dims"
  )
  rhdf5::h5closeAll()

  expect_error(read_sleap(path), "Cannot read the axes of")
})

test_that("sleap-io's version is recorded when the provenance names no SLEAP", {
  skip_if_not_installed("rhdf5")
  skip_if_not_installed("jsonlite")
  version_of <- function(name) {
    anicore::get_metadata(read_sleap(sleap_fixture(name)), "source_version")
  }

  # The provenance names the SLEAP that tracked it, and that wins.
  expect_equal(
    version_of("SLEAP_two-flies_sleap-io.matlab.analysis.h5"),
    "1.2.7"
  )
  expect_equal(
    version_of("SLEAP_untracked-pair_sleap-io.custom.analysis.h5"),
    "sleap-io 0.9.2"
  )
  # SLEAP's own exports have no root attributes.
  expect_true(is.na(version_of("SLEAP_small-robot_legacy.analysis.h5")))
})

test_that("a sleap-io h5 keeps its skeleton", {
  skip_if_not_installed("rhdf5")
  path <- sleap_fixture("SLEAP_two-flies_sleap-io.standard.analysis.h5")
  attached <- anicore::get_structure(read_sleap(path), "keypoint")

  expect_equal(attached$segments, read_structure(path)$segments)
  expect_equal(nrow(attached$segments), 12L)
})

test_that("an old h5 without score datasets reads with NA confidence", {
  skip_if_not_installed("rhdf5")
  path <- sleap_fixture("SLEAP_docs-example_no-scores.analysis.h5")
  expect_false("point_scores" %in% rhdf5::h5ls(path)$name)
  data <- read_sleap(path)

  expect_equal(nrow(data), 5L * 2L * 13L)
  expect_true(all(is.na(data$confidence)))
  expect_false(anyNA(data$x))
  expect_setequal(levels(data$individual), c("track_0", "track_1"))
})

test_that("SLEAP's own exports from its test data still read", {
  skip_if_not_installed("rhdf5")
  h5 <- read_sleap(sleap_fixture("SLEAP_small-robot_legacy.analysis.h5"))
  expect_equal(nrow(h5), 3L * 3L)
  expect_setequal(levels(h5$individual), "individual1")

  # An untracked row has an empty track, and is named as the h5 reader
  # names an untracked instance.
  csv <- read_sleap(sleap_fixture("SLEAP_minimal-instance_legacy.analysis.csv"))
  expect_setequal(levels(csv$individual), "individual1")
  expect_false(anyNA(csv$individual))
  expect_setequal(levels(csv$keypoint), c("A", "B"))
})

test_that("a track with two instances in a frame keeps the first", {
  # sleap-io's CSV has a row for each user-labelled and each predicted
  # instance, user-labelled first; its h5 keeps the user-labelled one.
  path <- sleap_fixture("SLEAP_two-flies_sleap-io.analysis.csv")
  raw <- vroom::vroom(path, show_col_types = FALSE) |> suppressMessages()
  user <- raw[1, ]
  user$head.x <- -1
  dup <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(rbind(user, raw), dup, delim = ",")

  data <- read_sleap(dup)
  first <- data[data$time == 0 & data$individual == "track_0", ]

  expect_equal(nrow(data), nrow(read_sleap(path)))
  expect_equal(first$x[first$keypoint == "head"], -1)
})

test_that("a CSV without scores or with a video column still reads", {
  path <- sleap_fixture("SLEAP_two-flies_sleap-io.analysis.csv")
  raw <- vroom::vroom(path, show_col_types = FALSE) |> suppressMessages()
  # User-labelled instances have no scores, and sleap-io sorts a video_idx
  # column in among the nodes when asked for one.
  trimmed <- raw[, !grepl("score$", names(raw))]
  trimmed$video_idx <- 0
  out <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(trimmed, out, delim = ",")

  data <- read_sleap(out)

  expect_true(all(is.na(data$confidence)))
  expect_equal(nlevels(data$keypoint), 13L)
  expect_equal(data$x, read_sleap(path)$x)
})

test_that("read_dataset() recognises the sleap-io exports", {
  skip_if_not_installed("rhdf5")
  expect_equal(
    detect_source(sleap_fixture(
      "SLEAP_two-flies_sleap-io.standard.analysis.h5"
    )),
    "sleap"
  )
  expect_equal(
    detect_source(sleap_fixture("SLEAP_untracked-pair_sleap-io.analysis.csv")),
    "sleap"
  )
})
