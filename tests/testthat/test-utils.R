# Test list:
# - get_file_ext(): basic extensions, multiple dots, no extension
# - get_individual_from_path(): single underscore, multiple underscores, no underscore
# - reflect_to_bottom_left(): flip with supplied `video_height`,
#   fallback to max(y), no-op when y is all NA

test_that("get_file_ext() extracts file extensions correctly", {
  expect_equal(get_file_ext("file.csv"), "csv")
  expect_equal(get_file_ext("data.tar.gz"), "gz")
  expect_equal(get_file_ext("path/to/file.txt"), "txt")
  expect_equal(get_file_ext("no_extension"), "no_extension")
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

  expect_equal(anicore::get_axis_directions(result)[["y"]], "up")
  expect_equal(anicore::get_axis_extents(result), c(y = 100))
  expect_equal(result$y, c(90, 80, 70))
})

test_that("reflect_to_bottom_left falls back to the furthest point when video_height is NULL", {
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

  expect_equal(anicore::get_axis_directions(result)[["y"]], "up")
  expect_equal(anicore::get_axis_extents(result), c(y = 30))
  expect_equal(result$y, c(20, 10, 0))
})

test_that("reflect_to_bottom_left leaves the data alone when y is all NA", {
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

  expect_equal(anicore::get_axis_directions(result)[["y"]], "down")
  expect_length(anicore::get_axis_extents(result), 0)
  expect_true(all(is.na(result$y)))
})

test_that("reflect_to_bottom_left declares the side the camera was on", {
  # `back` is the default for an image plane rather than something the file
  # says, and it is what the handedness is read from. A recording made
  # through a glass floor overrides it.
  data <- dplyr::tibble(
    individual = factor("ind1"),
    keypoint = factor("centroid"),
    time = 1:3,
    x = c(1, 2, 3),
    y = c(10, 20, 30)
  ) |>
    anicore::as_aniframe()

  result <- reflect_to_bottom_left(data, video_height = 100)

  expect_equal(anicore::get_axis_directions(result)[["z"]], "back")
  expect_equal(anicore::get_handedness(result), "right")
  expect_equal(anicore::get_angle_direction(result), "counter_clockwise")

  below <- anicore::set_axis_directions(result, c(z = "forward"))
  expect_equal(anicore::get_angle_direction(below), "clockwise")
})

test_that("there is no extent to measure without a vertical axis", {
  # A frame with no `y` role has nothing to reflect around, so the readers
  # leave the data as it arrived rather than inventing a height.
  polar <- dplyr::tibble(
    individual = factor("ind1"),
    keypoint = factor("centroid"),
    time = 1:3,
    rho = c(1, 2, 3),
    phi = c(0, 1, 2)
  ) |>
    anicore::as_aniframe()

  expect_null(compute_y_extent(polar))
})
