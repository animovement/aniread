# Tests for read_opticalflow
#
# - Reads CSV with expected headers
# - Reads CSV without headers (skips first 2 rows)
# - Renames columns based on col_dx, col_dy, col_time
# - Time conversion: POSIXt input zeros from start
# - Time conversion: character datetime input zeros from start
# - Time conversion: numeric seconds input zeros from start
# - Time conversion: numeric microseconds auto-detected and converted

test_that("read_opticalflow reads CSV with expected headers", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(
    data.frame(time = c(0, 1, 2), x = c(1, 2, 3), y = c(4, 5, 6)),
    path,
    row.names = FALSE
  )

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_s3_class(result, "data.frame")
  expect_named(result, c("time", "dx", "dy"))
  expect_equal(result$dx, c(1, 2, 3))
  expect_equal(result$dy, c(4, 5, 6))
})

test_that("read_opticalflow reads CSV without headers (skips first 2 rows)", {
  path <- withr::local_tempfile(fileext = ".csv")
  lines <- c(
    "Some metadata line",
    "Another metadata line",
    "x,y,time",
    "1,4,0",
    "2,5,1",
    "3,6,2"
  )
  writeLines(lines, path)

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_equal(result$dx, c(1, 2, 3))
  expect_equal(result$dy, c(4, 5, 6))
})

test_that("read_opticalflow renames columns based on parameters", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(
    data.frame(
      timestamp = c(0, 1, 2),
      delta_x = c(1, 2, 3),
      delta_y = c(4, 5, 6)
    ),
    path,
    row.names = FALSE
  )

  result <- read_opticalflow(
    path,
    col_time = "timestamp",
    col_dx = "delta_x",
    col_dy = "delta_y"
  )

  expect_named(result, c("time", "dx", "dy"))
  expect_equal(result$dx, c(1, 2, 3))
})

test_that("read_opticalflow converts POSIXt time and zeros from start", {
  path <- withr::local_tempfile(fileext = ".csv")
  times <- as.POSIXct(c(
    "2023-09-14 14:37:55",
    "2023-09-14 14:37:56",
    "2023-09-14 14:37:57"
  ))
  df <- data.frame(time = times, x = c(1, 2, 3), y = c(4, 5, 6))
  saveRDS(df, tmp_rds <- withr::local_tempfile(fileext = ".rds"))

  # vroom preserves POSIXct, so we need a different approach
  # Create a file that vroom will parse as POSIXct
  write.csv(
    data.frame(
      time = c(
        "2023-09-14 14:37:55",
        "2023-09-14 14:37:56",
        "2023-09-14 14:37:57"
      ),
      x = c(1, 2, 3),
      y = c(4, 5, 6)
    ),
    path,
    row.names = FALSE
  )

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_type(result$time, "double")
  expect_equal(result$time[1], 0)
  expect_equal(result$time[2], 1)
  expect_equal(result$time[3], 2)
})

test_that("read_opticalflow converts character datetime and zeros from start", {
  path <- withr::local_tempfile(fileext = ".csv")
  # Quote the times to ensure they're read as character
  lines <- c(
    'time,x,y',
    '"2023-09-14 14:37:55",1,4',
    '"2023-09-14 14:37:56",2,5',
    '"2023-09-14 14:37:57",3,6'
  )
  writeLines(lines, path)

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_type(result$time, "double")
  expect_equal(result$time[1], 0)
  expect_equal(diff(result$time), c(1, 1))
})

test_that("read_opticalflow handles numeric seconds and zeros from start", {
  path <- withr::local_tempfile(fileext = ".csv")
  write.csv(
    data.frame(time = c(100.0, 100.5, 101.0), x = c(1, 2, 3), y = c(4, 5, 6)),
    path,
    row.names = FALSE
  )

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_equal(result$time[1], 0)
  expect_equal(result$time[2], 0.5)
  expect_equal(result$time[3], 1.0)
})

test_that("read_opticalflow auto-detects microseconds and converts to seconds", {
  path <- withr::local_tempfile(fileext = ".csv")
  # 60Hz data: ~16667 microseconds between readings
  write.csv(
    data.frame(
      time = c(1684510755, 1684527395, 1684544035),
      x = c(1, 2, 3),
      y = c(4, 5, 6)
    ),
    path,
    row.names = FALSE
  )

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_equal(result$time[1], 0)
  # Differences should be in seconds (~0.0166)
  expected_diff <- (1684527395 - 1684510755) / 1e6
  expect_equal(result$time[2], expected_diff)
})

test_that("read_opticalflow keeps numeric seconds as-is when not microseconds", {
  path <- withr::local_tempfile(fileext = ".csv")
  # Small differences suggest already in seconds
  write.csv(
    data.frame(time = c(0.000, 0.016, 0.033), x = c(1, 2, 3), y = c(4, 5, 6)),
    path,
    row.names = FALSE
  )

  result <- read_opticalflow(
    path,
    col_time = "time",
    col_dx = "x",
    col_dy = "y"
  )

  expect_equal(result$time[1], 0)
  expect_equal(result$time[2], 0.016, tolerance = 1e-6)
  expect_equal(result$time[3], 0.033, tolerance = 1e-6)
})
