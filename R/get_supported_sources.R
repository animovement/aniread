#' List the formats aniread can read and write
#'
#' Returns the tracking / event software and file formats that `aniread`
#' supports, with the function that reads or writes each and the file
#' suffix(es) it handles. This lets downstream packages discover the
#' supported formats programmatically instead of hard-coding the list -
#' mirroring `movement`'s `get_supported_source_software()`.
#'
#' Suffixes are returned without a leading dot (e.g. `"csv"`, `"h5"`),
#' matching the convention used throughout `aniread` (see the
#' `expected_suffix` argument of the internal file validator). The
#' generic [read_custom()] reader is intentionally omitted because it has
#' no fixed source software or file suffix.
#'
#' The `source` names of the `"read"` rows are exactly those accepted by the
#' `source` argument of [read_dataset()], and returned by [detect_source()].
#' Those of the `"write"` rows are accepted by the `format` argument of
#' [write_dataset()].
#'
#' @return A [tibble][dplyr::tibble] with one row per supported source and
#'   direction, and the columns:
#'   \describe{
#'     \item{`source`}{Character. The source software / format name.}
#'     \item{`direction`}{Character. `"read"` or `"write"`.}
#'     \item{`fun`}{Character. The `aniread` function that reads or writes
#'       it.}
#'     \item{`suffix`}{List column of character vectors - the file
#'       suffix(es) the function reads or writes.}
#'   }
#'
#' @examples
#' get_supported_sources()
#'
#' # The formats aniread can write:
#' supported <- get_supported_sources()
#' supported[supported$direction == "write", ]
#'
#' # Which sources read HDF5 (`.h5`) files?
#' readers <- supported[supported$direction == "read", ]
#' readers$source[vapply(readers$suffix, \(s) "h5" %in% s, logical(1))]
#'
#' @export
get_supported_sources <- function() {
  rows <- lapply(source_registry(), function(entry) {
    read <- if (!is.null(entry$reader)) {
      dplyr::tibble(
        source = entry$source,
        direction = "read",
        fun = entry$reader,
        suffix = list(entry$suffix)
      )
    }
    write <- if (!is.null(entry$writer)) {
      dplyr::tibble(
        source = entry$source,
        direction = "write",
        fun = entry$writer,
        suffix = list(entry$write_suffix)
      )
    }
    dplyr::bind_rows(read, write)
  })

  dplyr::bind_rows(rows)
}
