# ---- Layout auto-detection (#88) ---------------------------------------

test_that("the raw layout is detected without being told", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")

  expect_equal(
    as.data.frame(read_animalta(path)),
    as.data.frame(read_animalta(path, detailed = FALSE))
  )
})

test_that("the detailed layout is detected without being told", {
  # Reading this file with the old default gave a header error naming
  # columns the user had never heard of, rather than pointing at
  # `detailed` (#88).
  path <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )

  expect_no_error(result <- read_animalta(path))
  expect_s3_class(result, "anipoint")
  expect_equal(
    as.data.frame(result),
    as.data.frame(read_animalta(path, detailed = TRUE))
  )
})

test_that("an explicit layout is still honoured", {
  detailed <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )

  # Naming the wrong layout still fails, and says which headers it wanted.
  expect_error(read_animalta(detailed, detailed = FALSE), "headers")
})

test_that("a layout that is neither auto nor logical errors", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")

  expect_error(read_animalta(path, detailed = "yes"), "must be")
})

test_that("read_dataset reads a detailed export", {
  # The case that motivated #88: detect_source() identified the file
  # correctly, but the dispatcher had no way to pass `detailed = TRUE`.
  path <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )

  expect_equal(detect_source(path), "animalta")
  expect_no_error(result <- read_dataset(path))
  expect_s3_class(result, "anipoint")
})

# ---- Time ---------------------------------------------------------------

test_that("time is AnimalTA's Time column, in seconds", {
  # AnimalTA writes seconds, so leaving unit_time at its default of frames
  # misread every time downstream.
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  raw <- utils::read.csv(path, sep = ";")
  result <- read_animalta(path)

  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_equal(sort(unique(result$time)), raw$Time)
})

test_that("the variable-individuals layout keeps its time in seconds too", {
  path <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )
  result <- read_animalta(path)

  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_equal(result$time, round(0:18 / 30, 2))
})

# ---- Sampling rate ------------------------------------------------------

test_that("the rate is read from the Frame and Time columns", {
  raw <- read_animalta(
    testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  )
  variable <- read_animalta(
    testthat::test_path("data/animalta/variable_individuals_single_arena.csv")
  )

  expect_identical(anicore::get_metadata(raw, "sampling_rate"), 30)
  expect_identical(anicore::get_metadata(variable, "sampling_rate"), 30)
  expect_false("frame" %in% names(raw))
  expect_false("frame" %in% names(variable))
})

test_that("a Time column that disagrees with Frame leaves the rate NA", {
  # As the variable-individuals fixture was before it was repaired: a
  # spreadsheet had rewritten 0.1 as 00.01, so Time no longer followed Frame.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "Frame;Time;Arena;Ind;X;Y",
      "0.0;0.0;0;0;514;133",
      "1.0;0.03;0;0;518;132",
      "2.0;0.07;0;0;518;133",
      "3.0;0.01;0;0;519;132",
      "4.0;0.13;0;0;521;130"
    ),
    path
  )

  data <- read_animalta(path)
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
})
