# Shared cache directory for sample-data downloads in tests.
#
# All tests that call `get_sample_data()` should pass `cache_dir =
# test_cache_dir()` so the same file isn't downloaded multiple times in
# one test run. Within a single R session this resolves to the same
# directory under `tempdir()`, so the second test that asks for the
# same source/dataset gets it from the local cache.
#
# Set the environment variable `ANIREAD_TEST_CACHE` to a persistent
# path (e.g. `tools::R_user_dir("aniread", "cache")`) to keep
# downloaded fixtures across R sessions during local development.

test_cache_dir <- function() {
  override <- Sys.getenv("ANIREAD_TEST_CACHE", "")
  cache <- if (nzchar(override)) {
    override
  } else {
    file.path(tempdir(), "aniread-test-cache")
  }
  dir.create(cache, recursive = TRUE, showWarnings = FALSE)
  cache
}
