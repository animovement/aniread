#' List the source software formats aniread can read
#'
#' Returns the tracking / event software that `aniread` supports, paired
#' with the reader function for each and the file suffix(es) it accepts.
#' This lets downstream packages discover the supported formats
#' programmatically instead of hard-coding the list — mirroring
#' `movement`'s `get_supported_source_software()`.
#'
#' Suffixes are returned without a leading dot (e.g. `"csv"`, `"h5"`),
#' matching the convention used throughout `aniread` (see the
#' `expected_suffix` argument of the internal file validator). The
#' generic [read_custom()] reader is intentionally omitted because it has
#' no fixed source software or file suffix.
#'
#' @return A [tibble][dplyr::tibble] with one row per supported source and
#'   the columns:
#'   \describe{
#'     \item{`source`}{Character. The source software / format name.}
#'     \item{`reader`}{Character. The `aniread` function that reads it.}
#'     \item{`suffix`}{List column of character vectors — the file
#'       suffix(es) the reader accepts.}
#'   }
#'
#' @examples
#' get_supported_sources()
#'
#' # All source names:
#' get_supported_sources()$source
#'
#' # Which sources read HDF5 (`.h5`) files?
#' supported <- get_supported_sources()
#' supported$source[vapply(supported$suffix, \(s) "h5" %in% s, logical(1))]
#'
#' @export
get_supported_sources <- function() {
  registry <- list(
    list(source = "aniframe", reader = "read_aniframe", suffix = "parquet"),
    list(source = "animalta", reader = "read_animalta", suffix = "csv"),
    list(source = "anipose", reader = "read_anipose", suffix = "csv"),
    list(source = "bonsai", reader = "read_bonsai", suffix = "csv"),
    list(source = "boris", reader = "read_boris", suffix = c("csv", "tsv")),
    list(source = "c3d", reader = "read_c3d", suffix = "c3d"),
    list(
      source = "deeplabcut",
      reader = "read_deeplabcut",
      suffix = c("csv", "h5")
    ),
    list(source = "fasttrack", reader = "read_fasttrack", suffix = "txt"),
    list(source = "fictrac", reader = "read_fictrac", suffix = "dat"),
    list(source = "freemocap", reader = "read_freemocap", suffix = "csv"),
    list(
      source = "idtrackerai",
      reader = "read_idtracker",
      suffix = c("csv", "h5")
    ),
    list(
      source = "lightningpose",
      reader = "read_lightningpose",
      suffix = "csv"
    ),
    list(source = "movement", reader = "read_movement", suffix = c("nc", "h5")),
    list(source = "octron", reader = "read_octron", suffix = "csv"),
    list(source = "sleap", reader = "read_sleap", suffix = c("h5", "csv")),
    list(source = "trackball", reader = "read_trackball", suffix = "csv"),
    list(source = "trackmate", reader = "read_trackmate", suffix = "xml"),
    list(source = "trex", reader = "read_trex", suffix = "csv")
  )

  dplyr::tibble(
    source = vapply(registry, `[[`, character(1), "source"),
    reader = vapply(registry, `[[`, character(1), "reader"),
    suffix = lapply(registry, `[[`, "suffix")
  )
}
