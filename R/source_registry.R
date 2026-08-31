#' Registry of supported source software
#'
#' @description
#' The single place where a supported source software is declared. Each entry
#' pairs a source name with the reader that opens it, the file suffix(es) it
#' accepts, the detector that recognises it from the file itself, and any
#' optional package that detector needs.
#'
#' [get_supported_sources()] is a public view over this registry, and
#' [detect_source()] and [read_dataset()] drive off it, so a new format is
#' added here once rather than in three places.
#'
#' @section Entry fields:
#' \describe{
#'   \item{`source`}{Source software name, as accepted by the `source`
#'     argument of [read_dataset()].}
#'   \item{`reader`}{Name of the `aniread` function that reads it.}
#'   \item{`suffix`}{File suffix(es) accepted, without a leading dot.}
#'   \item{`detector`}{Function of a single path returning `TRUE` when the
#'     file is of this source. See [detect_source()] for the contract.}
#'   \item{`requires`}{Named character vector mapping a suffix to the
#'     optional package its detector needs, or `NULL` when the detector needs
#'     nothing beyond base R. Suffixes absent from the vector have no
#'     requirement.}
#' }
#'
#' @return A list of registry entries.
#' @keywords internal
source_registry <- function() {
  list(
    list(
      source = "aniframe",
      reader = "read_aniframe",
      suffix = "parquet",
      detector = detect_aniframe_file,
      requires = NULL
    ),
    list(
      source = "animalta",
      reader = "read_animalta",
      suffix = "csv",
      detector = detect_animalta_file,
      requires = NULL
    ),
    list(
      source = "anipose",
      reader = "read_anipose",
      suffix = "csv",
      detector = detect_anipose_file,
      requires = NULL
    ),
    list(
      source = "bonsai",
      reader = "read_bonsai",
      suffix = "csv",
      detector = detect_bonsai_file,
      requires = NULL
    ),
    list(
      source = "boris",
      reader = "read_boris",
      suffix = c("csv", "tsv"),
      detector = detect_boris_file,
      requires = NULL
    ),
    list(
      source = "c3d",
      reader = "read_c3d",
      suffix = "c3d",
      detector = detect_c3d_file,
      requires = NULL
    ),
    list(
      source = "deeplabcut",
      reader = "read_deeplabcut",
      suffix = c("csv", "h5"),
      detector = detect_deeplabcut_file,
      requires = c(h5 = "rhdf5")
    ),
    list(
      source = "fasttrack",
      reader = "read_fasttrack",
      suffix = "txt",
      detector = detect_fasttrack_file,
      requires = NULL
    ),
    list(
      source = "fictrac",
      reader = "read_fictrac",
      suffix = "dat",
      detector = detect_fictrac_file,
      requires = NULL
    ),
    list(
      source = "freemocap",
      reader = "read_freemocap",
      suffix = "csv",
      detector = detect_freemocap_file,
      requires = NULL
    ),
    list(
      source = "idtrackerai",
      reader = "read_idtracker",
      suffix = c("csv", "h5"),
      detector = detect_idtrackerai_file,
      requires = c(h5 = "rhdf5")
    ),
    list(
      source = "lightningpose",
      reader = "read_lightningpose",
      suffix = "csv",
      detector = detect_lightningpose_file,
      requires = NULL
    ),
    list(
      source = "movement",
      reader = "read_movement",
      suffix = c("nc", "h5"),
      detector = detect_movement_file,
      requires = c(nc = "rhdf5", h5 = "rhdf5")
    ),
    list(
      source = "octron",
      reader = "read_octron",
      suffix = "csv",
      detector = detect_octron_file,
      requires = NULL
    ),
    # SLEAP CSV exports are advertised by neither the registry nor the reader:
    # `read_sleap()` aborts on them (see #87). Restore "csv" here when the
    # reader gains support.
    list(
      source = "sleap",
      reader = "read_sleap",
      suffix = "h5",
      detector = detect_sleap_file,
      requires = c(h5 = "rhdf5")
    ),
    # Matches the `source` metadata `read_trackball()` actually stamps.
    list(
      source = "trackball_bonsai",
      reader = "read_trackball",
      suffix = "csv",
      detector = detect_trackball_file,
      requires = NULL
    ),
    list(
      source = "trackmate",
      reader = "read_trackmate",
      suffix = "xml",
      detector = detect_trackmate_file,
      requires = c(xml = "xml2")
    ),
    list(
      source = "trex",
      reader = "read_trex",
      suffix = c("csv", "npz"),
      detector = detect_trex_file,
      requires = NULL
    )
  )
}

#' Look up a registry entry by source name
#' @param source Source software name.
#' @return The matching registry entry, or `NULL`.
#' @keywords internal
registry_entry <- function(source) {
  registry <- source_registry()
  match <- vapply(registry, \(e) identical(e$source, source), logical(1))
  if (!any(match)) {
    return(NULL)
  }
  registry[[which(match)[1]]]
}

#' Optional package a source's detector needs for a given suffix
#' @param entry A registry entry.
#' @param suffix File suffix, without a leading dot.
#' @return The package name, or `NA_character_` when nothing is required.
#' @keywords internal
registry_requires <- function(entry, suffix) {
  if (is.null(entry$requires) || !suffix %in% names(entry$requires)) {
    return(NA_character_)
  }
  unname(entry$requires[[suffix]])
}
