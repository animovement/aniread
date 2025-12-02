# Tests for get_sample_data():
# - Downloads data for valid predefined sources
# - Downloads data with specific dataset parameter
# - Uses cached files when available
# - Creates cache directory if it doesn't exist
# - Fails with informative error for unsupported source
# - Fails with informative error for unsupported dataset
# - Fails when source is missing
# - Returns correct file paths for sources with datasets
# - Returns path as character string
# - Different sources download different files
# - Downloads data from custom URL
# - Extracts basename correctly from URL
# - Caches custom URL downloads
# - Handles URLs with complex paths
# - Distinguishes between URL and source name
# - list_datasets without source shows all sources
# - list_datasets with source shows datasets for that source
# - TRex returns vector of file paths for multi-file datasets
# - TRex returns single path for single-file dataset

test_that("get_sample_data downloads data for valid sources", {
  temp_cache <- tempfile()

  # Test a few different sources with their default datasets
  sources_to_test <- c("deeplabcut", "sleap", "fictrac")

  for (source in sources_to_test) {
    path <- get_sample_data(source, cache_dir = temp_cache, quiet = TRUE)

    expect_true(file.exists(path))
    expect_true(file.info(path)$size > 0)
  }

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data downloads data with specific dataset parameter", {
  temp_cache <- tempfile()

  # Test getting a non-default dataset
  path <- get_sample_data(
    "deeplabcut",
    dataset = "two-mice",
    cache_dir = temp_cache,
    quiet = TRUE
  )

  expect_true(file.exists(path))
  expect_match(basename(path), "deeplabcut_two-mice.csv")

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data uses cached files when available", {
  temp_cache <- tempfile()

  # First download
  path1 <- get_sample_data("deeplabcut", cache_dir = temp_cache, quiet = TRUE)
  first_mtime <- file.info(path1)$mtime

  # Small delay to ensure time difference would be detectable
  Sys.sleep(0.1)

  # Second call should use cached file
  path2 <- get_sample_data("deeplabcut", cache_dir = temp_cache, quiet = TRUE)
  second_mtime <- file.info(path2)$mtime

  expect_equal(path1, path2)
  expect_equal(first_mtime, second_mtime)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data creates cache directory if it doesn't exist", {
  temp_cache <- file.path(tempdir(), "nested", "cache", "dir")

  expect_false(dir.exists(temp_cache))

  path <- get_sample_data("deeplabcut", cache_dir = temp_cache, quiet = TRUE)

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
    "list_datasets = TRUE"
  )
})

test_that("get_sample_data fails with informative error for unsupported dataset", {
  expect_error(
    get_sample_data("deeplabcut", dataset = "invalid_dataset"),
    "not available"
  )

  expect_error(
    get_sample_data("deeplabcut", dataset = "invalid_dataset"),
    "Available datasets"
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

test_that("get_sample_data returns correct file paths for sources", {
  temp_cache <- tempfile()

  # Test default datasets for each source
  test_cases <- list(
    list(source = "animalta", pattern = "animalta"),
    list(source = "anipose", pattern = "anipose"),
    list(source = "bonsai", pattern = "bonsai"),
    list(source = "deeplabcut", pattern = "deeplabcut"),
    list(source = "fictrac", pattern = "fictrac"),
    list(source = "freemocap", pattern = "freemocap"),
    list(source = "idtracker", pattern = "idtracker"),
    list(source = "lightningpose", pattern = "lightningpose"),
    list(source = "sleap", pattern = "sleap")
  )

  for (test_case in test_cases) {
    path <- get_sample_data(
      test_case$source,
      cache_dir = temp_cache,
      quiet = TRUE
    )
    expect_match(basename(path), test_case$pattern, ignore.case = TRUE)
  }

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data returns path as character string", {
  temp_cache <- tempfile()

  path <- get_sample_data("deeplabcut", cache_dir = temp_cache, quiet = TRUE)

  expect_type(path, "character")
  expect_length(path, 1)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("different sources download different files", {
  temp_cache <- tempfile()

  path1 <- get_sample_data("deeplabcut", cache_dir = temp_cache, quiet = TRUE)
  path2 <- get_sample_data("sleap", cache_dir = temp_cache, quiet = TRUE)

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

test_that("get_sample_data downloads data from custom URL", {
  temp_cache <- tempfile()

  # Use a real URL from the movement-data repo
  custom_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/trex/beetle.csv"

  path <- get_sample_data(custom_url, cache_dir = temp_cache, quiet = TRUE)

  expect_true(file.exists(path))
  expect_true(file.info(path)$size > 0)
  expect_equal(basename(path), "beetle.csv")

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data extracts basename correctly from URL", {
  test_urls <- c(
    "https://example.com/data/tracking.csv",
    "https://raw.githubusercontent.com/user/repo/main/data/file.h5",
    "http://data.example.org/experiments/test_data.dat"
  )

  expected_basenames <- c(
    "tracking.csv",
    "file.h5",
    "test_data.dat"
  )

  for (i in seq_along(test_urls)) {
    actual_basename <- basename(test_urls[i])
    expect_equal(actual_basename, expected_basenames[i])
  }
})

test_that("get_sample_data caches custom URL downloads", {
  temp_cache <- tempfile()

  custom_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/trex/beetle.csv"

  # First download
  path1 <- get_sample_data(custom_url, cache_dir = temp_cache, quiet = TRUE)
  first_mtime <- file.info(path1)$mtime

  # Second call should use cached file
  path2 <- get_sample_data(custom_url, cache_dir = temp_cache, quiet = TRUE)
  second_mtime <- file.info(path2)$mtime

  expect_equal(path1, path2)
  expect_equal(first_mtime, second_mtime)
  expect_equal(basename(path1), "beetle.csv")

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data handles URLs with complex paths", {
  temp_cache <- tempfile()

  # URL with nested path structure
  complex_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/fictrac/fictrac_sample.dat"

  path <- get_sample_data(complex_url, cache_dir = temp_cache, quiet = TRUE)

  expect_true(file.exists(path))
  expect_equal(basename(path), "fictrac_sample.dat")
  expect_match(path, temp_cache, fixed = TRUE)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data distinguishes between URL and source name", {
  temp_cache <- tempfile()

  # Download using source name
  path1 <- get_sample_data("trex", cache_dir = temp_cache, quiet = TRUE)

  # Download using URL
  custom_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/bonsai/LI850.csv"
  path2 <- get_sample_data(custom_url, cache_dir = temp_cache, quiet = TRUE)

  expect_match(basename(path1), "trex")
  expect_match(basename(path2), "LI850.csv")
  expect_false(identical(path1, path2))

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("list_datasets without source shows all sources", {
  # Capture output
  output <- capture.output(
    result <- get_sample_data(list_datasets = TRUE),
    type = "message"
  )

  expect_null(result)
  expect_true(any(grepl("Available sources", output)))
})

test_that("list_datasets with source shows datasets for that source", {
  # Capture output
  output <- capture.output(
    result <- get_sample_data("deeplabcut", list_datasets = TRUE),
    type = "message"
  )

  expect_null(result)
  expect_true(any(grepl("deeplabcut", output)))
})

test_that("TRex returns vector of file paths for multi-file datasets", {
  temp_cache <- tempfile()

  # Get the five-locusts dataset which is a zip file
  paths <- get_sample_data(
    "trex",
    dataset = "five-locusts",
    cache_dir = temp_cache,
    quiet = TRUE
  )

  # Should return a vector of paths
  expect_type(paths, "character")
  expect_true(length(paths) > 1)

  # All paths should exist
  for (path in paths) {
    expect_true(file.exists(path))
  }

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("TRex returns single path for single-file dataset", {
  temp_cache <- tempfile()

  # Get the beetles dataset which is a single CSV
  path <- get_sample_data(
    "trex",
    dataset = "beetles",
    cache_dir = temp_cache,
    quiet = TRUE
  )

  # Should return a single path
  expect_type(path, "character")
  expect_length(path, 1)
  expect_true(file.exists(path))
  expect_match(basename(path), "trex_sample.csv")

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data handles binary files correctly", {
  temp_cache <- tempfile()

  # Test h5 file (binary)
  path_h5 <- get_sample_data("sleap", cache_dir = temp_cache, quiet = TRUE)
  expect_true(file.exists(path_h5))
  expect_true(file.info(path_h5)$size > 0)

  # Test dat file (binary)
  path_dat <- get_sample_data("fictrac", cache_dir = temp_cache, quiet = TRUE)
  expect_true(file.exists(path_dat))
  expect_true(file.info(path_dat)$size > 0)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})
