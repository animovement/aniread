# Tests for resolve_column
#
# - Returns column name when given valid column name
# - Returns column name when given valid numeric index
# - Errors when column name doesn't exist
# - Errors when numeric index is too low
# - Errors when numeric index is too high

test_that("resolve_column returns column name when given valid column name", {
  data <- data.frame(time = 1, x = 2, y = 3)

  expect_equal(resolve_column(data, "time"), "time")
  expect_equal(resolve_column(data, "x"), "x")
  expect_equal(resolve_column(data, "y"), "y")
})

test_that("resolve_column returns column name when given valid numeric index", {
  data <- data.frame(time = 1, x = 2, y = 3)

  expect_equal(resolve_column(data, 1), "time")
  expect_equal(resolve_column(data, 2), "x")
  expect_equal(resolve_column(data, 3), "y")
})

test_that("resolve_column errors when column name doesn't exist", {
  data <- data.frame(time = 1, x = 2, y = 3)

  expect_error(resolve_column(data, "nonexistent"))
  expect_error(resolve_column(data, "timestamp"))
})

test_that("resolve_column errors when numeric index is too low", {
  data <- data.frame(time = 1, x = 2, y = 3)

  expect_error(resolve_column(data, 0))
  expect_error(resolve_column(data, -1))
})

test_that("resolve_column errors when numeric index is too high", {
  data <- data.frame(time = 1, x = 2, y = 3)

  expect_error(resolve_column(data, 4))
  expect_error(resolve_column(data, 100))
})
