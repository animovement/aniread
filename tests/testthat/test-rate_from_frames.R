# rate_from_frames(): the rate a frame number and a time in seconds agree on

test_that("a whole-number rate is preferred when it fits every row", {
  # A 28 fps recording timed to 1 ms: the span alone gives 28.0002.
  frame <- 0:507
  time <- round(frame / 28, 3)
  expect_identical(rate_from_frames(frame, time), 28)
})

test_that("a rate that is not a whole number is kept as the span gives it", {
  frame <- 0:999
  time <- round(frame * 1001 / 30000, 3)
  rate <- rate_from_frames(frame, time)
  expect_equal(rate, 30000 / 1001, tolerance = 1e-4)
  expect_false(rate == 30)
})

test_that("the times must follow one rate", {
  # Software timestamps that jitter by more than their rounding.
  frame <- 0:9
  time <- c(0, 0.03, 0.07, 0.09, 0.14, 0.16, 0.2, 0.25, 0.27, 0.3)
  expect_true(is.na(rate_from_frames(frame, time)))
})

test_that("a frame repeated across individuals is one frame", {
  frame <- rep(0:18, each = 3)
  time <- round(frame / 30, 2)
  expect_identical(rate_from_frames(frame, time), 30)
})

test_that("keeping every k-th frame divides the rate by k", {
  frame <- seq(0, 36, by = 2)
  time <- round(frame / 30, 2)
  expect_identical(rate_from_frames(frame, time), 15)
})

test_that("missing values are left out", {
  frame <- c(0:9, NA)
  time <- c(round(0:9 / 25, 2), 1)
  expect_identical(rate_from_frames(frame, time), 25)
})

test_that("a rate below 1 Hz is not rounded to zero", {
  frame <- 0:4
  time <- frame * 2
  expect_identical(rate_from_frames(frame, time), 0.5)
})

test_that("fewer than two frames, or no time between them, give NA", {
  expect_true(is.na(rate_from_frames(c(1, 1), c(0, 0))))
  expect_true(is.na(rate_from_frames(numeric(), numeric())))
  expect_true(is.na(rate_from_frames(0:2, c(1, 1, 1))))
})

test_that("time_resolution() reads the rounding step from the values", {
  expect_identical(time_resolution(c(0, 1, 2)), 1)
  expect_identical(time_resolution(c(639.07, 639.1)), 0.01)
  expect_identical(time_resolution(c(0, 0.036)), 0.001)
  expect_identical(time_resolution(0:2 / 3), 1e-6)
})
