#' Read projected FicTrac data
#'
#' This helper loads a FicTrac ``*.dat`` file, keeps only the timestamp and
#' 2‑D position columns, converts the timestamps to seconds, and returns the
#' result as an **aniframe** object.  If the physical ball radius is supplied,
#' the positions are scaled accordingly and the spatial unit metadata is set.
#'
#' @param path Character. Path to the FicTrac ``*.dat`` file.
#' @param ball_radius Numeric (optional). Physical radius of the tracking ball.
#'   When supplied the ``x`` and ``y`` coordinates are multiplied by this value.
#' @param unit_ball_radius Character. Unit of ``ball_radius`` (e.g., `"cm"` or
#'   `"mm"`). Defaults to `"cm"`. Ignored when ``ball_radius`` is `NULL`.
#'
#' @return An **aniframe** object with columns `time`, `x`, and `y`.  Metadata
#'   includes the source (`"fictrac"`), original filename, sampling rate,
#'   time unit (`"s"`), space unit (either `"none"` or the value of
#'   `unit_ball_radius`), and a Cartesian 2‑D coordinate system.
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

  # Headers
  fictrac_headers <- c(
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
    "movement_y",
    "timestamp",
    "seq_num",
    "delta_timestamp",
    "alt_timestamp"
  )

  # Load data
  data <- vroom::vroom(
    path,
    col_names = FALSE,
    show_col_types = FALSE
  ) |>
    suppressMessages()
  names(data) <- fictrac_headers

  data <- data |>
    dplyr::select(c("alt_timestamp", "pos_x", "pos_y")) |>
    dplyr::mutate(
      alt_timestamp = (.data$alt_timestamp -
        dplyr::first(.data$alt_timestamp)) /
        1000,
      keypoint = "centroid"
    ) |>
    dplyr::rename(
      time = "alt_timestamp",
      x = "pos_x",
      y = "pos_y"
    )

  # Calculate median sampling rate
  median_dt <- data$time |>
    diff() |>
    stats::median()

  sampling_rate <- 1 / median_dt

  # Init metadata
  data <- data |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
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
      aniframe::set_metadata(
        unit_space = unit_ball_radius
      )
  }

  data
}
