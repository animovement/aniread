#' @title Read AnimalTA data
#' @name read_animalta
#'
#' @description Read a data frame from AnimalTA. AnimalTA exports tracking
#' data in image (top-left) coordinates; the reader reflects y so the
#' returned aniframe is in the conventional `bottom_left` origin.
#'
#' AnimalTA writes the time since the start of the video in seconds, rounded
#' to 0.01 s, in its `Time` column. The reader keeps it as `time`, so
#' `unit_time` is `"s"`.
#'
#' AnimalTA does not write the frame rate, but its `Frame` column is the
#' frame number at the rate it tracked at, and `Time` that number divided by
#' the rate. When every row agrees on one rate, to within the 0.01 s
#' rounding, it becomes `sampling_rate`: the frames between the first and last
#' row over the seconds between them, or the whole number nearest to it when
#' that fits every row as well. Otherwise it is left `NA`. In a short file
#' the rounding leaves the rate uncertain by about 0.01 s over the file's
#' duration.
#'
#' AnimalTA numbers individuals from 0 within each arena, so an individual is
#' identified by its arena and its name together. The arena is its own
#' identity column, `arena`, holding AnimalTA's arena number (`"0"`, `"1"`,
#' ...), and `individual` holds AnimalTA's name for the target, `Ind<i>`.
#' Both layouts give the same values: the raw layout's columns are named
#' `X_Arena<a>_Ind<i>`, and the detailed layout's `Arena` and `Ind` columns
#' hold the same numbers. `arena`, `individual` and `keypoint` are the
#' aniframe's identity keys, so functions that work per individual keep
#' arenas apart. The `arena` column is there for every file, also when it has
#' a single arena.
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
  sampling_rate <- rate_from_frames(data$frame, data$time)

  data <- data |>
    dplyr::select(-"frame") |>
    dplyr::mutate(keypoint = factor("centroid")) |>
    dplyr::relocate("arena", "individual", "keypoint") |>
    dplyr::mutate(
      confidence = as.numeric(NA),
      arena = animalta_arena(.data$arena),
      keypoint = factor(.data$keypoint),
      individual = factor(.data$individual)
    )

  # Init metadata
  data <- data |>
    # AnimalTA numbers individuals within each arena, so the arena is part
    # of an individual's identity.
    anicore::as_anipoint(
      variables_what = c("arena", "individual", "keypoint")
    ) |>
    anicore::set_metadata(
      source = "animalta",
      filename = basename(path),
      unit_time = "s",
      sampling_rate = sampling_rate
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
    col_types = vroom::cols(Arena = "c", Ind = "c"),
    show_col_types = FALSE
  ) |>
    janitor::clean_names() |>
    dplyr::mutate(
      frame = as.numeric(.data$frame),
      time = as.numeric(.data$time)
    ) |>
    # `Ind` counts from 0 within each arena; named as the raw layout's
    # columns name it, `Ind<i>`. The arena is kept as its own column.
    dplyr::mutate(individual = paste0("Ind", .data$ind)) |>
    dplyr::select(-"ind")
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
      names_to = c("coordinate", "arena", "individual"),
      names_sep = "_",
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("frame", "time", "arena", "individual"),
      names_from = "coordinate",
      values_from = "val"
    ) |>
    # `clean_names()` gave `arena<a>` and `ind<i>`; back to AnimalTA's arena
    # number and its name for the target, `Ind<i>`.
    dplyr::mutate(
      arena = sub("^arena", "", .data$arena),
      individual = sub("^ind([0-9]+)$", "Ind\\1", .data$individual)
    )
  return(data)
}

#' AnimalTA's arena numbers as an identity key
#'
#' @param arena The arena numbers, as AnimalTA writes them.
#' @return A factor of the numbers as text, with its levels in numeric order
#'   so that arena 10 comes after arena 9.
#' @noRd
animalta_arena <- function(arena) {
  arena <- as.character(arena)
  values <- unique(arena)
  factor(arena, levels = values[order(as.numeric(values))])
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
