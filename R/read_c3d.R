read_c3d <- function(path) {
  # Check c3dr is installed
  check_c3dr()

  # Validate files
  validate_files(path, expected_suffix = "c3d")

  # Read data
  all_data <- c3dr::c3d_read(path)

  data <- c3dr::c3d_data(all_data, format = "longest") |>
    tidyr::pivot_wider(
      values_from = "value",
      names_from = "type"
    ) |>
    dplyr::rename(keypoint = "point", time = "frame") |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = all_data$parameters$MANUFACTURER$SOFTWARE,
      source_version = paste(
        all_data$parameters$MANUFACTURER$VERSION,
        collapse = "."
      ),
      filename = basename(path),
      unit_time = "frame",
      unit_space = all_data$parameters$POINT$UNITS
    ) |>
    dplyr::mutate(time = .data$time - 1) |>
    aniframe::set_sampling_rate(all_data$header$framerate)

  data
}
