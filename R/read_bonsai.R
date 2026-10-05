#' Read centroid tracking data from Bonsai
#'
#' @description Read a Bonsai data frame. Bonsai centroid coordinates
#' come from camera/video pipelines that use image (top-left) origin;
#' the reader reflects y so the returned aniframe is in the
#' conventional `bottom_left` origin.
#'
#' Bonsai workflows are user-defined, so what the CSV records about the
#' video depends on the workflow. When it writes the image alongside the
#' centroid, every row carries the image's `Size.Width` and `Size.Height`.
#' When all the images in the file have the same size, that is the frame
#' size: y is reflected around its height, and its width and height are
#' recorded as the `axis_extents` of x and y. Otherwise pass `video_height`,
#' or the largest `y` is used as the height and no extent is recorded for x.
#'
#' When the workflow records the blob's `Orientation`, it is kept as
#' `orientation_axis`: the angle of the blob's long axis, in radians from `x`
#' toward `y`, in `(-pi/2, pi/2]`. It is axial — the blob has no front — so it
#' is not declared as the frame's orientation (a `yaw`), and it is turned with
#' `y` when y is reflected.
#'
#' `time` is the seconds elapsed since the first `Timestamp`, so `unit_time`
#' is `"s"`, and the first `Timestamp` itself is kept as `start_datetime`.
#' `sampling_rate` is left `NA`. A Bonsai `Timestamp` is the time the
#' software received each frame, not when the camera captured it, so the
#' intervals between rows vary from frame to frame and do not state the
#' camera's rate. If you know it, set it with [anicore::set_metadata()].
#'
#' @param path Path to a Bonsai data file
#' @param video_height Optional numeric height of the source video frame
#'   in pixels. Takes precedence over the height the file records.
#'
#' @return a movement dataframe
#'
#' @examples
#' path <- system.file("extdata", "bonsai.csv", package = "aniread")
#' read_bonsai(path)
#' @export
read_bonsai <- function(path, video_height = NULL) {
  # There can be tracking from multiple ROIs at the same time
  # We need to check everything matches expectations
  # We should be able to use only a single timestamp (should be the same across all ROIs)
  validate_files(path, expected_suffix = "csv")
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages()
  frame_size <- bonsai_frame_size(data)

  data <- data |>
    anicore::convert_nan_to_na() |>
    dplyr::select(
      tidyselect::contains(c("Timestamp", "Centroid")),
      tidyselect::ends_with(".Orientation")
    ) |>
    dplyr::rename(
      time = tidyselect::contains("Timestamp"),
      x = tidyselect::contains("Centroid.X"),
      y = tidyselect::contains("Centroid.Y"),
      orientation_axis = tidyselect::ends_with(".Orientation")
    ) |>
    dplyr::mutate(
      keypoint = factor("centroid"),
      individual = factor(NA),
      confidence = as.numeric(NA)
    ) |>
    dplyr::relocate("keypoint", .after = "time") |>
    dplyr::relocate("individual", .after = "time")

  attributes(data)$spec <- NULL
  attributes(data)$problems <- NULL

  # Set aniframe class and metadata
  data <- data |>
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = "bonsai",
      filename = basename(path),
      start_datetime = data$time[[1]],
      unit_time = "s"
    ) |>
    dplyr::mutate(
      time = as.numeric(.data$time - min(.data$time, na.rm = TRUE))
    ) |>
    reflect_to_bottom_left(
      video_height = video_height %||% frame_size$height,
      video_width = frame_size$width
    )

  # Reflecting y reverses any angle measured from x toward y; an axial angle
  # is then brought back into (-pi/2, pi/2].
  reflected <- identical(
    unname(anicore::get_axis_directions(data)["y"]),
    "up"
  )
  if (reflected && "orientation_axis" %in% names(data)) {
    turned <- -data$orientation_axis
    data$orientation_axis <- ifelse(turned <= -pi / 2, turned + pi, turned)
  }
  return(data)
}

#' The frame size a Bonsai CSV records
#'
#' A workflow that writes an image writes its `Size.Width` and `Size.Height`
#' (as `Item1.Size.Width` and so on) on every row. The region of interest
#' has its own `RegionOfInterest.Width` and `.Height`, which are not the
#' frame.
#'
#' @param data The CSV as read, before any column is dropped.
#'
#' @return A list of `width` and `height`, each a single positive number
#'   when every image in the file has the same one, and `NULL` when the file
#'   records none or images of different sizes.
#' @noRd
bonsai_frame_size <- function(data) {
  one_size <- function(pattern) {
    values <- unlist(data[grep(pattern, names(data))], use.names = FALSE)
    values <- unique(values[!is.na(values)])
    if (length(values) == 1 && is.numeric(values) && values > 0) {
      values
    } else {
      NULL
    }
  }
  list(
    width = one_size("\\.Size\\.Width$"),
    height = one_size("\\.Size\\.Height$")
  )
}
