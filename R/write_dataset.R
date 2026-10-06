#' Write a movement or event dataset to any supported format
#'
#' @description
#' One entry point for every format `aniread` writes, the counterpart of
#' [read_dataset()]. By default the format is worked out from the file
#' suffix.
#'
#' @param data An aniframe: an [anipoint][anicore::anipoint],
#'   [anievent][anicore::anievent], or another frame built on them.
#' @param path Path to write to.
#' @param format Which format to write. `NULL` (the default) infers it from
#'   the suffix of `path`. Otherwise one of the `"write"` sources in
#'   [get_supported_sources()].
#' @param ... Passed on to the writer for `format`.
#'
#' @details
#' `write_dataset()` is a dispatcher, not a new writer: it works out which
#' writer to call and calls it.
#'
#' When several formats write the same suffix, the first listed in
#' [get_supported_sources()] is inferred: a `.csv` is written as a plain table
#' by [write_aniframe()], and inTRACKtive's CSV needs
#' `format = "intracktive"`.
#'
#' Parquet keeps everything: [read_dataset()] gives back the same class,
#' grouping and metadata that were written. Other formats keep what the
#' format can hold.
#'
#' @return `data`, invisibly.
#'
#' @seealso [read_dataset()] to read the file back, [get_supported_sources()]
#'   for what can be written, and the individual `write_*()` functions for
#'   format-specific arguments.
#'
#' @examplesIf rlang::is_installed("arrow")
#' data <- anicore::example_anipoint()
#' path <- tempfile(fileext = ".parquet")
#'
#' write_dataset(data, path)
#' read_dataset(path)
#'
#' # Name the format where the suffix is shared
#' write_dataset(data, tempfile(fileext = ".csv"), format = "intracktive")
#' @export
write_dataset <- function(data, path, format = NULL, ...) {
  if (!anicore::is_aniframe(data)) {
    cli::cli_abort(
      "{.arg data} must be an aniframe, not {.obj_type_friendly {data}}."
    )
  }
  if (!rlang::is_string(path)) {
    cli::cli_abort(
      "{.arg path} must be a single file path, not {.obj_type_friendly {path}}."
    )
  }

  suffix <- get_file_ext(basename(path))
  entry <- if (is.null(format)) {
    writer_for_suffix(suffix, path)
  } else {
    writer_for_format(format, suffix)
  }

  writer <- get(entry$writer, envir = asNamespace("aniread"), mode = "function")
  writer(data, path, ...)

  invisible(data)
}

#' The first writer for a suffix
#' @param suffix File suffix, without a leading dot.
#' @param path The path it came from, for the message.
#' @return A registry entry.
#' @keywords internal
writer_for_suffix <- function(suffix, path) {
  candidates <- Filter(
    \(e) !is.null(e$writer) && suffix %in% e$write_suffix,
    source_registry()
  )
  if (length(candidates) == 0) {
    writable <- unique(unlist(lapply(source_registry(), `[[`, "write_suffix")))
    cli::cli_abort(c(
      "Cannot infer a format to write {.file {basename(path)}}.",
      "x" = "No supported format writes {.val {suffix}} files.",
      "i" = "Writable suffixes are {.val {writable}}."
    ))
  }
  candidates[[1]]
}

#' The writer for a named format
#' @param format Format name.
#' @param suffix File suffix of the path, without a leading dot.
#' @return A registry entry.
#' @keywords internal
writer_for_format <- function(format, suffix) {
  if (!rlang::is_string(format)) {
    cli::cli_abort(
      "{.arg format} must be a single format name or {.code NULL}, not
       {.obj_type_friendly {format}}."
    )
  }
  entry <- registry_entry(format)
  if (is.null(entry$writer)) {
    cli::cli_abort(c(
      "Unsupported {.arg format}: {.val {format}}.",
      "i" = "Writable formats are {.val {registry_sources(\"write\")}}, or
             {.code NULL} to infer one from the file suffix."
    ))
  }
  if (!suffix %in% entry$write_suffix) {
    cli::cli_abort(c(
      "{.val {format}} is written to {.val {entry$write_suffix}} files, not
       {.val {suffix}}.",
      "i" = "Change the suffix of {.arg path}."
    ))
  }
  entry
}
