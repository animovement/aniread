# Tests:
# - Creates track_id from all grouping columns
# - Creates track_id from subset of grouping columns
# - Includes z column when present
# - Excludes z column when absent
# - Renames time to t
# - Writes correct column order to file

test_that("creates track_id from all grouping columns", {
  data <- aniframe::aniframe(
    session = c(1, 1, 2, 2),
    trial = c(1, 1, 1, 1),
    model = c("a", "a", "a", "a"),
    individual = c(1, 1, 2, 2),
    keypoint = c("nose", "nose", "nose", "nose"),
    time = c(0, 1, 0, 1),
    x = c(10, 11, 20, 21),
    y = c(5, 6, 7, 8)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(unique(result$track_id), c(1, 2))
  expect_equal(nrow(result), 4)

  unlink(temp_file)
})

test_that("creates track_id from subset of grouping columns", {
  data <- aniframe::aniframe(
    individual = c(1, 1, 2, 2),
    keypoint = c("nose", "nose", "tail", "tail"),
    time = c(0, 1, 0, 1),
    x = c(10, 11, 20, 21),
    y = c(5, 6, 7, 8)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(unique(result$track_id), c(1, 2))

  unlink(temp_file)
})

test_that("includes z column when present", {
  data <- aniframe::aniframe(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6),
    z = c(2, 3)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_true("z" %in% names(result))
  expect_equal(result$z, c(2, 3))

  unlink(temp_file)
})

test_that("excludes z column when absent", {
  data <- aniframe::aniframe(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_false("z" %in% names(result))

  unlink(temp_file)
})

test_that("renames time to t", {
  data <- aniframe::aniframe(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_true("t" %in% names(result))
  expect_false("time" %in% names(result))
  expect_equal(result$t, c(0, 1))

  unlink(temp_file)
})


test_that("writes correct column order to file", {
  data <- aniframe::aniframe(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6),
    z = c(2, 3)
  )

  temp_file <- tempfile(fileext = ".csv")
  write_intracktive(data, temp_file, quiet = TRUE)

  result <- vroom::vroom(temp_file, show_col_types = FALSE)

  expect_equal(names(result), c("track_id", "t", "x", "y", "z"))

  unlink(temp_file)
})

test_that("errors when no grouping columns are present", {
  data <- dplyr::tibble(time = c(0, 1), x = c(10, 11), y = c(5, 6))
  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  expect_error(
    write_intracktive(data, temp_file, quiet = TRUE),
    "No grouping columns"
  )
})

test_that("emits a success message when not quiet", {
  data <- aniframe::aniframe(
    individual = c(1, 1),
    time = c(0, 1),
    x = c(10, 11),
    y = c(5, 6)
  )
  temp_file <- tempfile(fileext = ".csv")
  on.exit(unlink(temp_file), add = TRUE)
  expect_message(
    write_intracktive(data, temp_file, quiet = FALSE),
    "Wrote inTRACKtive CSV"
  )
})
