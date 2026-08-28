#' Read centroid tracking data from Bonsai
#'
#' @description Read a Bonsai data frame. Bonsai centroid coordinates
#' come from camera/video pipelines that use image (top-left) origin;
#' the reader reflects y so the returned aniframe is in the
#' conventional `bottom_left` origin. Bonsai workflows are
#' user-defined and the output CSV does not record video resolution,
#' so pass `video_height` to get an accurate flip — otherwise `max(y)`
#' is used as a fallback.
#'
#' @param path Path to a Bonsai data file
#' @param video_height Optional numeric height of the source video frame
#'   in pixels.
#'
#' @return a movement dataframe
#'
#' @examples
#' path <- system.file("extdata", "bonsai.csv", package = "aniread")
#' read_bonsai(path)
#' @export
read_bonsai <- function(path, video_height = NULL) {
  # There can be tracking from multiple ROIs at the same time
  # We need to check everything matches expectations
  # We should be able to use only a single timestamp (should be the same across all ROIs)
  validate_files(path, expected_suffix = "csv")
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages() |>
    convert_nan_to_na() |>
    dplyr::select(tidyselect::contains(c("Timestamp", "Centroid"))) |>
    dplyr::rename(
      time = tidyselect::contains("Timestamp"),
      x = tidyselect::contains("X"),
      y = tidyselect::contains("Y")
    ) |>
    dplyr::mutate(
      keypoint = factor("centroid"),
      individual = factor(NA),
      confidence = as.numeric(NA)
    ) |>
    dplyr::relocate("keypoint", .after = "time") |>
    dplyr::relocate("individual", .after = "time")

  attributes(data)$spec <- NULL
  attributes(data)$problems <- NULL

  # Set aniframe class and metadata
  data <- data |>
    anicore::as_aniframe() |>
    anicore::set_metadata(
      source = "bonsai",
      filename = basename(path),
      start_datetime = data$time[[1]]
    ) |>
    dplyr::mutate(
      time = as.numeric(.data$time - min(.data$time, na.rm = TRUE))
    ) |>
    reflect_to_bottom_left(video_height = video_height)
  return(data)
}
