#' Read projected FicTrac data
#'
#' This helper loads a FicTrac ``*.dat`` file, keeps the timestamp, the 2‑D
#' fictive path and the animal's heading, converts the timestamps to seconds,
#' and returns the result as an anipoint. FicTrac's "integrated animal
#' heading" (the direction the animal faces) becomes `yaw` and is declared as
#' the frame's orientation, in radians from `x` toward `y`. FicTrac's movement
#' direction is the direction of travel, derivable from the path, and is not
#' kept. If the physical ball radius is supplied, the positions are scaled
#' accordingly and the spatial unit metadata is set.
#'
#' FicTrac 2 has written three layouts, told apart by their number of columns.
#' Columns 1 to 21 are the same in all of them; the rest hold timestamps:
#'
#' - **23 columns** (FicTrac 2.0 to 2.02): 22 is the timestamp, 23 the
#'   sequence counter. `time` is taken from the timestamp, which is the
#'   position in the video file (ms) or the frame capture time (ms).
#' - **24 columns** (untagged versions from July 2019, before 2.03): 22 is
#'   the frame capture time in ms since midnight, 23 the sequence counter, 24
#'   the time since the last frame (ms). `time` is taken from column 22.
#' - **25 columns** (FicTrac 2.03 onward): 22 is the timestamp, 23 the
#'   sequence counter, 24 the time since the last frame, 25 the "alt.
#'   timestamp", the frame capture time in ms since midnight. `time` is taken
#'   from column 25.
#'
#' `time` counts in seconds from the first row. A time in ms since midnight
#' starts again from zero at midnight, so where it drops by more than twelve
#' hours from one row to the next, the reader takes it as having passed
#' midnight and adds a day from there on. A recording that crosses midnight
#' therefore keeps running forward rather than jumping back.
#'
#' @param path Character. Path to the FicTrac ``*.dat`` file.
#' @param ball_radius Numeric (optional). Physical radius of the tracking ball.
#'   When supplied the ``x`` and ``y`` coordinates are multiplied by this value.
#' @param unit_ball_radius Character. Unit of ``ball_radius`` (e.g., `"cm"` or
#'   `"mm"`). Defaults to `"cm"`. Ignored when ``ball_radius`` is `NULL`.
#'
#' @return An anipoint with columns `time`, `x`, `y` and `yaw`. Metadata
#'   includes the source (`"fictrac"`), original filename, sampling rate,
#'   time unit (`"s"`), space unit (either `"none"` or the value of
#'   `unit_ball_radius`), and a Cartesian 2‑D coordinate system. `time` is in
#'   seconds from the first row; see "Time" in [read_dataset()].
#'
#' @examples
#' \dontrun{
#' # Assuming you have a FicTrac file called "fly1.dat"
#' traj <- read_fictrac("fly1.dat", ball_radius = 0.5, unit_ball_radius = "cm")
#' head(traj)
#' }
#'
#' @export
read_fictrac <- function(path, ball_radius = NULL, unit_ball_radius = "cm") {
  # Validate data
  validate_files(
    path,
    expected_suffix = "dat"
  )

  # Load data
  data <- vroom::vroom(
    path,
    col_names = FALSE,
    show_col_types = FALSE
  ) |>
    suppressMessages()
  names(data) <- fictrac_headers(ncol(data))

  # Files from 2.03 on keep the time since midnight in column 25; the
  # 24-column layout keeps it in column 22, where the 23-column layout keeps
  # its only timestamp.
  time_ms <- if ("alt_timestamp" %in% names(data)) {
    unwrap_midnight(data$alt_timestamp)
  } else {
    data$timestamp
  }

  data <- data |>
    dplyr::select(c("pos_x", "pos_y", "heading")) |>
    dplyr::mutate(time = (time_ms - time_ms[1]) / 1000, .before = 1) |>
    dplyr::mutate(keypoint = "centroid") |>
    dplyr::rename(
      x = "pos_x",
      y = "pos_y",
      yaw = "heading"
    )

  # Calculate median sampling rate
  median_dt <- data$time |>
    diff() |>
    stats::median()

  sampling_rate <- 1 / median_dt

  # Each path step is the forward/side motion rotated by the heading, so the
  # heading is anicore's yaw: the body axis, from x toward y.
  data <- data |>
    anicore::as_anipoint() |>
    anicore::set_variables(where = list(orientation = c(yaw = "yaw"))) |>
    anicore::set_metadata(
      source = "fictrac",
      filename = basename(path),
      sampling_rate = sampling_rate,
      unit_space = "none",
      unit_time = "s",
      coordinate_system = "cartesian_2d"
    )

  # Modify distance if ball radius is known
  if (!is.null(ball_radius)) {
    data <- data |>
      dplyr::mutate(
        x = .data$x * ball_radius,
        y = .data$y * ball_radius
      )

    data <- data |>
      anicore::set_metadata(
        unit_space = unit_ball_radius
      )
  }

  data
}

#' Column names of a FicTrac `.dat` file, by its number of columns
#'
#' Confirmed against `Trackball::logData()` in FicTrac's `src/Trackball.cpp`:
#' 23 columns up to tag 2.02, 24 from commit 41ab862 (July 2019), which wrote
#' the time since midnight in place of the timestamp and added the time since
#' the last frame, and 25 from commit 7894ebb (tag 2.03), which restored the
#' timestamp and moved the time since midnight to the end.
#'
#' @param n Number of columns in the file.
#' @return A character vector of `n` column names.
#' @keywords internal
#' @noRd
fictrac_headers <- function(n) {
  shared <- c(
    "frame",
    "delta_rot_cam_x",
    "delta_rot_cam_y",
    "delta_rot_cam_z",
    "delta_rot_error",
    "delta_rot_lab_x",
    "delta_rot_lab_y",
    "delta_rot_lab_z",
    "abs_rot_cam_x",
    "abs_rot_cam_y",
    "abs_rot_cam_z",
    "abs_rot_lab_x",
    "abs_rot_lab_y",
    "abs_rot_lab_z",
    "pos_x",
    "pos_y",
    "heading",
    "direction",
    "speed",
    "movement_x",
    "movement_y"
  )
  timestamps <- switch(
    as.character(n),
    "23" = c("timestamp", "seq_num"),
    # Column 22 holds the time since midnight, which 25-column files keep as
    # their alt. timestamp.
    "24" = c("alt_timestamp", "seq_num", "delta_timestamp"),
    "25" = c("timestamp", "seq_num", "delta_timestamp", "alt_timestamp"),
    cli::cli_abort(c(
      "A FicTrac {.file .dat} file has 23, 24 or 25 columns.",
      "x" = "This one has {n}."
    ))
  )
  c(shared, timestamps)
}

#' Keep a time since midnight running forward past midnight
#'
#' Where the time drops by more than twelve hours between two rows, the clock
#' has passed midnight, so a day is added to it from that row on.
#'
#' @param ms Numeric vector of times in ms since midnight.
#' @return `ms`, with a day added after each midnight.
#' @keywords internal
#' @noRd
unwrap_midnight <- function(ms) {
  day <- 24 * 60 * 60 * 1000
  ms + day * cumsum(c(0, diff(ms) < -day / 2))
}
