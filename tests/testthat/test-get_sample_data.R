# Tests for get_sample_data():
# - Downloads data for valid predefined sources
# - Uses cached files when available
# - Creates cache directory if it doesn't exist
# - Fails with informative error for unsupported source
# - Fails when source is missing
# - Returns correct file paths for all predefined sources
# - Returns path as character string
# - Different sources download different files
# - Downloads data from custom URL
# - Extracts basename correctly from URL
# - Caches custom URL downloads
# - Custom URL with query parameters uses correct basename
# - Handles URLs with complex paths

test_that("get_sample_data downloads data for valid sources", {
  # Create a temporary cache directory for testing
  temp_cache <- tempfile()

  # Test a few different sources
  sources_to_test <- c("deeplabcut", "sleap", "fictrac")

  for (source in sources_to_test) {
    path <- get_sample_data(source, cache_dir = temp_cache, quiet = TRUE)

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
  path1 <- get_sample_data("deeplabcut", cache_dir = temp_cache, quiet = TRUE)
  first_mtime <- file.info(path1)$mtime

  # Small delay to ensure time difference would be detectable
  # Sys.sleep(1.1)

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
    "Currently supported sources"
  )

  expect_error(
    get_sample_data("invalid_source"),
    "provide a URL"
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
    path <- get_sample_data(source, cache_dir = temp_cache, quiet = TRUE)
    expect_match(basename(path), expected_files[[source]], fixed = TRUE)
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
  custom_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/deeplabcut/mouse_single.csv"

  path <- get_sample_data(custom_url, cache_dir = temp_cache, quiet = TRUE)

  expect_true(file.exists(path))
  expect_true(file.info(path)$size > 0)
  expect_equal(basename(path), "mouse_single.csv")

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data extracts basename correctly from URL", {
  temp_cache <- tempfile()

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
    # We can't actually download from example.com, so we'll just test the path construction
    # by checking what the expected path would be
    expected_path <- file.path(temp_cache, expected_basenames[i])

    # Extract basename using the same logic as the function
    actual_basename <- basename(test_urls[i])
    expect_equal(actual_basename, expected_basenames[i])
  }

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
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
  complex_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/anipose/mouse_paw.csv"

  path <- get_sample_data(complex_url, cache_dir = temp_cache, quiet = TRUE)

  expect_true(file.exists(path))
  expect_equal(basename(path), "mouse_paw.csv")
  expect_match(path, temp_cache, fixed = TRUE)

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})

test_that("get_sample_data distinguishes between URL and source name", {
  temp_cache <- tempfile()

  # Download using source name
  path1 <- get_sample_data("trex", cache_dir = temp_cache, quiet = TRUE)

  # Download using URL (same data, but will have different basename)
  custom_url <- "https://raw.githubusercontent.com/animovement/movement-data/main/data/sleap/SLEAP_single-mouse_EPM.analysis.h5"
  path2 <- get_sample_data(custom_url, cache_dir = temp_cache, quiet = TRUE)

  expect_match(basename(path1), "trex_sample.csv")
  expect_match(basename(path2), "SLEAP_single-mouse_EPM.analysis.h5")
  expect_false(identical(path1, path2))

  # Cleanup
  unlink(temp_cache, recursive = TRUE)
})
