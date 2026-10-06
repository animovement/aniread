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
#' @param by Key columns to write one file per combination of, or `NULL`
#'   (the default) for a single file. Any of [anicore::get_keys()]; the role
#'   names `"what"` and `"when"` stand for all identity or all temporal keys,
#'   so `by = c("what", "when")` writes one file per track. See "Files per
#'   group".
#' @param ... Passed on to the writer for `format`.
#'
#' @section Files per group:
#' With `by`, each file is named from `path` with the key values appended
#' before the suffix: `"mice.csv"` with `by = "individual"` gives
#' `mice_individual-mouse1.csv`, `mice_individual-mouse2.csv`, and so on, and
#' several keys give `mice_individual-mouse1_session-2.csv`.
#'
#' For other names, put the keys in `path` in braces:
#' `"{session}/mice_{individual}.csv"`. The braces then set `by`, so it can be
#' left out, and directories in `path` are created. Characters other than
#' letters, digits, `.`, `_` and `-` in a value become `-`.
#'
#' Each file holds an aniframe with the same class and metadata as `data`.
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
#'
#' # One file per individual, or per track
#' dir <- tempfile()
#' dir.create(dir)
#' write_dataset(data, file.path(dir, "mice.parquet"), by = "individual")
#' write_dataset(data, file.path(dir, "{individual}/{keypoint}.parquet"))
#' list.files(dir, recursive = TRUE)
#' @export
write_dataset <- function(data, path, format = NULL, by = NULL, ...) {
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

  by <- resolve_by(data, by, path)
  if (length(by) == 0) {
    writer(data, path, ...)
    return(invisible(data))
  }

  combos <- unique(as.data.frame(unclass(data)[by]))
  paths <- vapply(
    seq_len(nrow(combos)),
    \(i) path_for_group(path, combos[i, , drop = FALSE]),
    character(1)
  )
  if (anyDuplicated(paths)) {
    clash <- paths[duplicated(paths)][[1]]
    cli::cli_abort(c(
      "Several groups would be written to {.file {clash}}.",
      "i" = "Their {.field {by}} values differ only in characters that are not
             allowed in a file name."
    ))
  }

  for (i in seq_along(paths)) {
    rows <- lapply(by, \(key) {
      rlang::expr(!!rlang::sym(key) %in% !!combos[[key]][i])
    })
    dir.create(dirname(paths[[i]]), recursive = TRUE, showWarnings = FALSE)
    writer(dplyr::filter(data, !!!rows), paths[[i]], ...)
  }

  # Everything is written below the part of path before the first brace
  root <- sub("/?[^/]*\\{.*$", "", path)
  root <- if (identical(root, path)) dirname(path) else root
  cli::cli_inform(
    "Wrote {length(paths)} file{?s}, one per {.field {by}}, to
     {.path {if (nzchar(root)) root else '.'}}."
  )
  invisible(data)
}

#' The key columns to split by
#'
#' Expands the role names `"what"` and `"when"`, takes the keys named in braces
#' in `path` when `by` is `NULL`, and checks that the two agree.
#'
#' @inheritParams write_dataset
#' @return A character vector of key columns, empty for a single file.
#' @keywords internal
resolve_by <- function(data, by, path) {
  placeholders <- regmatches(
    path,
    gregexpr("(?<=\\{)[^{}]+(?=\\})", path, perl = TRUE)
  )[[1]]
  if (is.null(by)) {
    by <- placeholders
  }
  if (!is.character(by)) {
    cli::cli_abort(
      "{.arg by} must be a character vector of keys, not {.obj_type_friendly {by}}."
    )
  }

  roles <- c("what", "when")
  by <- unique(unlist(lapply(by, \(b) {
    if (b %in% roles) anicore::get_variables(data, b, "keys") else b
  })))

  keys <- anicore::get_keys(data)
  unknown <- setdiff(by, keys)
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Cannot split by {.field {unknown}}: not a key of {.arg data}.",
      "i" = "The keys are {.field {keys}}, or {.val {roles}} for all of a role."
    ))
  }

  if (length(placeholders) > 0) {
    unnamed <- setdiff(by, placeholders)
    if (length(unnamed) > 0) {
      cli::cli_abort(c(
        "{.arg path} names {.field {placeholders}} in braces, but {.arg by}
         also splits by {.field {unnamed}}.",
        "i" = "Add {.code {paste0('{', unnamed, '}')}} to {.arg path}, or leave
               {.arg by} out."
      ))
    }
  }

  by
}

#' The path one group is written to
#' @param path The path given to [write_dataset()].
#' @param values A one-row data frame of the group's key values.
#' @return A file path.
#' @keywords internal
path_for_group <- function(path, values) {
  safe <- vapply(
    values,
    \(v) gsub("[^A-Za-z0-9._-]+", "-", ifelse(is.na(v), "NA", as.character(v))),
    character(1)
  )

  if (grepl("{", path, fixed = TRUE)) {
    for (key in names(safe)) {
      path <- gsub(paste0("{", key, "}"), safe[[key]], path, fixed = TRUE)
    }
    return(path)
  }

  suffix <- get_file_ext(basename(path))
  stem <- substr(path, 1, nchar(path) - nchar(suffix) - 1)
  paste0(stem, "_", paste0(names(safe), "-", safe, collapse = "_"), ".", suffix)
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
