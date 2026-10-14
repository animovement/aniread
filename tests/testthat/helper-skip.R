# Helpers for skipping tests that depend on the network.
#
# Used to keep CRAN-like environments (r-universe) and offline test
# runs from failing on transient download problems (slow GIN server,
# captive portals, no internet, etc.).

skip_if_no_network <- function() {
  testthat::skip_on_cran()
  # `skip_if_offline()` needs curl; without it the network can't be checked,
  # so skip rather than attempt the download.
  testthat::skip_if_not_installed("curl")
  testthat::skip_if_offline()
}
