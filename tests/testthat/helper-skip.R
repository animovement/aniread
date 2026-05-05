# Helpers for skipping tests that depend on the network.
#
# Used to keep CRAN-like environments (r-universe) and offline test
# runs from failing on transient download problems (slow GIN server,
# captive portals, no internet, etc.).

skip_if_no_network <- function() {
  testthat::skip_on_cran()
  # `skip_if_offline()` requires the `curl` package; degrade gracefully
  # when it isn't installed so the helper itself never hard-errors.
  if (requireNamespace("curl", quietly = TRUE)) {
    testthat::skip_if_offline()
  }
}
