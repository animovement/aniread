#' Write aniframe data to inTRACKtive CSV format
#'
#' Converts an aniframe to the CSV format required by inTRACKtive for
#' browser-based interactive visualization of tracking data. The function
#' creates unique integer track identifiers from combinations of grouping
#' columns present in the data.
#'
#' @param data An aniframe containing tracking data with required columns
#'   `time`, `x`, and `y`. Optional columns include `z` for 3D data and
#'   grouping columns (`session`, `trial`, `model`, `individual`, `keypoint`).
#' @param filename File path to write the CSV.
#' @param quiet Suppress messages. TRUE/FALSE. Defaults to FALSE.
#'
#' @details
#' inTRACKtive requires tracking data with a unique integer `track_id` for each
#' tracked object. This function automatically generates track IDs from any
#' combination of aniframe grouping columns that are present in the data.
#'
#' The output format includes:
#' - `track_id`: Integer identifier for each unique track
#' - `t`: Time values (renamed from `time`)
#' - `x`, `y`: Spatial coordinates
#' - `z`: Optional third dimension if present
#'
#' The resulting CSV can be converted to inTRACKtive's Zarr format using their
#' command-line tools or Python package.
#'
#' @return Returns the input data unchanged.
#'
#' @references
#' Huijben, T.A.P.M., Anderson, A.G., Sweet, A. et al. (2025). inTRACKtive: a
#' web-based tool for interactive cell tracking visualization. Nature Methods.
#'
#' @examples
#' \dontrun{
#' # Write aniframe to inTRACKtive CSV
#' write_intracktive(my_data, "tracks.csv")
#'
#' # Get formatted data without writing
#' formatted <- write_intracktive(my_data)
#' }
#'
#' @export
write_intracktive <- function(data, filename, quiet = FALSE) {
  # Identify grouping columns that are present
  grouping_cols <- c("session", "trial", "model", "individual", "keypoint")
  present_cols <- grouping_cols[grouping_cols %in% names(data)]

  if (length(present_cols) == 0) {
    cli::cli_abort("No grouping columns found. Expected at least one of: {.val {grouping_cols}}")
  }

  # Create track_id from combination of present grouping columns
  intracktive_data <- data |>
    dplyr::group_by(dplyr::across(dplyr::all_of(present_cols))) |>
    dplyr::mutate(track_id = dplyr::cur_group_id()) |>
    dplyr::ungroup() |>
    dplyr::rename(t = "time") |>
    dplyr::select("track_id", "t", "x", "y", dplyr::any_of("z")) |>
    suppressWarnings()

  # Write to CSV
  vroom::vroom_write(intracktive_data, filename, delim = ",")
  if (quiet == FALSE){
    cli::cli_alert_success("Wrote inTRACKtive CSV to {.path {filename}}")
  }

  invisible(data)
}
