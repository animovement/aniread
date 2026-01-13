#' Read centroid tracking data from Bonsai
#'
#' @description Read a Bonsai data frame
#'
#' @param path Path to a Bonsai data file
#'
#' @return a movement dataframe
#'
#' @export
read_bonsai <- function(path) {
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
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = "bonsai",
      filename = basename(path),
      start_datetime = data$time[[1]]
    ) |>
    dplyr::mutate(time = as.numeric(.data$time - min(.data$time, na.rm = TRUE)))
  return(data)
}
