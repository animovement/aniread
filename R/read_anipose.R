#' Read Anipose 3D pose estimation data
#'
#' Reads CSV files output by Anipose's 3D triangulation pipeline and converts
#' them into aniframe format. The function handles the pivot from wide format
#' (one column per keypoint-coordinate combination) to long format with separate
#' rows for each keypoint at each time point.
#'
#' @param path Character string specifying the path to an Anipose CSV file.
#'   Typically these are found in the `pose-3d` directory of your Anipose output.
#' @param unit_space Character string specifying the spatial units of the
#'   coordinates. This should match the units you used for your calibration board
#'   dimensions (e.g., "mm", "cm", "m"). Default is "mm".
#'
#' @return An aniframe (tibble) with the following columns:
#'   * `time`: Frame number, Anipose's `fnum`, with the first frame of the
#'     video at 0; see "Time" in [read_dataset()]
#'   * `keypoint`: Name of the tracked body part
#'   * `x`, `y`, `z`: 3D coordinates in the specified units
#'   * `confidence`: Mean detection confidence across cameras (0-1 scale)
#'
#'   The aniframe includes metadata about the data source, filename, spatial
#'   units, and coordinate system.
#'
#' @section Anipose Data Structure:
#' Anipose outputs CSV files with columns like `bodypart_x`, `bodypart_y`,
#' `bodypart_z`, `bodypart_error`, `bodypart_ncams`, and `bodypart_score` for
#' each tracked keypoint. The coordinates are in whatever units you specified
#' for your calibration board dimensions.
#'
#' @references
#' - Karashchuk, P., Rupp, K. L., Dickinson, E. S., Walling-Bell, S., Sanders,
#'   E., Azim, E., Brunton, B. W., & Tuthill, J. C. (2021). Anipose: A toolkit
#'   for robust markerless 3D pose estimation. *Cell Reports*, 36(13), 109730.
#'   \doi{10.1016/j.celrep.2021.109730}.
#'
#' @examples
#' path <- system.file("extdata", "anipose.csv", package = "aniread")
#'
#' # Read anipose data with default millimeter units
#' read_anipose(path)
#'
#' # Read with centimeter units
#' read_anipose(path, unit_space = "cm")
#'
#'
#' @export
read_anipose <- function(path, unit_space = "mm") {
  # Validate files
  validate_files(path)

  # Read data
  data <- vroom::vroom(path) |>
    suppressMessages()

  # Handle empty file
  if (nrow(data) == 0) {
    added_na <- TRUE
    data[1, ] <- NA
  } else {
    added_na <- FALSE
  }

  # Remove unneeded columns
  last_score_col <- max(which(endsWith(names(data), "_score")))
  data <- data |>
    dplyr::select(1:dplyr::all_of(last_score_col), "fnum") |>
    dplyr::relocate("fnum", .before = 1) |>
    dplyr::rename(time = "fnum")

  # Wrangle into aniframe format
  data <- data |>
    tidyr::pivot_longer(
      cols = 2:ncol(data),
      values_to = "values",
      names_sep = "_",
      names_to = c("keypoint", "coordinate")
    ) |>
    dplyr::filter(!.data$coordinate %in% c("ncams", "error")) |>
    tidyr::pivot_wider(
      id_cols = c("time", "keypoint"),
      values_from = "values",
      names_from = "coordinate"
    ) |>
    dplyr::rename(confidence = "score") |>
    anicore::as_anipoint()

  # Set metadata
  data <- data |>
    anicore::set_metadata(
      source = "anipose",
      filename = basename(path),
      unit_space = unit_space,
      coordinate_system = "cartesian_3d"
    )

  # Remove col again if it was empty
  if (added_na == TRUE) {
    data <- data[0, ]
  }

  data
}
