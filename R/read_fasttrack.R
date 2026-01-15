#' Read FastTrack tracking data
#'
#' Reads a FastTrack tracking result file (.txt format) and returns an
#' aniframe with keypoints for head, body, and tail positions.
#'
#' @param path Path to a FastTrack tracking.txt file.
#'
#' @return An aniframe
#'
#' @export
read_fasttrack <- function(path) {
  # Validate file
  validate_files(path)

  data <- vroom::vroom(
    path,
    delim = "\t",
    col_types = vroom::cols(.default = vroom::col_double()),
    progress = FALSE
  )

  # Rename columns for consistent pivoting pattern (value_keypoint)
  data <- data |>
    dplyr::rename(
      x_head = "xHead",
      y_head = "yHead",
      angle_head = "tHead",
      x_body = "xBody",
      y_body = "yBody",
      angle_body = "tBody",
      x_tail = "xTail",
      y_tail = "yTail",
      angle_tail = "tTail",
      majorAxisLength_head = "headMajorAxisLength",
      minorAxisLength_head = "headMinorAxisLength",
      excentricity_head = "headExcentricity",
      majorAxisLength_body = "bodyMajorAxisLength",
      minorAxisLength_body = "bodyMinorAxisLength",
      excentricity_body = "bodyExcentricity",
      majorAxisLength_tail = "tailMajorAxisLength",
      minorAxisLength_tail = "tailMinorAxisLength",
      excentricity_tail = "tailExcentricity"
    )

  # Pivot to long format with one row per keypoint
  data <- data |>
    tidyr::pivot_longer(
      cols = c(
        "x_head",
        "y_head",
        "angle_head",
        "x_body",
        "y_body",
        "angle_body",
        "x_tail",
        "y_tail",
        "angle_tail",
        "majorAxisLength_head",
        "minorAxisLength_head",
        "excentricity_head",
        "majorAxisLength_body",
        "minorAxisLength_body",
        "excentricity_body",
        "majorAxisLength_tail",
        "minorAxisLength_tail",
        "excentricity_tail"
      ),
      names_to = c(".value", "keypoint"),
      names_sep = "_"
    )

  # Rename to aniframe conventions
  data <- data |>
    dplyr::rename(
      time = "imageNumber",
      individual = "id"
    ) |>
    dplyr::mutate(
      keypoint = dplyr::if_else(
        .data$keypoint == "body",
        "centroid",
        .data$keypoint
      ),
      area = dplyr::if_else(.data$keypoint == "centroid", .data$areaBody, NA)
    ) |>
    dplyr::select("individual", "keypoint", "time", "x", "y", "area")

  data <- aniframe::as_aniframe(data) |>
    aniframe::set_metadata(
      source = "fasttrack",
      filename = basename(path)
    )

  data
}
