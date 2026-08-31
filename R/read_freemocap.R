#' Read FreeMoCap motion capture data
#'
#' @description Reads the FreeMoCap tidy export, written as
#' `<recording_name>_by_frame.csv`. FreeMoCap added a `reprojection_error`
#' column at v1.8.0, so that layout exists in an 8- and a 9-column form;
#' both are read, and which one was parsed is recorded in the
#' `source_format` metadata field.
#'
#' FreeMoCap also writes `<recording_name>_by_trajectory.csv` and the
#' per-model wide files in `output_data/` (`mediapipe_body_3d_xyz.csv` and
#' siblings). Neither is read yet; both are recognised, so the error names
#' what the file is rather than what it is not.
#'
#' @param path Path to a FreeMoCap `by_frame.csv` file.
#' @param format Export layout. `"auto"` reads it from the column names;
#'   `"by_frame"` requires that layout.
#'
#' @return An aniframe with `time`, `model`, `keypoint` and `x`/`y`/`z` in
#'   millimetres on a 3D cartesian coordinate system. A 9-column file keeps
#'   `reprojection_error` as a measurement column. `time` is seconds
#'   elapsed from `start_datetime` when the file carries timestamps, and
#'   frames when it does not.
#'
#' @examples
#' path <- system.file("extdata", "freemocap.csv", package = "aniread")
#' read_freemocap(path)
#'
#' @export
read_freemocap <- function(path, format = c("auto", "by_frame")) {
  validate_files(path)
  format <- match.arg(format)

  data <- vroom::vroom(path) |>
    suppressMessages()

  detected <- detect_freemocap_format(data)

  if (!startsWith(detected, "by_frame")) {
    cli::cli_abort(c(
      "{.arg path} is not a FreeMoCap {.val by_frame} file.",
      "x" = "{.path {basename(path)}} looks like {describe_freemocap_format(detected)}.",
      "i" = "Read the file written as {.file <recording_name>_by_frame.csv}.",
      "i" = "See {.fun aniread::read_freemocap} for the layouts FreeMoCap writes."
    ))
  }

  data <- data |>
    dplyr::select(-"timestamp_by_camera") |>
    dplyr::rename(time = "frame")

  data <- data |>
    anicore::as_aniframe() |>
    anicore::set_metadata(
      source = "freemocap",
      source_format = detected,
      filename = basename(path),
      unit_space = "mm",
      coordinate_system = "cartesian_3d"
    )

  if (!all(is.na(data$timestamp))) {
    # Add timestamp to metadata and keep only elapsed time
    data <- data |>
      anicore::set_metadata(
        start_datetime = dplyr::first(data$timestamp),
        unit_time = "s"
      ) |>
      dplyr::mutate(
        time = as.numeric(.data$timestamp - dplyr::first(.data$timestamp))
      )
  } else {
    # Else just set unit_time to frame
    data <- data |>
      anicore::set_metadata(
        unit_time = "frame"
      )
  }

  # Remove timestamp column
  data <- data |>
    dplyr::select(-"timestamp")

  data
}

#' Identify which FreeMoCap export layout a data frame holds
#'
#' Dispatches on column names rather than a column count, so a column added
#' upstream turns a known layout into a newer known layout rather than an
#' unrecognised one.
#'
#' @param data A data frame read from a FreeMoCap CSV.
#'
#' @return One of `"by_frame_8col"`, `"by_frame_9col"`, `"by_trajectory"`,
#'   `"wide"` or `"unknown"`.
#' @noRd
detect_freemocap_format <- function(data) {
  cols <- names(data)

  tidy_cols <- c(
    "frame",
    "timestamp",
    "timestamp_by_camera",
    "model",
    "keypoint",
    "x",
    "y",
    "z"
  )
  if (all(tidy_cols %in% cols)) {
    if ("reprojection_error" %in% cols) {
      return("by_frame_9col")
    }
    return("by_frame_8col")
  }

  # by_trajectory keeps the frame index but names each tracked point in the
  # columns, so there is no `keypoint` column to group by.
  if (!"keypoint" %in% cols && any(grepl("_(x|y|z)$", cols))) {
    if ("frame" %in% cols) {
      return("by_trajectory")
    }
    return("wide")
  }

  "unknown"
}

#' Describe a detected FreeMoCap layout for an error message
#'
#' @param format A value returned by `detect_freemocap_format()`.
#'
#' @return A one-clause description.
#' @noRd
describe_freemocap_format <- function(format) {
  switch(
    format,
    by_trajectory = "the by_trajectory export",
    wide = "a per-model wide export, such as output_data/mediapipe_body_3d_xyz.csv",
    "neither a FreeMoCap export nor a file this reader recognises"
  )
}
