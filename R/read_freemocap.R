#' Read FreeMoCap motion capture data
#'
#' Imports FreeMoCap motion capture data from a CSV file and converts it to an
#' aniframe format. The function expects data in tidy format (typically files ending in
#' 'by_frame.csv') and will error if other formats are detected.
#'
#' @param path Character string specifying the path to the FreeMoCap CSV file.
#'   Should be a file ending in 'by_frame.csv'.
#'
#' @return An aniframe object with the following characteristics:
#'   * Metadata indicating source as "freemocap"
#'   * Spatial units in millimeters (mm)
#'   * 3D Cartesian coordinate system
#'   * Time units in seconds (if timestamps available) or frames (if not)
#'   * Start datetime in metadata (if timestamps available)
#'
#' @examples
#' \dontrun{
#' # Read FreeMoCap data
#' mocap_data <- read_freemocap("path/to/data_by_frame.csv")
#'
#' # Check metadata
#' aniframe::get_metadata(mocap_data)
#' }
#'
#' @export
read_freemocap <- function(path) {
  validate_files(path)

  data <- vroom::vroom(path) |>
    suppressMessages()

  if (ncol(data) < 10) {
    # There's 8 columns - awaiting extra reprojection_error
    data <- data |>
      dplyr::select(-"timestamp_by_camera") |>
      dplyr::rename(time = "frame")
  } else {
    cli::cli_abort(
      "We only support FreeMoCap data in tidy format - look for a file that ends in 'by_frame.csv'."
    )
  }

  data <- data |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = "freemocap",
      filename = basename(path),
      unit_space = "mm",
      coordinate_system = "cartesian_3d"
    )

  if (!all(is.na(data$timestamp))) {
    # Add timestamp to metadata and keep only elapsed time
    data <- data |>
      aniframe::set_metadata(
        start_datetime = dplyr::first(data$timestamp),
        unit_time = "s"
      ) |>
      dplyr::mutate(
        time = as.numeric(.data$timestamp - dplyr::first(.data$timestamp))
      )
  } else {
    # Else just set unit_time to frame
    data <- data |>
      aniframe::set_metadata(
        unit_time = "frame"
      )
  }

  # Remove timestamp column
  data <- data |>
    dplyr::select(-"timestamp")

  data
}
