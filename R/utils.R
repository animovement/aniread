#' Reflect image-plane data from a top-left to a bottom-left origin
#'
#' Marks the data's `origin` as `"top_left"` (so the reflection is well
#' defined), applies a user-supplied `video_height` to the `y_height`
#' metadata when given, then calls [aniframe::set_origin()] to reflect
#' y around `y_height`. Used by all readers whose source data is in an
#' image / video coordinate system. When `video_height` is `NULL`, the
#' `y_height` value already on the aniframe (set to `max(y)` by
#' [aniframe::as_aniframe()] when not otherwise populated) is used.
#'
#' @param data An aniframe with image-plane (top-left) coordinates.
#' @param video_height Optional numeric height of the source video frame
#'   in y-axis units. When supplied, takes precedence over the existing
#'   `y_height` metadata.
#'
#' @return An aniframe with reflected y coordinates and `origin` set to
#'   `"bottom_left"`.
#' @keywords internal
reflect_to_bottom_left <- function(data, video_height = NULL) {
  data <- aniframe::set_metadata(data, origin = "top_left")
  if (!is.null(video_height)) {
    data <- aniframe::set_y_height(data, video_height)
  }
  # When y is empty / all-NA, as_aniframe leaves y_height as NA. There's
  # nothing to reflect, so leave the data marked as top_left and return.
  y_height <- aniframe::get_metadata(data, "y_height")
  if (length(y_height) == 0 || is.na(y_height)) {
    return(data)
  }
  aniframe::set_origin(data, "bottom_left")
}

#' @keywords internal
get_file_ext <- function(filename) {
  nameSplit <- strsplit(x = filename, split = "\\.")[[1]]
  return(nameSplit[length(nameSplit)])
}

#' @keywords internal
convert_nan_to_na <- function(data) {
  dplyr::mutate(
    data,
    dplyr::across(dplyr::where(is.numeric), function(x) {
      ifelse(is.nan(x), NA, x)
    })
  )
}

# For TRex files
#' @keywords internal
get_individual_from_path <- function(path) {
  strsplit(tools::file_path_sans_ext(basename(path)), "_(?!.*_)", perl = TRUE)[[
    1
  ]]
}
