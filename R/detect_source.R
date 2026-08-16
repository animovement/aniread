#' Detect which source software wrote a file
#'
#' @description
#' Works out which of the supported source software formats a file is in, by
#' looking at the file itself rather than trusting its name. This is what
#' [read_dataset()] uses when `source = "auto"`.
#'
#' Candidates are first narrowed to the sources registered for the file's
#' suffix, then each candidate's detector inspects the file's contents. Exactly
#' one match is required.
#'
#' @param paths Path to the file. If several paths are given (as
#'   [read_trackball()] takes), only the first is inspected.
#'
#' @details
#' DeepLabCut and LightningPose export structurally identical CSV files, so a
#' file in that format matches both. Rather than guess, `detect_source()`
#' returns the combined name `"deeplabcut/lightningpose"`; [read_dataset()]
#' reads it with [read_deeplabcut()] - the parse is the same either way - and
#' records the combined name as the source, so the ambiguity is preserved
#' rather than silently resolved.
#'
#' Detectors for HDF5, Parquet, XML and C3D files need an optional package
#' (`rhdf5`, `arrow`, `xml2`, `c3dr`). When one is not installed its sources
#' are skipped, and if nothing is detected the error names both the skipped
#' sources and the packages that would have been consulted.
#'
#' @section Writing a detector:
#' A detector is a function of a single path returning `TRUE` when the file is
#' of that source. It must be cheap - read a handful of lines, or an HDF5
#' index, never the whole file - and it need not be defensive: `detect_source()`
#' runs each one with messages and warnings suppressed and treats an error as
#' "did not match".
#'
#' @return The source name, as it appears in [get_supported_sources()], or the
#'   combined `"deeplabcut/lightningpose"`.
#'
#' @seealso [read_dataset()] to read the file, [get_supported_sources()] for
#'   the supported formats.
#'
#' @examples
#' \dontrun{
#' detect_source("mouse.csv")
#' #> [1] "deeplabcut/lightningpose"
#' }
#' @export
detect_source <- function(paths) {
  path <- paths[[1]]
  validate_files(path)

  suffix <- tolower(get_file_ext(path))
  registry <- source_registry()
  candidates <- Filter(\(e) suffix %in% e$suffix, registry)

  if (length(candidates) == 0) {
    cli::cli_abort(c(
      "Cannot detect the source software of {.file {basename(path)}}.",
      "x" = "No supported source reads {.val {suffix}} files.",
      "i" = "See {.run aniread::get_supported_sources()} for the formats
             {.pkg aniread} can read."
    ))
  }

  matched <- character(0)
  skipped <- character(0)
  missing_pkgs <- character(0)

  for (entry in candidates) {
    pkg <- registry_requires(entry, suffix)
    if (!is.na(pkg) && !rlang::is_installed(pkg)) {
      skipped <- c(skipped, entry$source)
      missing_pkgs <- c(missing_pkgs, pkg)
      next
    }
    if (isTRUE(run_detector(entry$detector, path))) {
      matched <- c(matched, entry$source)
    }
  }

  if (length(matched) == 1) {
    return(matched)
  }

  # DeepLabCut and LightningPose share a CSV layout; the pair is expected.
  if (setequal(matched, c("deeplabcut", "lightningpose"))) {
    return(AMBIGUOUS_DLC_LP)
  }

  if (length(matched) > 1) {
    cli::cli_abort(c(
      "Cannot detect the source software of {.file {basename(path)}}.",
      "x" = "It matches more than one source: {.val {matched}}.",
      "i" = "Pass {.arg source} explicitly to {.fn read_dataset} to choose."
    ))
  }

  cli::cli_abort(c(
    "Cannot detect the source software of {.file {basename(path)}}.",
    "x" = "Its contents match none of the sources that read {.val {suffix}}
           files: {.val {vapply(candidates, `[[`, character(1), 'source')}}.",
    if (length(skipped) > 0) {
      c(
        "!" = "{.val {skipped}} {?was/were} not checked because
               {?package/packages} {.pkg {unique(missing_pkgs)}}
               {?is/are} not installed."
      )
    },
    "i" = "Pass {.arg source} explicitly to {.fn read_dataset} if you know the
           format."
  ))
}

# Combined name used when a CSV matches both the DeepLabCut and the
# LightningPose detector.
AMBIGUOUS_DLC_LP <- "deeplabcut/lightningpose"

#' Run one detector, treating any failure as a non-match
#' @param detector A detector function.
#' @param path Path to the file.
#' @keywords internal
run_detector <- function(detector, path) {
  tryCatch(
    suppressMessages(suppressWarnings(detector(path))),
    error = function(e) FALSE
  )
}


#' Format detectors
#'
#' @description
#' One predicate per supported format, each returning `TRUE` when the file at
#' `path` was written by that source software. See [detect_source()] for the
#' contract they follow and how they are dispatched.
#'
#' @param path Path to the file.
#' @return `TRUE` when the file matches the format, otherwise `FALSE`.
#' @name source_detectors
#' @keywords internal
NULL


# ---- Shared helpers ---------------------------------------------------------

#' Read the first lines of a text file
#' @param path Path to the file.
#' @param n Number of lines.
#' @keywords internal
peek_lines <- function(path, n = 5) {
  readLines(path, n = n, warn = FALSE)
}

#' Split the first line of a file into fields
#' @param path Path to the file.
#' @param delim Field delimiter.
#' @keywords internal
peek_header <- function(path, delim = ",") {
  lines <- peek_lines(path, n = 1)
  if (length(lines) == 0) {
    return(character(0))
  }
  trimws(strsplit(lines[[1]], delim, fixed = TRUE)[[1]])
}

#' Read the leading bytes of a file
#' @param path Path to the file.
#' @param n Number of bytes.
#' @keywords internal
peek_bytes <- function(path, n) {
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  readBin(con, what = "raw", n = n)
}

#' Names of the top-level datasets in an HDF5 file
#' @param path Path to the file.
#' @keywords internal
peek_h5_names <- function(path) {
  contents <- rhdf5::h5ls(path)
  on.exit(rhdf5::h5closeAll(), add = TRUE)
  unique(contents$name)
}


# ---- Detectors: delimited text ----------------------------------------------

#' @rdname source_detectors
#' @keywords internal
detect_animalta_file <- function(path) {
  # Both AnimalTA layouts open the same way: the raw export continues into
  # X_Arena<n>_Ind<n> columns, the detailed one into Arena;Ind;X;Y.
  header <- peek_header(path, delim = ";")
  length(header) >= 3 && identical(header[1:2], c("Frame", "Time"))
}

#' @rdname source_detectors
#' @keywords internal
detect_anipose_file <- function(path) {
  header <- peek_header(path)
  "fnum" %in%
    header &&
    any(endsWith(header, "_score")) &&
    any(endsWith(header, "_error")) &&
    any(endsWith(header, "_ncams"))
}

#' @rdname source_detectors
#' @keywords internal
detect_bonsai_file <- function(path) {
  # Bonsai names every column after the workflow item that produced it, so a
  # multi-item workflow gives Item1.* through ItemN.*.
  header <- peek_header(path)
  length(header) > 1 && all(grepl("^Item\\d+\\.", header))
}

#' @rdname source_detectors
#' @keywords internal
detect_boris_file <- function(path) {
  # detect_boris_format() aborts when the file is not a BORIS export, which
  # run_detector() turns into a non-match.
  !is.null(detect_boris_format(path))
}

#' @rdname source_detectors
#' @keywords internal
detect_freemocap_file <- function(path) {
  identical(
    peek_header(path),
    c(
      "frame",
      "timestamp",
      "timestamp_by_camera",
      "model",
      "keypoint",
      "x",
      "y",
      "z"
    )
  )
}

#' @rdname source_detectors
#' @keywords internal
detect_octron_file <- function(path) {
  # Octron writes a key/value preamble before the table.
  lines <- peek_lines(path, n = 5)
  any(grepl("^\\s*(video_name|frame_count|frame_count_analyzed)\\s*:", lines))
}

#' @rdname source_detectors
#' @keywords internal
detect_trex_file <- function(path) {
  header <- peek_header(path)
  length(header) > 1 &&
    identical(header[[1]], "frame") &&
    any(grepl("#", header, fixed = TRUE))
}

#' @rdname source_detectors
#' @keywords internal
detect_fasttrack_file <- function(path) {
  header <- peek_header(path, delim = "\t")
  all(c("xHead", "yHead", "tHead") %in% header)
}

#' @rdname source_detectors
#' @keywords internal
detect_fictrac_file <- function(path) {
  # FicTrac writes a headerless, all-numeric table of 23+ columns.
  header <- peek_header(path)
  length(header) >= 23 &&
    !anyNA(suppressWarnings(as.numeric(header)))
}

#' @rdname source_detectors
#' @keywords internal
detect_trackball_file <- function(path) {
  # Headerless Bonsai optical-flow capture: dx, dy, device clock, PC datetime,
  # inter-sample interval. Reuses the layout detection the reader itself uses.
  layout <- detect_opticalflow_layout(path)
  if (isTRUE(layout$has_header)) {
    return(FALSE)
  }
  lines <- peek_lines(path, n = layout$skip + 1)
  if (length(lines) <= layout$skip) {
    return(FALSE)
  }
  fields <- trimws(strsplit(lines[[layout$skip + 1]], ",", fixed = TRUE)[[1]])
  length(fields) == 5 &&
    !is.na(suppressWarnings(as.POSIXct(
      fields[[4]],
      format = "%Y-%m-%dT%H:%M:%OS",
      tz = "UTC"
    )))
}


# ---- Detectors: shared CSV layouts ------------------------------------------

#' Does a CSV carry a DeepLabCut-style header block?
#' @param path Path to the file.
#' @keywords internal
has_deeplabcut_csv_header <- function(path) {
  lines <- peek_lines(path, n = 4)
  if (length(lines) < 3) {
    return(FALSE)
  }
  first_col <- vapply(
    lines,
    \(l) trimws(strsplit(l, ",", fixed = TRUE)[[1]][1]),
    character(1),
    USE.NAMES = FALSE
  )
  identical(first_col[[1]], "scorer") &&
    all(c("bodyparts", "coords") %in% first_col)
}

#' @rdname source_detectors
#' @keywords internal
detect_deeplabcut_file <- function(path) {
  if (identical(tolower(get_file_ext(path)), "h5")) {
    return("df_with_missing" %in% peek_h5_names(path))
  }
  has_deeplabcut_csv_header(path)
}

#' @rdname source_detectors
#' @keywords internal
detect_lightningpose_file <- function(path) {
  # Structurally indistinguishable from a DeepLabCut CSV; the pair is resolved
  # by detect_source() into a combined source name.
  has_deeplabcut_csv_header(path)
}

#' @rdname source_detectors
#' @keywords internal
detect_idtrackerai_file <- function(path) {
  if (identical(tolower(get_file_ext(path)), "h5")) {
    return("trajectories" %in% peek_h5_names(path))
  }
  # The trajectories CSV pairs `seconds` with x1/y1... columns. The companion
  # probabilities CSV shares `seconds` but not the coordinates, and is passed
  # to read_idtracker() separately rather than read on its own.
  header <- peek_header(path)
  all(c("seconds", "x1", "y1") %in% header)
}


# ---- Detectors: HDF5 --------------------------------------------------------

#' @rdname source_detectors
#' @keywords internal
detect_sleap_file <- function(path) {
  all(c("tracks", "node_names") %in% peek_h5_names(path))
}

#' @rdname source_detectors
#' @keywords internal
detect_movement_file <- function(path) {
  all(
    c("individuals", "keypoints", "position", "confidence") %in%
      peek_h5_names(path)
  )
}


# ---- Detectors: other containers --------------------------------------------

#' @rdname source_detectors
#' @keywords internal
detect_trackmate_file <- function(path) {
  xml <- xml2::read_xml(path)
  !is.na(xml2::xml_find_first(xml, ".//Model"))
}

#' @rdname source_detectors
#' @keywords internal
detect_c3d_file <- function(path) {
  # A C3D file opens with a parameter-block pointer followed by the format key
  # 0x50, which is what identifies the format rather than the suffix.
  bytes <- peek_bytes(path, 2)
  length(bytes) == 2 && bytes[[2]] == as.raw(0x50)
}

#' @rdname source_detectors
#' @keywords internal
detect_aniframe_file <- function(path) {
  identical(rawToChar(peek_bytes(path, 4)), "PAR1")
}
