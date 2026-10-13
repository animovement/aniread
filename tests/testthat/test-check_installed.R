# Testing check_rhdf5(), check_arrow(), check_xml2() and check_c3dr()
# - Each asks rlang::check_installed() for its package, with a reason
# - rhdf5 installs from Bioconductor's r-universe, before the user's repos
# - The CRAN packages install the default way, from the user's repos

capture_check_installed <- function(env = parent.frame()) {
  captured <- new.env()
  local_mocked_bindings(
    check_installed = function(pkg, reason = NULL, action = NULL, ...) {
      captured$pkg <- pkg
      captured$reason <- reason
      captured$action <- action
      invisible()
    },
    .package = "rlang",
    .env = env
  )
  captured
}

test_that("check_rhdf5 installs rhdf5 from Bioconductor's r-universe", {
  captured <- capture_check_installed()
  install_args <- NULL
  local_mocked_bindings(
    install.packages = function(pkgs, repos, ...) {
      install_args <<- list(pkgs = pkgs, repos = repos)
    },
    .package = "utils"
  )
  withr::local_options(repos = c(CRAN = "https://cran.example.org"))

  check_rhdf5()
  captured$action()

  expect_equal(captured$pkg, "rhdf5")
  expect_match(captured$reason, "for reading HDF5 files")
  expect_equal(install_args$pkgs, "rhdf5")
  expect_equal(
    unname(install_args$repos),
    c("https://bioc.r-universe.dev", "https://cran.example.org")
  )
})

test_that("check_arrow, check_xml2 and check_c3dr install from CRAN", {
  helpers <- list(
    arrow = list(check_arrow, "for reading and writing Parquet files"),
    xml2 = list(check_xml2, "for reading TrackMate files"),
    c3dr = list(check_c3dr, "for reading C3D files")
  )

  for (pkg in names(helpers)) {
    captured <- capture_check_installed()
    helpers[[pkg]][[1]]()

    expect_equal(captured$pkg, pkg)
    expect_match(captured$reason, helpers[[pkg]][[2]])
    # No custom action: rlang installs from the user's own repos
    expect_null(captured$action)
  }
})
