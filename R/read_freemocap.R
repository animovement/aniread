#' Read FreeMoCap motion capture data
#'
#' @description Reads all three layouts FreeMoCap writes, dispatching on the
#' column names:
#'
#' * `<recording>_by_frame.csv` — the tidy export. FreeMoCap added a
#'   `reprojection_error` column at v1.8.0, so this exists in an 8- and a
#'   9-column form; both are read.
#' * `<recording>_by_trajectory.csv` — one column triple per tracked point,
#'   with the camera timestamps alongside.
#' * `output_data/mediapipe_*_3d_xyz.csv` — the per-model wide files, one
#'   model each and no timestamps.
#'
#' Which layout was read is recorded in the `source_format` metadata field.
#' Point names are parsed the way FreeMoCap's own data saver parses them, so
#' the same recording gives the same `model` and `keypoint` values whichever
#' layout it is read from.
#'
#' @param path Path to a FreeMoCap CSV.
#' @param format Export layout. `"auto"` reads it from the column names;
#'   naming one requires that layout and errors on anything else.
#'
#' @return An aniframe with `time`, `model`, `keypoint`, `confidence` and
#'   `x`/`y`/`z` in millimetres on a 3D cartesian coordinate system. `time`
#'   is seconds elapsed from `start_datetime` where the layout carries
#'   timestamps, and frames where it does not.
#'
#' @details
#' `confidence` comes from `reprojection_error`, which only the 9-column
#' `by_frame` export carries; every other layout gives all-`NA` confidence.
#' The two run in opposite directions — a reprojection error is a distance in
#' pixels, so zero is perfect and larger is worse, whereas every other reader
#' in aniread fills `confidence` from a likelihood or a probability where
#' larger is better. Storing the error unchanged would make
#' `aniprocess::filter_na_across(method = "confidence")` drop the best
#' points, so it is mapped through
#'
#' \deqn{confidence = 1 / (1 + error)}
#'
#' which is monotone decreasing onto \eqn{(0, 1]}: a zero error gives 1.
#' The mapping is invertible, so the original error is recoverable as
#' `1 / confidence - 1`.
#'
#' @examples
#' path <- system.file("extdata", "freemocap.csv", package = "aniread")
#' read_freemocap(path)
#'
#' # The same recording in its by_trajectory form
#' path <- system.file(
#'   "extdata",
#'   "freemocap_by_trajectory.csv",
#'   package = "aniread"
#' )
#' read_freemocap(path)
#'
#' @export
read_freemocap <- function(
  path,
  format = c("auto", "by_frame", "by_trajectory", "wide")
) {
  validate_files(path)
  format <- match.arg(format)

  data <- vroom::vroom(path) |>
    suppressMessages()

  detected <- detect_freemocap_format(data)

  if (detected == "unknown") {
    cli::cli_abort(c(
      "{.arg path} is not a FreeMoCap export.",
      "x" = "No known layout matches the columns of {.path {basename(path)}}.",
      "i" = "See {.fun aniread::read_freemocap} for the layouts FreeMoCap writes."
    ))
  }

  layout <- if (startsWith(detected, "by_frame")) "by_frame" else detected

  if (format != "auto" && format != layout) {
    cli::cli_abort(c(
      "{.arg path} is not a FreeMoCap {.val {format}} file.",
      "x" = "{.path {basename(path)}} is {describe_freemocap_format(detected)}.",
      "i" = "Pass {.code format = \"auto\"} to read it as what it is."
    ))
  }

  data <- switch(
    layout,
    by_frame = read_freemocap_by_frame(data),
    by_trajectory = read_freemocap_by_trajectory(data),
    wide = read_freemocap_wide(data)
  )

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

  data |>
    dplyr::select(-"timestamp")
}

#' Read the tidy `by_frame` layout
#'
#' `model` and `keypoint` are already columns here, so there is nothing to
#' parse - only `reprojection_error` to map onto `confidence` where the file
#' is new enough to carry one.
#'
#' @param data A data frame read from a FreeMoCap `by_frame.csv`.
#'
#' @return A data frame with `time`, `timestamp`, `model`, `keypoint`,
#'   `confidence` and `x`/`y`/`z`.
#' @noRd
read_freemocap_by_frame <- function(data) {
  data <- data |>
    dplyr::select(-"timestamp_by_camera") |>
    dplyr::rename(time = "frame")

  # A reprojection error runs the other way from a confidence, so it is
  # inverted rather than renamed. See @details.
  if ("reprojection_error" %in% names(data)) {
    data |>
      dplyr::mutate(
        confidence = 1 / (1 + .data$reprojection_error),
        .keep = "unused"
      )
  } else {
    data |>
      dplyr::mutate(confidence = as.numeric(NA))
  }
}

#' Read the `by_trajectory` layout
#'
#' One column triple per tracked point, prefixed with the point name, and no
#' frame column - the row position is the frame. The camera timestamps sit
#' alongside, so time can be resolved in seconds.
#'
#' @param data A data frame read from a FreeMoCap `by_trajectory.csv`.
#'
#' @return As [read_freemocap_by_frame()].
#' @noRd
read_freemocap_by_trajectory <- function(data) {
  timestamps <- data$timestamp

  data |>
    dplyr::select(-tidyselect::any_of(c("timestamp", "timestamp_by_camera"))) |>
    pivot_freemocap_points(timestamps = timestamps)
}

#' Read a per-model wide file
#'
#' `output_data/mediapipe_body_3d_xyz.csv` and its siblings: one column triple
#' per tracked point and nothing else, so the row position is the frame and
#' there are no timestamps to work from.
#'
#' @param data A data frame read from a FreeMoCap `*_3d_xyz.csv`.
#'
#' @return As [read_freemocap_by_frame()].
#' @noRd
read_freemocap_wide <- function(data) {
  pivot_freemocap_points(data, timestamps = NULL)
}

#' Turn point-per-column FreeMoCap data into one row per point per frame
#'
#' Shared by the `by_trajectory` and wide layouts, which differ only in
#' whether timestamps accompany the coordinates.
#'
#' @param data A data frame whose columns are all `<point>_<x|y|z>`.
#' @param timestamps Optional vector of timestamps, one per row of `data`.
#'
#' @return As [read_freemocap_by_frame()].
#' @noRd
pivot_freemocap_points <- function(data, timestamps = NULL) {
  if (is.null(timestamps)) {
    timestamps <- rep(as.POSIXct(NA), nrow(data))
  }

  # Frames are row positions in these layouts. `by_frame` counts from 0, so
  # these do too, or the same recording would not line up across layouts.
  data |>
    dplyr::mutate(
      time = dplyr::row_number() - 1L,
      timestamp = timestamps
    ) |>
    tidyr::pivot_longer(
      cols = -tidyselect::all_of(c("time", "timestamp")),
      names_to = c("point", "axis"),
      names_pattern = "^(.*)_([xyz])$"
    ) |>
    tidyr::pivot_wider(names_from = "axis", values_from = "value") |>
    dplyr::mutate(
      model = parse_freemocap_model(.data$point),
      keypoint = parse_freemocap_keypoint(.data$point),
      confidence = as.numeric(NA),
      .keep = "unused"
    ) |>
    dplyr::relocate("time", "timestamp", "model", "keypoint")
}

#' Split a FreeMoCap point name into its model
#'
#' Mirrors `DataSaver._parse_keypoint_name()` in FreeMoCap, so a recording
#' read from a wide or `by_trajectory` file reports the same models as the
#' same recording read from `by_frame.csv`. The hands are the special case:
#' `left_hand_0000` and `right_hand_0000` share one `mediapipe_hand` model
#' rather than becoming `mediapipe_left` and `mediapipe_right`.
#'
#' @param point Character vector of point names, e.g. `"body_nose"`.
#'
#' @return Character vector of model names, e.g. `"mediapipe_body"`.
#' @noRd
parse_freemocap_model <- function(point) {
  ifelse(
    grepl("^(left|right)_hand_", point),
    "mediapipe_hand",
    ifelse(
      grepl("_", point),
      paste0("mediapipe_", sub("_.*$", "", point)),
      "mediapipe"
    )
  )
}

#' Split a FreeMoCap point name into its keypoint
#'
#' @param point Character vector of point names, e.g. `"body_nose"`.
#'
#' @return Character vector of keypoint names, e.g. `"nose"`.
#' @noRd
parse_freemocap_keypoint <- function(point) {
  ifelse(
    grepl("^(left|right)_hand_", point),
    sub("^(left|right)_hand_", "\\1_", point),
    ifelse(grepl("_", point), sub("^[^_]*_", "", point), point)
  )
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

  # Both remaining layouts are entirely `<point>_<x|y|z>` columns. They differ
  # by the timestamps: by_trajectory carries them, the wide files do not.
  # Neither has a frame column - the row position is the frame.
  point_cols <- setdiff(cols, c("timestamp", "timestamp_by_camera"))
  if (length(point_cols) > 0 && all(grepl("_[xyz]$", point_cols))) {
    if (all(c("timestamp", "timestamp_by_camera") %in% cols)) {
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
    by_frame_8col = "the 8-column by_frame export",
    by_frame_9col = "the 9-column by_frame export",
    by_trajectory = "the by_trajectory export",
    wide = "a per-model wide export, such as output_data/mediapipe_body_3d_xyz.csv",
    "not a layout this reader recognises"
  )
}
