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

  header <- readLines(path, n = 6)
  video_height <- as.numeric(
    trimws(sub(
      "video_height:",
      "",
      grep("^video_height:", header, value = TRUE)
    ))
  )

  data <- vroom::vroom(path, skip = 6, show_col_types = FALSE) |>
    suppressMessages()

  data <- data |>
    dplyr::rename(
      track = "track_id",
      time = "frame_idx",
      x = "pos_x",
      y = "pos_y",
      confidence = "confidence"
    ) |>
    dplyr::select(-dplyr::any_of("frame_counter")) |>
    dplyr::rename(
      centroid_x = "x",
      centroid_y = "y",
      bbox_min_x = "bbox_x_min",
      bbox_min_y = "bbox_y_min",
      bbox_max_x = "bbox_x_max",
      bbox_max_y = "bbox_y_max"
    )

  id_cols <- c("track", "time", "label", "confidence")
  spatial_cols <- c(
    "centroid_x",
    "centroid_y",
    "bbox_min_x",
    "bbox_min_y",
    "bbox_max_x",
    "bbox_max_y"
  )
  descriptor_cols <- setdiff(names(data), c(id_cols, spatial_cols))

  data <- data |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(spatial_cols),
      names_to = c("keypoint", ".value"),
      names_pattern = "(.+)_(x|y)"
    ) |>
    dplyr::mutate(
      dplyr::across(
        dplyr::all_of(descriptor_cols),
        \(col) dplyr::if_else(.data$keypoint == "centroid", col, NA)
      ),
      y = video_height - .data$y
    )

  if (keep_bbox == FALSE) {
    data <- data |>
      dplyr::filter(!.data$keypoint %in% c("bbox_min", "bbox_max"))
  }

  aniframe::as_aniframe(
    data,
    variables_what = c("label", "track", "keypoint")
  ) |>
    aniframe::set_metadata(
      source = "octron",
      filename = basename(path)
    )
}
