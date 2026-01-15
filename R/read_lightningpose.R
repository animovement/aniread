#' Read LightningPose data
#'
#' Read csv files from LightningPose (LP).
#'
#' @param path Path to a LightningPose data file
#'
#' @return an aniframe
#' @export
read_lightningpose <- function(path) {
  read_deeplabcut(path) |>
    aniframe::set_metadata(
      source = "lightningpose"
    )
}
