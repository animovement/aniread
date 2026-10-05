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
#' @return An aniframe. `time` is movement's `time` coordinate, with the first
#'   frame of the video at 0; see "Time" in [read_dataset()].
#'
#' @details
#' The movement package stores pose estimation data in a specific netCDF/HDF5 structure
#' with datasets for individuals, keypoints, position coordinates, confidence
#' scores, and time. This function reads that structure and reshapes it into
#' a tidy aniframe format. The underlying tracking software outputs
#' image (top-left) coordinates, so the reader reflects y to
#' `bottom_left` before returning.
#'
#' Since version 0.17.0, movement names the dimensions `individual` and
#' `keypoint`; files saved by earlier versions name them `individuals` and
#' `keypoints`. Both read the same way.
#'
#' The axes are taken from the file's `space` coordinate, so a 2D dataset
#' gives `x` and `y` and a 3D one `x`, `y` and `z`. The `confidence`
#' variable becomes the `confidence` column. movement stores it either for
#' each point, with dimensions (`time`, `keypoint`, `individual`), or for
#' each individual, with dimensions (`time`, `individual`); a per-individual
#' score is repeated for every keypoint of that individual.
#'
#' Only poses datasets are read. A bounding boxes dataset (`ds_type`
#' `"bboxes"`) or a multi-view dataset, which has a further `view`
#' dimension, is an error.
#'
#' The file's root attributes describe the recording, and the reader keeps
#' what has a place in the metadata:
#'
#' * `source_software` becomes `source`, and the name of `source_file`
#'   becomes `filename`. A file without `source_file` (a dataset movement
#'   built from arrays rather than loaded from a file) takes the name of the
#'   file read.
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

  metadata <- rhdf5::h5readAttributes(path, "/")
  dims <- movement_dim_names(path, metadata$ds_type)

  unit_time <- movement_unit_time(metadata$time_unit)
  sampling_rate <- movement_sampling_rate(metadata$fps)

  individuals <- as.vector(rhdf5::h5read(path, dims[["individual"]]))
  keypoints <- as.vector(rhdf5::h5read(path, dims[["keypoint"]]))
  axes <- as.vector(rhdf5::h5read(path, "space"))
  time <- as.vector(rhdf5::h5read(path, "time"))
  position <- rhdf5::h5read(path, "position")
  confidence <- rhdf5::h5read(path, "confidence")

  # rhdf5 reverses movement's (time, space, keypoint, individual) order
  pose_dim <- c(length(individuals), length(keypoints), length(axes))
  if (!identical(dim(position), c(pose_dim, length(time)))) {
    cli::cli_abort(c(
      "{.arg path} does not hold a single-view movement poses dataset.",
      "x" = "{.var position} should have the dimensions (time, space,
        keypoint, individual), but has {length(dim(position))} dimensions.",
      "i" = "A multi-view dataset has a further {.var view} dimension; save
        each view to its own file to read it."
    ))
  }
  confidence <- movement_point_confidence(
    confidence,
    pose_dim[1:2],
    length(time)
  )

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
      filename = basename(metadata$source_file %||% path),
      unit_time = unit_time,
      unit_space = "px"
    )

  if (!is.na(sampling_rate)) {
    data <- anicore::set_metadata(data, sampling_rate = sampling_rate)
  }

  reflect_to_bottom_left(data, video_height = video_height)
}

#' Names of movement's individual and keypoint dimensions
#'
#' movement 0.17.0 renamed the dimensions `individuals` and `keypoints` to
#' `individual` and `keypoint`; files saved before keep the plural names.
#'
#' @param path Path to the file.
#' @param ds_type The `ds_type` root attribute, or `NULL` when absent.
#' @param call The environment of the function reporting the error.
#'
#' @return A named character vector, `individual` and `keypoint`, giving the
#'   name each dimension has in the file.
#' @noRd
movement_dim_names <- function(
  path,
  ds_type = NULL,
  call = rlang::caller_env()
) {
  if (identical(as.vector(ds_type), "bboxes")) {
    cli::cli_abort(
      c(
        "{.arg path} holds a movement bounding boxes dataset.",
        "i" = "{.fn read_movement} reads movement poses datasets only."
      ),
      call = call
    )
  }
  names <- unique(rhdf5::h5ls(path)$name)
  rhdf5::h5closeAll()
  found <- c(
    individual = intersect(c("individual", "individuals"), names)[1],
    keypoint = intersect(c("keypoint", "keypoints"), names)[1]
  )
  if (anyNA(found)) {
    cli::cli_abort(
      c(
        "{.arg path} does not hold a movement poses dataset.",
        "x" = "No {.var individual} and {.var keypoint} dimensions (or
        {.var individuals} and {.var keypoints}, as movement named them
        before 0.17.0) were found."
      ),
      call = call
    )
  }
  found
}

#' Confidence for every point
#'
#' movement stores confidence per point, (time, keypoint, individual), or,
#' since 0.17.0, per individual, (time, individual). rhdf5 reads the
#' dimensions in reverse.
#'
#' @param confidence The array read by rhdf5.
#' @param pose_dim The number of individuals and keypoints.
#' @param n_time The number of frames.
#' @param call The environment of the function reporting the error.
#'
#' @return An array with dimensions (individual, keypoint, time), where a
#'   per-individual score is repeated for each of its keypoints.
#' @noRd
movement_point_confidence <- function(
  confidence,
  pose_dim,
  n_time,
  call = rlang::caller_env()
) {
  if (identical(dim(confidence), c(pose_dim, n_time))) {
    return(confidence)
  }
  if (identical(dim(confidence), c(pose_dim[[1]], n_time))) {
    # Recycle (individual, time) over keypoints, then move keypoint second
    by_individual <- array(confidence, c(pose_dim[[1]], n_time, pose_dim[[2]]))
    return(aperm(by_individual, c(1, 3, 2)))
  }
  cli::cli_abort(
    c(
      "movement {.var confidence} has unexpected dimensions.",
      "i" = "Expected (time, keypoint, individual) or (time, individual)."
    ),
    call = call
  )
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
