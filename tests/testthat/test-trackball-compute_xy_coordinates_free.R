# Tests for compute_xy_coordinates_free
#
# - Renames time_group to time
# - Renames y_1 to dx and y_2 to dy
# - Calculates x as cumulative sum of dx
# - Calculates y as cumulative sum of dy
# - Output has expected columns

test_that("compute_xy_coordinates_free renames columns correctly", {
  data <- data.frame(
    time_group = c(0, 1, 2),
    x_1 = c(1, 2, 3),
    y_1 = c(10, 20, 30),
    x_2 = c(4, 5, 6),
    y_2 = c(40, 50, 60)
  )

  result <- compute_xy_coordinates_free(data)

  expect_true("time" %in% names(result))
  expect_true("dx" %in% names(result))
  expect_true("dy" %in% names(result))
  expect_false("time_group" %in% names(result))
})

test_that("compute_xy_coordinates_free uses y_1 as dx and y_2 as dy", {
  data <- data.frame(
    time_group = c(0, 1, 2),
    x_1 = c(100, 200, 300),
    y_1 = c(1, 2, 3),
    x_2 = c(400, 500, 600),
    y_2 = c(4, 5, 6)
  )

  result <- compute_xy_coordinates_free(data)

  expect_equal(result$dx, c(1, 2, 3))
  expect_equal(result$dy, c(4, 5, 6))
})

test_that("compute_xy_coordinates_free calculates x as cumsum of dx", {
  data <- data.frame(
    time_group = c(0, 1, 2, 3),
    x_1 = 0,
    y_1 = c(10, 20, 30, 40),
    x_2 = 0,
    y_2 = 0
  )

  result <- compute_xy_coordinates_free(data)

  expect_equal(result$x, cumsum(c(10, 20, 30, 40)))
  expect_equal(result$x, c(10, 30, 60, 100))
})

test_that("compute_xy_coordinates_free calculates y as cumsum of dy", {
  data <- data.frame(
    time_group = c(0, 1, 2, 3),
    x_1 = 0,
    y_1 = 0,
    x_2 = 0,
    y_2 = c(5, 10, 15, 20)
  )

  result <- compute_xy_coordinates_free(data)

  expect_equal(result$y, cumsum(c(5, 10, 15, 20)))
  expect_equal(result$y, c(5, 15, 30, 50))
})

test_that("compute_xy_coordinates_free handles negative values", {
  data <- data.frame(
    time_group = c(0, 1, 2, 3),
    x_1 = 0,
    y_1 = c(10, -5, 20, -10),
    x_2 = 0,
    y_2 = c(-5, 10, -15, 20)
  )

  result <- compute_xy_coordinates_free(data)

  expect_equal(result$x, c(10, 5, 25, 15))
  expect_equal(result$y, c(-5, 5, -10, 10))
})

test_that("compute_xy_coordinates_free preserves time values", {
  data <- data.frame(
    time_group = c(0, 1, 2, 3),
    x_1 = 0,
    y_1 = 1,
    x_2 = 0,
    y_2 = 1
  )

  result <- compute_xy_coordinates_free(data)

  expect_equal(result$time, c(0, 1, 2, 3))
})
