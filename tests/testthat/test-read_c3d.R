# Tests for read_c3d
# - Errors on invalid file path
# - Errors on non-.c3d file extension
# - Returns an aniframe
# - Has expected columns (time, keypoint, x, y, z)
# - Time is 0-indexed
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

  expect_s3_class(result, "aniframe")
  expect_named(
    result,
    c("time", "keypoint", "x", "y", "z"),
    ignore.order = TRUE
  )
})

test_that("read_c3d time is 0-indexed", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows")
  skip_if(is.null(path), "c3d sample download unavailable")

  result <- read_c3d(path)

  expect_equal(min(result$time), 0)
})

test_that("read_c3d sets metadata and sampling rate", {
  skip_if_not_installed("c3dr")
  skip_on_os("windows")
  skip_if(is.null(path), "c3d sample download unavailable")

  result <- read_c3d(path)

  meta <- aniframe::get_metadata(result)
  expect_true(!is.null(meta$source))
  expect_true(!is.null(meta$filename))
  expect_true(!is.null(meta$unit_time))
  expect_true(!is.null(meta$unit_space))
  expect_true(!is.null(aniframe::get_metadata(result, "sampling_rate")))
})
