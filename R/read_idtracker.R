#' Read idtracker.ai data
#'
#' idtracker.ai stores trajectories in image (top-left) coordinates; the
#' reader reflects y so the returned aniframe is in the conventional
#' `bottom_left` origin. For h5 files the frame height is read from the
#' file, as described below. CSV exports do not include the frame
#' height, so pass `video_height` explicitly to get an accurate flip
#' (otherwise `max(y)` is used as a fallback).
#'
#' An h5 file also records, as attributes of its root, how the recording
#' was tracked, and the reader keeps what has a place in the metadata:
#'
#' * `version`, the idtracker.ai version that tracked it, becomes the
#'   `source_version` metadata field.
#' * `frames_per_second`, the frame rate of the video, becomes the
#'   `sampling_rate` metadata field. `time` stays the frame number counted
#'   from 1, so `unit_time` is still `"frame"`; the frame rate is what
#'   converts it to seconds.
#' * `height`, the height of the video frame, is what y is reflected
#'   around, unless `video_height` is given. A `height` dataset is used
#'   when there is no such attribute.
#'
#' Both fields stay `NA` when the file does not record them. The CSV
#' export keeps these in a separate `attributes.json` rather than in
#' `trajectories.csv`, so a frame read from the CSV has neither
#' `source_version` nor `sampling_rate`; set them with
#' [anicore::set_metadata()].
#'
#' The CSV export's time column (`seconds`, or `time` in newer releases) is
#' the time in seconds, so a frame read from it has `unit_time` `"s"`, where
#' one read from the h5 has `"frame"`.
#'
#' @param path Path to an idtracker.ai data frame
#' @param path_probabilities Path to a csv file with probabilities. Only needed if you are reading csv files as they are included in h5 files.
#' @param version idtracker.ai version. Currently only v6 output is implemented
#' @param video_height Optional numeric height of the source video frame in
#'   pixels. Overrides the value read from the h5 file when both are
#'   available.
#'
#' @return a movement dataframe
#' @examples
#' path <- system.file("extdata", "idtracker.csv", package = "aniread")
#' read_idtracker(path)
#' @export
read_idtracker <- function(
  path,
  path_probabilities = NULL,
  version = 6,
  video_height = NULL
) {
  # Needs to check the file extension
  # If probabilites are given, extension needs to be csv
  validate_files(path, expected_suffix = c("csv", "h5"))
  if (!is.null(path_probabilities) && get_file_ext(path) == "h5") {
    cli::cli_warn(
      "You supplied a h5 file and probabilities in csv; the h5 data already contains the probabilities, so we only the h5 data."
    )
  }
  if (get_file_ext(path) == "csv") {
    data <- read_idtracker_csv(path, path_probabilities, version = version)
    recorded <- list(source_version = NA_character_, sampling_rate = NA_real_)
    unit_time <- "s"
  } else if (get_file_ext(path) == "h5") {
    data <- read_idtracker_h5(path, version = version)
    recorded <- read_idtracker_h5_attributes(path)
    unit_time <- "frame"
    if (is.null(video_height) && !is.na(recorded$height)) {
      video_height <- recorded$height
    }
    if (is.null(video_height)) {
      video_height <- tryCatch(
        as.numeric(rhdf5::h5read(path, "height")),
        error = function(e) NULL
      )
    }
  }

  # Init metadata
  data <- data |>
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = "idtrackerai",
      source_version = recorded$source_version,
      filename = basename(path),
      unit_space = "px",
      unit_time = unit_time,
      sampling_rate = recorded$sampling_rate
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  return(data)
}

#' What an idtracker.ai h5 records about the recording
#'
#' idtracker.ai writes the scalars of its output as attributes of the root
#' group and the arrays as datasets. Of the attributes, `version`,
#' `frames_per_second` and `height` have a place in the metadata; the rest
#' (`video_paths`, `body_length`, `length_unit`, the accuracy estimates and
#' `identities_labels`) have none.
#'
#' @return A list of `source_version` (a string), `sampling_rate` and
#'   `height` (positive numbers), each `NA` when the file does not record a
#'   usable value.
#' @noRd
read_idtracker_h5_attributes <- function(path) {
  attrs <- rhdf5::h5readAttributes(path, "/")
  list(
    source_version = idtracker_string(attrs$version),
    sampling_rate = idtracker_positive_number(attrs$frames_per_second),
    height = idtracker_positive_number(attrs$height)
  )
}

#' A single non-empty string from an h5 attribute, or `NA`
#' @noRd
idtracker_string <- function(x) {
  x <- as.vector(x)
  if (rlang::is_string(x) && nzchar(x)) x else NA_character_
}

#' A single positive, finite number from an h5 attribute, or `NA`
#' @noRd
idtracker_positive_number <- function(x) {
  x <- as.vector(x)
  if (is.numeric(x) && length(x) == 1 && is.finite(x) && x > 0) {
    as.numeric(x)
  } else {
    NA_real_
  }
}

#' @inheritParams read_idtracker
#' @keywords internal
read_idtracker_csv <- function(path, path_probabilities, version = 6) {
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages() |>
    janitor::clean_names() |>
    rename_idtracker_time_column()

  data <- data |>
    tidyr::pivot_longer(
      cols = 2:ncol(data),
      names_to = c("coordinate", "individual"),
      names_sep = "(?<=[A-Za-z])(?=[0-9])",
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("time", "individual"),
      names_from = "coordinate",
      values_from = "val"
    ) |>
    dplyr::mutate(individual = factor(.data$individual))

  if (!is.null(path_probabilities)) {
    probs <- read_idtracker_probabilities(path_probabilities)
    data <- dplyr::left_join(data, probs, by = c("individual", "time"))
  }

  # Convert NaN to NA
  data <- data |>
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      ~ ifelse(is.nan(.), NA, .)
    )) |>
    dplyr::mutate(
      individual = factor(.data$individual),
      keypoint = factor("centroid")
    ) |>
    dplyr::relocate("keypoint", .after = "individual")

  return(data)
}

#' @inheritParams read_idtracker
#' @keywords internal
read_idtracker_probabilities <- function(path) {
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages() |>
    janitor::clean_names() |>
    rename_idtracker_time_column()

  data <- data |>
    tidyr::pivot_longer(
      cols = 2:ncol(data),
      names_to = c("placeholder", "individual"),
      names_sep = "(?<=[A-Za-z])(?=[0-9])",
      values_to = "confidence"
    ) |>
    dplyr::select(-"placeholder")
  data
}

# idtracker.ai renamed the leading time column from `seconds` to `time`
# in newer releases. Accept either, normalising to `time`.
#' @keywords internal
rename_idtracker_time_column <- function(data) {
  if ("seconds" %in% names(data) && !"time" %in% names(data)) {
    data <- dplyr::rename(data, time = "seconds")
  }
  data
}

#' @inheritParams read_idtracker
#' @keywords internal
read_idtracker_h5 <- function(path, version = version) {
  # Check that rhdf5 is installed
  check_rhdf5()

  traj_dimensions <- rhdf5::h5ls(path) |>
    dplyr::as_tibble(.name_repair = "unique") |>
    dplyr::filter(.data$name == "trajectories") |>
    dplyr::pull(dim) |>
    strsplit(" x ")

  n_individuals <- traj_dimensions[[1]][2] |> as.numeric()

  data <- data.frame()
  for (i in 1:n_individuals) {
    trajectories <- rhdf5::h5read(path, "trajectories")[, i, ] |>
      t() |>
      dplyr::as_tibble(.name_repair = "unique") |>
      suppressMessages() |>
      dplyr::rename(x = "...1", y = "...2")

    probs <- rhdf5::h5read(path, "id_probabilities")[, i, ] |>
      dplyr::as_tibble(.name_repair = "unique") |>
      dplyr::rename(confidence = "value")

    data_temp <- dplyr::bind_cols(trajectories, probs) |>
      dplyr::mutate(
        individual = factor(i),
        keypoint = factor("centroid"),
        time = dplyr::row_number()
      )

    data <- dplyr::bind_rows(data, data_temp)
  }

  data <- data |>
    # Convert NaN to NA
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      ~ ifelse(is.nan(.), NA, .)
    )) |>
    dplyr::relocate("keypoint", .before = "x") |>
    dplyr::relocate("individual", .before = "keypoint") |>
    dplyr::relocate("time", .before = "individual") |>
    dplyr::mutate(
      individual = factor(.data$individual),
      keypoint = factor(.data$keypoint)
    )
  return(data)
}
