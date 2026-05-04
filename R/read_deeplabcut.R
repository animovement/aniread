#' Read DeepLabCut data
#'
#' Read files from DeepLabCut (DLC) in either csv or h5 format.
#' DeepLabCut stores predictions in image (top-left) coordinates; the
#' reader reflects y so the returned aniframe is in the conventional
#' `bottom_left` origin. DLC's csv/h5 exports do not contain the source
#' video resolution (it lives in the project's `config.yaml`), so pass
#' `video_height` to get an accurate flip — otherwise `max(y)` is used
#' as a fallback.
#'
#' @param path Path to a DeepLabCut data file
#' @param video_height Optional numeric height of the source video frame
#'   in pixels.
#' @return an aniframe
#' @export
read_deeplabcut <- function(path, video_height = NULL) {
  # Validate file
  validate_files(path, expected_suffix = c("csv", "h5"))

  # Check whether it's a multi-animal data set
  ext <- get_file_ext(path)

  data <- if (ext == "csv") {
    read_deeplabcut_csv(path)
  } else {
    read_deeplabcut_h5(path)
  }

  # Init metadata
  data <- data |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = "deeplabcut",
      filename = basename(path)
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  data
}

#' Read DeepLabCut data
#'
#' Read csv files from DeepLabCut (DLC). The function recognises whether it is a
#' single- or multi-animal dataset.
#'
#' @param path Path to a DeepLabCut data file
#' @param multianimal By default, whether a file is multi-animal is detected automatically. This gives an option to ensure it. logical TRUE/FALSE.
#'
#' @return a movement dataframe
#' @keywords internal
read_deeplabcut_csv <- function(path, multianimal = NULL) {
  # Check whether it's a multi-animal data set
  if (is.null(multianimal)) {
    multianimal <- vroom::vroom(
      path,
      delim = ",",
      show_col_types = FALSE,
      skip = 3,
      n_max = 1,
      col_names = FALSE
    ) |>
      t() |>
      is.character()
  }

  if (multianimal == FALSE) {
    data <- read_deeplabcut_csv_single(path)
  } else if (multianimal == TRUE) {
    data <- read_deeplabcut_csv_multi(path)
  }

  data
}

#' Read single-animal DLC files
#' @keywords internal
read_deeplabcut_csv_single <- function(path) {
  # Get metadata
  header_2 <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 1,
    n_max = 1,
    col_names = FALSE
  )

  header_3 <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 2,
    n_max = 1,
    col_names = FALSE
  )

  new_headers <- rbind(header_2, header_3) |>
    t() |>
    as.data.frame() |>
    dplyr::mutate(new_names = paste(.data$V1, .data$V2, sep = "_")) |>
    dplyr::select("new_names") |>
    as.data.frame() |>
    dplyr::pull()

  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 3,
    col_names = new_headers
  )

  # Do check

  # Wrangle
  data <- data |>
    dplyr::rename(time = 1) |>
    tidyr::pivot_longer(
      cols = !"time",
      names_to = c("keypoint", "pos"),
      names_pattern = "(.*)_(\\w+)",
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("time", "keypoint"),
      names_from = "pos",
      values_from = "val"
    ) |>
    dplyr::rename(confidence = "likelihood") |>
    dplyr::mutate(keypoint = factor(.data$keypoint))

  data
}

#' Read multi-animal DLC files
#' @keywords internal
read_deeplabcut_csv_multi <- function(path) {
  # Get metadata
  header_2 <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 1,
    n_max = 1,
    col_names = FALSE
  )

  header_3 <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 2,
    n_max = 1,
    col_names = FALSE
  )

  header_4 <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 3,
    n_max = 1,
    col_names = FALSE
  )

  new_headers <- rbind(header_2, header_3, header_4) |>
    t() |>
    as.data.frame() |>
    dplyr::mutate(new_names = paste(.data$V1, .data$V2, .data$V3, sep = "_")) |>
    dplyr::select("new_names") |>
    as.data.frame() |>
    dplyr::pull()

  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE,
    skip = 4,
    col_names = new_headers
  )

  # Do check

  # Wrangle
  data <- data |>
    dplyr::rename(time = 1) |>
    tidyr::pivot_longer(
      cols = !"time",
      names_to = c("individual", "keypoint", "pos"),
      names_sep = "_",
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("time", "individual", "keypoint"),
      names_from = "pos",
      values_from = "val"
    ) |>
    dplyr::rename(confidence = "likelihood") |>
    dplyr::mutate(
      individual = factor(.data$individual),
      keypoint = factor(.data$keypoint)
    )

  data
}

#' Read DeepLabCut H5 file
#'
#' @param path Path to the DLC .h5 file
#' @return An aniframe with columns: time, individual, keypoint, x, y, confidence
#' @keywords internal
read_deeplabcut_h5 <- function(path) {
  # Check that rhdf5 is installed
  check_rhdf5()

  # Read data
  raw <- rhdf5::h5read(
    path,
    "/df_with_missing/table",
    compoundAsDataFrame = FALSE
  )

  # Read attributes
  attrs <- rhdf5::h5readAttributes(path, "/df_with_missing/table")

  # Detect multi-animal by checking level names in info attribute
  multianimal <- ifelse(
    length(
      grepl("Vindividuals", attrs$info)
    ) >
      0,
    TRUE,
    FALSE
  )

  # Parse the column structure from the pickle string
  col_info <- parse_dlc_pickle(attrs$values_block_0_kind, multianimal)

  # Transpose the matrix (DLC stores it as n_cols x n_frames)
  mat <- t(raw$values_block_0)

  # Build column names
  if (multianimal) {
    col_names <- paste(
      col_info$individual,
      col_info$bodypart,
      col_info$coord,
      sep = "_"
    )
  } else {
    col_names <- paste(col_info$bodypart, col_info$coord, sep = "_")
  }
  colnames(mat) <- col_names

  # Create data frame with frame index
  data <- dplyr::as_tibble(mat)
  data$time <- raw$index

  # Pivot to long format
  if (multianimal) {
    data <- data |>
      tidyr::pivot_longer(
        cols = -"time",
        names_to = c("individual", "keypoint", ".value"),
        names_sep = "_"
      ) |>
      dplyr::rename(confidence = "likelihood")
  } else {
    data <- data |>
      tidyr::pivot_longer(
        cols = -"time",
        names_to = c("keypoint", ".value"),
        names_pattern = "(.+)_(x|y|likelihood)"
      ) |>
      dplyr::rename(confidence = "likelihood")
  }

  data
}

#' Parse DLC pickle string to extract column order
#'
#' @param pickle_str The values_block_0_kind attribute string
#' @param multianimal Whether this is a multi-animal dataset
#' @return A tibble with bodypart, coord columns (and individual if multi-animal)
#' @keywords internal
parse_dlc_pickle <- function(pickle_str, multianimal = FALSE) {
  strings <- stringr::str_extract_all(pickle_str, "V[^\n]+")[[1]]
  strings <- sub("^V", "", strings)

  # Skip scorer (first string)
  rest <- strings[-1]

  coords <- c("x", "y", "likelihood")

  if (multianimal) {
    # Remaining strings are: individual, bodypart, coord pattern
    # Individuals and bodyparts are non-coord strings
    non_coords <- setdiff(unique(rest), coords)

    # Need to figure out which are individuals vs bodyparts
    # In the pickle, order is: ind1, bp1, x, y, likelihood, bp2, x, y, likelihood, ..., ind2, bp1, ...
    # First non-coord after scorer is an individual
    # We can detect the pattern by finding where individuals repeat

    # Find positions of non-coord strings
    is_non_coord <- rest %in% non_coords
    non_coord_positions <- which(is_non_coord)

    # The first one is an individual, then bodyparts follow until we see
    # another string that starts a new individual (detected by seeing x after it)
    # Actually simpler: individuals appear less frequently than bodyparts

    counts <- table(rest[is_non_coord])
    # Bodyparts appear once per individual, individuals appear once per themselves
    # but coords appear most often. Need another approach.

    # Look at the sequence: the first non-coord is individual, then bodyparts
    # until we see the same individual or a new one
    first_non_coord <- rest[non_coord_positions[1]]

    # Count occurrences of the first non-coord string
    first_count <- sum(rest == first_non_coord)

    # If it appears multiple times (once per coord set), it's a bodypart repeated
    # for a single individual. If it appears few times, it might be an individual.

    # Better approach: look at the stride. After (ind, bp, x, y, likelihood),
    # we either get (bp, x, y, likelihood) or (ind, bp, x, y, likelihood)
    # Stride of 4 = same individual, different bodypart
    # Stride of 5 = new individual

    # Simplest: assume first non-coord is individual, collect all unique
    # non-coords that appear right before a bodypart
    # Actually, let's just use position-based logic

    # Find gaps between non-coord strings
    gaps <- diff(non_coord_positions)
    # Gap of 3 = x,y,likelihood between bodyparts (same individual)
    # Gap of 4 = x,y,likelihood + individual between (new individual)

    # If we see gap of 4, the item at that position is a new individual
    individual_positions <- c(1, non_coord_positions[which(gaps == 4) + 1])
    individuals <- unique(rest[non_coord_positions[individual_positions]])
    bodyparts <- setdiff(non_coords, individuals)

    dplyr::tibble(
      individual = rep(individuals, each = length(bodyparts) * 3),
      bodypart = rep(rep(bodyparts, each = 3), times = length(individuals)),
      coord = rep(coords, times = length(individuals) * length(bodyparts))
    )
  } else {
    bodyparts <- setdiff(unique(rest), coords)

    dplyr::tibble(
      bodypart = rep(bodyparts, each = 3),
      coord = rep(coords, times = length(bodyparts))
    )
  }
}
