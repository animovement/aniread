#' @keywords internal
check_rhdf5 <- function() {
  # Check that rhdf5 is installed
  rlang::check_installed(
    "rhdf5",
    reason = "for reading HDF5 files,",
    action = function(...) {
      utils::install.packages(
        'rhdf5',
        repos = c(
          'https://animovement.r-universe.dev',
          'https://cloud.r-project.org'
        )
      )
    }
  )
}

#' @keywords internal
check_arrow <- function() {
  # Check that arrow is installed
  rlang::check_installed(
    "arrow",
    reason = "for using the reading and writing Parquet files,",
    action = function(...) {
      utils::install.packages(
        'arrow',
        repos = c(
          'https://animovement.r-universe.dev',
          'https://cloud.r-project.org'
        )
      )
    }
  )
}

#' @keywords internal
check_xml2 <- function() {
  # Check that xml2 is installed
  rlang::check_installed(
    "xml2",
    reason = "for using the reading TrackMate files,",
    action = function(...) {
      utils::install.packages(
        'xml2',
        repos = c(
          'https://animovement.r-universe.dev',
          'https://cloud.r-project.org'
        )
      )
    }
  )
}
