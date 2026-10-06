#' Download sample tracking data
#'
#' Downloads sample data for different animal tracking software and returns the path
#' to the downloaded file. The function caches the data to avoid repeated downloads.
#'
#' @param source Character string specifying either a source name, as
#'   [read_dataset()] names it, or a URL. Currently supported source names:
#'   - "animalta": Data from AnimalTA
#'   - "anipose": Mouse paw tracking data
#'   - "bonsai": Tracking data from Bonsai
#'   - "c3d": Motion capture in C3D (2 datasets): "example", a walking
#'     trial, and "sample-static", a static calibration trial
#'   - "deeplabcut": Mouse/animal tracking from DeepLabCut (4 datasets)
#'   - "fasttrack": Tracking from FastTrack
#'   - "fictrac": Fictrac sample data
#'   - "freemocap": FreeMoCap motion capture of a person doing star jumps
#'     (4 datasets), from movement's sample data, written by FreeMoCap's own
#'     saver. The default, "star-jump", is the 9-column `by_frame.csv` of
#'     v1.7.4 and later; "star-jump_v1.7" is the 8-column one of earlier
#'     versions; "star-jump_by_trajectory" and "star-jump_wide" are the
#'     recording's `by_trajectory.csv` and `mediapipe_body_3d_xyz.csv`
#'   - "idtrackerai": Trajectories from idtracker.ai (2 datasets): the `.h5`
#'     export, and "trajectories_csv", the CSV export
#'   - "lightningpose": Mouse tracking from LightningPose (3 datasets). The
#'     default, "IBL-paw_EKS-left", is the Ensemble Kalman Smoother's output
#'     for one camera
#'   - "movement": netCDF files saved by the movement Python package
#'     (2 datasets). The default, "two-mice_octagon", has the dimension names
#'     movement uses since 0.17.0; "legacy-plural" is the same recording
#'     with the plural names of earlier versions
#'   - "octron": Segmentation tracking from OCTRON
#'   - "sleap": Animal tracking from SLEAP (4 datasets)
#'   - "trackball_bonsai": Two optical-flow sensors under a trackball,
#'     logged with Bonsai. Unpacks to one file per sensor and returns both
#'     paths, which [read_trackball()] reads as one recording
#'   - "trackmate": Cell tracking from TrackMate (3 datasets)
#'   - "trex": Multi-animal tracking from TRex (2 datasets). The default,
#'     "five-locusts", unpacks to one `.npz` per individual and returns a
#'     vector of paths, which [read_trex()] reads as one recording
#'
#'   `"idtracker"` and `"trackball"`, the names before these matched
#'   [read_dataset()], still work but are deprecated.
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
#'   For a dataset distributed as a zip file (the TRex "five-locusts" and
#'   trackball datasets), returns a character vector of paths to the files it
#'   unpacks to. For all others, returns a single file path. Returns NULL
#'   invisibly if `list_datasets = TRUE`.
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
#' - https://gin.swc.ucl.ac.uk/neuroinformatics/movement-sample-data
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
  sources <- sample_data_sources()
  if (!missing(source)) {
    source <- resolve_sample_source(source)
  }

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

  # Try to download the file with appropriate method
  download_success <- try(
    {
      utils::download.file(
        file_url,
        destfile = data_path,
        quiet = TRUE,
        # Binary for every file: text mode corrupts binary files on Windows,
        # and keeps a text file's line endings as they are elsewhere
        mode = "wb",
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

#' Sample datasets, by source
#'
#' Keys are the source names of [source_registry()], so a source is named the
#' same here as in [read_dataset()]. The first dataset of a source is its
#' default; keep defaults small.
#'
#' @return A named list of sources, each a named list of datasets with `url`
#'   and `filename`.
#' @keywords internal
sample_data_sources <- function() {
  gin_base <- "https://gin.swc.ucl.ac.uk/neuroinformatics/movement-sample-data/raw/master"
  github_base <- "https://raw.githubusercontent.com/animovement/movement-data/main/data"
  gin <- function(path, filename) {
    list(url = paste0(gin_base, path), filename = filename)
  }
  github <- function(path, filename) {
    list(url = paste0(github_base, path), filename = filename)
  }

  list(
    animalta = list(
      "single-individual" = github(
        "/AnimalTA/single_individual_multi_arena.csv",
        "animalta_single-individual.csv"
      )
    ),
    anipose = list(
      "mouse-paw" = gin(
        "/poses/anipose_mouse-paw_anipose-paper.triangulation.csv",
        "anipose_mouse-paw.csv"
      )
    ),
    bonsai = list(
      "LI850" = github("/bonsai/LI850.csv", "bonsai_LI850.csv")
    ),
    c3d = list(
      "example" = github("/c3d/example.c3d", "example.c3d"),
      "sample-static" = github(
        "/c3d/Sample_Static.c3d",
        "c3d_sample-static.c3d"
      )
    ),
    deeplabcut = list(
      "single-mouse_EPM" = gin(
        "/poses/DLC_single-mouse_EPM.predictions.h5",
        "deeplabcut_single-mouse_EPM.h5"
      ),
      "two-mice" = gin(
        "/poses/DLC_two-mice.predictions.csv",
        "deeplabcut_two-mice.csv"
      ),
      "single-wasp" = gin(
        "/poses/DLC_single-wasp.predictions.h5",
        "deeplabcut_single-wasp.h5"
      ),
      "single-wasp_csv" = gin(
        "/poses/DLC_single-wasp.predictions.csv",
        "deeplabcut_single-wasp.csv"
      )
    ),
    fasttrack = list(
      "tracking" = github("/fasttrack/tracking.txt", "fasttrack_tracking.txt")
    ),
    fictrac = list(
      "sample" = github("/fictrac/fictrac_sample.dat", "fictrac_sample.dat")
    ),
    freemocap = list(
      # movement's star-jump recording (CC BY 4.0, Max Staras), written by
      # FreeMoCap v1.8.2's own saver: the 9-column by_frame layout.
      "star-jump" = github(
        "/freemocap/freemocap_star-jump_by_frame.csv",
        "freemocap_star-jump_by_frame.csv"
      ),
      # The same recording as FreeMoCap v1.7.3 writes it: 8 columns, no
      # reprojection_error.
      "star-jump_v1.7" = github(
        "/freemocap/freemocap_star-jump_by_frame_v1.7.csv",
        "freemocap_star-jump_by_frame_v1.7.csv"
      ),
      "star-jump_by_trajectory" = github(
        "/freemocap/freemocap_star-jump_by_trajectory.csv",
        "freemocap_star-jump_by_trajectory.csv"
      ),
      "star-jump_wide" = github(
        "/freemocap/freemocap_star-jump_mediapipe_body_3d_xyz.csv",
        "freemocap_star-jump_mediapipe_body_3d_xyz.csv"
      )
    ),
    idtrackerai = list(
      "trajectories" = github(
        "/idtrackerai/trajectories.h5",
        "idtracker_trajectories.h5"
      ),
      "trajectories_csv" = github(
        "/idtrackerai/trajectories_csv/trajectories.csv",
        "idtracker_trajectories.csv"
      )
    ),
    lightningpose = list(
      # The Ensemble Kalman Smoother's output for one camera of IBL's paw
      # recordings: 172 kB, where the two AIND recordings are 24 MB each.
      "IBL-paw_EKS-left" = gin(
        "/poses/EKS_IBL-paw_multicam_left.predictions.csv",
        "lightningpose_IBL-paw_EKS-left.csv"
      ),
      "mouse-face" = gin(
        "/poses/LP_mouse-face_AIND.predictions.csv",
        "lightningpose_mouse-face.csv"
      ),
      "mouse-twoview" = gin(
        "/poses/LP_mouse-twoview_AIND.predictions.csv",
        "lightningpose_mouse-twoview.csv"
      )
    ),
    movement = list(
      # Saved by movement 0.17.0 or later, with singular dimension names
      "two-mice_octagon" = gin(
        "/poses/MOVE_two-mice_octagon.analysis.nc",
        "movement_two-mice_octagon.nc"
      ),
      # The same recording saved before 0.17.0, with the plural `individuals`
      # and `keypoints` dimensions
      "legacy-plural" = github(
        "/movement/SLEAP_two-mice_octagon.analysis-1768334869096.nc",
        "movement_two-mice_octagon_legacy-plural.nc"
      )
    ),
    octron = list(
      "sample" = github("/octron/sample-data.csv", "octron_sample.csv")
    ),
    sleap = list(
      "single-mouse_EPM" = gin(
        "/poses/SLEAP_single-mouse_EPM.analysis.h5",
        "sleap_single-mouse_EPM.h5"
      ),
      "two-mice_octagon" = gin(
        "/poses/SLEAP_two-mice_octagon.analysis.h5",
        "sleap_two-mice_octagon.h5"
      ),
      "zebras_drone" = gin(
        "/poses/SLEAP_OSFM_zebras_drone.h5",
        "sleap_zebras_drone.h5"
      ),
      # Named tracks, in 50 kB
      "three-mice_Aeon" = gin(
        "/poses/SLEAP_three-mice_Aeon_mixed-labels.analysis.h5",
        "sleap_three-mice_Aeon.h5"
      )
    ),
    trackball_bonsai = list(
      "beetles" = github(
        "/trackball/single_named/trackball.zip",
        "trackball_beetles.zip"
      )
    ),
    trackmate = list(
      # Six tracks with divisions, and the frame interval recorded
      "celegans-early" = github(
        "/trackmate/CelegansEarly_MIP.xml",
        "trackmate_celegans-early.xml"
      ),
      "U251" = github(
        "/trackmate/U251_mitoRED_lifeAct670_3-MIP.xml",
        "trackmate_U251.xml"
      ),
      "trpL" = github("/trackmate/trpL_150310-11.xml", "trackmate_trpL.xml")
    ),
    trex = list(
      # Listed first, so it is the default: five locusts over 2845 frames with
      # pose keypoints, per-frame detection probability and identities, where
      # "beetles" is a 19-frame CSV excerpt that cannot carry an example.
      "five-locusts" = gin(
        "/poses/TRex_five-locusts.zip",
        "trex_five-locusts.zip"
      ),
      "beetles" = github("/trex/beetle.csv", "trex_sample.csv")
    )
  )
}

# Source names get_sample_data() used before they matched the registry
SAMPLE_DATA_ALIASES <- c(
  idtracker = "idtrackerai",
  trackball = "trackball_bonsai"
)

#' Map a superseded sample-data source name to its registry name
#' @param source A source name or URL.
#' @return The registry name, or `source` unchanged.
#' @keywords internal
resolve_sample_source <- function(source) {
  if (!rlang::is_string(source) || !source %in% names(SAMPLE_DATA_ALIASES)) {
    return(source)
  }
  new <- SAMPLE_DATA_ALIASES[[source]]
  lifecycle::deprecate_soft(
    "0.8.0",
    I(sprintf('get_sample_data("%s")', source)),
    I(sprintf('get_sample_data("%s")', new))
  )
  new
}
