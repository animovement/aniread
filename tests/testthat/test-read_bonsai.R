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
  # Without y or a recorded frame height there is nothing to reflect around.
  raw <- raw[!grepl("Size\\.(Width|Height)$", names(raw))]
  utils::write.csv(raw, path, row.names = FALSE)
  result <- suppressWarnings(read_bonsai(path))
  expect_equal(result$orientation_axis[1], raw$Item3.Value.Orientation[1])
})

test_that("read_bonsai gives time in seconds and leaves the rate unset", {
  # Bonsai's Timestamp is when the software received each frame, so the
  # intervals jitter and state no rate; the elapsed seconds are kept.
  path <- system.file("extdata", "bonsai.csv", package = "aniread")
  raw <- vroom::vroom(path, delim = ",", show_col_types = FALSE)
  result <- read_bonsai(path)

  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))
  expect_equal(
    result$time,
    as.numeric(raw$Item3.Timestamp - min(raw$Item3.Timestamp))
  )
})

test_that("read_bonsai reflects y around the frame the images record", {
  # Every image item in the file is 1920 x 1080; the largest y is only 826,
  # so reflecting around it put every y 254 px off.
  path <- testthat::test_path("data/bonsai/LI850.csv")
  raw <- utils::read.csv(path)
  result <- read_bonsai(path)

  expect_equal(
    anicore::get_metadata(result, "axis_extents"),
    c(x = 1920, y = 1080)
  )
  expect_equal(result$y, 1080 - raw$Item3.Value.Centroid.Y)
  expect_equal(result$x, raw$Item3.Value.Centroid.X)

  # An explicit video_height still wins.
  result <- read_bonsai(path, video_height = 1200)
  expect_equal(result$y, 1200 - raw$Item3.Value.Centroid.Y)
})

test_that("read_bonsai falls back to the largest y when the images disagree", {
  path <- withr::local_tempfile(fileext = ".csv")
  raw <- utils::read.csv(system.file(
    "extdata",
    "bonsai.csv",
    package = "aniread"
  ))
  raw$Item2.Size.Height <- 540
  raw$Item2.Size.Width <- 960
  utils::write.csv(raw, path, row.names = FALSE)
  result <- read_bonsai(path)

  extent <- max(raw$Item3.Value.Centroid.Y)
  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = extent))
  expect_equal(result$y, extent - raw$Item3.Value.Centroid.Y)
})

test_that("bonsai_frame_size() needs one positive size", {
  expect_identical(
    bonsai_frame_size(data.frame(Item1.Size.Width = c(640, NA))),
    list(width = 640, height = NULL)
  )
  expect_identical(
    bonsai_frame_size(data.frame(Item1.Size.Height = c("a", "a"))),
    list(width = NULL, height = NULL)
  )
  expect_identical(
    bonsai_frame_size(data.frame(x = 1)),
    list(width = NULL, height = NULL)
  )
})
