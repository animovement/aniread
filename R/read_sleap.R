#' Read SLEAP data
#'
#' Reads either of SLEAP's analysis exports: the HDF5 file, or the CSV
#' with columns `track`, `frame_idx`, `instance.score` and a
#' `.x`/`.y`/`.score` triple per node.
#'
#' SLEAP stores predictions in image (top-left) coordinates; the reader
#' reflects y so the returned aniframe is in the conventional
#' `bottom_left` origin. Neither export includes the source video
#' resolution, so pass `video_height` to get an accurate flip — otherwise
#' `max(y)` is used as a fallback.
#'
#' `individual` is the track name SLEAP recorded, from either export. A
#' recording with no tracks - a single unnamed instance, or predictions that
#' were never tracked - has no names to use, and falls back to
#' `individual1`, `individual2`, and so on.
#'
#' @param path A SLEAP analysis file, either HDF5 (`.h5`) or CSV.
#' @param video_height Optional numeric height of the source video frame
#'   in pixels.
#'
#' @return a movement dataframe
#' @export
read_sleap <- function(path, video_height = NULL) {
  validate_files(path, expected_suffix = c("h5", "csv"))

  file_ext <- get_file_ext(path)
  if (file_ext == "h5") {
    data <- read_sleap_h5(path)
  } else if (file_ext == "csv") {
    data <- read_sleap_csv(path)
  }

  # Init metadata
  data <- data |>
    anicore::as_aniframe() |>
    anicore::set_metadata(
      source = "sleap",
      source_format = file_ext,
      filename = basename(path)
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  return(data)
}

#' SLEAP HDF5 Reader
#' @keywords internal
read_sleap_h5 <- function(path) {
  # Check that rhdf5 is installed
  check_rhdf5()

  n_individuals <- rhdf5::h5ls(path) |>
    dplyr::as_tibble() |>
    dplyr::filter(.data$name == "track_names") |>
    dplyr::pull(dim) |>
    as.numeric()

  if (n_individuals == 0) {
    n_individuals <- 1
  }

  node_names <- rhdf5::h5read(path, "node_names") |>
    as.vector()

  # SLEAP records the names it tracked under, and they are more use than a
  # position in the file. A recording with no tracks - a single unnamed
  # instance, or predictions that were never tracked - has none, and falls
  # back to the positional name.
  track_names <- as.vector(rhdf5::h5read(path, "track_names"))
  individual_names <- if (length(track_names) == n_individuals) {
    as.character(track_names)
  } else {
    paste0("individual", seq_len(n_individuals))
  }

  data <- data.frame()
  for (i in 1:n_individuals) {
    point_scores <- rhdf5::h5read(path, "point_scores")[,, i] |>
      dplyr::as_tibble(.name_repair = "unique") |>
      suppressMessages() |>
      dplyr::rename_with(~node_names) |>
      dplyr::mutate(time = dplyr::row_number()) |>
      tidyr::pivot_longer(
        cols = !"time",
        names_to = "keypoint",
        values_to = "confidence"
      )

    x_coords <- rhdf5::h5read(path, "tracks")[,, 1, i] |>
      dplyr::as_tibble(.name_repair = "unique") |>
      suppressMessages() |>
      dplyr::rename_with(~node_names) |>
      dplyr::mutate(time = dplyr::row_number()) |>
      tidyr::pivot_longer(
        cols = !"time",
        names_to = "keypoint",
        values_to = "x"
      )

    y_coords <- rhdf5::h5read(path, "tracks")[,, 2, i] |>
      dplyr::as_tibble(.name_repair = "unique") |>
      suppressMessages() |>
      dplyr::rename_with(~node_names) |>
      dplyr::mutate(time = dplyr::row_number()) |>
      tidyr::pivot_longer(
        cols = !"time",
        names_to = "keypoint",
        values_to = "y"
      )

    df_temp <- dplyr::left_join(
      x_coords,
      y_coords,
      by = c("time", "keypoint")
    ) |>
      dplyr::left_join(point_scores, by = c("time", "keypoint")) |>
      dplyr::mutate(dplyr::across(
        dplyr::where(is.numeric),
        ~ dplyr::na_if(., NaN)
      )) |>
      dplyr::mutate(individual = individual_names[[i]])

    data <- dplyr::bind_rows(data, df_temp)
  }

  data <- data |>
    dplyr::relocate("individual", .after = "time") |>
    dplyr::arrange(.data$time, .data$individual) |>
    dplyr::mutate(
      keypoint = factor(.data$keypoint),
      individual = factor(.data$individual)
    )

  return(data)
}

#' SLEAP analysis CSV reader
#'
#' The CSV export carries one row per instance, with columns `track`,
#' `frame_idx`, `instance.score` and a `.x`/`.y`/`.score` triple per node.
#' Node names are taken from the columns rather than assumed, since a
#' recording has whatever skeleton it was tracked with.
#'
#' Two things are aligned with [read_sleap_h5()] so that one recording reads
#' the same from either export: `time` counts from 1, where `frame_idx`
#' counts from 0; and a frame in which an instance was not detected comes
#' back as an all-`NA` row rather than being absent, since the CSV holds a
#' row per *instance* and omits those entirely.
#'
#' @param path Path to a SLEAP analysis CSV.
#'
#' @return A data frame with `time`, `individual`, `keypoint`, `x`, `y` and
#'   `confidence`.
#' @keywords internal
read_sleap_csv <- function(path) {
  data <- vroom::vroom(path, delim = ",", show_col_types = FALSE) |>
    suppressMessages()

  required <- c("track", "frame_idx")
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{.path {basename(path)}} is not a SLEAP analysis CSV.",
      "x" = "Missing column{?s}: {.field {missing}}.",
      "i" = "The export has {.field track}, {.field frame_idx},
             {.field instance.score} and a {.field .x}/{.field .y}/{.field .score}
             triple per node."
    ))
  }

  # `instance.score` scores the whole instance rather than a node, and the
  # h5 reader takes its confidence from the per-node scores, so it is
  # dropped here for parity rather than becoming a keypoint called
  # "instance".
  node_data <- data |>
    dplyr::select(-tidyselect::any_of(c("instance.score", "track_score"))) |>
    tidyr::pivot_longer(
      cols = -tidyselect::all_of(c("track", "frame_idx")),
      names_to = c("keypoint", "measure"),
      names_pattern = "^(.*)\\.(x|y|score)$"
    ) |>
    tidyr::pivot_wider(names_from = "measure", values_from = "value") |>
    dplyr::rename(confidence = "score") |>
    dplyr::mutate(
      individual = as.character(.data$track),
      # frame_idx counts from 0; read_sleap_h5() counts from 1.
      time = .data$frame_idx + 1
    ) |>
    dplyr::select(
      "time",
      "individual",
      "keypoint",
      "x",
      "y",
      "confidence"
    )

  # The CSV holds a row per instance, so a frame where an instance was not
  # detected is simply absent. The h5 export carries the full grid, and
  # read_octron() reinstates the same way (#80).
  node_data |>
    tidyr::complete(
      .data$individual,
      time = seq(min(node_data$time), max(node_data$time)),
      .data$keypoint
    ) |>
    dplyr::mutate(
      individual = factor(.data$individual),
      keypoint = factor(.data$keypoint)
    ) |>
    dplyr::arrange(.data$time, .data$individual, .data$keypoint) |>
    dplyr::relocate("individual", .after = "time")
}
