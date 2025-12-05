#' Calibrate trackball from raw sensor file
#'
#' Reads a calibration recording and computes calibration values. Spin the ball
#' a known number of times in one direction while recording.
#'
#' @param path Path to calibration CSV file.
#' @param ball_diameter Diameter of the trackball in desired output units (e.g., mm or cm).
#' @param ball_rotations Number of complete rotations performed.
#' @param col_dx Column name for x-axis values.
#' @param col_dy Column name for y-axis values.
#'
#' @return A list with two elements:
#'   - `counts_per_rotation`: Sensor counts per full rotation (for `ball_calibration` in `read_trackball`).
#'   - `calibration_factor`: Distance per sensor count (for `set_unit_distance`).
#' @export
calibrate_trackball <- function(
  path,
  ball_diameter,
  ball_rotations,
  col_dx = "x",
  col_dy = "y"
) {
  data <- vroom::vroom(path, delim = ",", show_col_types = FALSE) |>
    suppressMessages()

  total_x <- sum(data[[col_dx]], na.rm = TRUE)
  total_y <- sum(data[[col_dy]], na.rm = TRUE)
  total_counts <- max(abs(total_x), abs(total_y))

  counts_per_rotation <- total_counts / ball_rotations
  circumference <- pi * ball_diameter
  calibration_factor <- circumference / counts_per_rotation

  list(
    counts_per_rotation = counts_per_rotation,
    calibration_factor = calibration_factor
  )
}
