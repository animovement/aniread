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

# Other dtypes ------------------------------------------------------------
# TRex writes only float32/64 and uint64, so the remaining branches of the
# integer reader are never reached by a real file. They are the branches
# that would misread silently rather than error, so they are built here.

# `size` has to match the dtype: writeBin() defaults to 4-byte integers
# whatever the header claims, which is its own silent-misread trap.
write_npy <- function(path, values, descr, size, n = length(values)) {
  # `n` is elements, which is not the same as length(values) when the body is
  # supplied as raw bytes.
  header <- sprintf(
    "{'descr': '%s', 'fortran_order': False, 'shape': (%d,), }",
    descr,
    n
  )
  padding <- 64 - ((10 + nchar(header) + 1) %% 64)
  header <- paste0(header, strrep(" ", padding), "\n")

  con <- file(path, open = "wb")
  on.exit(close(con))
  writeBin(as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59, 0x01, 0x00)), con)
  writeBin(as.integer(nchar(header)), con, size = 2L, endian = "little")
  writeBin(charToRaw(header), con)
  if (is.raw(values)) {
    writeBin(values, con)
  } else {
    writeBin(values, con, size = size, endian = "little")
  }
}

read_one_npy <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con))
  read_npy(con)
}

test_that("a signed 4-byte integer array reads back", {
  path <- withr::local_tempfile(fileext = ".npy")
  write_npy(path, c(-2L, 0L, 7L), "<i4", 4L)

  expect_equal(read_one_npy(path)$values, c(-2, 0, 7))
})

test_that("a signed 2-byte integer array reads back", {
  path <- withr::local_tempfile(fileext = ".npy")
  write_npy(path, c(-1L, 300L), "<i2", 2L)

  expect_equal(read_one_npy(path)$values, c(-1, 300))
})

test_that("an unsigned 2-byte integer reads past the signed limit", {
  # 40000 does not fit in a signed 2-byte integer, so reading it as one
  # would come back negative rather than erroring.
  path <- withr::local_tempfile(fileext = ".npy")
  write_npy(path, c(40000L, 1L), "<u2", 2L)

  expect_equal(read_one_npy(path)$values, c(40000, 1))
})

test_that("an unsigned 4-byte integer reads past the signed limit", {
  # 3000000000 exceeds .Machine$integer.max, so it is assembled from bytes
  # rather than read as an integer.
  path <- withr::local_tempfile(fileext = ".npy")
  write_npy(path, as.raw(c(0x00, 0x5e, 0xd0, 0xb2)), "<u4", 4L, n = 1)

  expect_equal(read_one_npy(path)$values, 3000000000)
})

test_that("a double array reads back", {
  path <- withr::local_tempfile(fileext = ".npy")
  write_npy(path, c(1.5, -2.25), "<f8", 8L)

  expect_equal(read_one_npy(path)$values, c(1.5, -2.25))
})

test_that("an unsupported dtype is an error, not a silent misread", {
  path <- withr::local_tempfile(fileext = ".npy")
  write_npy(path, as.raw(rep(0x00, 8)), "<c8", 8L, n = 1)

  expect_error(read_one_npy(path), "dtype")
})
