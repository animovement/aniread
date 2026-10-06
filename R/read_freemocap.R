#' Read FreeMoCap motion capture data
#'
#' @description Reads the layouts FreeMoCap v1 and v2 write, dispatching on
#' the column names rather than the file name:
#'
#' * `<recording>_by_frame.csv`: the v1 tidy export. FreeMoCap added a
#'   `reprojection_error` column at v1.7.4, so this exists in an 8- and a
#'   9-column form; both are read.
#' * `<recording>_by_trajectory.csv`: v1's one column triple per tracked
#'   point, with the camera timestamps alongside.
#' * `output_data/mediapipe_*_3d_xyz.csv`: v1's per-model wide files, one
#'   model each and no timestamps.
#' * `output_data/freemocap_data_by_frame.csv`, and the `.parquet` beside it:
#'   the v2 tidy export, one row per keypoint per trajectory per frame (see
#'   `trajectory`). Reading the Parquet file needs the arrow package.
#' * `output_data/<tracker>_<aspect>_<trajectory>.csv`: v2's per-trajectory
#'   files, such as `mediapipe_body_3d_xyz.csv`. They keep v1's names but are
#'   long (`frame`, `keypoint`, `x`, `y`, `z`), so they are told from v1's wide
#'   files by their columns. Their model is read from the file name.
#'
#' Which layout was read is recorded in the `source_format` metadata field.
#' Point names are parsed the way FreeMoCap's own data saver parses them, so
#' the same recording gives the same `model` and `keypoint` values whichever
#' layout it is read from.
#'
#' @param path Path to a FreeMoCap CSV, or a v2 Parquet file.
#' @param format `r lifecycle::badge("experimental")` Export layout.
#'   `"auto"` (default) reads it from the column names; naming one requires
#'   that layout and errors on anything else. The layout names may change
#'   while one convention for readers of a source with several export layouts
#'   is settled ([#118](https://github.com/animovement/aniread/issues/118)).
#' @param trajectory Which positions to read from the v2 tidy export:
#'   `"3d_xyz"` (default), the triangulated, filtered keypoints, or
#'   `"rigid_3d_xyz"`, the same keypoints with bone lengths held constant.
#'   FreeMoCap only computes `rigid_3d_xyz` for aspects with a joint
#'   hierarchy (the body), so other aspects keep `3d_xyz` and a message says
#'   which. Ignored, with a warning, for every other layout.
#'
#' @return An aniframe with `time`, `model`, `keypoint`, `confidence` and
#'   `x`/`y`/`z` in millimetres on a 3D cartesian coordinate system. `time`
#'   is seconds elapsed from `start_datetime` where the layout carries
#'   timestamps, and frames where it does not. Either way the first frame is
#'   at 0; see "Time" in [read_dataset()].
#'
#' @details
#' `confidence` comes from `reprojection_error`, which the 9-column
#' `by_frame` export and the v2 tidy export carry; every other layout gives
#' all-`NA` confidence. The two run in opposite directions: a reprojection
#' error is a distance in pixels, so zero is perfect and larger is worse,
#' whereas every other reader in aniread fills `confidence` from a likelihood
#' or a probability where larger is better. Storing the error unchanged would
#' make `aniprocess::mask_na_across(method = "confidence")` mask the best
#' points, so it is mapped through
#'
#' \deqn{confidence = 1 / (1 + error)}
#'
#' which is monotone decreasing onto \eqn{(0, 1]}: a zero error gives 1.
#' The mapping is invertible, so the original error is recoverable as
#' `1 / confidence - 1`.
#'
#' ## FreeMoCap v2
#'
#' v2 writes its output through skellyforge. Its tidy export names each model
#' `<tracker>.<aspect>` (`mediapipe.body`, `rtmpose.left_hand`); these are
#' read as `<tracker>_<aspect>` (`mediapipe_body`, `rtmpose_left_hand`), the
#' naming of v1's `model` column and of v2's own per-trajectory file names.
#' The hands keep separate models, since v2's hand keypoint names do not say
#' which hand they belong to.
#'
#' Each keypoint appears once per trajectory type, so only one set of
#' positions is read, chosen by `trajectory`. The centres of mass
#' (`total_body_center_of_mass` and `segment_center_of_mass`) are added as
#' keypoints of a `<tracker>_com` model, as v1 kept them in `mediapipe_com`,
#' with the keypoint names v2 gives them. (Only the body has centres of mass
#' in FreeMoCap's models; another aspect's would go to `<tracker>_<aspect>_com`,
#' so that segment names cannot collide.) Any other trajectory type is not
#' read.
#'
#' v2 writes no timestamps, so `time` is the frame number and `sampling_rate`
#' is left unset. FreeMoCap's main pipeline does not attach reprojection
#' errors to the skeleton it saves, so `confidence` is usually all `NA` too.
#'
#' [detect_source()] recognises the v2 tidy CSV. It does not claim the
#' per-trajectory files, whose five columns any tidy export could have, or
#' the Parquet file; read those with `read_freemocap()` directly.
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
#' # FreeMoCap v2's tidy export, reading the rigid-body positions
#' path <- system.file("extdata", "freemocap_v2.csv", package = "aniread")
#' read_freemocap(path, trajectory = "rigid_3d_xyz")
#'
#' @export
read_freemocap <- function(
  path,
  format = c(
    "auto",
    "by_frame",
    "by_trajectory",
    "wide",
    "v2_by_frame",
    "v2_trajectory"
  ),
  trajectory = c("3d_xyz", "rigid_3d_xyz")
) {
  validate_files(path)
  format <- match.arg(format)
  trajectory_given <- !missing(trajectory)
  trajectory <- match.arg(trajectory)

  data <- read_freemocap_table(path)

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

  if (trajectory_given && layout != "v2_by_frame") {
    cli::cli_warn(c(
      "{.arg trajectory} is ignored for this file.",
      "i" = "{.path {basename(path)}} is {describe_freemocap_format(detected)};
             only FreeMoCap v2's tidy export holds several trajectories."
    ))
  }

  data <- switch(
    layout,
    by_frame = read_freemocap_by_frame(data),
    by_trajectory = read_freemocap_by_trajectory(data),
    wide = read_freemocap_wide(data),
    v2_by_frame = read_freemocap_v2_by_frame(data, trajectory),
    v2_trajectory = read_freemocap_v2_trajectory(data, path)
  )

  data <- data |>
    anicore::as_anipoint() |>
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

#' Read a FreeMoCap file into a data frame
#'
#' FreeMoCap v2 writes its tidy export as Parquet as well as CSV. The two are
#' told apart by the Parquet magic bytes rather than the file name, as the
#' layouts are told apart by their columns.
#'
#' Names are read as text: a face keypoint such as `0000` would otherwise be
#' guessed to be the number 0.
#'
#' @param path Path to a FreeMoCap CSV or Parquet file.
#'
#' @return A data frame.
#' @noRd
read_freemocap_table <- function(path) {
  if (identical(peek_bytes(path, 4), charToRaw("PAR1"))) {
    check_arrow()
    return(as.data.frame(arrow::read_parquet(path)))
  }

  header <- names(vroom::vroom(path, n_max = 0, show_col_types = FALSE))
  text_cols <- intersect(c("model", "keypoint", "trajectory"), header)
  col_types <- vroom::cols(.default = vroom::col_guess())
  col_types$cols[text_cols] <- list(vroom::col_character())

  vroom::vroom(path, col_types = col_types, show_col_types = FALSE) |>
    suppressMessages()
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
#' @return As `read_freemocap_by_frame()`.
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
#' @return As `read_freemocap_by_frame()`.
#' @noRd
read_freemocap_wide <- function(data) {
  pivot_freemocap_points(data, timestamps = NULL)
}

#' Read FreeMoCap v2's tidy export
#'
#' `freemocap_data_by_frame.csv` (and `.parquet`), written by skellyforge's
#' `Actor.save_out_all_data_csv()`: `frame, keypoint, x, y, z, model,
#' trajectory, reprojection_error`, one row per keypoint per trajectory per
#' frame. One position trajectory is kept per model, and the centres of mass
#' are added as keypoints of their own model.
#'
#' @param data A data frame read from a v2 `freemocap_data_by_frame` file.
#' @param trajectory The position trajectory to read, `"3d_xyz"` or
#'   `"rigid_3d_xyz"`.
#'
#' @return As `read_freemocap_by_frame()`.
#' @noRd
read_freemocap_v2_by_frame <- function(data, trajectory) {
  is_com <- data$trajectory %in% FREEMOCAP_COM_TRAJECTORIES
  positions <- data[!is_com, , drop = FALSE]

  # rigid_3d_xyz only exists where skellyforge could enforce bone lengths,
  # which needs a joint hierarchy: the body, not the hands or the face. Those
  # keep their 3d_xyz rather than vanishing from the frame.
  models <- unique(positions$model)
  has_requested <- unique(positions$model[positions$trajectory == trajectory])
  fallback <- setdiff(models, has_requested)
  if (trajectory != "3d_xyz" && length(fallback) > 0) {
    cli::cli_inform(c(
      "i" = "No {.val {trajectory}} for {.val {freemocap_v2_model(fallback)}}; read
             {.val 3d_xyz} for {cli::qty(length(fallback))}{?it/them} instead."
    ))
  }
  traj <- positions$trajectory
  requested <- positions$model %in% has_requested & traj == trajectory
  fallen_back <- positions$model %in% fallback & traj == "3d_xyz"
  positions <- positions[requested | fallen_back, , drop = FALSE]
  positions$model <- freemocap_v2_model(positions$model)

  com <- data[is_com, , drop = FALSE]
  com$model <- freemocap_v2_com_model(com$model)

  dplyr::bind_rows(positions, com) |>
    dplyr::select(-"trajectory") |>
    finish_freemocap_v2()
}

#' Read one of FreeMoCap v2's per-trajectory files
#'
#' `<tracker>_<aspect>_<trajectory>.csv`, written by skellyforge's
#' `Actor.save_out_csv_data()`: `frame, keypoint, x, y, z` and nothing else,
#' so the model comes from the file name. A name that does not end in a known
#' trajectory keeps its whole stem as the model.
#'
#' @param data A data frame read from a v2 per-trajectory CSV.
#' @param path The path it was read from.
#'
#' @return As `read_freemocap_by_frame()`.
#' @noRd
read_freemocap_v2_trajectory <- function(data, path) {
  stem <- sub("\\.[^.]*$", "", basename(path))
  pattern <- paste0(
    "^(.+?)_(",
    paste(
      c(FREEMOCAP_POSITION_TRAJECTORIES, FREEMOCAP_COM_TRAJECTORIES),
      collapse = "|"
    ),
    ")$"
  )

  model <- stem
  # The shortest prefix, so `_rigid_3d_xyz` is not read as `_3d_xyz`.
  if (grepl(pattern, stem, perl = TRUE)) {
    model <- sub(pattern, "\\1", stem, perl = TRUE)
    if (
      sub(pattern, "\\2", stem, perl = TRUE) %in% FREEMOCAP_COM_TRAJECTORIES
    ) {
      # The file name joins tracker and aspect with an underscore, as the
      # model is read; the tidy export's dot is put back to find the aspect.
      model <- freemocap_v2_com_model(sub("_", ".", model, fixed = TRUE))
    }
  }

  data |>
    dplyr::mutate(model = model) |>
    finish_freemocap_v2()
}

#' Shape v2 rows like the other layouts
#'
#' @param data A data frame with `frame`, `model`, `keypoint`, `x`, `y`, `z`
#'   and optionally `reprojection_error`.
#'
#' @return As `read_freemocap_by_frame()`.
#' @noRd
finish_freemocap_v2 <- function(data) {
  # v2 writes no timestamps; the frame number is the time.
  data <- data |>
    dplyr::rename(time = "frame") |>
    dplyr::mutate(timestamp = as.POSIXct(NA))

  if ("reprojection_error" %in% names(data)) {
    data <- data |>
      dplyr::mutate(
        confidence = 1 / (1 + as.numeric(.data$reprojection_error)),
        .keep = "unused"
      )
  } else {
    data$confidence <- as.numeric(NA)
  }

  data |>
    dplyr::select(
      "time",
      "timestamp",
      "model",
      "keypoint",
      "x",
      "y",
      "z",
      "confidence"
    )
}

#' Name a v2 model the way v1 names its models
#'
#' v2's tidy export writes `<tracker>.<aspect>`; v1's `model` column and v2's
#' own per-trajectory file names use `<tracker>_<aspect>`.
#'
#' @param model Character vector such as `"rtmpose.left_hand"`.
#'
#' @return Character vector such as `"rtmpose_left_hand"`.
#' @noRd
freemocap_v2_model <- function(model) {
  sub(".", "_", model, fixed = TRUE)
}

#' Name the model a v2 centre of mass belongs to
#'
#' v1 kept the centres of mass in their own `mediapipe_com` model, apart from
#' the landmarks, so that a segment name could not collide with a landmark
#' name. The body's go to `<tracker>_com` likewise; another aspect's, should a
#' model ever define them, to `<tracker>_<aspect>_com`.
#'
#' @param model Character vector such as `"rtmpose.body"`.
#'
#' @return Character vector such as `"rtmpose_com"`.
#' @noRd
freemocap_v2_com_model <- function(model) {
  tracker <- sub("\\..*$", "", model)
  aspect <- sub("^[^.]*\\.?", "", model)
  as.character(ifelse(
    aspect == "body",
    paste0(tracker, "_com"),
    paste0(freemocap_v2_model(model), "_com")
  ))
}

# Trajectory names from skellyforge's `TrajectoryNames`
# (skellyforge/skellymodels/models/aspect.py).
FREEMOCAP_POSITION_TRAJECTORIES <- c("3d_xyz", "rigid_3d_xyz")
FREEMOCAP_COM_TRAJECTORIES <- c(
  "total_body_center_of_mass",
  "segment_center_of_mass"
)

#' Turn point-per-column FreeMoCap data into one row per point per frame
#'
#' Shared by the `by_trajectory` and wide layouts, which differ only in
#' whether timestamps accompany the coordinates.
#'
#' @param data A data frame whose columns are all `<point>_<x|y|z>`.
#' @param timestamps Optional vector of timestamps, one per row of `data`.
#'
#' @return As `read_freemocap_by_frame()`.
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
#'   `"wide"`, `"v2_by_frame"`, `"v2_trajectory"` or `"unknown"`.
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

  # FreeMoCap v2 (skellyforge) dropped the timestamps and added `trajectory`.
  v2_cols <- c("frame", "keypoint", "x", "y", "z")
  if (all(c(v2_cols, "model", "trajectory") %in% cols)) {
    return("v2_by_frame")
  }
  # Its per-trajectory files keep v1's names, but are long, not wide.
  if (all(v2_cols %in% cols)) {
    return("v2_trajectory")
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
    v2_by_frame = "the FreeMoCap v2 freemocap_data_by_frame export",
    v2_trajectory = "a FreeMoCap v2 per-trajectory export, such as output_data/mediapipe_body_3d_xyz.csv",
    "not a layout this reader recognises"
  )
}
