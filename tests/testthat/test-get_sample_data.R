test_that("get_sample_data downloads data for valid sources", {
  # Create a temporary cache directory for testing
  temp_cache <- tempfile()

  # Test a few different sources
  sources_to_test <- c("deeplabcut", "sleap", "fictrac")

  for (source in sources_to_test) {
    path <- get_sample_data(source, cache_dir = temp_cache)

    expect_true(file.exists(path))
    expect_true(file.info(path)$size > 0)
    expect_match(path, source, ignore.case = TRUE)
  }

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data uses cached files when available", {
  temp_cache <- tempfile()

  # First download
  path1 <- get_sample_data("deeplabcut", cache_dir = temp_cache)
  first_mtime <- file.info(path1)$mtime

  # Small delay to ensure time difference would be detectable
  Sys.sleep(1.1)

  # Second call should use cached file
  path2 <- get_sample_data("deeplabcut", cache_dir = temp_cache)
  second_mtime <- file.info(path2)$mtime

  expect_equal(path1, path2)
  expect_equal(first_mtime, second_mtime)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data creates cache directory if it doesn't exist", {
  temp_cache <- file.path(tempdir(), "nested", "cache", "dir")

  expect_false(dir.exists(temp_cache))

  path <- get_sample_data("deeplabcut", cache_dir = temp_cache)

  expect_true(dir.exists(temp_cache))
  expect_true(file.exists(path))

  # Cleanup
  unlink(file.path(tempdir(), "nested"), recursive = TRUE)
})

test_that("get_sample_data fails with informative error for unsupported source", {
  expect_error(
    get_sample_data("invalid_source"),
    "not supported"
  )

  expect_error(
    get_sample_data("invalid_source"),
    "Currently supported sources"
  )
})

test_that("get_sample_data fails when source is missing", {
  expect_error(
    get_sample_data(),
    "Must specify"
  )

  expect_error(
    get_sample_data(),
    "source"
  )
})

test_that("get_sample_data returns correct file paths for all sources", {
  temp_cache <- tempfile()

  expected_files <- list(
    animalta = "animalta_sample.csv",
    anipose = "anipose_sample.csv",
    bonsai = "bonsai_sample.csv",
    deeplabcut = "deeplabcut_sample.csv",
    fictrac = "fictrac_sample.dat",
    freemocap = "freemocap_sample.csv",
    idtrackerai = "idtracker_sample.h5",
    lightningpose = "lightningpose_sample.csv",
    sleap = "sleap_sample.h5",
    trex = "trex_sample.csv"
  )

  for (source in names(expected_files)) {
    path <- get_sample_data(source, cache_dir = temp_cache)
    expect_match(basename(path), expected_files[[source]], fixed = TRUE)
  }

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data returns path as character string", {
  temp_cache <- tempfile()

  path <- get_sample_data("deeplabcut", cache_dir = temp_cache)

  expect_type(path, "character")
  expect_length(path, 1)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("different sources download different files", {
  temp_cache <- tempfile()

  path1 <- get_sample_data("deeplabcut", cache_dir = temp_cache)
  path2 <- get_sample_data("sleap", cache_dir = temp_cache)

  expect_false(identical(path1, path2))
  expect_true(file.exists(path1))
  expect_true(file.exists(path2))

  # Files should have different sizes (different data)
  size1 <- file.info(path1)$size
  size2 <- file.info(path2)$size
  expect_false(identical(size1, size2))

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})
