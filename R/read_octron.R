#' Read Octron Segmentation Data
#'
#' Reads CSV files exported from Octron video segmentation software.
#' The function parses the metadata header and returns tracking data
#' as an aniframe with centroid positions, bounding box corners, and
#' shape descriptors.
#'
#' @param path Path to the Octron CSV file.
#' @param keep_bbox Keep bounding box coordinates? Default FALSE.
#'
#' @return An aniframe
#'
#' @export
read_octron <- function(path, keep_bbox = FALSE) {
  validate_files(path)

  data <- vroom::vroom(path, skip = 6, show_col_types = FALSE) |>
    suppressMessages()

  data <- data |>
    dplyr::rename(
      individual = "track_id",
      time = "frame_idx",
      x = "pos_x",
      y = "pos_y",
      confidence = "confidence"
    ) |>
    dplyr::mutate(
      keypoint = "centroid",
    ) |>
    dplyr::select(-c("frame_counter", "bbox_area"))

  data <- data |>
    dplyr::select(-"keypoint") |>
    dplyr::rename(
      centroid_x = "x",
      centroid_y = "y",
      bbox_min_x = "bbox_x_min",
      bbox_min_y = "bbox_y_min",
      bbox_max_x = "bbox_x_max",
      bbox_max_y = "bbox_y_max"
    ) |>
    tidyr::pivot_longer(
      cols = c(
        "centroid_x",
        "centroid_y",
        "bbox_min_x",
        "bbox_min_y",
        "bbox_max_x",
        "bbox_max_y"
      ),
      names_to = c("keypoint", ".value"),
      names_pattern = "(.+)_(x|y)"
    ) |>
    dplyr::mutate(
      dplyr::across(
        c("area", "eccentricity", "solidity", "orientation"),
        \(col) dplyr::if_else(.data$keypoint == "centroid", col, NA)
      )
    )

  if (keep_bbox == FALSE) {
    data <- data |>
      dplyr::filter(!.data$keypoint %in% c("bbox_min", "bbox_max"))
  }

  aniframe::as_aniframe(data) |>
    aniframe::set_metadata(
      source = "octron",
      filename = basename(path)
    )
}
