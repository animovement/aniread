#' List the source software formats aniread can read
#'
#' Returns the tracking / event software that `aniread` supports, paired
#' with the reader function for each and the file suffix(es) it accepts.
#' This lets downstream packages discover the supported formats
#' programmatically instead of hard-coding the list - mirroring
#' `movement`'s `get_supported_source_software()`.
#'
#' Suffixes are returned without a leading dot (e.g. `"csv"`, `"h5"`),
#' matching the convention used throughout `aniread` (see the
#' `expected_suffix` argument of the internal file validator). The
#' generic [read_custom()] reader is intentionally omitted because it has
#' no fixed source software or file suffix.
#'
#' The `source` names listed here are exactly those accepted by the
#' `source` argument of [read_dataset()], and returned by
#' [detect_source()].
#'
#' @return A [tibble][dplyr::tibble] with one row per supported source and
#'   the columns:
#'   \describe{
#'     \item{`source`}{Character. The source software / format name.}
#'     \item{`reader`}{Character. The `aniread` function that reads it.}
#'     \item{`suffix`}{List column of character vectors - the file
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
  registry <- source_registry()

  dplyr::tibble(
    source = vapply(registry, `[[`, character(1), "source"),
    reader = vapply(registry, `[[`, character(1), "reader"),
    suffix = lapply(registry, `[[`, "suffix")
  )
}
