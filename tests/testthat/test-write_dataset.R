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

# by --------------------------------------------------------------------------
#
# - One file per value of one key, named <stem>_<key>-<value>.<suffix>
# - Several keys, in the order given
# - "what" and "when" stand for all keys of a role; both for every key
# - Braces in path name the files, set by, and create directories
# - Each file holds an aniframe with the class and metadata of data
# - Values are made safe for file names; a clash after that errors
# - NA values are written to a file of their own
# - Errors: by not a key, not character, or disagreeing with the braces

test_that("by writes one file per value of a key", {
  skip_if_not_installed("arrow")
  data <- anicore::example_anipoint(n_obs = 2, n_individuals = 2)
  dir <- withr::local_tempdir()

  expect_message(
    write_dataset(data, file.path(dir, "mice.parquet"), by = "individual"),
    "Wrote 2 files"
  )

  expect_setequal(
    list.files(dir),
    c("mice_individual-1.parquet", "mice_individual-2.parquet")
  )
})

test_that("each file keeps the class and metadata of data", {
  skip_if_not_installed("arrow")
  data <- anicore::example_anipoint(n_obs = 2, n_individuals = 2)
  dir <- withr::local_tempdir()

  write_dataset(data, file.path(dir, "mice.parquet"), by = "individual") |>
    suppressMessages()
  one <- read_dataset(file.path(dir, "mice_individual-1.parquet"))

  expect_identical(class(one), class(data))
  expect_identical(anicore::get_metadata(one), anicore::get_metadata(data))
  expect_true(all(one$individual == 1))
  expect_equal(nrow(one), sum(data$individual == 1))
})

test_that("by takes several keys, in the order given", {
  data <- anicore::example_anipoint(n_obs = 2, n_individuals = 2)
  dir <- withr::local_tempdir()

  write_dataset(
    data,
    file.path(dir, "mice.csv"),
    by = c("session", "individual")
  ) |>
    suppressMessages() |>
    suppressWarnings()

  expect_setequal(
    list.files(dir),
    c("mice_session-1_individual-1.csv", "mice_session-1_individual-2.csv")
  )
})

test_that("the role names stand for all keys of a role", {
  data <- anicore::example_anipoint(
    n_obs = 2,
    n_individuals = 2,
    n_keypoints = 2
  )
  what <- anicore::get_variables(data, "what", "keys")
  when <- anicore::get_variables(data, "when", "keys")

  expect_identical(resolve_by(data, "what", "x.csv"), what)
  expect_identical(resolve_by(data, "when", "x.csv"), when)
  expect_setequal(
    resolve_by(data, c("what", "when"), "x.csv"),
    anicore::get_keys(data)
  )
  expect_identical(
    resolve_by(data, c("individual", "what"), "x.csv"),
    unique(c("individual", what))
  )
})

test_that("by = c('what', 'when') writes one file per track", {
  data <- anicore::example_anipoint(
    n_obs = 2,
    n_individuals = 2,
    n_keypoints = 3
  )
  dir <- withr::local_tempdir()

  write_dataset(data, file.path(dir, "t.csv"), by = c("what", "when")) |>
    suppressMessages() |>
    suppressWarnings()

  expect_length(list.files(dir), 6)
})

test_that("braces in path name the files and set by", {
  skip_if_not_installed("arrow")
  data <- anicore::example_anipoint(
    n_obs = 2,
    n_individuals = 2,
    n_keypoints = 2
  )
  dir <- withr::local_tempdir()

  write_dataset(data, file.path(dir, "{individual}", "{keypoint}.parquet")) |>
    suppressMessages()

  files <- list.files(dir, recursive = TRUE)
  expect_length(files, 4)
  expect_true(all(dirname(files) %in% c("1", "2")))
})

test_that("values are made safe for file names", {
  expect_identical(
    path_for_group("out/m.csv", data.frame(individual = "mouse 1/a")),
    "out/m_individual-mouse-1-a.csv"
  )
  expect_identical(
    path_for_group("out/{individual}.csv", data.frame(individual = "a:b")),
    "out/a-b.csv"
  )
  expect_identical(
    path_for_group("m.csv", data.frame(individual = NA)),
    "m_individual-NA.csv"
  )
})

test_that("groups whose names clash once made safe are refused", {
  data <- anicore::example_anipoint(n_obs = 2, n_individuals = 2)
  data$individual <- ifelse(data$individual == 1, "a b", "a/b")
  data <- anicore::as_anipoint(data)

  expect_error(
    write_dataset(
      data,
      file.path(withr::local_tempdir(), "m.csv"),
      by = "individual"
    ),
    "Several groups would be written"
  )
})

test_that("by is checked against the keys and the braces", {
  data <- anicore::example_anipoint(n_obs = 2, n_individuals = 2)
  path <- file.path(withr::local_tempdir(), "m.csv")

  expect_error(write_dataset(data, path, by = "x"), "not a key")
  expect_error(write_dataset(data, path, by = 1), "character vector")
  expect_error(
    write_dataset(data, sub("m.csv", "{individual}.csv", path), by = "session"),
    "also splits by"
  )
  expect_error(
    write_dataset(data, sub("m.csv", "{nope}.csv", path)),
    "not a key"
  )
})
