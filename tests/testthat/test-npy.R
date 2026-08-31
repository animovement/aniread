# Tests for the .npy / .npz readers
#
# .npz is a zip of .npy arrays, and .npy is a short header over a raw
# buffer. These are parsed here rather than by a dependency, so the parsing
# needs covering directly - particularly the dtypes readBin() cannot handle.

npz_fixture <- function() {
  system.file("extdata", "trex_id3.npz", package = "aniread")
}

test_that("read_npz() returns one vector per array", {
  arrays <- read_npz(npz_fixture())

  expect_type(arrays, "list")
  expect_true(all(c("time", "X", "Y", "detection_p", "id") %in% names(arrays)))
  expect_length(arrays$time, 5)
})

test_that("float arrays read back at their stored values", {
  arrays <- read_npz(npz_fixture())

  expect_equal(arrays$X[1:2], c(10, 10.5))
  expect_equal(arrays$frame_rate, 30)
  expect_equal(arrays$cm_per_pixel, 0.1)
})

test_that("a uint64 array reads back exactly", {
  # readBin() has no 64-bit integer, so `id` is assembled from its bytes.
  # Getting this wrong returns silent nonsense rather than an error.
  expect_equal(read_npz(npz_fixture())$id, 3)
})

test_that("a scalar array is a length-one vector", {
  expect_length(read_npz(npz_fixture())$frame_rate, 1)
})

test_that("is_npz_file() distinguishes an npz from other files", {
  expect_true(is_npz_file(npz_fixture()))
  expect_false(is_npz_file(system.file(
    "extdata",
    "trex.csv",
    package = "aniread"
  )))

  # A zip with no .npy members is not an npz.
  path <- withr::local_tempfile(fileext = ".zip")
  inner <- withr::local_tempfile(fileext = ".txt")
  writeLines("x", inner)
  withr::with_dir(dirname(inner), zip(path, basename(inner), flags = "-q"))
  expect_false(is_npz_file(path))
})

test_that("read_npy() rejects a file that is not an npy", {
  path <- withr::local_tempfile(fileext = ".npy")
  writeLines("definitely not numpy", path)

  con <- file(path, open = "rb")
  withr::defer(close(con))
  expect_error(read_npy(con), "magic string")
})
