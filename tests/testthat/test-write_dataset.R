# Tests for write_dataset
#
# - Round trip through Parquet keeps class, grouping, metadata and data, for
#   every aniframe class: anipoint (with and without a structure),
#   anisegment, anijoint and anievent
# - The format is inferred from the suffix
# - A shared suffix infers the first format listed (.csv is a plain table)
# - A named format dispatches to its writer
# - Arguments in ... reach the writer
# - Returns data invisibly
# - Errors: data not an aniframe, path not a string, unknown suffix, unknown
#   or read-only format, suffix the named format does not write

structured_anipoint <- function() {
  anicore::example_anipoint(n_obs = 3, n_individuals = 1) |>
    anicore::set_structure(anicore::example_structure())
}

expect_round_trip <- function(data) {
  skip_if_not_installed("arrow")
  path <- withr::local_tempfile(fileext = ".parquet")

  write_dataset(data, path)
  result <- read_dataset(path)

  expect_identical(class(result), class(data))
  expect_identical(dplyr::group_vars(result), dplyr::group_vars(data))
  expect_identical(anicore::get_metadata(result), anicore::get_metadata(data))
  expect_equal(
    as.data.frame(unclass(result)),
    as.data.frame(unclass(data)),
    ignore_attr = TRUE
  )
}

test_that("an anipoint round-trips through Parquet", {
  expect_round_trip(anicore::example_anipoint())
})

test_that("an anipoint with a structure round-trips through Parquet", {
  expect_round_trip(structured_anipoint())
})

test_that("an anisegment round-trips through Parquet", {
  expect_round_trip(anicore::as_anisegment(structured_anipoint()))
})

test_that("an anijoint round-trips through Parquet", {
  expect_round_trip(anicore::as_anijoint(structured_anipoint()))
})

test_that("an anievent round-trips through Parquet", {
  events <- read_boris(test_path(
    "data/boris/tabular/test_export_events_tabular.csv"
  ))
  expect_s3_class(events, "anievent")
  expect_round_trip(events)
})

test_that("the format is inferred from the suffix", {
  skip_if_not_installed("arrow")
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".parquet")

  write_dataset(data, path)

  expect_identical(detect_source(path), "aniframe")
})

test_that("a .csv is written as a plain table, not for inTRACKtive", {
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".csv")

  expect_warning(write_dataset(data, path), "do not preserve metadata")

  written <- vroom::vroom(path, show_col_types = FALSE)
  expect_false("track_id" %in% names(written))
  expect_true("time" %in% names(written))
})

test_that("a named format dispatches to its writer", {
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".csv")

  write_dataset(data, path, format = "intracktive", quiet = TRUE)

  written <- vroom::vroom(path, show_col_types = FALSE)
  expect_true(all(c("track_id", "t", "x", "y") %in% names(written)))
})

test_that("arguments in ... reach the writer", {
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".csv")

  expect_message(
    write_dataset(data, path, format = "intracktive", quiet = FALSE),
    "inTRACKtive"
  )
  expect_no_message(
    write_dataset(data, path, format = "intracktive", quiet = TRUE)
  )
})

test_that("write_dataset returns data invisibly", {
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".csv")

  expect_invisible(write_dataset(
    data,
    path,
    format = "intracktive",
    quiet = TRUE
  ))
  expect_identical(
    write_dataset(data, path, format = "intracktive", quiet = TRUE),
    data
  )
})

test_that("write_dataset rejects data that is not an aniframe", {
  expect_error(
    write_dataset(mtcars, withr::local_tempfile(fileext = ".parquet")),
    "must be an aniframe"
  )
})

test_that("write_dataset rejects a path that is not a single string", {
  data <- anicore::example_anipoint()
  expect_error(
    write_dataset(data, c("a.parquet", "b.parquet")),
    "single file path"
  )
  expect_error(write_dataset(data, 1), "single file path")
})

test_that("write_dataset names the suffix it cannot infer from", {
  data <- anicore::example_anipoint()
  expect_error(
    write_dataset(data, withr::local_tempfile(fileext = ".xlsx")),
    "No supported format writes \"xlsx\" files"
  )
})

test_that("write_dataset rejects an unknown or read-only format", {
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".csv")

  expect_error(write_dataset(data, path, format = "nope"), "Unsupported")
  expect_error(write_dataset(data, path, format = "octron"), "Unsupported")
  expect_error(write_dataset(data, path, format = c("a", "b")), "single format")
})

test_that("write_dataset rejects a suffix the named format does not write", {
  data <- anicore::example_anipoint()
  path <- withr::local_tempfile(fileext = ".parquet")

  expect_error(
    write_dataset(data, path, format = "intracktive"),
    "written to \"csv\" files"
  )
})
