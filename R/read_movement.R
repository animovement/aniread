#' Read data exported from the movement Python package
#'
#' @export
read_movement <- function(path) {
  # Check for rhdf5
  check_rhdf5()

  # Validate file
  validate_files(path, expected_suffix = c("nc", "h5"))

  # h5ls(path)
  metadata <- h5readAttributes(path, "/")

  # Temporary unit workaround until https://github.com/animovement/aniframe/issues/45 is solved
  if (metadata$time_unit == "seconds") {
    metadata$time_unit = "s"
  }

  #
  individuals <- rhdf5::h5read(path, "individuals")
  keypoints <- rhdf5::h5read(path, "keypoints")
  position <- rhdf5::h5read(path, "position")
  confidence <- rhdf5::h5read(path, "confidence")
  space <- h5read(path, "space")
  time <- h5read(path, "time")

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
    dplyr::mutate(time = time[time_idx]) |>
    dplyr::select("individual", "keypoint", "time", "x", "y") |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = metadata$source_software,
      filename = basename(metadata$source_file),
      unit_time = metadata$time_unit,
      unit_space = "px",
      sampling_rate = as.numeric(metadata$fps)
    )

  data
}
