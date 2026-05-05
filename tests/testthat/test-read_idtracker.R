# Tests for read_idtracker
#
# - Reads CSV exports that use the legacy `seconds` time column
# - Reads CSV exports that use the newer `time` time column (#60)
# - Probabilities CSV with either column name joins correctly

test_that("read_idtracker reads CSV with legacy `seconds` column", {
  trajectories <- test_path(
    "data/idtrackerai/trajectories_csv",
    "trajectories.csv"
  )
  probabilities <- test_path(
    "data/idtrackerai/trajectories_csv",
    "id_probabilities.csv"
  )

  result <- read_idtracker(
    trajectories,
    path_probabilities = probabilities
  )

  expect_s3_class(result, "aniframe")
  expect_true(all(
    c("time", "individual", "x", "y", "confidence") %in% names(result)
  ))
  expect_true(is.numeric(result$time))
})

test_that("read_idtracker reads CSV with renamed `time` column", {
  # Synthesise a tiny CSV in the newer format where idtracker.ai renamed
  # the leading column from `seconds` to `time` (issue #60).
  trajectories <- tempfile(fileext = ".csv")
  probabilities <- tempfile(fileext = ".csv")
  on.exit(unlink(c(trajectories, probabilities)), add = TRUE)

  writeLines(
    c(
      "time,x1,y1,x2,y2",
      "0.000,10.0,20.0,30.0,40.0",
      "0.036,11.0,21.0,31.0,41.0"
    ),
    trajectories
  )
  writeLines(
    c(
      "time,id_probabilities1,id_probabilities2",
      "0.000,1.0,1.0",
      "0.036,1.0,1.0"
    ),
    probabilities
  )

  result <- read_idtracker(
    trajectories,
    path_probabilities = probabilities
  )

  expect_s3_class(result, "aniframe")
  expect_true(all(
    c("time", "individual", "x", "y", "confidence") %in% names(result)
  ))
  expect_equal(sort(unique(result$time)), c(0.000, 0.036))
  expect_setequal(as.character(unique(result$individual)), c("1", "2"))
})
