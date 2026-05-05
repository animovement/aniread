# Tests for read_movement()
#
# - Returns an aniframe
# - Has required columns (individual, keypoint, time, x, y)
# - Column types are correct
# - Metadata is populated
# - Errors on invalid file path
# - Errors on wrong file extension

# Wrap the sample-data download so a failure (offline, slow GIN server,
# etc.) doesn't error out the whole test file — tests that need the file
# skip individually below.
path <- tryCatch(
  get_sample_data("movement", cache_dir = test_cache_dir(), quiet = TRUE),
  error = function(e) NULL
)

test_that("read_movement returns an aniframe", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  expect_s3_class(result, "aniframe")
})

test_that("read_movement has required columns", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  expect_true(all(
    c("individual", "keypoint", "time", "x", "y") %in% names(result)
  ))
})

test_that("read_movement column types are correct", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  expect_type(result$time, "double")
  expect_type(result$x, "double")
  expect_type(result$y, "double")
})

test_that("read_movement populates metadata", {
  skip_if(is.null(path), "movement sample download unavailable")
  result <- read_movement(path)
  meta <- aniframe::get_metadata(result)

  expect_false(is.null(meta$source))
  expect_false(is.null(meta$filename))
  expect_false(is.null(meta$unit_time))
  expect_false(is.null(meta$unit_space))
  expect_false(is.null(meta$sampling_rate))
})

test_that("read_movement errors on invalid path", {
  expect_error(read_movement("nonexistent_file.h5"))
})

test_that("read_movement errors on wrong file extension", {
  tmp <- tempfile(fileext = ".csv")
  file.create(tmp)
  on.exit(unlink(tmp))

  expect_error(read_movement(tmp))
})
