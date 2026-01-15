# Testing check_rhdf5() and check_arrow()
# - Functions call rlang::check_installed with correct arguments
# - Custom action installs from correct repositories
# - Correct reason messages are provided

test_that("check_rhdf5 works and calls correct functions", {
  captured_args <- NULL

  local_mocked_bindings(
    check_installed = function(pkg, reason, action) {
      captured_args <<- list(pkg = pkg, reason = reason, action = action)
      # Actually execute the action to get coverage
      action()
    },
    .package = "rlang"
  )

  install_args <- NULL
  local_mocked_bindings(
    install.packages = function(pkgs, repos, ...) {
      install_args <<- list(pkgs = pkgs, repos = repos)
    },
    .package = "utils"
  )

  check_rhdf5()

  expect_equal(captured_args$pkg, "rhdf5")
  expect_match(captured_args$reason, "for reading HDF5 files")
  expect_type(captured_args$action, "closure")

  expect_equal(install_args$pkgs, "rhdf5")
  expect_equal(
    install_args$repos,
    c('https://bioc.r-universe.dev', 'https://cloud.r-project.org')
  )
})

test_that("check_arrow works and calls correct functions", {
  captured_args <- NULL

  local_mocked_bindings(
    check_installed = function(pkg, reason, action) {
      captured_args <<- list(pkg = pkg, reason = reason, action = action)
      # Actually execute the action to get coverage
      action()
    },
    .package = "rlang"
  )

  install_args <- NULL
  local_mocked_bindings(
    install.packages = function(pkgs, repos, ...) {
      install_args <<- list(pkgs = pkgs, repos = repos)
    },
    .package = "utils"
  )

  check_arrow()

  expect_equal(captured_args$pkg, "arrow")
  expect_match(
    captured_args$reason,
    "for reading and writing Parquet files"
  )
  expect_type(captured_args$action, "closure")

  expect_equal(install_args$pkgs, "arrow")
  expect_equal(
    install_args$repos,
    c('https://animovement.r-universe.dev', 'https://cloud.r-project.org')
  )
})

test_that("check_xml2 works and calls correct functions", {
  captured_args <- NULL

  local_mocked_bindings(
    check_installed = function(pkg, reason, action) {
      captured_args <<- list(pkg = pkg, reason = reason, action = action)
      # Actually execute the action to get coverage
      action()
    },
    .package = "rlang"
  )

  install_args <- NULL
  local_mocked_bindings(
    install.packages = function(pkgs, repos, ...) {
      install_args <<- list(pkgs = pkgs, repos = repos)
    },
    .package = "utils"
  )

  check_xml2()

  expect_equal(captured_args$pkg, "xml2")
  expect_match(
    captured_args$reason,
    "for reading TrackMate files"
  )
  expect_type(captured_args$action, "closure")

  expect_equal(install_args$pkgs, "xml2")
  expect_equal(
    install_args$repos,
    c('https://animovement.r-universe.dev', 'https://cloud.r-project.org')
  )
})

test_that("check_c3dr works and calls correct functions", {
  captured_args <- NULL

  local_mocked_bindings(
    check_installed = function(pkg, reason, action) {
      captured_args <<- list(pkg = pkg, reason = reason, action = action)
      # Actually execute the action to get coverage
      action()
    },
    .package = "rlang"
  )

  install_args <- NULL
  local_mocked_bindings(
    install.packages = function(pkgs, repos, ...) {
      install_args <<- list(pkgs = pkgs, repos = repos)
    },
    .package = "utils"
  )

  check_c3dr()

  expect_equal(captured_args$pkg, "c3dr")
  expect_match(
    captured_args$reason,
    "for reading C3D files"
  )
  expect_type(captured_args$action, "closure")

  expect_equal(install_args$pkgs, "c3dr")
  expect_equal(
    install_args$repos,
    c('https://animovement.r-universe.dev', 'https://cloud.r-project.org')
  )
})
