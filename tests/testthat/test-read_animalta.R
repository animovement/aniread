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
  expect_s3_class(result, "aniframe")
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
  expect_s3_class(result, "aniframe")
})
