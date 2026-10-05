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
#' * `width`, the width of the video frame, written by newer releases,
#'   becomes the x extent in the `axis_extents` metadata field.
#' * `identities_labels`, the names of the identities, which can be changed
#'   in idtracker.ai's validator, name the individuals. idtracker.ai writes
#'   `"1"`, `"2"`, ... when none were set, which are also the names used
#'   when the file has no usable labels (one distinct, non-empty label per
#'   individual).
#'
#' `source_version` and `sampling_rate` stay `NA` when the file does not
#' record them, and no x extent is recorded without a `width`.
#'
#' The CSV export keeps these in a separate `attributes.json` rather than in
#' `trajectories.csv`, and the reader does not read it, so a frame read from
#' the CSV has no `source_version`; set it with [anicore::set_metadata()].
#' Its time column (`seconds`, or `time` in newer releases) is the time in
#' seconds, so `unit_time` is `"s"`, where a frame read from the h5 has
#' `"frame"`. The time column still states the frame rate: idtracker.ai
#' writes one row per frame, with the time as the row number divided by the
#' frame rate, rounded to 1 ms. The reader takes the rate from the rows over
#' the time they span, or the whole number nearest to it when that fits every
#' row as well, and sets it as `sampling_rate`. It is left `NA` when the
#' times are not evenly spaced.
#'
#' When idtracker.ai could not read the video's frame rate, it writes the
#' CSV export without a time column, and `frames_per_second` as `null` in
#' `attributes.json`. `time` is then the row number, counted from 1 as the
#' h5 reader counts frames, `unit_time` is `"frame"`, and `sampling_rate` is
#' `NA`. Set the rate with [anicore::set_metadata()] if you know it.
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
    recorded <- list(
      source_version = NA_character_,
      sampling_rate = NA_real_,
      width = NA_real_
    )
    if (idtracker_csv_has_time(path)) {
      # One row per frame, so the row number is the frame number.
      times <- sort(unique(data$time))
      recorded$sampling_rate <- rate_from_frames(seq_along(times) - 1, times)
      unit_time <- "s"
    } else {
      unit_time <- "frame"
    }
  } else if (get_file_ext(path) == "h5") {
    data <- read_idtracker_h5(path, version = version)
    recorded <- read_idtracker_h5_attributes(path)
    data$individual <- label_idtracker_individuals(
      data$individual,
      recorded$identities_labels
    )
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
    reflect_to_bottom_left(
      video_height = video_height,
      video_width = if (!is.na(recorded$width)) recorded$width
    )

  return(data)
}

#' What an idtracker.ai h5 records about the recording
#'
#' idtracker.ai writes the scalars of its output as attributes of the root
#' group and the arrays as datasets. Of the attributes, `version`,
#' `frames_per_second`, `height`, `width` and `identities_labels` have a
#' place in the frame; the rest (`video_paths`, `body_length`,
#' `length_unit` and the accuracy estimates) have none.
#'
#' @return A list of `source_version` (a string), `sampling_rate`, `height`
#'   and `width` (positive numbers), each `NA` when the file does not record
#'   a usable value, and `identities_labels` (a character vector, or `NULL`).
#' @noRd
read_idtracker_h5_attributes <- function(path) {
  attrs <- rhdf5::h5readAttributes(path, "/")
  list(
    source_version = idtracker_string(attrs$version),
    sampling_rate = idtracker_positive_number(attrs$frames_per_second),
    height = idtracker_positive_number(attrs$height),
    width = idtracker_positive_number(attrs$width),
    identities_labels = attrs$identities_labels
  )
}

#' Name idtracker.ai individuals by their identity labels
#'
#' The h5 reader numbers individuals by their position in the trajectories,
#' `1` to `n`, which is identity `i` and so `identities_labels[i]`.
#'
#' @param individual The factor of positions.
#' @param labels The `identities_labels` attribute, or `NULL`.
#'
#' @return `individual` relabelled, with the labels as levels in identity
#'   order; unchanged when the labels are not one distinct, non-empty string
#'   per individual.
#' @noRd
label_idtracker_individuals <- function(individual, labels) {
  labels <- as.character(as.vector(labels))
  n <- nlevels(individual)
  usable <- length(labels) == n &&
    !anyNA(labels) &&
    all(nzchar(labels)) &&
    !anyDuplicated(labels)
  if (!usable) {
    return(individual)
  }
  factor(labels[as.integer(as.character(individual))], levels = labels)
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
      cols = !"time",
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
      cols = !"time",
      names_to = c("placeholder", "individual"),
      names_sep = "(?<=[A-Za-z])(?=[0-9])",
      values_to = "confidence"
    ) |>
    dplyr::select(-"placeholder")
  data
}

# idtracker.ai renamed the leading time column from `seconds` to `time`
# in newer releases. Accept either, normalising to `time`. It writes no
# time column when it could not read the video's frame rate; the rows are
# then numbered as the h5 reader numbers frames, from 1.
#' @keywords internal
rename_idtracker_time_column <- function(data) {
  if ("seconds" %in% names(data) && !"time" %in% names(data)) {
    data <- dplyr::rename(data, time = "seconds")
  }
  if (!"time" %in% names(data)) {
    data <- dplyr::mutate(data, time = dplyr::row_number(), .before = 1)
  }
  data
}

#' Whether an idtracker.ai CSV export has a time column
#'
#' idtracker.ai writes `seconds` (`time` in newer releases) as the first
#' column of `trajectories.csv` when it knows the video's frame rate, and
#' no time column when it could not read one.
#'
#' @param path Path to `trajectories.csv`.
#' @return `TRUE` or `FALSE`.
#' @noRd
idtracker_csv_has_time <- function(path) {
  any(c("seconds", "time") %in% peek_header(path))
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
