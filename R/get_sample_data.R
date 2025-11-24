#' Download sample tracking data
#'
#' Downloads sample data for different animal tracking software and returns the path
#' to the downloaded file. The function caches the data to avoid repeated downloads.
#'
#' @param source Character string specifying the tracking software. Currently supported:
#'   - "animalta": Data from AnimalTA (single individual, multi-arena)
#'   - "anipose": Mouse paw tracking data
#'   - "bonsai": Tracking data from Bonsai
#'   - "deeplabcut": Mouse tracking from DeepLabCut
#'   - "fictrac": Fictrac sample data (.dat format)
#'   - "freemocap": FreeMoCap test data by frame
#'   - "idtrackerai": Trajectories from idtracker.ai (.h5 format)
#'   - "lightningpose": Mouse tracking from LightningPose
#'   - "sleap": Single mouse EPM tracking from SLEAP (.h5 format)
#'   - "trex": Beetle tracking from TRex
#'
#' @param cache_dir Character string specifying the directory where to cache the downloaded
#'   files. Defaults to a temporary directory using `tempdir()`. Set to a permanent
#'   location to persist data across R sessions.
#'
#' @return Character string with the path to the downloaded file.
#'
#' @details
#' The function downloads sample data from a GitHub repository and caches it locally.
#' If the file already exists in the cache directory, it will use the cached version
#' instead of downloading it again.
#'
#' The data sources are hosted at: https://github.com/animovement/movement-data
#'
#' @examples
#' \dontrun{
#' # Get path to DeepLabCut sample data
#' path <- get_sample_data("deeplabcut")
#'
#' # Read the data with the corresponding reader function
#' data <- read_deeplabcut(path)
#' }
#' @export
get_sample_data <- function(source, cache_dir = tempdir()) {
  # Define available sources and their corresponding URLs
  sources <- list(
    animalta = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/AnimalTA/single_individual_multi_arena.csv",
      filename = "animalta_sample.csv"
    ),
    anipose = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/anipose/mouse_paw.csv",
      filename = "anipose_sample.csv"
    ),
    bonsai = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/bonsai/LI850.csv",
      filename = "bonsai_sample.csv"
    ),
    deeplabcut = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/deeplabcut/mouse_single.csv",
      filename = "deeplabcut_sample.csv"
    ),
    fictrac = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/fictrac/fictrac_sample.dat",
      filename = "fictrac_sample.dat"
    ),
    freemocap = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/freemocap/freemocap_test_data_by_frame.csv",
      filename = "freemocap_sample.csv"
    ),
    idtrackerai = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/idtrackerai/trajectories.h5",
      filename = "idtracker_sample.h5"
    ),
    lightningpose = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/lightningpose/mouse_single.csv",
      filename = "lightningpose_sample.csv"
    ),
    sleap = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/sleap/SLEAP_single-mouse_EPM.analysis.h5",
      filename = "sleap_sample.h5"
    ),
    trex = list(
      url = "https://raw.githubusercontent.com/animovement/movement-data/main/data/trex/beetle.csv",
      filename = "trex_sample.csv"
    )
  )
  # Check if source is provided
  if (missing(source)) {
    cli::cli_abort(
      "Must specify a {.arg source}. Currently supported sources: {.val {names(sources)}}"
    )
  }

  # Check if source is supported
  if (!source %in% names(sources)) {
    cli::cli_abort(c(
      "Source {.val {source}} is not supported.",
      "i" = "Currently supported sources: {.val {names(sources)}}"
    ))
  }

  # Get URL and filename for the specified source
  file_url <- sources[[source]]$url
  filename <- sources[[source]]$filename

  data_path <- file.path(cache_dir, filename)

  if (!file.exists(data_path)) {
    cli::cli_inform("Downloading sample {source} data...")

    # Create cache directory if it doesn't exist
    if (!dir.exists(cache_dir)) {
      dir.create(cache_dir, recursive = TRUE)
    }

    # Try to download the file
    download_success <- try(
      {
        utils::download.file(file_url, destfile = data_path, quiet = TRUE)
      },
      silent = TRUE
    )

    # Check if download failed
    if (inherits(download_success, "try-error")) {
      cli::cli_abort(c(
        "Failed to download sample data.",
        "i" = "Please check your internet connection.",
        "i" = "URL attempted: {.url {file_url}}"
      ))
    }
  }

  return(data_path)
}
