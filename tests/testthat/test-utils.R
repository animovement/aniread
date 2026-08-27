# Test list:
# - get_file_ext(): basic extensions, multiple dots, no extension
# - convert_nan_to_na(): NaN conversion, mixed types, no NaN values
# - get_individual_from_path(): single underscore, multiple underscores, no underscore
# - reflect_to_bottom_left(): flip with supplied `video_height`,
#   fallback to max(y), no-op when y is all NA

test_that("get_file_ext() extracts file extensions correctly", {
  expect_equal(get_file_ext("file.csv"), "csv")
  expect_equal(get_file_ext("data.tar.gz"), "gz")
  expect_equal(get_file_ext("path/to/file.txt"), "txt")
  expect_equal(get_file_ext("no_extension"), "no_extension")
})

test_that("convert_nan_to_na() converts NaN to NA in numeric columns", {
  test_data <- data.frame(
    x = c(1, NaN, 3),
    y = c(NaN, 2, NaN),
    z = c("a", "b", "c")
  )

  result <- convert_nan_to_na(test_data)

  expect_true(is.na(result$x[2]))
  expect_true(is.na(result$y[1]))
  expect_true(is.na(result$y[3]))
  expect_false(is.na(result$x[1]))
  expect_equal(result$z, c("a", "b", "c"))
})

test_that("convert_nan_to_na() handles data without NaN", {
  test_data <- data.frame(x = c(1, 2, 3), y = c(4, 5, 6))
  result <- convert_nan_to_na(test_data)

  expect_equal(result, test_data)
})

test_that("get_individual_from_path() splits on last underscore", {
  expect_equal(
    get_individual_from_path("individual_123.csv"),
    c("individual", "123")
  )
  expect_equal(
    get_individual_from_path("path/to/subject_trial_01.txt"),
    c("subject_trial", "01")
  )
  expect_equal(
    get_individual_from_path("simple.csv"),
    "simple"
  )
})

test_that("reflect_to_bottom_left flips y around supplied video_height", {
  data <- dplyr::tibble(
    individual = factor("ind1"),
    keypoint = factor("centroid"),
    time = 1:3,
    x = c(1, 2, 3),
    y = c(10, 20, 30)
  ) |>
    anicore::as_aniframe()

  result <- reflect_to_bottom_left(data, video_height = 100)
  meta <- anicore::get_metadata(result)

  expect_equal(as.character(meta$origin), "bottom_left")
  expect_equal(meta$y_height, 100)
  expect_equal(result$y, c(90, 80, 70))
})

test_that("reflect_to_bottom_left falls back to max(y) when video_height is NULL", {
  data <- dplyr::tibble(
    individual = factor("ind1"),
    keypoint = factor("centroid"),
    time = 1:3,
    x = c(1, 2, 3),
    y = c(10, 20, 30)
  ) |>
    anicore::as_aniframe()

  result <- reflect_to_bottom_left(data, video_height = NULL)
  meta <- anicore::get_metadata(result)

  expect_equal(as.character(meta$origin), "bottom_left")
  expect_equal(meta$y_height, 30)
  expect_equal(result$y, c(20, 10, 0))
})

test_that("reflect_to_bottom_left leaves origin unchanged when y is all NA", {
  data <- dplyr::tibble(
    individual = factor("ind1"),
    keypoint = factor("centroid"),
    time = 1:3,
    x = c(1, 2, 3),
    y = as.numeric(c(NA, NA, NA))
  ) |>
    anicore::as_aniframe()

  result <- reflect_to_bottom_left(data, video_height = NULL)
  meta <- anicore::get_metadata(result)

  expect_equal(as.character(meta$origin), "top_left")
  expect_true(all(is.na(result$y)))
})
