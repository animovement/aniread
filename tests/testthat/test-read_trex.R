# The .npz export --------------------------------------------------------
# TRex's native export carries what the CSV does not: pose keypoints, a
# per-frame detection probability, the identity, and the recording's frame
# rate and frame size. See #116.

npz_path <- function() {
  system.file("extdata", "trex_id3.npz", package = "aniread")
}

# Rebuild an npz from a named list of arrays, so a fixture can be stripped of
# a field to exercise what happens when a recording lacks it.
write_npz <- function(path, arrays) {
  dir <- withr::local_tempdir()
  members <- vapply(
    names(arrays),
    function(nm) {
      values <- arrays[[nm]]
      descr <- if (nm == "id") "<u8" else "<f8"
      size <- 8L
      header <- sprintf(
        "{'descr': '%s', 'fortran_order': False, 'shape': (%d,), }",
        descr,
        length(values)
      )
      header <- paste0(
        header,
        strrep(" ", 64 - ((10 + nchar(header) + 1) %% 64)),
        "\n"
      )
      member <- file.path(dir, paste0(nm, ".npy"))
      con <- file(member, open = "wb")
      writeBin(as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59, 0x01, 0x00)), con)
      writeBin(as.integer(nchar(header)), con, size = 2L, endian = "little")
      writeBin(charToRaw(header), con)
      if (descr == "<u8") {
        writeBin(as.raw(c(as.integer(values[[1]]), rep(0L, 7))), con)
      } else {
        writeBin(as.numeric(values), con, size = size, endian = "little")
      }
      close(con)
      member
    },
    character(1)
  )
  withr::with_dir(dir, zip(path, basename(members), flags = "-q"))
  invisible(path)
}

test_that("read_trex() reads the npz export", {
  data <- read_trex(npz_path())

  expect_s3_class(data, "aniframe")
  expect_equal(anicore::get_metadata(data)$source_format, "npz")
  expect_equal(anicore::get_metadata(data)$source, "trex")
})

test_that("the npz supplies identity, which the CSV leaves NA", {
  data <- read_trex(npz_path())

  expect_equal(levels(data$individual), "3")
  expect_false(any(is.na(data$individual)))
})

test_that("the npz supplies confidence, which the CSV leaves NA", {
  data <- read_trex(npz_path())
  confidence <- data$confidence[!is.na(data$confidence)]

  expect_gt(length(confidence), 0)
  expect_true(all(confidence > 0 & confidence <= 1))
})

test_that("pose keypoints are discovered rather than assumed", {
  # The count depends on the pose model the recording was tracked with, so
  # the fixture's two must not be hard-coded anywhere.
  data <- read_trex(npz_path())

  expect_setequal(levels(data$keypoint), c("centroid", "pose0", "pose1"))
})

test_that("TRex's Inf marks a missing frame, and reads back as NA", {
  data <- read_trex(npz_path())

  expect_false(any(is.infinite(data$x)))
  expect_false(any(is.infinite(data$y)))
  # The fixture's third frame is untracked in every field.
  expect_equal(sum(is.na(data$x)), nlevels(data$keypoint))
})

test_that("the npz supplies the sampling rate without rescaling time", {
  data <- read_trex(npz_path())
  md <- anicore::get_metadata(data)

  expect_equal(md$sampling_rate, 30)
  expect_equal(as.character(md$unit_time), "s")
  # TRex reports seconds already; treating them as frames would divide the
  # step by the frame rate.
  expect_equal(median(diff(sort(unique(data$time)))), 1 / 30, tolerance = 1e-6)
})

test_that("several npz files read as one recording", {
  data <- read_trex(c(npz_path(), npz_path()))

  expect_equal(nrow(data), 2 * nrow(read_trex(npz_path())))
})

test_that("format = 'csv' refuses a vector of paths", {
  expect_error(
    read_trex(c(npz_path(), npz_path()), format = "csv"),
    "single file"
  )
})

test_that("detect_source() recognises a TRex npz", {
  expect_equal(detect_source(npz_path()), "trex")
})

test_that("the CSV reader treats Inf as missing too", {
  # TRex writes Inf for an untracked frame in both exports; its own docs mask
  # them out before plotting.
  csv <- system.file("extdata", "trex.csv", package = "aniread")
  raw <- vroom::vroom(csv, show_col_types = FALSE) |> suppressMessages()
  raw[["X (cm)"]][2] <- Inf
  raw[["Y (cm)"]][2] <- Inf

  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(raw, path, delim = ",")

  data <- read_trex(path)
  expect_false(any(is.infinite(data$x)))
  expect_false(any(is.infinite(data$y)))
  expect_true(any(is.na(data$x)))
})

test_that("the CSV reader tolerates a file without the optional columns", {
  # `output_fields` is set per run, so vx/vy/timestamp need not be present.
  csv <- system.file("extdata", "trex.csv", package = "aniread")
  raw <- vroom::vroom(csv, show_col_types = FALSE) |> suppressMessages()
  raw <- raw[, !names(raw) %in% c("VX (cm/s)", "VY (cm/s)", "timestamp")]

  path <- withr::local_tempfile(fileext = ".csv")
  vroom::vroom_write(raw, path, delim = ",")

  expect_s3_class(read_trex(path), "aniframe")
})

test_that("an npz with no pose arrays reads as centroid only", {
  # Whether a recording has pose depends on how it was tracked, so the
  # keypoints are discovered - and there may be none.
  arrays <- read_npz(npz_path())
  keep <- arrays[!grepl("^pose[XY]", names(arrays))]

  path <- withr::local_tempfile(fileext = ".npz")
  write_npz(path, keep)

  data <- read_trex(path)
  expect_setequal(levels(data$keypoint), "centroid")
  expect_equal(nrow(data), length(arrays$time))
})

test_that("an npz with no video_size falls back to max(y)", {
  # video_size is what lets the reflection use the real frame height; without
  # it the reader falls back the way the CSV path always has.
  arrays <- read_npz(npz_path())
  keep <- arrays[names(arrays) != "video_size"]

  path <- withr::local_tempfile(fileext = ".npz")
  write_npz(path, keep)

  expect_s3_class(read_trex(path), "aniframe")
})
