#' @keywords internal
check_rhdf5 <- function() {
  # rhdf5 is on Bioconductor, not CRAN. Install it from Bioconductor's
  # r-universe, so a user needs neither BiocManager nor a Bioconductor repo
  # set up; its dependencies come from the user's own repos.
  rlang::check_installed(
    "rhdf5",
    reason = "for reading HDF5 files,",
    action = function(...) {
      utils::install.packages(
        "rhdf5",
        repos = c("https://bioc.r-universe.dev", getOption("repos"))
      )
    }
  )
}

#' @keywords internal
check_arrow <- function() {
  rlang::check_installed(
    "arrow",
    reason = "for reading and writing Parquet files,"
  )
}

#' @keywords internal
check_xml2 <- function() {
  rlang::check_installed("xml2", reason = "for reading TrackMate files,")
}

#' @keywords internal
check_c3dr <- function() {
  rlang::check_installed("c3dr", reason = "for reading C3D files,")
}
