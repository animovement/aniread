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

  key <- arrow::read_parquet(path, as_data_frame = FALSE)$metadata$animovement
  expect_identical(jsonlite::fromJSON(key)$class, "anijoint")
  expect_identical(class(read_aniframe(path)), class(data))
})

test_that("the metadata is written to the animovement key, not to arrow's", {
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_anipoint() |>
    anicore::set_metadata(sampling_rate = 30, unit_space = "mm")
  write_aniframe(data, path)

  stored <- arrow::read_parquet(path, as_data_frame = FALSE)$metadata
  # Readable without R: plain JSON, values as the documented layout has them
  key <- jsonlite::fromJSON(stored$animovement)
  expect_identical(key$class, "anipoint")
  expect_identical(key$metadata$time$sampling_rate, 30L)
  expect_identical(key$metadata$space$unit_space, "mm")
  # arrow's R-only key holds no second copy
  expect_false(any(grepl("spec_version", stored$r %||% "", fixed = TRUE)))
  expect_null(attr(arrow::read_parquet(path), "metadata")) # anicore: allow-metadata
})

test_that("a file whose key records only the class still reads", {
  # As written between aniread#202 and #203: the class in our key, the
  # metadata in arrow's
  path <- withr::local_tempfile(fileext = ".parquet")
  data <- anicore::example_anipoint(n_obs = 3, n_individuals = 1) |>
    anicore::set_structure(anicore::example_structure()) |>
    anicore::as_anijoint()
  table <- arrow::arrow_table(data) |>
    suppressWarnings()
  table$metadata$animovement <- '{"class":["anijoint"]}'
  arrow::write_parquet(table, path)

  result <- read_aniframe(path)
  expect_identical(class(result), class(data))
  expect_identical(anicore::get_metadata(result), anicore::get_metadata(data))
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
