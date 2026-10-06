# Tests for read_c3d
# - Errors on invalid file path
# - Errors on non-.c3d file extension
# - Returns an aniframe
# - Has expected columns (time, keypoint, x, y, z)
# - Time is in seconds from the recording's first frame (#150)
# - Metadata is set correctly
# - Sampling rate is set
# Wrap the sample-data download so a failure (offline, slow GIN server,
# etc.) doesn't error out the whole test file — tests that need the file
# skip individually below.
path <- tryCatch(
  get_sample_data("c3d", cache_dir = test_cache_dir(), quiet = TRUE),
  error = function(e) NULL
)

test_that("read_c3d validates input", {
  expect_error(read_c3d("nonexistent.c3d"))
  expect_error(read_c3d("file.csv"))
})

test_that("read_c3d returns an aniframe with expected structure", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows") # These tests result in errors in the Windows runners
  skip_if(is.null(path), "c3d sample download unavailable")

  result <- read_c3d(path)

  expect_s3_class(result, "anipoint")
  expect_named(
    result,
    c("time", "keypoint", "x", "y", "z"),
    ignore.order = TRUE
  )
})

test_that("read_c3d keeps the recording frame the file starts at (#150)", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows")
  skip_if(is.null(path), "c3d sample download unavailable")

  # The sample's header says it starts at frame 705 of a 200 Hz recording,
  # counted from 1, so its first row is 704 / 200 s from the first frame.
  result <- read_c3d(path)

  expect_equal(min(result$time), 704 / 200)
  expect_equal(max(result$time), 1043 / 200)
})

# A C3D file written by c3dr's own writer (ezc3d), which numbers the first
# frame 1: the first three frames of the example file c3dr ships (MIT).
write_c3d_from_frame_1 <- function() {
  example <- c3dr::c3d_read(c3dr::c3d_example())
  trimmed <- c3dr::c3d_setdata(
    example,
    newdata = c3dr::c3d_data(example)[1:3, ],
    newanalog = c3dr::c3d_analog(example)[1:30, ]
  )
  out <- withr::local_tempfile(fileext = ".c3d", .local_envir = parent.frame())
  c3dr::c3d_write(trimmed, out)
  out
}

test_that("the first frame of the recording reads as time 0 (#150)", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows")

  out <- write_c3d_from_frame_1()
  header <- readBin(out, "raw", 10)
  expect_equal(
    readBin(
      header[7:8],
      "integer",
      size = 2,
      signed = FALSE,
      endian = "little"
    ),
    1
  )

  result <- read_c3d(out)
  expect_equal(sort(unique(result$time)), c(0, 1, 2) / 200)
})

test_that("the first frame comes from TRIAL:ACTUAL_START_FIELD when set", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows")

  out <- write_c3d_from_frame_1()
  # Two signed 16-bit words, low word first: frame 70000 is 4464 + 1 * 65536,
  # and frame 40000 is stored as -25536.
  expect_equal(
    c3d_first_frame(out, list(TRIAL = list(ACTUAL_START_FIELD = c(4464L, 1L)))),
    69999
  )
  expect_equal(
    c3d_first_frame(
      out,
      list(TRIAL = list(ACTUAL_START_FIELD = c(-25536L, 0L)))
    ),
    39999
  )
  expect_equal(c3d_first_frame(out, list()), 0)
})

test_that("read_c3d sets metadata and sampling rate", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows")
  skip_if(is.null(path), "c3d sample download unavailable")

  result <- read_c3d(path)

  meta <- anicore::get_metadata(result)
  expect_true(!is.null(meta$source))
  expect_true(!is.null(meta$filename))
  expect_true(!is.null(meta$unit_time))
  expect_true(!is.null(meta$unit_space))
  expect_true(!is.null(anicore::get_metadata(result, "sampling_rate")))
})
