#' @title Read AnimalTA data
#' @name read_animalta
#'
#' @description Read a data frame from AnimalTA. AnimalTA exports tracking
#' data in image (top-left) coordinates; the reader reflects y so the
#' returned aniframe is in the conventional `bottom_left` origin.
#'
#' @param path An AnimalTA data frame
#' @param detailed Which export layout the file uses. `"auto"` (the
#'   default) reads it from the header: the raw layout continues into
#'   `X_Arena<n>_Ind<n>` columns, the detailed one into `Arena;Ind;X;Y`.
#'   Pass `TRUE` or `FALSE` to state it explicitly. We only have limited
#'   support for detailed data.
#' @param video_height Optional numeric height of the source video frame in
#'   pixels. AnimalTA does not record this in the export, so when not
#'   supplied the maximum observed `y` is used as a fallback.
#'
#' @return a movement dataframe
#'
#' @references
#' - Chiara, V., & Kim, S.-Y. (2023). AnimalTA: A highly flexible and easy-to-use
#' program for tracking and analysing animal movement in different environments.
#' *Methods in Ecology and Evolution*, 14, 1699–1707. \doi{0.1111/2041-210X.14115}.
#'
#' @examples
#' path <- system.file("extdata", "animalta.csv", package = "aniread")
#' read_animalta(path)
#' @export
read_animalta <- function(path, detailed = "auto", video_height = NULL) {
  detailed <- resolve_animalta_layout(path, detailed)

  # Inspect headers
  if (detailed == TRUE) {
    validate_files(
      path,
      expected_suffix = "csv",
      expected_headers = c("X", "Y", "Time")
    )
    data <- read_animalta_detailed(path)
  } else {
    validate_files(
      path,
      expected_suffix = "csv",
      expected_headers = c("Time", "X_Arena0_Ind0", "Y_Arena0_Ind0")
    )
    data <- read_animalta_raw(path)
  }
  data <- data |>
    dplyr::mutate(keypoint = factor("centroid")) |>
    dplyr::relocate("keypoint", .after = "individual") |>
    dplyr::mutate(
      confidence = as.numeric(NA),
      keypoint = factor(.data$keypoint),
      individual = factor(.data$individual)
    )

  # Init metadata
  data <- data |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = "animalta",
      filename = basename(path)
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  return(data)
}

#' @inheritParams read_animalta
#' @keywords internal
read_animalta_detailed <- function(path) {
  data <- vroom::vroom(
    path,
    delim = ";",
    show_col_types = FALSE
  ) |>
    janitor::clean_names() |>
    dplyr::mutate(
      frame = as.numeric(.data$frame),
      time = as.numeric(.data$time)
    ) |>
    dplyr::rename(individual = "ind") |>
    dplyr::mutate(individual = factor(.data$individual)) |>
    dplyr::select(-c("frame", "arena"))
  attributes(data)$spec <- NULL
  attributes(data)$problems <- NULL
  return(data)
}

#' @inheritParams read_animalta
#' @keywords internal
read_animalta_raw <- function(path) {
  data <- vroom::vroom(
    path,
    delim = ";",
    show_col_types = FALSE
  ) |>
    janitor::clean_names()

  data <- data |>
    tidyr::pivot_longer(
      cols = 3:ncol(data),
      names_to = c("coordinate", "individual", "arena"),
      names_sep = "_",
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("time", "individual", "arena"),
      names_from = "coordinate",
      values_from = "val"
    ) |>
    tidyr::unite("individual", c("individual", "arena")) |>
    dplyr::mutate(individual = factor(.data$individual))
  return(data)
}


#' Work out which AnimalTA export layout a file uses
#'
#' The two layouts are separable from their first line — the raw export
#' continues into `X_Arena<n>_Ind<n>` columns, the detailed one into
#' `Arena;Ind;X;Y` — and [read_animalta()] already encodes both header
#' sets. It just used to consult its argument instead of looking, so a
#' detailed file read with the default gave a header error naming columns
#' the user had never heard of rather than pointing at `detailed` (#88).
#'
#' @param path Path to the file.
#' @param detailed `"auto"`, or a logical stating the layout outright.
#'
#' @return `TRUE` for the detailed layout, `FALSE` for the raw one.
#' @keywords internal
resolve_animalta_layout <- function(path, detailed) {
  if (is.logical(detailed) && length(detailed) == 1 && !is.na(detailed)) {
    return(detailed)
  }

  if (!identical(detailed, "auto")) {
    cli::cli_abort(c(
      "{.arg detailed} must be {.val auto}, {.val TRUE} or {.val FALSE}.",
      "x" = "Got {.val {detailed}}."
    ))
  }

  header <- peek_header(path, delim = ";")
  all(c("Arena", "Ind", "X", "Y") %in% header)
}
