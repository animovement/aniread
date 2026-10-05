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
#' The axes are taken from the file's `space` coordinate, so a 2D dataset
#' gives `x` and `y` and a 3D one `x`, `y` and `z`. The `confidence`
#' variable becomes the `confidence` column.
#'
#' The file's root attributes describe the recording, and the reader keeps
#' what has a place in the metadata:
#'
#' * `source_software` becomes `source`, and the name of `source_file`
#'   becomes `filename`.
#' * `time_unit` becomes `unit_time`. movement writes `"seconds"` when it was
#'   given the frame rate and `"frames"` when it was not; these become `"s"`
#'   and `"frame"`.
#' * `fps` becomes `sampling_rate`. movement writes it only when it was
#'   given one, so a file whose time is in frames leaves `sampling_rate`
#'   `NA`. Set it with [anicore::set_metadata()] if you know it.
#'
#' @export
read_movement <- function(path, video_height = NULL) {
  # Check for rhdf5
  check_rhdf5()

  # Validate file
  validate_files(path, expected_suffix = c("nc", "h5"))

  # h5ls(path)
  metadata <- rhdf5::h5readAttributes(path, "/")

  unit_time <- movement_unit_time(metadata$time_unit)
  sampling_rate <- movement_sampling_rate(metadata$fps)

  individuals <- as.vector(rhdf5::h5read(path, "individuals"))
  keypoints <- as.vector(rhdf5::h5read(path, "keypoints"))
  axes <- as.vector(rhdf5::h5read(path, "space"))
  time <- as.vector(rhdf5::h5read(path, "time"))
  position <- rhdf5::h5read(path, "position")
  confidence <- rhdf5::h5read(path, "confidence")

  # rhdf5 reverses movement's (time, space, keypoints, individuals) order
  dimnames(position) <- list(
    individual = individuals,
    keypoint = keypoints,
    coord = axes,
    time_idx = seq_along(time)
  )
  dimnames(confidence) <- list(
    individual = individuals,
    keypoint = keypoints,
    time_idx = seq_along(time)
  )

  confidence <- as.data.frame.table(confidence, responseName = "confidence") |>
    dplyr::as_tibble() |>
    dplyr::mutate(time_idx = as.integer(as.character(.data$time_idx)))

  data <- as.data.frame.table(position, responseName = "value") |>
    dplyr::as_tibble() |>
    dplyr::mutate(time_idx = as.integer(as.character(.data$time_idx))) |>
    tidyr::pivot_wider(names_from = "coord", values_from = "value") |>
    dplyr::left_join(
      confidence,
      by = c("individual", "keypoint", "time_idx")
    ) |>
    dplyr::mutate(time = time[.data$time_idx]) |>
    dplyr::select(
      "individual",
      "keypoint",
      "time",
      tidyselect::all_of(axes),
      "confidence"
    ) |>
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = metadata$source_software,
      filename = basename(metadata$source_file),
      unit_time = unit_time,
      unit_space = "px"
    )

  if (!is.na(sampling_rate)) {
    data <- anicore::set_metadata(data, sampling_rate = sampling_rate)
  }

  reflect_to_bottom_left(data, video_height = video_height)
}

#' Map movement's time unit onto anicore's
#'
#' @param time_unit The `time_unit` root attribute, or `NULL` when absent.
#'
#' @return One of anicore's `unit_time` levels: `"s"` for movement's
#'   `"seconds"`, `"frame"` for its `"frames"`, otherwise `"unknown"`.
#' @noRd
movement_unit_time <- function(time_unit) {
  time_unit <- as.vector(time_unit)
  if (length(time_unit) != 1 || is.na(time_unit)) {
    return("unknown")
  }
  units <- c(seconds = "s", frames = "frame")
  if (time_unit %in% names(units)) {
    return(units[[time_unit]])
  }
  cli::cli_warn(c(
    "movement time unit {.val {time_unit}} has no equivalent in anicore.",
    "i" = "Setting {.field unit_time} to {.val unknown}."
  ))
  "unknown"
}

#' Sampling rate from movement's fps
#'
#' @param fps The `fps` root attribute, or `NULL` when absent.
#'
#' @return The rate in Hz, or `NA` when the file records no positive rate.
#' @noRd
movement_sampling_rate <- function(fps) {
  fps <- suppressWarnings(as.numeric(fps))
  if (length(fps) != 1 || !is.finite(fps) || fps <= 0) {
    return(NA_real_)
  }
  fps
}
