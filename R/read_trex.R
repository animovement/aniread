#' Read TRex Movement Tracking Data
#'
#' @description
#' Reads movement tracking data exported from TRex (Walter & Couzin, 2021),
#' from either of its two exports.
#'
#' The `.npz` export is TRex's native one: a zip of `.npy` arrays, one file
#' per tracked individual, so a whole recording is a vector of paths. It
#' carries the pose keypoints, a per-frame detection probability, the
#' identity, and the recording's frame rate and frame size. The CSV export
#' carries the centroid and midline of a single individual and none of that
#' metadata, so several columns come back `NA`.
#'
#' @param path Character string specifying the path to a TRex CSV file.
#'   The file should contain columns for:
#'   - time
#'   - x and y coordinates for tracked points (e.g., x_head, y_head)
#'   - x and y coordinates for centroid (x_number_wcentroid_cm, y_number_wcentroid_cm)
#'
#' @return A data frame containing movement data with the following columns:
#'   - `time`: Time values from the tracking
#'   - `individual`: Factor. The identity TRex assigned, from the `.npz`
#'     export; `NA` from the CSV export, which does not record it
#'   - `keypoint`: Factor identifying tracked points (e.g., "head", "centroid")
#'   - `x`: x-coordinates in centimeters
#'   - `y`: y-coordinates in centimeters
#'   - `confidence`: Numeric. TRex's per-frame `detection_p` from the `.npz`
#'     export; `NA` from the CSV export, which does not record it
#'
#' @details
#' The function performs several processing steps:
#' 1. Validates the input file format (must be CSV)
#' 2. Reads the data using vroom for efficient processing
#' 3. Cleans column names to a consistent format
#' 4. Restructures the data from wide to long format
#' 5. Initializes metadata fields required for movement data
#'
#' @references
#' Walter, T., & Couzin, I. D. (2021). TRex, a fast multi-animal tracking
#' system with markerless identification, and 2D estimation of posture and
#' visual fields. eLife, 10, e64000.
#'
#' @examples
#' # TRex's native export: one .npz per tracked individual
#' path <- system.file("extdata", "trex_id3.npz", package = "aniread")
#' read_trex(path)
#'
#' \dontrun{
#' # A whole recording is the vector of paths get_sample_data() returns
#' read_trex(get_sample_data("trex"))
#' }
#'
#' @seealso
#' - TRex software: https://trex.run
#'
#' @param format Which export to read. `"auto"` (default) reads it from the
#'   file: the `.npz` export is a zip of `.npy` arrays, the CSV export is not.
#' @param video_height Optional numeric height of the source video frame
#'   in the same spatial units as the tracking output (TRex defaults to
#'   centimetres). The `.npz` export records this as `video_size` and it is
#'   used automatically; TRex's CSV export does not, so without it `max(y)`
#'   is used as a fallback when reflecting to `bottom_left`.
#'
#' @export
read_trex <- function(
  path,
  format = c("auto", "csv", "npz"),
  video_height = NULL
) {
  format <- match.arg(format)
  validate_files(path, expected_suffix = c("csv", "npz"))

  if (format == "auto") {
    format <- if (all(vapply(path, is_npz_file, logical(1)))) "npz" else "csv"
  }

  if (format == "csv") {
    if (length(path) > 1) {
      cli::cli_abort(c(
        "{.arg path} must be a single file for the CSV export.",
        "i" = "Only TRex's {.file .npz} export is written one file per individual."
      ))
    }
    data <- read_trex_csv(path)
    sampling_rate <- NULL
    frame_height <- NULL
  } else {
    data <- read_trex_npz(path)
    # The npz records the frame rate and frame size the CSV export omits, so
    # neither has to be supplied or guessed.
    first <- read_npz(path[[1]])
    sampling_rate <- first[["frame_rate"]]
    frame_height <- trex_frame_height(first)
  }

  # TRex reports `time` in seconds in both exports, so `unit_time` is
  # declared rather than derived. That matters: set_sampling_rate() converts
  # the index when unit_time is "frame" or "unknown", which would divide an
  # already-seconds column by the frame rate.
  data <- data |>
    anicore::as_aniframe() |>
    anicore::set_metadata(
      source = "trex",
      source_format = format,
      filename = basename(path),
      unit_time = "s"
    )

  if (
    !is.null(sampling_rate) &&
      length(sampling_rate) == 1 &&
      is.finite(sampling_rate)
  ) {
    data <- anicore::set_metadata(data, sampling_rate = sampling_rate)
  }

  data |>
    reflect_to_bottom_left(video_height = video_height %||% frame_height)
}

#' The frame height a TRex `.npz` records, in the units of its coordinates
#'
#' `video_size` is in pixels and the coordinates are in centimetres, so the
#' height is scaled by `cm_per_pixel` before it can be reflected around.
#'
#' @param arrays The named list from `read_npz()`.
#'
#' @return A single numeric height, or `NULL` when the file records none.
#' @noRd
trex_frame_height <- function(arrays) {
  size <- arrays[["video_size"]]
  scale <- arrays[["cm_per_pixel"]]
  if (is.null(size) || length(size) < 2 || is.null(scale)) {
    return(NULL)
  }
  size[[2]] * scale
}

#' Read and Process TRex CSV File
#'
#' @description
#' Internal function that handles the actual reading and processing of
#' TRex CSV files. Called by read_trex() after file validation.
#'
#' @param path Character string specifying path to TRex CSV file
#'
#' @return A processed data frame in movement data format
#'
#' @keywords internal
read_trex_csv <- function(path) {
  # Read function
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages() |>
    janitor::clean_names() |>
    dplyr::select(tidyselect::contains(c("x_", "y_", "time"))) |>
    # Which columns a TRex CSV carries is set per run by its `output_fields`
    # parameter, so these are dropped if present rather than required.
    dplyr::select(!tidyselect::any_of(c("vx_cm_s", "vy_cm_s", "timestamp"))) |>
    dplyr::rename(
      x_centroid = "x_number_wcentroid_cm",
      x_head = "x_cm",
      y_centroid = "y_number_wcentroid_cm",
      y_head = "y_cm"
    ) |>
    tidyr::pivot_longer(
      cols = !"time",
      names_sep = "_",
      names_to = c("pos", "keypoint"),
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("time", "keypoint"),
      names_from = "pos",
      values_from = "val"
    ) |>
    dplyr::mutate(
      individual = factor(NA),
      confidence = as.numeric(NA),
      keypoint = factor(.data$keypoint)
    ) |>
    convert_inf_to_na() |>
    dplyr::relocate("individual", .after = "time")

  return(data)
}

#' Read TRex `.npz` output
#'
#' TRex's native per-individual export: one `.npz` per tracked individual,
#' each a zip of `.npy` arrays, one array per field. It carries what the CSV
#' export does not - the pose keypoints, a per-frame detection probability,
#' the identity, and the recording's frame rate and frame size - so several
#' of the CSV reader's `NA` columns are real values here.
#'
#' @param paths Character vector of `.npz` paths. TRex writes one per
#'   individual, so a whole recording is a vector.
#'
#' @return A data frame in movement data format, with one `individual` per
#'   file.
#' @noRd
read_trex_npz <- function(paths) {
  data <- do.call(rbind, lapply(paths, read_trex_npz_file))

  data |>
    dplyr::mutate(
      individual = factor(.data$individual),
      keypoint = factor(.data$keypoint)
    ) |>
    dplyr::relocate("individual", .after = "time")
}

#' Read one TRex `.npz` file
#'
#' @param path Path to a single `.npz`.
#'
#' @return A data frame for one individual.
#' @noRd
read_trex_npz_file <- function(path) {
  arrays <- read_npz(path)
  time <- arrays[["time"]]

  # `X`/`Y` are the centroid TRex reports alongside the pose, already in
  # centimetres where the pose keypoints are in pixels; `cm_per_pixel` is
  # what relates them, and is recorded in the file.
  scale <- arrays[["cm_per_pixel"]] %||% 1
  pose <- extract_trex_pose(arrays)
  if (nrow(pose) > 0) {
    pose$x <- pose$x * scale
    pose$y <- pose$y * scale
  }

  centroid <- data.frame(
    time = time,
    keypoint = "centroid",
    x = arrays[["X"]],
    y = arrays[["Y"]],
    stringsAsFactors = FALSE
  )

  out <- rbind(centroid, pose)
  out$individual <- as.character(arrays[["id"]] %||% NA)
  out$confidence <- rep(
    arrays[["detection_p"]] %||% NA_real_,
    length.out = nrow(out)
  )

  # TRex marks a frame it could not track with Inf rather than NaN, across
  # every field at once - coordinates and detection probability alike. Left
  # alone these propagate through every downstream calculation as Inf rather
  # than dropping out as missing.
  out <- convert_inf_to_na(out)

  out[order(out$time, out$keypoint), , drop = FALSE]
}

#' Pull the pose keypoints out of a TRex `.npz`
#'
#' TRex writes one array per keypoint per axis, named `poseX0`, `poseY0`,
#' `poseX1` and so on. The count is not fixed - it depends on the pose model
#' the recording was tracked with - so the keypoints are discovered from the
#' array names rather than assumed.
#'
#' @param arrays The named list from `read_npz()`.
#'
#' @return A data frame of `time`, `keypoint`, `x`, `y`; zero rows when the
#'   recording carries no pose.
#' @noRd
extract_trex_pose <- function(arrays) {
  empty <- data.frame(
    time = numeric(),
    keypoint = character(),
    x = numeric(),
    y = numeric(),
    stringsAsFactors = FALSE
  )

  indices <- sub(
    "^poseX",
    "",
    grep("^poseX[0-9]+$", names(arrays), value = TRUE)
  )
  indices <- indices[paste0("poseY", indices) %in% names(arrays)]
  if (length(indices) == 0) {
    return(empty)
  }

  indices <- indices[order(as.numeric(indices))]

  do.call(
    rbind,
    lapply(indices, function(i) {
      data.frame(
        time = arrays[["time"]],
        keypoint = paste0("pose", i),
        x = arrays[[paste0("poseX", i)]],
        y = arrays[[paste0("poseY", i)]],
        stringsAsFactors = FALSE
      )
    })
  )
}
