#' Read LightningPose data
#'
#' Read csv files from LightningPose (LP). Like DeepLabCut, the source
#' is in image (top-left) coordinates and the reader reflects y to
#' `bottom_left`.
#'
#' Lightning Pose writes DeepLabCut's csv layout, so the file is read by
#' [read_deeplabcut()]. That includes the output of its Ensemble Kalman
#' Smoother (EKS, scorer `ensemble-kalman_tracker`), which has nine coords
#' per keypoint: `x`, `y` and `likelihood` are read, and the ensemble
#' medians and variances and the posterior variances (`x_ens_median`,
#' `y_ens_median`, `x_ens_var`, `y_ens_var`, `x_posterior_var`,
#' `y_posterior_var`) are not. Its multi-camera 3D output,
#' `multicam_3d_results.csv`, reads as 3D with `x`, `y` and `z`, without
#' confidence and without reflecting y; see [read_deeplabcut()].
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
