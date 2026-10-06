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
  data <- anicore::example_anipoint()
  write_aniframe(data, path)

  result <- read_aniframe(path)

  expect_true(anicore::is_aniframe(result))
})

test_that("read_aniframe restores the aniframe class", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_anipoint()
  write_aniframe(data, path)

  result <- read_aniframe(path)

  expect_s3_class(result, c("anipoint", "aniframe"))
})

test_that("read_aniframe preserves metadata", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_anipoint()
  original_metadata <- attr(data, "metadata")
  write_aniframe(data, path)

  result <- read_aniframe(path)

  expect_equal(attr(result, "metadata"), original_metadata)
})

test_that("read_aniframe errors for non-parquet extensions", {
  data <- anicore::example_anipoint()
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

test_that("read_aniframe restores the subclass recorded in the file", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_anipoint(n_obs = 3, n_individuals = 1) |>
    anicore::set_structure(anicore::example_structure()) |>
    anicore::as_anijoint()
  write_aniframe(data, path)

  stored <- arrow::read_parquet(path, as_data_frame = FALSE)$metadata
  expect_identical(stored$animovement, '{"class":["anijoint"]}')
  expect_identical(class(read_aniframe(path)), class(data))
})

test_that("read_aniframe infers the class of a file that records none", {
  # Files written before the class was recorded carry only the metadata
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_anipoint()
  arrow::write_parquet(data, path) |>
    suppressWarnings()

  expect_null(
    arrow::read_parquet(path, as_data_frame = FALSE)$metadata$animovement
  )
  expect_s3_class(read_aniframe(path), c("anipoint", "aniframe"))
})

test_that("read_aniframe tells an anievent by its metadata when no class is recorded", {
  path <- withr::local_tempfile(fileext = ".parquet")
  events <- read_boris(test_path(
    "data/boris/tabular/test_export_events_tabular.csv"
  ))
  # As arrow leaves a grouped frame: the metadata kept, the classes gone
  class(events) <- c("tbl_df", "tbl", "data.frame")
  arrow::write_parquet(events, path)

  expect_false(anicore::is_aniframe(arrow::read_parquet(path)))
  expect_s3_class(read_aniframe(path), c("anievent", "aniframe"))
})

test_that("read_aniframe errors when file does not exist", {
  expect_error(read_aniframe("nonexistent.parquet"))
})
