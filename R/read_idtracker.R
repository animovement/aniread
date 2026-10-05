#' Read idtracker.ai data
#'
#' idtracker.ai stores trajectories in image (top-left) coordinates; the
#' reader reflects y so the returned aniframe is in the conventional
#' `bottom_left` origin. For h5 files the frame height is read from the
#' file, as described below. CSV exports do not include the frame
#' height, so pass `video_height` explicitly to get an accurate flip
#' (otherwise `max(y)` is used as a fallback).
#'
#' An h5 file also records, as attributes of its root, how the recording
#' was tracked, and the reader keeps what has a place in the metadata:
#'
#' * `version`, the idtracker.ai version that tracked it, becomes the
#'   `source_version` metadata field.
#' * `frames_per_second`, the frame rate of the video, becomes the
#'   `sampling_rate` metadata field. `time` stays the frame number, counted
#'   from 0 as idtracker.ai counts frames, so `unit_time` is still `"frame"`;
#'   the frame rate is what converts it to seconds.
#' * `height`, the height of the video frame, is what y is reflected
#'   around, unless `video_height` is given. A `height` dataset is used
#'   when there is no such attribute.
#' * `width`, the width of the video frame, written by newer releases,
#'   becomes the x extent in the `axis_extents` metadata field.
#' * `identities_labels`, the names of the identities, which can be changed
#'   in idtracker.ai's validator, name the individuals. idtracker.ai writes
#'   `"1"`, `"2"`, ... when none were set, which are also the names used
#'   when the file has no usable labels (one distinct, non-empty label per
#'   individual).
#'
#' `source_version` and `sampling_rate` stay `NA` when the file does not
#' record them, and no x extent is recorded without a `width`.
#'
#' The CSV export keeps these in a separate `attributes.json` rather than in
#' `trajectories.csv`, and the reader does not read it, so a frame read from
#' the CSV has no `source_version`; set it with [anicore::set_metadata()].
#' Its time column (`seconds`, or `time` in newer releases) is the time in
#' seconds, so `unit_time` is `"s"`, where a frame read from the h5 has
#' `"frame"`. The time column still states the frame rate: idtracker.ai
#' writes one row per frame, with the time as the row number divided by the
#' frame rate, rounded to 1 ms. The reader takes the rate from the rows over
#' the time they span, or the whole number nearest to it when that fits every
#' row as well, and sets it as `sampling_rate`. It is left `NA` when the
#' times are not evenly spaced.
#'
#' When idtracker.ai could not read the video's frame rate, it writes the
#' CSV export without a time column, and `frames_per_second` as `null` in
#' `attributes.json`. `time` is then the frame number, the row counted from
#' 0 as the h5 reader counts frames, `unit_time` is `"frame"`, and
#' `sampling_rate` is `NA`. Set the rate with [anicore::set_metadata()] if you know it.
#'
#' @section Tidy CSV and Parquet exports:
#' idtracker.ai 6.0.13 added a Parquet export, `trajectories.parquet`, and
#' 6.0.14 a tidy CSV export, `trajectories_tidy.csv`. Both hold one row per
#' frame and individual, with the columns `frame`, `time`, `individual`, `x`,
#' `y` and `probability`, and are written only when asked for in
#' `TRAJECTORIES_FORMATS` (or by `idtrackerai_format --formats csv_tidy
#' parquet`).
#'
#' * The Parquet file stores the attributes the h5 keeps (`version`,
#'   `frames_per_second`, `height`, `width`, `identities_labels`, ...) as JSON
#'   in its own metadata, and the reader uses them as it does the h5's.
#' * The tidy CSV keeps them in `attributes_tidy.json` beside it, which the
#'   reader reads when it is there, since idtracker.ai writes the two together
#'   as one export.
#'
#' `frame` and `individual` count from 0. Individuals are numbered from 1, as
#' the h5 reader numbers them, and named by `identities_labels` where those
#' are usable. `probability` becomes `confidence`. When the frame rate is
#' known, `time` is the file's time in seconds, which is the frame over the
#' frame rate, as the CSV export times its rows, with `unit_time` `"s"` and
#' the frame rate as `sampling_rate`. When idtracker.ai could not read the
#' frame rate it still writes a `time` column, but as the frame over 1, so
#' `time` is then the frame, counted from 0, with `unit_time` `"frame"` and
#' `sampling_rate` `NA`. Without
#' `attributes_tidy.json`, a tidy CSV whose `time` equals its `frame` in every
#' row is read as one without a frame rate, and otherwise the rate is taken
#' from the two columns, as for the CSV export.
#'
#' @param path Path to an idtracker.ai data frame
#' @param path_probabilities Path to a csv file with probabilities. Only needed if you are reading csv files as they are included in h5 files.
#' @param version idtracker.ai version. Currently only v6 output is implemented
#' @param video_height Optional numeric height of the source video frame in
#'   pixels. Overrides the value read from the h5 or Parquet file when both
#'   are available.
#' @param format Which idtracker.ai export `path` is: `"h5"`, the CSV export
#'   (`"csv"`, `trajectories.csv`), the tidy CSV export (`"csv_tidy"`,
#'   `trajectories_tidy.csv`) or `"parquet"`. The default, `"auto"`, tells
#'   them apart by the suffix and, for a CSV, by its header. Which one was
#'   read is recorded in the `source_format` metadata field.
#'
#' @return a movement dataframe. The first frame of the video is at
#'   `time = 0`, in frames or in seconds; see "Time" in [read_dataset()].
#' @examples
#' path <- system.file("extdata", "idtracker.csv", package = "aniread")
#' read_idtracker(path)
#' @export
read_idtracker <- function(
  path,
  path_probabilities = NULL,
  version = 6,
  video_height = NULL,
  format = c("auto", "h5", "csv", "csv_tidy", "parquet")
) {
  format <- match.arg(format)
  validate_files(path, expected_suffix = c("csv", "h5", "parquet"))
  if (format == "auto") {
    format <- detect_idtracker_format(path)
  }
  if (!is.null(path_probabilities) && format != "csv") {
    cli::cli_warn(c(
      "Ignoring {.arg path_probabilities}.",
      "i" = "The idtracker.ai {format} export already contains the
             probabilities."
    ))
  }
  if (format == "csv") {
    data <- read_idtracker_csv(path, path_probabilities, version = version)
    recorded <- list(
      source_version = NA_character_,
      sampling_rate = NA_real_,
      width = NA_real_
    )
    if (idtracker_csv_has_time(path)) {
      # One row per frame, so the row number is the frame number.
      times <- sort(unique(data$time))
      recorded$sampling_rate <- rate_from_frames(seq_along(times) - 1, times)
      unit_time <- "s"
    } else {
      unit_time <- "frame"
    }
  } else if (format == "h5") {
    data <- read_idtracker_h5(path, version = version)
    recorded <- read_idtracker_h5_attributes(path)
    data$individual <- label_idtracker_individuals(
      data$individual,
      recorded$identities_labels
    )
    unit_time <- "frame"
    if (is.null(video_height) && !is.na(recorded$height)) {
      video_height <- recorded$height
    }
    if (is.null(video_height)) {
      video_height <- tryCatch(
        as.numeric(rhdf5::h5read(path, "height")),
        error = function(e) NULL
      )
    }
  } else {
    tidy <- read_idtracker_tidy(path, format)
    data <- tidy$data
    recorded <- tidy$recorded
    unit_time <- tidy$unit_time
    if (is.null(video_height) && !is.na(recorded$height)) {
      video_height <- recorded$height
    }
  }

  # Init metadata
  data <- data |>
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = "idtrackerai",
      source_format = format,
      source_version = recorded$source_version,
      filename = basename(path),
      unit_space = "px",
      unit_time = unit_time,
      sampling_rate = recorded$sampling_rate
    ) |>
    reflect_to_bottom_left(
      video_height = video_height,
      video_width = if (!is.na(recorded$width)) recorded$width
    )

  return(data)
}

#' What an idtracker.ai h5 records about the recording
#'
#' idtracker.ai writes the scalars of its output as attributes of the root
#' group and the arrays as datasets. Of the attributes, `version`,
#' `frames_per_second`, `height`, `width` and `identities_labels` have a
#' place in the frame; the rest (`video_paths`, `body_length`,
#' `length_unit` and the accuracy estimates) have none.
#'
#' @return A list of `source_version` (a string), `sampling_rate`, `height`
#'   and `width` (positive numbers), each `NA` when the file does not record
#'   a usable value, and `identities_labels` (a character vector, or `NULL`).
#' @noRd
read_idtracker_h5_attributes <- function(path) {
  attrs <- rhdf5::h5readAttributes(path, "/")
  list(
    source_version = idtracker_string(attrs$version),
    sampling_rate = idtracker_positive_number(attrs$frames_per_second),
    height = idtracker_positive_number(attrs$height),
    width = idtracker_positive_number(attrs$width),
    identities_labels = attrs$identities_labels
  )
}

#' Which idtracker.ai export a file is
#'
#' The suffix tells the h5 and the Parquet export apart; the two CSV exports
#' share a suffix and are told apart by the tidy export's header.
#'
#' @return `"h5"`, `"parquet"`, `"csv_tidy"` or `"csv"`.
#' @noRd
detect_idtracker_format <- function(path) {
  ext <- tolower(get_file_ext(path))
  if (ext %in% c("h5", "parquet")) {
    return(ext)
  }
  if (is_idtracker_tidy_csv(path)) "csv_tidy" else "csv"
}

# The columns of idtracker.ai's tidy CSV and Parquet exports, in the order
# its writers put them.
IDTRACKER_TIDY_COLUMNS <- c(
  "frame",
  "time",
  "individual",
  "x",
  "y",
  "probability"
)

#' Whether a CSV is idtracker.ai's tidy export, by its header
#' @noRd
is_idtracker_tidy_csv <- function(path) {
  identical(peek_header(path), IDTRACKER_TIDY_COLUMNS)
}

#' Whether a Parquet file was written by idtracker.ai
#'
#' idtracker.ai stores its attributes as JSON in the file's own metadata,
#' under `idtrackerai_attributes`, which only the footer has to be read for.
#' @noRd
is_idtracker_parquet <- function(path) {
  identical(rawToChar(peek_bytes(path, 4)), "PAR1") &&
    "idtrackerai_attributes" %in%
      names(arrow::ParquetFileReader$create(path)$GetSchema()$metadata)
}

#' Read idtracker.ai's tidy CSV or Parquet export
#'
#' @param path Path to `trajectories_tidy.csv` or `trajectories.parquet`.
#' @param format `"csv_tidy"` or `"parquet"`.
#'
#' @return A list of `data`, the rows as an aniframe's columns, `recorded`,
#'   as `read_idtracker_h5_attributes()` returns it, and `unit_time`.
#' @noRd
read_idtracker_tidy <- function(path, format) {
  if (format == "parquet") {
    check_arrow()
    table <- arrow::read_parquet(path, as_data_frame = FALSE)
    attributes <- table$metadata$idtrackerai_attributes
    rows <- as.data.frame(table)
  } else {
    rows <- vroom::vroom(
      path,
      delim = ",",
      col_types = vroom::cols(frame = "i", individual = "i", .default = "d"),
      na = c("", "NA", "nan"),
      show_col_types = FALSE
    )
    # Written beside the CSV, as part of the same export.
    json <- file.path(dirname(path), "attributes_tidy.json")
    attributes <- if (file.exists(json)) {
      paste(readLines(json, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
    }
  }
  recorded <- parse_idtracker_attributes(attributes)

  # idtracker.ai writes `time` as the frame over the frame rate, or over 1
  # when it could not read the rate, so the time is then the frame.
  fps_known <- if (is.null(attributes)) {
    !isTRUE(all(rows$time == rows$frame))
  } else {
    !is.na(recorded$sampling_rate)
  }
  if (fps_known) {
    time <- rows$time
    unit_time <- "s"
    if (is.na(recorded$sampling_rate)) {
      recorded$sampling_rate <- rate_from_frames(rows$frame, rows$time)
    }
  } else {
    time <- rows$frame
    unit_time <- "frame"
  }

  individual <- label_idtracker_individuals(
    factor(rows$individual + 1L),
    recorded$identities_labels
  )
  data <- dplyr::tibble(
    time = time,
    individual = individual,
    keypoint = factor("centroid"),
    x = rows$x,
    y = rows$y,
    confidence = rows$probability
  ) |>
    nan_to_na() |>
    dplyr::arrange(.data$individual, .data$time)

  list(data = data, recorded = recorded, unit_time = unit_time)
}

#' What idtracker.ai's attributes JSON records about the recording
#'
#' The tidy CSV and Parquet exports hold the attributes the h5 keeps as
#' attributes of its root, as one JSON object.
#'
#' @param json The JSON text, or `NULL` when there is none.
#' @return As `read_idtracker_h5_attributes()`.
#' @noRd
parse_idtracker_attributes <- function(json) {
  attrs <- list()
  if (!is.null(json)) {
    rlang::check_installed(
      "jsonlite",
      reason = "to read idtracker.ai's attributes."
    )
    attrs <- jsonlite::fromJSON(json, simplifyVector = TRUE)
  }
  list(
    source_version = idtracker_string(attrs$version),
    sampling_rate = idtracker_positive_number(attrs$frames_per_second),
    height = idtracker_positive_number(attrs$height),
    width = idtracker_positive_number(attrs$width),
    identities_labels = attrs$identities_labels
  )
}

#' Name idtracker.ai individuals by their identity labels
#'
#' The h5 reader numbers individuals by their position in the trajectories,
#' `1` to `n`, which is identity `i` and so `identities_labels[i]`.
#'
#' @param individual The factor of positions.
#' @param labels The `identities_labels` attribute, or `NULL`.
#'
#' @return `individual` relabelled, with the labels as levels in identity
#'   order; unchanged when the labels are not one distinct, non-empty string
#'   per individual.
#' @noRd
label_idtracker_individuals <- function(individual, labels) {
  labels <- as.character(as.vector(labels))
  n <- nlevels(individual)
  usable <- length(labels) == n &&
    !anyNA(labels) &&
    all(nzchar(labels)) &&
    !anyDuplicated(labels)
  if (!usable) {
    return(individual)
  }
  factor(labels[as.integer(as.character(individual))], levels = labels)
}

#' A single non-empty string from an h5 attribute, or `NA`
#' @noRd
idtracker_string <- function(x) {
  x <- as.vector(x)
  if (rlang::is_string(x) && nzchar(x)) x else NA_character_
}

#' A single positive, finite number from an h5 attribute, or `NA`
#' @noRd
idtracker_positive_number <- function(x) {
  x <- as.vector(x)
  if (is.numeric(x) && length(x) == 1 && is.finite(x) && x > 0) {
    as.numeric(x)
  } else {
    NA_real_
  }
}

#' @inheritParams read_idtracker
#' @keywords internal
read_idtracker_csv <- function(path, path_probabilities, version = 6) {
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages() |>
    janitor::clean_names() |>
    rename_idtracker_time_column()

  data <- data |>
    tidyr::pivot_longer(
      cols = !"time",
      names_to = c("coordinate", "individual"),
      names_sep = "(?<=[A-Za-z])(?=[0-9])",
      values_to = "val"
    ) |>
    tidyr::pivot_wider(
      id_cols = c("time", "individual"),
      names_from = "coordinate",
      values_from = "val"
    )

  if (!is.null(path_probabilities)) {
    probs <- read_idtracker_probabilities(path_probabilities)
    data <- dplyr::left_join(data, probs, by = c("individual", "time"))
  }

  # Individuals are numbered by their columns, so levels follow the numbers
  # ("2" before "10").
  ids <- unique(data$individual)
  data <- data |>
    nan_to_na() |>
    dplyr::mutate(
      individual = factor(
        .data$individual,
        levels = ids[order(as.integer(ids))]
      ),
      keypoint = factor("centroid")
    ) |>
    dplyr::relocate("keypoint", .after = "individual")

  return(data)
}

#' @inheritParams read_idtracker
#' @keywords internal
read_idtracker_probabilities <- function(path) {
  data <- vroom::vroom(
    path,
    delim = ",",
    show_col_types = FALSE
  ) |>
    suppressMessages() |>
    janitor::clean_names() |>
    rename_idtracker_time_column()

  data <- data |>
    tidyr::pivot_longer(
      cols = !"time",
      names_to = c("placeholder", "individual"),
      names_sep = "(?<=[A-Za-z])(?=[0-9])",
      values_to = "confidence"
    ) |>
    dplyr::select(-"placeholder")
  data
}

# idtracker.ai renamed the leading time column from `seconds` to `time`
# in newer releases. Accept either, normalising to `time`. It writes no
# time column when it could not read the video's frame rate; the rows are
# then numbered as idtracker.ai numbers frames, from 0.
#' @keywords internal
rename_idtracker_time_column <- function(data) {
  if ("seconds" %in% names(data) && !"time" %in% names(data)) {
    data <- dplyr::rename(data, time = "seconds")
  }
  if (!"time" %in% names(data)) {
    data <- dplyr::mutate(data, time = dplyr::row_number() - 1, .before = 1)
  }
  data
}

#' Whether an idtracker.ai CSV export has a time column
#'
#' idtracker.ai writes `seconds` (`time` in newer releases) as the first
#' column of `trajectories.csv` when it knows the video's frame rate, and
#' no time column when it could not read one.
#'
#' @param path Path to `trajectories.csv`.
#' @return `TRUE` or `FALSE`.
#' @noRd
idtracker_csv_has_time <- function(path) {
  any(c("seconds", "time") %in% peek_header(path))
}

#' @inheritParams read_idtracker
#' @keywords internal
read_idtracker_h5 <- function(path, version = version) {
  # Check that rhdf5 is installed
  check_rhdf5()

  traj_dimensions <- rhdf5::h5ls(path) |>
    dplyr::as_tibble(.name_repair = "unique") |>
    dplyr::filter(.data$name == "trajectories") |>
    dplyr::pull(dim) |>
    strsplit(" x ")

  n_individuals <- traj_dimensions[[1]][2] |> as.numeric()

  data <- data.frame()
  for (i in 1:n_individuals) {
    trajectories <- rhdf5::h5read(path, "trajectories")[, i, ] |>
      t() |>
      dplyr::as_tibble(.name_repair = "unique") |>
      suppressMessages() |>
      dplyr::rename(x = "...1", y = "...2")

    probs <- rhdf5::h5read(path, "id_probabilities")[, i, ] |>
      dplyr::as_tibble(.name_repair = "unique") |>
      dplyr::rename(confidence = "value")

    data_temp <- dplyr::bind_cols(trajectories, probs) |>
      dplyr::mutate(
        individual = factor(i),
        keypoint = factor("centroid"),
        # One row per frame of the video, from idtracker.ai's frame 0.
        time = dplyr::row_number() - 1
      )

    data <- dplyr::bind_rows(data, data_temp)
  }

  data <- data |>
    nan_to_na() |>
    dplyr::relocate("keypoint", .before = "x") |>
    dplyr::relocate("individual", .before = "keypoint") |>
    dplyr::relocate("time", .before = "individual") |>
    dplyr::mutate(
      individual = factor(.data$individual),
      keypoint = factor(.data$keypoint)
    )
  return(data)
}

#' Turn the NaN idtracker.ai writes for a lost position into NA
#'
#' Only the numeric columns: `ifelse()` over a factor would return its codes.
#' @noRd
nan_to_na <- function(data) {
  dplyr::mutate(
    data,
    dplyr::across(dplyr::where(is.double), \(x) replace(x, is.nan(x), NA))
  )
}
