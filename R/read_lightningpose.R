#' Read LightningPose data
#'
#' Read csv files from LightningPose (LP). Like DeepLabCut, the source
#' is in image (top-left) coordinates and the reader reflects y to
#' `bottom_left`.
#'
#' @param path Path to a LightningPose data file
#' @param video_height Optional numeric height of the source video frame
#'   in pixels. Falls back to `max(y)` when not supplied.
#'
#' @return an aniframe
#' @examples
#' path <- system.file("extdata", "lightningpose.csv", package = "aniread")
#' read_lightningpose(path)
#' @export
read_lightningpose <- function(path, video_height = NULL) {
  read_deeplabcut(path, video_height = video_height) |>
    anicore::set_metadata(
      source = "lightningpose"
    )
}
