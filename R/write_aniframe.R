#' Write an *aniframe* to disk
#'
#' This high‑level wrapper writes an **aniframe** object to a file in one of the
#' supported formats (`parquet`, `csv`, or `tsv`). We highly recommend using `parquet`
#' as neither `csv` or `tsv` can preserve the metadata.
#'
#' @param data     An **aniframe** object (see `aniframe::is_aniframe()`).
#' @param filename Character string specifying the output file name.  The file
#'   extension determines which writer is used.
#' @param ...      Additional arguments passed to the format‑specific writer
#'   (`write_aniframe_csv()` or `write_aniframe_parquet()`).  Typical arguments
#'   include `delim`, `col_names`, `compression`, etc., depending on the backend.
#'
#' @return The original `data` object (invisibly), enabling pipe‑friendly usage.
#'
#' @details
#' * **Supported extensions** are `"parquet"`, `"csv"` and `"tsv"`. We highly recommend using `parquet`
#' as neither `csv` or `tsv` can preserve the metadata.
#' * CSV/TSV files are written with the *vroom* for fast I/O.
#' * Parquet files are written with the *arrow* package is installed (install‑on‑demand if missing).
#'
#' @examples
#' \dontrun{
#' ## Create a small aniframe for demonstration
#' df <- aniframe::example_aniframe()
#'
#' ## Write the aniframe as CSV
#' write_aniframe(df, "demo.csv")
#'
#' ## Write the same aniframe as Parquet
#' write_aniframe(df, "demo.parquet")
#' }
#' @export
write_aniframe <- function(data, filename, ...) {
  dot_args <- list(...)
  ext <- .get_file_ext(filename)
  allowed_exts <- c("parquet", "csv", "tsv")

  # Input validation
  if (!aniframe::is_aniframe(data)) {
    cli::cli_abort("Data is not an aniframe.")
  }
  if (!ext %in% allowed_exts) {
    cli::cli_abort(
      "File extension needs to be one of {allowed_exts} (got {ext})."
    )
  }

  # Validate filename
  if (ext == "parquet") {
    write_aniframe_parquet(data, filename, ...)
  } else if (ext %in% c("csv", "tsv")) {
    cli::cli_warn(
      "{ext} files do not preserve metadata. We highly recommend saving in `parquet` format to preserve all metadata."
    )
    write_aniframe_csv(data, filename, ...)
  }

  invisible(data)
}

#' @keywords internal
write_aniframe_csv <- function(data, filename, ...) {
  dot_args <- list(...)

  # # Validate filename
  # ensure_file_has_expected_suffix(filename, "csv")

  # Write data
  vroom::vroom_write(data, filename, ...) |>
    suppressWarnings()
}

#' @keywords internal
write_aniframe_parquet <- function(data, filename, ...) {
  dot_args <- list(...)

  # Check that arrow is installed
  rlang::check_installed(
    "arrow",
    reason = "to use write_aniframe()",
    action = function(...) {
      utils::install.packages(
        'arrow',
        repos = c(
          'https://roaldarbol.r-universe.dev',
          'https://cloud.r-project.org'
        )
      )
    }
  )

  # Validate filename
  ensure_file_has_expected_suffix(filename, "parquet")

  # Write data
  arrow::write_parquet(data, filename, ...) |>
    suppressWarnings()
}
