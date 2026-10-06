#' Write an *aniframe* to disk
#'
#' This high‑level wrapper writes an **aniframe** object to a file in one of the
#' supported formats (`parquet`, `csv`, or `tsv`). We highly recommend using `parquet`
#' as neither `csv` or `tsv` can preserve the metadata.
#'
#' @param data     An **aniframe** object (see `anicore::is_aniframe()`).
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
#' * CSV/TSV files are written with *vroom* for fast I/O: `.csv` comma-separated
#'   and `.tsv` tab-separated, unless `delim` is passed.
#' * Parquet files are written with the *arrow* package is installed (install‑on‑demand if missing).
#'
#' @examples
#' \dontrun{
#' ## Create a small aniframe for demonstration
#' df <- anicore::example_anipoint()
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
  ext <- get_file_ext(filename)
  allowed_exts <- c("parquet", "csv", "tsv")

  # Input validation
  if (!anicore::is_aniframe(data)) {
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
write_aniframe_csv <- function(data, filename, delim = NULL, ...) {
  # Validate filename
  ensure_file_has_expected_suffix(filename, c("csv", "tsv"))

  # vroom's own default is a tab whatever the extension (#136)
  delim <- delim %||% if (get_file_ext(filename) == "csv") "," else "\t"

  # Write data
  vroom::vroom_write(data, filename, delim = delim, ...) |>
    suppressWarnings()
}

#' @keywords internal
write_aniframe_parquet <- function(data, filename, ...) {
  dot_args <- list(...)

  # Check that arrow is installed
  check_arrow()

  # Validate filename
  ensure_file_has_expected_suffix(filename, "parquet")

  # arrow strips the class from a grouped frame, so record it for read_aniframe()
  table <- arrow::arrow_table(data) |>
    suppressWarnings()
  table$metadata[[CLASS_KEY]] <- paste(aniframe_subclass(data), collapse = ",")

  # Write data
  arrow::write_parquet(table, filename, ...) |>
    suppressWarnings()
}

# Parquet key-value metadata holding the aniframe subclass, e.g. "anijoint".
CLASS_KEY <- "animovement_class"

#' The classes an aniframe has in front of `aniframe`
#' @param data An aniframe.
#' @return A character vector, e.g. `"anipoint"`.
#' @keywords internal
aniframe_subclass <- function(data) {
  cls <- class(data)
  cls[seq_len(match("aniframe", cls) - 1L)]
}
