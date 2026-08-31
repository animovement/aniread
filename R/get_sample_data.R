#' Download sample tracking data
#'
#' Downloads sample data for different animal tracking software and returns the path
#' to the downloaded file. The function caches the data to avoid repeated downloads.
#'
#' @param source Character string specifying either a tracking software name or a URL.
#'   Currently supported software names:
#'   - "animalta": Data from AnimalTA
#'   - "anipose": Mouse paw tracking data
#'   - "bonsai": Tracking data from Bonsai
#'   - "deeplabcut": Mouse/animal tracking from DeepLabCut (3 datasets)
#'   - "fictrac": Fictrac sample data
#'   - "freemocap": FreeMoCap motion capture test data
#'   - "idtracker": Trajectories from idtracker.ai
#'   - "lightningpose": Mouse tracking from LightningPose (2 datasets)
#'   - "movement": Movement package native format (2 datasets)
#'   - "sleap": Animal tracking from SLEAP (3 datasets)
#'   - "trex": Multi-animal tracking from TRex (2 datasets). The default,
#'     "five-locusts", unpacks to one `.npz` per individual and returns a
#'     vector of paths, which [read_trex()] reads as one recording
#'
#'   Alternatively, provide a URL string (starting with "http://" or "https://")
#'   to download a file from a custom location.
#'
#' @param dataset Character string specifying which dataset to download for sources
#'   that have multiple options. If NULL (default), the first listed dataset is used.
#'   Call `get_sample_data(list_datasets = TRUE)` to see all available options.
#' @param cache_dir Character string specifying the directory where to cache the downloaded
#'   files. Defaults to a temporary directory using `tempdir()`. Set to a permanent
#'   location to persist data across R sessions.
#' @param quiet TRUE/FALSE. TRUE suppresses inform messages.
#' @param list_datasets TRUE/FALSE. If TRUE, prints available sources and datasets.
#'   Can be called with or without specifying a source.
#'
#' @return Character string (or vector) with the path(s) to the downloaded file(s).
#'   For TRex datasets, returns a character vector of paths to the individual tracking
#'   files. For all other sources, returns a single file path. Returns NULL invisibly
#'   if `list_datasets = TRUE`.
#'
#' @details
#' The function downloads sample data and caches it locally. If the file already exists
#' in the cache directory, it will use the cached version instead of downloading again.
#'
#' Some sources have multiple datasets available. The first dataset listed for each
#' source is used by default when `dataset = NULL`.
#'
#' Special handling for TRex datasets:
#' TRex datasets are distributed as zip files containing multiple individual tracking
#' files (one per animal). The function automatically extracts these and returns a
#' vector of paths to the individual files.
#'
#' The predefined data sources are hosted at:
#' - https://gin.g-node.org/neuroinformatics/movement-test-data
#' - https://github.com/animovement/movement-data
#'
#' @examples
#' \dontrun{
#' # See all available sources and datasets
#' get_sample_data(list_datasets = TRUE)
#'
#' # See datasets for a specific source
#' get_sample_data("sleap", list_datasets = TRUE)
#'
#' # Get default dataset for SLEAP
#' path <- get_sample_data("sleap")
#'
#' # Get a specific SLEAP dataset
#' path <- get_sample_data("sleap", dataset = "zebras_drone")
#'
#' # Get TRex data (returns vector of paths to individual files)
#' paths <- get_sample_data("trex")
#'
#' # Download from a custom URL
#' path <- get_sample_data("https://example.com/data/tracking.csv")
#' }
#' @export
get_sample_data <- function(
  source,
  dataset = NULL,
  cache_dir = tempdir(),
  quiet = FALSE,
  list_datasets = FALSE
) {
  # Base URLs for data repositories
  gin_base <- "https://gin.g-node.org/neuroinformatics/movement-test-data/raw/master"
  github_base <- "https://raw.githubusercontent.com/animovement/movement-data/main/data"

  # Define available sources and their corresponding URLs
  sources <- list(
    animalta = list(
      "single-individual" = list(
        url = paste0(
          github_base,
          "/AnimalTA/single_individual_multi_arena.csv"
        ),
        filename = "animalta_single-individual.csv"
      )
    ),
    anipose = list(
      "mouse-paw" = list(
        url = paste0(
          gin_base,
          "/poses/anipose_mouse-paw_anipose-paper.triangulation.csv"
        ),
        filename = "anipose_mouse-paw.csv"
      )
    ),
    bonsai = list(
      "LI850" = list(
        url = paste0(github_base, "/bonsai/LI850.csv"),
        filename = "bonsai_LI850.csv"
      )
    ),
    deeplabcut = list(
      "single-mouse_EPM" = list(
        url = paste0(gin_base, "/poses/DLC_single-mouse_EPM.predictions.h5"),
        filename = "deeplabcut_single-mouse_EPM.h5"
      ),
      "two-mice" = list(
        url = paste0(gin_base, "/poses/DLC_two-mice.predictions.csv"),
        filename = "deeplabcut_two-mice.csv"
      ),
      "single-wasp" = list(
        url = paste0(gin_base, "/poses/DLC_single-wasp.predictions.h5"),
        filename = "deeplabcut_single-wasp.h5"
      )
    ),
    c3d = list(
      "example" = list(
        url = paste0(github_base, "/c3d/example.c3d"),
        filename = "example.c3d"
      )
    ),
    fictrac = list(
      "sample" = list(
        url = paste0(github_base, "/fictrac/fictrac_sample.dat"),
        filename = "fictrac_sample.dat"
      )
    ),
    freemocap = list(
      "test-data" = list(
        url = paste0(
          github_base,
          "/freemocap/freemocap_test_data_by_frame.csv"
        ),
        filename = "freemocap_test_data_by_frame.csv"
      )
    ),
    idtracker = list(
      "trajectories" = list(
        url = paste0(github_base, "/idtrackerai/trajectories.h5"),
        filename = "idtracker_trajectories.h5"
      )
    ),
    lightningpose = list(
      "mouse-face" = list(
        url = paste0(gin_base, "/poses/LP_mouse-face_AIND.predictions.csv"),
        filename = "lightningpose_mouse-face.csv"
      ),
      "mouse-twoview" = list(
        url = paste0(gin_base, "/poses/LP_mouse-twoview_AIND.predictions.csv"),
        filename = "lightningpose_mouse-twoview.csv"
      )
    ),
    movement = list(
      "two-mice_octagon" = list(
        url = paste0(
          github_base,
          "/movement/SLEAP_two-mice_octagon.analysis-1768334869096.nc"
        ),
        filename = "sleap_two-mice_octagon.nc"
      )
    ),
    sleap = list(
      "single-mouse_EPM" = list(
        url = paste0(gin_base, "/poses/SLEAP_single-mouse_EPM.analysis.h5"),
        filename = "sleap_single-mouse_EPM.h5"
      ),
      "two-mice_octagon" = list(
        url = paste0(gin_base, "/poses/SLEAP_two-mice_octagon.analysis.h5"),
        filename = "sleap_two-mice_octagon.h5"
      ),
      "zebras_drone" = list(
        url = paste0(gin_base, "/poses/SLEAP_OSFM_zebras_drone.h5"),
        filename = "sleap_zebras_drone.h5"
      )
    ),
    trackball = list(
      "beetles" = list(
        url = paste0(github_base, "/trackball/single_named/trackball.zip"),
        filename = "trackball_beetles.zip"
      )
    ),
    trex = list(
      # Listed first, so it is the default: five locusts over 2845 frames with
      # pose keypoints, per-frame detection probability and identities, where
      # "beetles" is a 19-frame CSV excerpt that cannot carry an example.
      "five-locusts" = list(
        url = paste0(gin_base, "/poses/TRex_five-locusts.zip"),
        filename = "trex_five-locusts.zip"
      ),
      "beetles" = list(
        url = paste0(github_base, "/trex/beetle.csv"),
        filename = "trex_sample.csv"
      )
    )
  )

  # Handle list_datasets request
  if (list_datasets) {
    if (missing(source)) {
      # List all sources and their datasets
      cli::cli_h2("Available sources and datasets")
      cli::cli_text("")

      for (src in names(sources)) {
        datasets <- names(sources[[src]])
        n_datasets <- length(datasets)

        if (n_datasets == 1) {
          cli::cli_alert_info("{.strong {src}}: {.val {datasets}}")
        } else {
          cli::cli_alert_info("{.strong {src}} ({n_datasets} datasets)")
          cli::cli_div(theme = list(".cli-ul" = list("margin-left" = 2)))
          cli::cli_ul()
          for (i in seq_along(datasets)) {
            if (i == 1) {
              cli::cli_li("{.val {datasets[i]}} (default)")
            } else {
              cli::cli_li("{.val {datasets[i]}}")
            }
          }
          cli::cli_end()
          cli::cli_end()
        }
      }

      return(invisible(NULL))
    } else {
      # List datasets for specific source
      if (!source %in% names(sources)) {
        cli::cli_abort(c(
          "Source {.val {source}} is not supported.",
          "i" = "Currently supported sources: {.val {names(sources)}}",
          "i" = "Use {.code get_sample_data(list_datasets = TRUE)} to see all options"
        ))
      }

      datasets <- names(sources[[source]])
      cli::cli_h2("Available datasets for {.strong {source}}")
      cli::cli_text("")
      cli::cli_ul()
      for (i in seq_along(datasets)) {
        if (i == 1) {
          cli::cli_li("{.val {datasets[i]}} (default)")
        } else {
          cli::cli_li("{.val {datasets[i]}}")
        }
      }
      cli::cli_end()

      return(invisible(NULL))
    }
  }

  # Check if source is provided
  if (missing(source)) {
    cli::cli_abort(c(
      "Must specify a {.arg source}.",
      "i" = "Use {.code get_sample_data(list_datasets = TRUE)} to see available sources"
    ))
  }

  # Check if source is a URL
  is_url <- grepl("^https?://", source)

  # Handle URL case
  if (is_url) {
    file_url <- source
    filename <- basename(source)
  } else {
    # Check if source is a supported predefined source
    if (!source %in% names(sources)) {
      cli::cli_abort(c(
        "Source {.val {source}} is not supported.",
        "i" = "Use {.code get_sample_data(list_datasets = TRUE)} to see available sources",
        "i" = "Alternatively, provide a URL starting with 'http://' or 'https://'"
      ))
    }

    # Get available datasets for this source
    available_datasets <- names(sources[[source]])

    # Determine which dataset to use (first one is default)
    if (is.null(dataset)) {
      dataset <- available_datasets[1]
    }

    # Check if requested dataset exists
    if (!dataset %in% available_datasets) {
      cli::cli_abort(c(
        "Dataset {.val {dataset}} is not available for source {.val {source}}.",
        "i" = "Available datasets: {.val {available_datasets}}",
        "i" = "Use {.code get_sample_data(\"{source}\", list_datasets = TRUE)} to see details"
      ))
    }

    # Get URL and filename for the specified source and dataset
    file_url <- sources[[source]][[dataset]]$url
    filename <- sources[[source]][[dataset]]$filename
  }

  data_path <- file.path(cache_dir, filename)

  # Check if this is a zip file that needs extraction
  is_zip <- tolower(tools::file_ext(filename)) == "zip"

  if (is_zip) {
    # For zip files, check if the extracted folder already exists
    extract_dir <- file.path(cache_dir, tools::file_path_sans_ext(filename))
    if (dir.exists(extract_dir)) {
      # Get all files in the extracted directory (excluding subdirectories)
      extracted_files <- list.files(
        extract_dir,
        full.names = TRUE,
        recursive = TRUE
      )
      extracted_files <- extracted_files[!dir.exists(extracted_files)]
      return(extracted_files)
    }
  } else {
    # For non-zip files, check if the file already exists
    if (file.exists(data_path)) {
      return(data_path)
    }
  }

  # Need to download the file
  if (quiet == FALSE) {
    if (is_url) {
      cli::cli_inform("Downloading data from custom URL...")
    } else {
      is_default <- dataset == names(sources[[source]])[1]
      if (is_default) {
        cli::cli_inform("Downloading {source} data...")
      } else {
        cli::cli_inform("Downloading {source} {.val {dataset}} dataset...")
      }
    }
  }

  # Create cache directory if it doesn't exist
  if (!dir.exists(cache_dir)) {
    dir.create(cache_dir, recursive = TRUE)
  }

  # Determine download mode based on file extension
  file_ext <- tolower(tools::file_ext(filename))
  binary_extensions <- c(
    "h5",
    "hdf5",
    "dat",
    "zip",
    "tar",
    "gz",
    "mp4",
    "avi",
    "slp",
    "nc"
  )
  download_mode <- if (file_ext %in% binary_extensions) "wb" else "w"

  # Try to download the file with appropriate method
  download_success <- try(
    {
      utils::download.file(
        file_url,
        destfile = data_path,
        quiet = TRUE,
        mode = download_mode,
        method = "auto"
      )
    },
    silent = TRUE
  )

  # Check if download failed
  if (inherits(download_success, "try-error")) {
    cli::cli_abort(c(
      "Failed to download data.",
      "i" = "Please check your internet connection.",
      "i" = "URL attempted: {.url {file_url}}"
    ))
  }

  # Verify the file was actually downloaded and has content
  if (!file.exists(data_path) || file.info(data_path)$size == 0) {
    # nocov start
    # Defensive — `download.file` exiting cleanly with a missing/empty
    # destination is a server-side oddity that's hard to fixture in tests.
    cli::cli_abort(c(
      "Download appeared to succeed but file is missing or empty.",
      "i" = "This may be a temporary issue with the data repository.",
      "i" = "URL attempted: {.url {file_url}}"
    ))
    # nocov end
  }

  # Handle zip file extraction
  if (is_zip) {
    extract_dir <- file.path(cache_dir, tools::file_path_sans_ext(filename))

    if (quiet == FALSE) {
      cli::cli_inform("Extracting {filename}...")
    }

    # Extract the zip file
    utils::unzip(data_path, exdir = extract_dir)

    # Get all files in the extracted directory (excluding subdirectories)
    extracted_files <- list.files(
      extract_dir,
      full.names = TRUE,
      recursive = TRUE
    )
    extracted_files <- extracted_files[!dir.exists(extracted_files)]

    # Return the vector of file paths
    return(extracted_files)
  }

  return(data_path)
}
