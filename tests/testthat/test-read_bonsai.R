test_that("read_bonsai keeps the blob orientation as an axial angle turned with y", {
  path <- system.file("extdata", "bonsai.csv", package = "aniread")
  raw <- utils::read.csv(path)
  result <- read_bonsai(path)
  expect_true("orientation_axis" %in% names(result))
  expect_length(anicore::get_variables(result, "where", "orientation"), 0)
  expect_equal(result$orientation_axis[1], -raw$Item3.Value.Orientation[1])
  expect_true(all(
    result$orientation_axis > -pi / 2 & result$orientation_axis <= pi / 2,
    na.rm = TRUE
  ))
})

test_that("an axial angle at -pi/2 after turning is brought back to pi/2", {
  path <- withr::local_tempfile(fileext = ".csv")
  raw <- utils::read.csv(system.file(
    "extdata",
    "bonsai.csv",
    package = "aniread"
  ))
  raw$Item3.Value.Orientation[1] <- pi / 2
  utils::write.csv(raw, path, row.names = FALSE)
  expect_equal(read_bonsai(path)$orientation_axis[1], pi / 2)
})

test_that("read_bonsai leaves the angle alone when y is not reflected", {
  path <- withr::local_tempfile(fileext = ".csv")
  raw <- utils::read.csv(system.file(
    "extdata",
    "bonsai.csv",
    package = "aniread"
  ))
  raw$Item3.Value.Centroid.Y <- NA
  utils::write.csv(raw, path, row.names = FALSE)
  result <- suppressWarnings(read_bonsai(path))
  expect_equal(result$orientation_axis[1], raw$Item3.Value.Orientation[1])
})
