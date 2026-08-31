#' Turn image-plane data the right way up
#'
#' Image and video tooling counts y downward from the top of the frame,
#' while plotting and maths count it upward. Every reader whose source is
#' an image plane declares the convention its data arrived in and then
#' turns the vertical axis over, so downstream sees one convention.
#'
#' The depth axis is declared too, as `back` — the camera on the near side
#' of the scene. That is the default for these formats rather than
#' something the file says, and it is what [anicore::get_handedness()] and
#' [anicore::get_angle_direction()] are read from, so a recording made
#' through a glass floor should say so with
#' `anicore::set_axis_directions(data, c(z = "forward"))`.
#'
#' `anicore` no longer invents an extent to reflect around, so the reader
#' supplies one: the video height when the source gives it, and otherwise
#' the furthest tracked point, which is the guess `as_aniframe()` used to
#' make on everyone's behalf.
#'
#' @param data An aniframe with image-plane coordinates.
#' @param video_height Optional numeric height of the source video frame
#'   in y-axis units. When supplied, takes precedence over the extent
#'   inferred from the data.
#'
#' @return An aniframe with y counting upward.
#' @keywords internal
reflect_to_bottom_left <- function(data, video_height = NULL) {
  data <- anicore::set_metadata(
    data,
    axis_directions = c(x = "right", y = "down", z = "back")
  )

  extent <- video_height %||% compute_y_extent(data)
  # Nothing to reflect around when y is empty or all-NA, so the data is
  # left as it arrived rather than turned over on a guess.
  if (is.null(extent)) {
    return(data)
  }

  data <- anicore::set_axis_extents(data, stats::setNames(extent, "y"))
  anicore::set_axis_directions(data, c(y = "up"))
}


#' Work out how far the data runs along its vertical axis
#'
#' @param data An aniframe.
#'
#' @return A single positive number, or `NULL` when there is nothing to
#'   measure.
#' @keywords internal
compute_y_extent <- function(data) {
  axes <- anicore::get_axes(data)
  if (!"y" %in% names(axes) || !axes[["y"]] %in% names(data)) {
    return(NULL)
  }

  observed <- suppressWarnings(max(data[[axes[["y"]]]], na.rm = TRUE))
  if (!is.finite(observed) || observed <= 0) {
    return(NULL)
  }
  observed
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

#' Convert Inf to NA in numeric columns
#'
#' The sibling of [convert_nan_to_na()], for sources that mark a missing
#' observation with an infinity rather than a `NaN`. TRex is one: its own
#' documentation masks `np.inf` out before plotting, and its `missing` flag
#' is 1 in exactly those frames.
#'
#' @param data A data frame.
#' @return A data frame with `Inf` and `-Inf` replaced by `NA` in numeric
#'   columns.
#' @keywords internal
convert_inf_to_na <- function(data) {
  dplyr::mutate(
    data,
    dplyr::across(dplyr::where(is.numeric), function(x) {
      ifelse(is.infinite(x), NA, x)
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
