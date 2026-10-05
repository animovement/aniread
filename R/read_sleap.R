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
#' `individual1`, `individual2`, and so on. In the CSV, where such rows have
#' an empty `track`, they are numbered in the order they appear within each
#' frame. sleap-io (which writes SLEAP's exports from SLEAP 1.6.3 on) gives
#' the instances of an untracked recording the names `track_0`, `track_1`,
#' ... in the `.h5`, and those are kept like any other track name.
#'
#' Both the files SLEAP wrote itself and those written by sleap-io are read.
#' sleap-io can store the `.h5` arrays in another axis order (its `"standard"`
#' preset, or custom axes) and records the order in each dataset's `dims`
#' attribute, which the reader follows; a file without it has SLEAP's
#' original layout. The frame axis of a sleap-io `.h5` runs to the end of the
#' video, so frames after the last detection come back as `NA` rows, as
#' undetected frames always have. Very old `.h5` files have no
#' `point_scores`, and give `NA` confidence.
#'
#' The `.h5` also carries the skeleton the recording was tracked with and a
#' record of the run, and both are kept:
#'
#' * The skeleton is attached as the frame's `keypoint` structure, read as
#'   [read_structure_sleap()] reads it: the nodes become points and the body
#'   edges segments. A file written without edges gives points alone.
#' * The SLEAP version that ran the tracking, from the file's `provenance`
#'   record, becomes the `source_version` metadata field. When the record
#'   names none, a file written by sleap-io gives the sleap-io version that
#'   wrote it instead, as `"sleap-io 0.9.2"` for example. It stays `NA` when
#'   the file records neither.
#'
#' The CSV carries neither, so a frame read from it has no structure and no
#' `source_version`. Attach one with [read_structure()] and
#' [anicore::set_structure()].
#'
#' @param path A SLEAP analysis file, either HDF5 (`.h5`) or CSV.
#' @param video_height Optional numeric height of the source video frame
#'   in pixels.
#'
#' @return a movement dataframe. `time` is SLEAP's frame index, so the first
#'   frame of the video is at `time = 0`; see "Time" in [read_dataset()].
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
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = "sleap",
      source_format = file_ext,
      filename = basename(path)
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  # Only the h5 carries a skeleton and a provenance record (#143).
  if (file_ext == "h5") {
    data <- data |>
      anicore::set_structure(read_sleap_analysis_skeleton(path)) |>
      anicore::set_metadata(source_version = read_sleap_version(path))
  }

  return(data)
}

#' The SLEAP version a SLEAP analysis .h5 was tracked with
#'
#' SLEAP writes a JSON `provenance` record into the export, whose
#' `sleap_version` is the version that ran the tracking. Its
#' `start_timestamp` is when tracking ran, not when the video was recorded,
#' so it is not a `start_datetime`.
#'
#' sleap-io also records the version of itself that wrote the file, as the
#' root attribute `sleap_io_version`. That says which exporter wrote the
#' file rather than which SLEAP tracked it, so it is used only when the
#' provenance names no SLEAP version, and is labelled as sleap-io's.
#'
#' @return A single string, or `NA` when the file has no record of it.
#' @noRd
read_sleap_version <- function(path) {
  version <- read_sleap_provenance_version(path)
  if (!is.na(version)) {
    return(version)
  }
  sleap_io <- rhdf5::h5readAttributes(path, "/")$sleap_io_version
  if (rlang::is_string(sleap_io) && nzchar(sleap_io)) {
    paste("sleap-io", sleap_io)
  } else {
    NA_character_
  }
}

#' @noRd
read_sleap_provenance_version <- function(path) {
  if (!"provenance" %in% rhdf5::h5ls(path)$name) {
    return(NA_character_)
  }
  rlang::check_installed(
    "jsonlite",
    reason = "to read the SLEAP version from an .h5 file."
  )
  provenance <- tryCatch(
    jsonlite::fromJSON(
      as.character(rhdf5::h5read(path, "provenance")),
      simplifyVector = FALSE
    ),
    error = function(e) NULL
  )
  version <- if (is.list(provenance)) provenance$sleap_version
  if (rlang::is_string(version) && nzchar(version)) version else NA_character_
}

#' SLEAP HDF5 Reader
#'
#' Reads `tracks` and `point_scores` into one layout whatever order the file
#' stores their axes in, following the `dims` attribute sleap-io writes.
#' `time` is the position on the frame axis, counting from 0, which is
#' SLEAP's `frame_idx`.
#' @keywords internal
read_sleap_h5 <- function(path) {
  # Check that rhdf5 is installed
  check_rhdf5()

  tracks <- read_sleap_array(path, "tracks", c("frame", "node", "xy", "track"))
  n_frames <- dim(tracks)[[1]]
  n_nodes <- dim(tracks)[[2]]
  n_tracks <- dim(tracks)[[4]]

  # Very old analysis files have no score datasets at all.
  scores <- if ("point_scores" %in% rhdf5::h5ls(path)$name) {
    read_sleap_array(path, "point_scores", c("frame", "node", "track"))
  } else {
    array(NA_real_, dim = c(n_frames, n_nodes, n_tracks))
  }

  node_names <- as.character(rhdf5::h5read(path, "node_names"))

  # SLEAP records the names it tracked under, and they are more use than a
  # position in the file. A recording with no tracks - a single unnamed
  # instance, or predictions that were never tracked - has none, and falls
  # back to the positional name.
  track_names <- as.character(rhdf5::h5read(path, "track_names"))
  individual_names <- if (length(track_names) == n_tracks) {
    track_names
  } else {
    paste0("individual", seq_len(n_tracks))
  }

  # One row per node, frame and track, nodes varying fastest, then frames.
  # Subsetting drops axes of length one, so the shape is restored first.
  flatten <- function(values) {
    values <- array(values, dim = c(n_frames, n_nodes, n_tracks))
    values <- as.vector(aperm(values, c(2, 1, 3)))
    values[is.nan(values)] <- NA
    values
  }
  data <- data.frame(
    # The frame axis starts at the first frame of the video, SLEAP's
    # `frame_idx` 0.
    time = rep(seq_len(n_frames) - 1, each = n_nodes, times = n_tracks),
    individual = rep(individual_names, each = n_nodes * n_frames),
    keypoint = rep(node_names, times = n_frames * n_tracks),
    x = flatten(tracks[,, 1, ]),
    y = flatten(tracks[,, 2, ]),
    confidence = flatten(scores)
  )

  data <- data |>
    dplyr::arrange(.data$time, .data$individual) |>
    dplyr::mutate(
      keypoint = factor(.data$keypoint),
      individual = factor(.data$individual)
    )

  return(data)
}

#' Read a SLEAP analysis array with its axes in a given order
#'
#' SLEAP wrote its analysis arrays in one layout, `tracks` as
#' `(track, xy, node, frame)` and `point_scores` as `(track, node, frame)` in
#' HDF5's row-major order. sleap-io keeps that as its default `"matlab"`
#' preset, but can also write its `"standard"` preset or custom axes, and
#' records each dataset's axes in a `dims` attribute, a JSON list such as
#' `["frame", "track", "node", "xy"]`. The order is taken from there when it
#' is present, and SLEAP's layout is assumed when it is not.
#'
#' rhdf5 reverses the axes of what it reads, so the original layout arrives
#' as `(frame, node, xy, track)`.
#'
#' @param name The dataset.
#' @param axes The axis names, in the order to return them.
#' @return An array with its axes in the order of `axes`.
#' @noRd
read_sleap_array <- function(path, name, axes) {
  values <- rhdf5::h5read(path, name)
  stored <- rhdf5::h5readAttributes(path, name)$dims
  if (is.null(stored)) {
    return(values)
  }
  # The names are plain identifiers, so the JSON list is read without a
  # parser.
  stored <- gsub('"', "", regmatches(stored, gregexpr('"[^"]*"', stored))[[1]])
  stored <- rev(stored)
  if (length(stored) != length(dim(values)) || !setequal(stored, axes)) {
    cli::cli_abort(c(
      "Cannot read the axes of {.field {name}} in {.path {basename(path)}}.",
      "x" = "Its {.field dims} attribute names {.val {rev(stored)}}.",
      "i" = "Expected the axes {.val {axes}}, in any order."
    ))
  }
  aperm(values, match(axes, stored))
}

#' SLEAP analysis CSV reader
#'
#' The CSV export carries one row per instance, with columns `track`,
#' `frame_idx`, `instance.score` and a `.x`/`.y`/`.score` triple per node.
#' Node names are taken from the columns rather than assumed, since a
#' recording has whatever skeleton it was tracked with. Columns are matched
#' by name, so their order does not matter: SLEAP wrote the nodes in
#' skeleton order with `.x`, `.y`, `.score`, where sleap-io sorts them by
#' name.
#'
#' A row with an empty `track` is an instance in no track. It is named
#' `individual1`, `individual2`, ... by its place among the untracked rows of
#' its frame, as [read_sleap_h5()] names the instances of a file without
#' track names. sleap-io writes a frame's user-labelled instances before its
#' predicted ones, and where a track has both in one frame, the
#' user-labelled one is kept, as sleap-io's `.h5` export keeps it.
#'
#' `time` is `frame_idx`, which counts from 0, as [read_sleap_h5()] counts
#' frames, so one recording reads the same from either export. A frame in
#' which an instance was not detected comes back as an all-`NA` row rather
#' than being absent, as it does from the h5, since the CSV holds a row per
#' *instance* and omits those entirely.
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
  # "instance". Anything else that is not a node coordinate or score, such
  # as the video column sleap-io can add, is dropped too.
  data <- data |>
    dplyr::select(
      tidyselect::all_of(c("track", "frame_idx")),
      tidyselect::matches("\\.(x|y|score)$"),
      -tidyselect::any_of("instance.score")
    ) |>
    dplyr::mutate(track = as.character(.data$track)) |>
    dplyr::mutate(slot = dplyr::row_number(), .by = c("frame_idx", "track")) |>
    dplyr::filter(is.na(.data$track) | .data$slot == 1) |>
    dplyr::mutate(
      track = dplyr::coalesce(.data$track, paste0("individual", .data$slot))
    ) |>
    dplyr::select(-"slot")

  node_data <- data |>
    tidyr::pivot_longer(
      cols = -tidyselect::all_of(c("track", "frame_idx")),
      names_to = c("keypoint", "measure"),
      names_pattern = "^(.*)\\.(x|y|score)$"
    ) |>
    tidyr::pivot_wider(names_from = "measure", values_from = "value")

  # A file of user-labelled instances alone has no scores.
  if (!"score" %in% names(node_data)) {
    node_data$score <- NA_real_
  }

  node_data <- node_data |>
    dplyr::rename(confidence = "score") |>
    dplyr::mutate(
      individual = .data$track,
      # frame_idx counts from 0, the first frame of the video.
      time = .data$frame_idx
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
