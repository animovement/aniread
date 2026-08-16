# Tests against fixtures shaped like real Bonsai captures (#85).
#
# Every other trackball fixture is built with write.csv(), i.e. a well-formed,
# header-bearing, gap-free, perfectly synchronised file. Real captures are
# headerless, sometimes preceded by a line of serial junk, drop characters
# mid-line, contain multi-second gaps, and start the two sensors seconds apart.
# These fixtures reproduce that shape.
#
# Bonsai layout: dx, dy, device_clock_us, pc_datetime, interval_s

# Write a headerless Bonsai-style capture.
#
# t0        epoch seconds of the first sample
# n         number of data rows
# junk      prepend a line of serial-port noise
# badrow    index of a row to truncate (drops the leading dx field)
# gap_after insert a `gap` second pause after this row
make_sensor <- function(
  path,
  t0 = 1e9,
  n = 300,
  dx = 0,
  dy = 1,
  rate = 60,
  junk = FALSE,
  badrow = NA,
  gap_after = NA,
  gap = 0,
  dup = 1
) {
  offsets <- seq_len(n) / rate
  if (!is.na(gap_after)) {
    offsets[(gap_after + 1):n] <- offsets[(gap_after + 1):n] + gap
  }
  us <- 1e6 * (t0 + offsets)
  dt <- format(
    as.POSIXct(us / 1e6, origin = "1970-01-01", tz = "UTC"),
    "%Y-%m-%dT%H:%M:%OS7+00:00"
  )
  lines <- sprintf("%d,%d,%.0f,%s,0.0166", dx, dy, us, dt)
  if (dup > 1) {
    lines <- rep(lines, each = dup)
  }
  # Serial capture occasionally drops a field mid-line.
  if (!is.na(badrow)) {
    lines[badrow] <- sub("^[-0-9]+,", "", lines[badrow])
  }
  if (junk) {
    lines <- c("!b?b??????????j", lines)
  }
  writeLines(lines, path)
  path
}

# Column positions in the Bonsai layout.
BONSAI <- list(col_time = 4, col_dx = 1, col_dy = 2)

read_bonsai_trackball <- function(paths, ...) {
  do.call(
    read_trackball,
    c(list(paths = paths), BONSAI, list(...))
  )
}


# ---- Leading junk line (defect 4) -------------------------------------------

test_that("read_opticalflow keeps every data row whether or not there is a junk line", {
  with_junk <- make_sensor(withr::local_tempfile(fileext = ".csv"), junk = TRUE)
  without <- make_sensor(withr::local_tempfile(fileext = ".csv"), junk = FALSE)

  expect_equal(nrow(read_opticalflow(with_junk, 4, 1, 2)), 300)
  expect_equal(nrow(read_opticalflow(without, 4, 1, 2)), 300)
})

test_that("read_opticalflow does not take a data row as a header", {
  path <- make_sensor(withr::local_tempfile(fileext = ".csv"), junk = TRUE)

  expect_false(detect_opticalflow_layout(path)$has_header)
  expect_equal(detect_opticalflow_layout(path)$skip, 1)
})

test_that("detect_opticalflow_layout still finds a real header", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("junk line", "x,y,time", "1,4,0", "2,5,1"), path)

  layout <- detect_opticalflow_layout(path)
  expect_equal(layout$skip, 1)
  expect_true(layout$has_header)
})


# ---- Corrupt rows (defect 3) ------------------------------------------------

test_that("a corrupt row is dropped rather than aborting the read", {
  path <- make_sensor(withr::local_tempfile(fileext = ".csv"), badrow = 50)

  # Reading via the device clock used to fail in median(diff(sort(time))).
  expect_no_error(read_opticalflow(path, col_time = 3, col_dx = 1, col_dy = 2))
  # ...and via the datetime column, much further away, inside seq().
  result <- read_opticalflow(path, col_time = 4, col_dx = 1, col_dy = 2)
  expect_equal(nrow(result), 299)
  expect_false(anyNA(result$time))
})

test_that("dropped rows are reported unless quiet", {
  path <- make_sensor(withr::local_tempfile(fileext = ".csv"), badrow = 50)

  expect_message(
    read_opticalflow(path, 4, 1, 2, quiet = FALSE),
    "Dropped 1 malformed row"
  )
  expect_no_message(read_opticalflow(path, 4, 1, 2, quiet = TRUE))
})


# ---- Duplicated timestamps (defect 5) ---------------------------------------

test_that("microsecond scaling is detected despite duplicated timestamps", {
  # Every timestamp repeated 3x, so the plain median diff is 0.
  path <- make_sensor(withr::local_tempfile(fileext = ".csv"), n = 100, dup = 3)

  result <- read_opticalflow(path, col_time = 3, col_dx = 1, col_dy = 2)

  # A microsecond clock left undivided would span 1e6x too long.
  expect_lt(max(result$time) - min(result$time), 10)
})

test_that("detect_time_divisor ignores zero and NA steps", {
  expect_equal(detect_time_divisor(c(1, 1, 1, 16667, 16667, 33334)), 1e6)
  expect_equal(detect_time_divisor(c(0, 0, 0.016, 0.033)), 1)
  expect_equal(detect_time_divisor(c(NA, 1e6, 2e6)), 1e6)
  # No positive steps at all: fall back to seconds rather than erroring.
  expect_equal(detect_time_divisor(c(5, 5, 5)), 1)
})


# ---- Sensor start offset (defect 1) -----------------------------------------

test_that("two sensors are aligned on their true offset", {
  # Sensor 2 starts 4 s later; both run 5 s, so the overlap is the last ~1 s.
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9 + 4)

  result <- read_bonsai_trackball(
    c(s1, s2),
    setup = "of_free",
    sampling_rate = 60
  )

  # Overlap only, not the ~5 s union the old zeroing produced.
  expect_lt(max(result$time), 1.05)
  expect_lt(nrow(result), 70)
})

test_that("read_opticalflow returns time on an absolute scale", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9 + 4)

  t1 <- read_opticalflow(s1, 4, 1, 2)$time
  t2 <- read_opticalflow(s2, 4, 1, 2)$time

  # The 4 s offset survives the read - it is the only thing that can align them.
  expect_equal(min(t2) - min(t1), 4, tolerance = 1e-3)
})

test_that("sensor 2's motion lands in the correct bins", {
  # Sensor 1 runs 3 s from t0 with dy = 0; sensor 2 starts 1 s later with dy = 1.
  s1 <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9,
    n = 180,
    dy = 0
  )
  s2 <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9 + 1,
    n = 180,
    dy = 1
  )

  result <- read_bonsai_trackball(
    c(s1, s2),
    setup = "of_free",
    sampling_rate = 60
  )

  # of_free maps y_1 -> dx and y_2 -> dy, so x stays flat while y accumulates
  # sensor 2's motion. Sample times do not land one-per-bin under floor(), so
  # check the invariants rather than a fixed per-bin count.
  expect_equal(unique(result$x), 0)
  expect_true(all(diff(result$y) >= 0))
  # Every sensor 2 sample inside the shared window is counted exactly once.
  expect_equal(max(result$y), 120)
})

test_that("start_datetime is the wall-clock instant of t = 0", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9 + 4)

  result <- read_bonsai_trackball(
    c(s1, s2),
    setup = "of_free",
    sampling_rate = 60
  )

  # t = 0 is the first shared sample, i.e. the later sensor's start.
  start <- aniframe::get_metadata(result)$start_datetime
  expect_equal(
    as.numeric(start),
    1e9 + 4 + 1 / 60,
    tolerance = 1e-3
  )
})

test_that("non-overlapping recordings error rather than failing downstream", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9, n = 60)
  s2 <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9 + 600,
    n = 60
  )

  expect_error(
    read_bonsai_trackball(c(s1, s2), setup = "of_free", sampling_rate = 60),
    "do not overlap"
  )
})


# ---- Shared-clock requirement (defect 2) ------------------------------------

test_that("a non-datetime col_time warns in the two-sensor path", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9 + 1)

  expect_warning(
    read_trackball(
      c(s1, s2),
      setup = "of_free",
      sampling_rate = 60,
      col_time = 3,
      col_dx = 1,
      col_dy = 2
    ),
    class = "aniread_sensor_local_clock"
  )
})

test_that("a datetime col_time does not warn", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9 + 1)

  expect_no_warning(
    read_bonsai_trackball(c(s1, s2), setup = "of_free", sampling_rate = 60)
  )
})


# ---- Gaps (defect 8) --------------------------------------------------------

test_that("gaps are back-filled to a regular grid for two sensors", {
  s1 <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9,
    n = 120,
    gap_after = 60,
    gap = 2
  )
  s2 <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9,
    n = 120,
    gap_after = 60,
    gap = 2
  )

  result <- read_bonsai_trackball(
    c(s1, s2),
    setup = "of_free",
    sampling_rate = 60
  )

  expect_equal(unique(round(diff(result$time), 9)), round(1 / 60, 9))
})

test_that("gaps are back-filled to a regular grid for one sensor", {
  s1 <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9,
    n = 120,
    gap_after = 60,
    gap = 2
  )

  result <- read_bonsai_trackball(
    s1,
    setup = "of_fixed",
    sampling_rate = 60,
    counts_per_rotation = 1000
  )

  expect_equal(unique(round(diff(result$time), 9)), round(1 / 60, 9))
})

test_that("one- and two-sensor paths agree on the time grid", {
  # The same gappy file read both ways must produce the same grid.
  path <- make_sensor(
    withr::local_tempfile(fileext = ".csv"),
    t0 = 1e9,
    n = 120,
    gap_after = 60,
    gap = 2
  )

  one <- read_bonsai_trackball(
    path,
    setup = "of_fixed",
    sampling_rate = 60,
    counts_per_rotation = 1000
  )
  two <- read_bonsai_trackball(
    c(path, path),
    setup = "of_fixed",
    sampling_rate = 60,
    counts_per_rotation = 1000
  )

  expect_equal(one$time, two$time)
})

test_that("an implausible number of time bins errors instead of exhausting memory", {
  data <- dplyr::tibble(time_group = c(0, 1e9), x_1 = 1, y_1 = 1)

  expect_error(
    fill_missing_time_groups(data, zero_cols = c("x_1", "y_1")),
    "implausibly many"
  )
})


# ---- Argument handling (defects 6, 7) ---------------------------------------

test_that("setup is matched, and a typo gives an informative error", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)

  # Omitted: defaults to of_free rather than "condition has length > 1".
  expect_no_error(
    read_bonsai_trackball(c(s1, s2), sampling_rate = 60)
  )
  expect_error(
    read_bonsai_trackball(c(s1, s2), setup = "free", sampling_rate = 60),
    "should be one of"
  )
})

test_that("of_free with a single file errors up front", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)

  expect_error(
    read_bonsai_trackball(s1, setup = "of_free", sampling_rate = 60),
    "expected 2 files"
  )
})

test_that("a character col_time on a headerless file errors informatively", {
  s1 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)
  s2 <- make_sensor(withr::local_tempfile(fileext = ".csv"), t0 = 1e9)

  expect_error(
    read_trackball(
      c(s1, s2),
      setup = "of_free",
      sampling_rate = 60,
      col_time = "time",
      col_dx = 1,
      col_dy = 2
    ),
    "doesn't have named headers"
  )
})


# ---- Defensive paths --------------------------------------------------------

test_that("a file with nothing usable in it errors clearly", {
  path <- withr::local_tempfile(fileext = ".csv")
  # Right number of fields, but the timestamp is missing on every row, so
  # every row is dropped. (Truncating every row instead would not work: the
  # short width would simply become the modal one.)
  writeLines(rep("0,1,2718587701,,0.0166", 5), path)

  expect_error(
    read_opticalflow(path, col_time = 4, col_dx = 1, col_dy = 2),
    "No usable rows left"
  )
})

test_that("timestamps vroom leaves as character are parsed", {
  # vroom parses ISO8601 to POSIXct itself; a non-ISO but still
  # as.POSIXct()-readable layout is what reaches the character branch.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "time,x,y",
      "2023/09/14 14:37:55,1,4",
      "2023/09/14 14:37:56,2,5",
      "2023/09/14 14:37:57,3,6"
    ),
    path
  )

  result <- read_opticalflow(path, col_time = "time", col_dx = "x", col_dy = "y")

  expect_type(result$time, "double")
  expect_equal(diff(result$time), c(1, 1))
  expect_equal(
    as.numeric(attr(result, "start_datetime")),
    as.numeric(as.POSIXct("2023-09-14 14:37:55"))
  )
})

test_that("is_header_row treats a row of empty fields as data", {
  expect_false(is_header_row(c("", "  ", "")))
  expect_false(is_header_row(character(0)))
  expect_true(is_header_row(c("x", "y", "time")))
})

test_that("fill_missing_time_groups errors when no finite times are present", {
  empty <- dplyr::tibble(time_group = numeric(0), x_1 = numeric(0))

  expect_error(
    suppressWarnings(fill_missing_time_groups(empty, zero_cols = "x_1")),
    "Could not determine the time range"
  )
})
