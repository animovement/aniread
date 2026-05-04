#' Read data exported from the movement Python package
#'
#' Imports pose estimation data from netCDF/HDF5 files created by the
#' [movement](https://movement.neuroinformatics.dev/) Python package.
#'
#' @param path Path to an HDF5 file (`.nc` or `.h5`) exported from movement.
#' @param video_height Optional numeric height of the source video frame
#'   in pixels. movement does not currently store this in the netCDF
#'   attributes, so without it `max(y)` is used as a fallback when
#'   reflecting to `bottom_left`.
#'
#' @return An aniframe
#'
#' @details
#' The movement package stores pose estimation data in a specific netCDF/HDF5 structure
#' with datasets for individuals, keypoints, position coordinates, confidence
#' scores, and time. This function reads that structure and reshapes it into
#' a tidy aniframe format. The underlying tracking software outputs
#' image (top-left) coordinates, so the reader reflects y to
#' `bottom_left` before returning.
#'
#' @export
read_movement <- function(path, video_height = NULL) {
  # Check for rhdf5
  check_rhdf5()

  # Validate file
  validate_files(path, expected_suffix = c("nc", "h5"))

  # h5ls(path)
  metadata <- rhdf5::h5readAttributes(path, "/")

  # Temporary unit workaround until https://github.com/animovement/aniframe/issues/45 is solved
  if (metadata$time_unit == "seconds") {
    metadata$time_unit = "s"
  }

  #
  individuals <- rhdf5::h5read(path, "individuals")
  keypoints <- rhdf5::h5read(path, "keypoints")
  position <- rhdf5::h5read(path, "position")
  confidence <- rhdf5::h5read(path, "confidence")
  space <- rhdf5::h5read(path, "space")
  time <- rhdf5::h5read(path, "time")

  dimnames(position) <- list(
    individual = individuals,
    keypoint = keypoints,
    coord = c("x", "y"),
    time_idx = seq_along(time)
  )

  data <- as.data.frame.table(position, responseName = "value") |>
    dplyr::as_tibble() |>
    dplyr::mutate(time_idx = as.integer(as.character(.data$time_idx))) |>
    tidyr::pivot_wider(names_from = "coord", values_from = "value") |>
    dplyr::mutate(time = time[.data$time_idx]) |>
    dplyr::select("individual", "keypoint", "time", "x", "y") |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = metadata$source_software,
      filename = basename(metadata$source_file),
      unit_time = metadata$time_unit,
      unit_space = "px",
      sampling_rate = as.numeric(metadata$fps)
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  data
}
