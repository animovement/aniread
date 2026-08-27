# Tests for read_aniframe
#
# - Returns an aniframe object when reading a valid parquet file
# - Restores the aniframe class that arrow strips
# - Preserves metadata through the write/read cycle
# - Errors when file extension is not .parquet
# - Errors when parquet file does not contain aniframe metadata
# - Errors when file does not exist

test_that("read_aniframe returns a valid aniframe", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_aniframe()
  write_aniframe(data, path)

  result <- read_aniframe(path)

  expect_true(anicore::is_aniframe(result))
})

test_that("read_aniframe restores the aniframe class", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_aniframe()
  write_aniframe(data, path)

  result <- read_aniframe(path)

  expect_true("aniframe" %in% class(result))
})

test_that("read_aniframe preserves metadata", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_aniframe()
  original_metadata <- attr(data, "metadata")
  write_aniframe(data, path)

  result <- read_aniframe(path)

  expect_equal(attr(result, "metadata"), original_metadata)
})

test_that("read_aniframe errors for non-parquet extensions", {
  data <- anicore::example_aniframe()
  path_csv <- withr::local_tempfile(fileext = ".csv")
  path_tsv <- withr::local_tempfile(fileext = ".tsv")
  write_aniframe(data, path_csv) |>
    suppressWarnings()
  write_aniframe(data, path_tsv) |>
    suppressWarnings()
  expect_error(
    read_aniframe(path_csv),
    "File must be a Parquet file"
  )
  expect_error(
    read_aniframe(path_tsv),
    "File must be a Parquet file"
  )
})

test_that("read_aniframe errors for parquet without aniframe metadata", {
  path <- withr::local_tempfile(fileext = ".parquet")
  plain_df <- data.frame(x = 1:5, y = 1:5, time = 1:5)
  arrow::write_parquet(plain_df, path)

  expect_error(
    read_aniframe(path),
    "does not contain a valid aniframe"
  )
})

test_that("read_aniframe errors when file does not exist", {
  expect_error(read_aniframe("nonexistent.parquet"))
})
