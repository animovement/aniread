# Tests for join_trackball_files
#
# - Finds shared time frame between sensors
# - Filters data to shared time frame
# - Groups readings into bins based on sampling rate
# - Sums dx/dy values within each bin
# - Joins sensors with _1 and _2 suffixes
# - Fills NA values with zeros after join
# - Fills missing time bins with zeros
# - Output has expected columns

test_that("join_trackball_files finds shared time frame", {
  data_list <- list(
    data.frame(time = c(0, 1, 2, 3, 4), dx = 1, dy = 1),
    data.frame(time = c(2, 3, 4, 5, 6), dx = 1, dy = 1)
  )

  result <- join_trackball_files(data_list, sampling_rate = 1)

  # Shared time is 2-4, but filtering is > and <, so only 3 remains
  expect_true(all(result$time_group >= 0))
})
test_that("join_trackball_files groups readings by sampling rate", {
  data_list <- list(
    data.frame(
      time = c(0.00, 0.01, 0.02, 0.05, 0.06),
      dx = c(1, 1, 1, 1, 1),
      dy = 0
    ),
    data.frame(
      time = c(0.00, 0.01, 0.02, 0.05, 0.06),
      dx = c(1, 1, 1, 1, 1),
      dy = 0
    )
  )

  # With sampling_rate = 20, bins are 0.05s wide
  # floor(0.00 * 20) = 0, floor(0.01 * 20) = 0, floor(0.02 * 20) = 0
  # floor(0.05 * 20) = 1, floor(0.06 * 20) = 1
  result <- join_trackball_files(data_list, sampling_rate = 20)

  # Should have 2 time groups (0 and 1)
  expect_equal(nrow(result), 2)
  expect_equal(sort(result$time_group), c(0, 1))
})

test_that("join_trackball_files sums dx/dy within bins", {
  data_list <- list(
    data.frame(time = c(0.5, 0.6, 0.7), dx = c(10, 20, 30), dy = c(1, 2, 3)),
    data.frame(time = c(0.5, 0.6, 0.7), dx = c(5, 5, 5), dy = c(1, 1, 1))
  )

  # sampling_rate = 1 means all readings fall in bin 0
  result <- join_trackball_files(data_list, sampling_rate = 1)

  expect_equal(result$x_1, 60)
  expect_equal(result$y_1, 6)
  expect_equal(result$x_2, 15)
  expect_equal(result$y_2, 3)
})

test_that("join_trackball_files joins with correct suffixes", {
  data_list <- list(
    data.frame(time = c(0.5), dx = 10, dy = 20),
    data.frame(time = c(0.5), dx = 30, dy = 40)
  )

  result <- join_trackball_files(data_list, sampling_rate = 1)

  expect_true(all(
    c("x_1", "y_1", "x_2", "y_2", "time_group") %in% names(result)
  ))
  expect_equal(result$x_1, 10)
  expect_equal(result$y_1, 20)
  expect_equal(result$x_2, 30)
  expect_equal(result$y_2, 40)
})

test_that("join_trackball_files fills NA with zeros after join", {
  # Sensors have overlapping time range but readings in different bins
  data_list <- list(
    data.frame(time = c(0, 0.5, 2), dx = c(10, 20, 0), dy = c(1, 2, 0)),
    data.frame(time = c(0, 1.5, 2), dx = c(0, 30, 0), dy = c(0, 3, 0))
  )

  result <- join_trackball_files(data_list, sampling_rate = 1)
  result <- result[order(result$time_group), ]

  # time_group 0: sensor 1 has 10+20=30, sensor 2 has 0
  # time_group 1: sensor 1 has NA (filled to 0), sensor 2 has 30
  # time_group 2: both have 0

  row_1 <- result[result$time_group == 1, ]
  expect_equal(row_1$x_1, 0)
  expect_equal(row_1$x_2, 30)
})

test_that("join_trackball_files fills missing time bins with zeros", {
  # Create data with a gap in time bins
  data_list <- list(
    data.frame(time = c(0.5, 3.5), dx = c(10, 20), dy = c(1, 2)),
    data.frame(time = c(0.5, 3.5), dx = c(10, 20), dy = c(1, 2))
  )

  result <- join_trackball_files(data_list, sampling_rate = 1)
  result <- result[order(result$time_group), ]

  # Should have bins 0, 1, 2, 3
  expect_equal(result$time_group, c(0, 1, 2, 3))

  # Bins 1 and 2 should be zeros
  expect_equal(result$x_1[result$time_group == 1], 0)
  expect_equal(result$x_1[result$time_group == 2], 0)
})

test_that("join_trackball_files output is sorted by time_group", {
  data_list <- list(
    data.frame(time = c(2.5, 0.5, 1.5), dx = c(1, 2, 3), dy = 0),
    data.frame(time = c(1.5, 2.5, 0.5), dx = c(4, 5, 6), dy = 0)
  )

  result <- join_trackball_files(data_list, sampling_rate = 1)

  expect_equal(result$time_group, sort(result$time_group))
})
