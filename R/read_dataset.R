#' Read a movement or event dataset from any supported format
#'
#' @description
#' One entry point for every format `aniread` supports. By default the source
#' software is worked out from the file itself, so you do not have to know
#' which reader a file needs before opening it.
#'
#' @param paths Path to the file to read. A few readers take more than one
#'   path - [read_trackball()] takes one per sensor - in which case pass them
#'   all; detection inspects the first.
#' @param source Which source software wrote the file. `"auto"` (the default)
#'   detects it with [detect_source()]. Otherwise one of the names in
#'   [get_supported_sources()].
#' @param ... Passed on to the reader for `source`. This is how arguments that
#'   only some readers take are supplied, e.g. `sampling_rate` for
#'   [read_trackball()] or `path_probabilities` for [read_idtracker()].
#'
#' @details
#' `read_dataset()` is a dispatcher, not a new reader: it works out which
#' reader to call and calls it. The object you get back is exactly what the
#' underlying reader returns - an [aniframe][aniframe::aniframe] for tracking
#' data, or an [anievent][aniframe::anievent] for behavioural events from
#' [read_boris()].
#'
#' DeepLabCut and LightningPose CSV exports are structurally identical, so a
#' file in that format cannot be attributed to one or the other. Such a file is
#' read with [read_deeplabcut()] - the parse is the same either way - and its
#' `source` metadata is set to `"deeplabcut/lightningpose"` to record that the
#' distinction is undetermined. Pass `source` explicitly to override this.
#'
#' @return An [aniframe][aniframe::aniframe] or
#'   [anievent][aniframe::anievent], depending on the reader.
#'
#' @seealso [detect_source()] to detect the format without reading,
#'   [get_supported_sources()] for what is supported, and the individual
#'   `read_*()` functions for format-specific arguments.
#'
#' @examples
#' \dontrun{
#' # Let aniread work out the format
#' data <- read_dataset("mouse.h5")
#'
#' # Name it explicitly
#' data <- read_dataset("mouse.h5", source = "sleap")
#'
#' # Reader-specific arguments pass straight through
#' data <- read_dataset(
#'   c("sensor1.csv", "sensor2.csv"),
#'   sampling_rate = 60,
#'   col_time = 4,
#'   col_dx = 1,
#'   col_dy = 2
#' )
#' }
#' @export
read_dataset <- function(paths, source = "auto", ...) {
  if (!rlang::is_string(source)) {
    cli::cli_abort(
      "{.arg source} must be a single source name or {.val auto}, not
       {.obj_type_friendly {source}}."
    )
  }

  if (identical(source, "auto")) {
    source <- detect_source(paths)
  }

  # The ambiguous DeepLabCut/LightningPose CSV parses identically either way.
  ambiguous <- identical(source, AMBIGUOUS_DLC_LP)
  lookup <- if (ambiguous) "deeplabcut" else source

  entry <- registry_entry(lookup)
  if (is.null(entry)) {
    supported <- get_supported_sources()$source
    cli::cli_abort(c(
      "Unsupported {.arg source}: {.val {source}}.",
      "i" = "Supported sources are {.val {supported}}, or {.val auto} to
             detect the format from the file."
    ))
  }

  reader <- get(entry$reader, envir = asNamespace("aniread"), mode = "function")
  data <- reader(paths, ...)

  if (ambiguous) {
    data <- aniframe::set_metadata(data, source = AMBIGUOUS_DLC_LP)
  }

  data
}
