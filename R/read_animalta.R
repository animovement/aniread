#' @title Read AnimalTA data
#' @name read_animalta
#'
#' @description Read a data frame from AnimalTA. AnimalTA exports tracking
#' data in image (top-left) coordinates; the reader reflects y so the
#' returned aniframe is in the conventional `bottom_left` origin.
#'
#' AnimalTA writes positions in three layouts, and the reader reads all
#' three. Which one it read is recorded in the `source_format` metadata
#' field.
#'
#' * `"fixed"`: the coordinates file of a video tracked with a fixed number
#'   of targets (`coordinates/<video>_Coordinates.csv`, or
#'   `corrected_coordinates/<video>_Corrected.csv` once corrected). One row
#'   per frame, with a pair of columns per target, `X_Arena<a>_Ind<i>` and
#'   `Y_Arena<a>_Ind<i>`. When a target alone in its arena was tracked with
#'   AnimalTA's "Separate head from tail" option, its pair is replaced by
#'   `X_Arena<a>_Ind<i>_Head`, `Y_..._Head`, `X_..._Tail` and `Y_..._Tail`.
#'   Once the tracking is corrected, AnimalTA holds them as two targets and
#'   names the same columns `X_Arena<a>_Ind<i>_part0` and so on for the head
#'   and `..._part1` for the tail. Both become the keypoints `head` and `tail`
#'   of `Ind<i>`; AnimalTA writes no centroid for such a target. Every other
#'   target has the keypoint `centroid`, AnimalTA's name for the one position
#'   it tracks.
#' * `"variable"`: the coordinates file of a video tracked with a variable
#'   number of targets. One row per target and frame, in the columns
#'   `Frame`, `Time`, `Arena`, `Ind`, `X` and `Y`.
#' * `"detailed"`: a file from the "Detailed data" folder that AnimalTA's
#'   "Run analyses" writes, `Results/Detailed_data/<video>/Arena_<a><target>.csv`.
#'   It holds one target, one row per frame, and the columns ticked under
#'   "Detailed data columns": by default `Time`, `X`, `Y` (`X_Smoothed` and
#'   `Y_Smoothed` when a smoothing filter was applied) and measures derived
#'   from them, such as `Distance` and `Speed`. Only the time and positions
#'   are kept. The target is named from the file name. Several files, one per
#'   target, can be read at once by passing their paths together. A target
#'   tracked with "Separate head from tail" has two files,
#'   `Arena_<a>Ind<i>_part0.csv` for its head and `Arena_<a>Ind<i>_part1.csv`
#'   for its tail, which read together as the keypoints `head` and `tail` of
#'   one individual.
#'
#' AnimalTA's head and tail are the two ends of the animal's skeleton, kept
#' apart from frame to frame by distance. AnimalTA does not work out which end
#' is the head, so check that `head` is the head before relying on it.
#'
#' Positions in the coordinates files are in pixels. Positions in a detailed
#' file are in the unit of the scale set in AnimalTA, and in pixels when none
#' was set. The file does not record which, so `unit_space` keeps its default
#' of `"px"`; if a scale was set, declare its unit with
#' [anicore::set_metadata()], and give `video_height` in that unit too.
#'
#' AnimalTA writes the time since the start of the video in seconds in its
#' `Time` column, rounded to 0.01 s in the coordinates files and to 0.001 s in
#' a detailed file. The reader keeps it as `time`, so `unit_time` is `"s"`. A
#' detailed file exported without the `Time` column but with `Frame` is
#' timed by its frame number instead, with `unit_time` `"frame"`.
#'
#' AnimalTA does not write the frame rate, but each row is a frame at the
#' rate it tracked at: the coordinates files give its number in `Frame`, and
#' a detailed file has a row for every frame. When every row agrees on one
#' rate, to within the rounding of `Time`, it becomes `sampling_rate`: the
#' frames between the first and last row over the seconds between them, or
#' the whole number nearest to it when that fits every row as well. Otherwise
#' it is left `NA`. In a short file the rounding leaves the rate uncertain by
#' about one rounding step over the file's duration.
#'
#' AnimalTA numbers individuals from 0 within each arena, so an individual is
#' identified by its arena and its name together. The arena is its own
#' identity column, `arena`, holding AnimalTA's arena number (`"0"`, `"1"`,
#' ...), and `individual` holds AnimalTA's name for the target: `Ind<i>`, or
#' the name it was given in AnimalTA, with its case kept. Every layout gives
#' the same values: the fixed layout's columns are named `X_Arena<a>_Ind<i>`,
#' the variable layout's `Arena` and `Ind` columns hold the same arena and
#' target, and so does a detailed file's name, `Arena_<a>Ind<i>.csv`. A
#' detailed file whose name is not in that form is named after the file, with
#' its arena `NA`. `arena`, `individual` and `keypoint` are the aniframe's
#' identity keys, so functions that work per individual keep arenas apart.
#' The `arena` column is there for every file, also when it has a single
#' arena.
#'
#' @param path Path to an AnimalTA file. Several detailed files, one per
#'   target, can be given together.
#' @param format `r lifecycle::badge("experimental")` Which layout the file
#'   uses: `"auto"` (the default) reads it from the header; `"fixed"`,
#'   `"variable"` or `"detailed"` require that layout and error on anything
#'   else. The layout names may change while one convention for readers of a
#'   source with several export layouts is settled
#'   ([#118](https://github.com/animovement/aniread/issues/118)).
#' @param video_height Optional numeric height of the source video frame, in
#'   pixels for the coordinates files. AnimalTA does not record this in the
#'   export, so when not supplied the maximum observed `y` is used as a
#'   fallback.
#' @param detailed `r lifecycle::badge("deprecated")` Use `format` instead.
#'   `detailed = TRUE` named the layout of a variable number of targets,
#'   now `format = "variable"`, and `detailed = FALSE` the fixed one, now
#'   `format = "fixed"`.
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
read_animalta <- function(
  path,
  format = c("auto", "fixed", "variable", "detailed"),
  video_height = NULL,
  detailed = deprecated()
) {
  # `detailed` was the second argument, so a logical given by position
  # lands in `format`.
  if (is.logical(format)) {
    detailed <- format
    format <- "auto"
  }
  validate_files(path)
  if (lifecycle::is_present(detailed)) {
    lifecycle::deprecate_warn(
      "0.8.0",
      "read_animalta(detailed)",
      "read_animalta(format)"
    )
    format <- animalta_format_from_detailed(detailed)
  }
  format <- resolve_animalta_layout(path, format)

  if (format != "detailed" && length(path) > 1) {
    cli::cli_abort(c(
      "Only detailed files can be read several at once.",
      "x" = "{.path {basename(path[[1]])}} is in the {.val {format}} layout,
             which holds every target of a video in one file."
    ))
  }

  if (format == "detailed") {
    detailed_data <- read_animalta_detailed(path)
    data <- detailed_data$data
    sampling_rate <- detailed_data$sampling_rate
    unit_time <- detailed_data$unit_time
  } else {
    data <- switch(
      format,
      fixed = read_animalta_fixed(path),
      variable = read_animalta_variable(path)
    )
    unit_time <- "s"
    sampling_rate <- rate_from_frames(data$frame, data$time)
  }

  data <- data |>
    dplyr::select(-"frame") |>
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
      source_format = format,
      filename = basename(path[[1]]),
      unit_time = unit_time,
      sampling_rate = sampling_rate
    ) |>
    reflect_to_bottom_left(video_height = video_height)

  return(data)
}

#' Read AnimalTA's coordinates file for a fixed number of targets
#'
#' @inheritParams read_animalta
#' @return A data frame of `frame`, `time`, `arena`, `individual`,
#'   `keypoint`, `x` and `y`.
#' @noRd
read_animalta_fixed <- function(path) {
  validate_files(
    path,
    expected_suffix = "csv",
    expected_headers = c("Frame", "Time")
  )
  data <- vroom::vroom(
    path,
    delim = ";",
    na = c("", "NA"),
    show_col_types = FALSE
  )
  coordinate_cols <- setdiff(names(data), c("Frame", "Time"))
  columns <- parse_animalta_columns(coordinate_cols)

  data |>
    dplyr::rename(frame = "Frame", time = "Time") |>
    tidyr::pivot_longer(
      cols = tidyselect::all_of(coordinate_cols),
      names_to = "column",
      values_to = "val",
      values_transform = list(val = as.numeric)
    ) |>
    dplyr::left_join(columns, by = "column") |>
    tidyr::pivot_wider(
      id_cols = c("frame", "time", "arena", "individual", "keypoint"),
      names_from = "coordinate",
      values_from = "val"
    ) |>
    dplyr::mutate(
      frame = as.numeric(.data$frame),
      time = as.numeric(.data$time)
    ) |>
    dplyr::select(
      "frame",
      "time",
      "arena",
      "individual",
      "keypoint",
      "x",
      "y"
    )
}

#' Split AnimalTA's coordinate column names into their parts
#'
#' AnimalTA names a target's columns `X_Arena<a>_<target>` and
#' `Y_Arena<a>_<target>`, where the target is `Ind<i>` unless it was renamed.
#' Head and tail columns are split off the target by
#' `animalta_target_parts()`.
#'
#' @param columns The column names after `Frame` and `Time`.
#' @return A data frame of `column`, `coordinate`, `arena`, `individual`
#'   and `keypoint`, one row per column.
#' @noRd
parse_animalta_columns <- function(columns) {
  pattern <- "^([XY])_Arena([0-9]+)_(.+)$"
  unknown <- columns[!grepl(pattern, columns)]
  if (length(unknown) > 0) {
    cli::cli_abort(c(
      "Cannot read the coordinate columns of this AnimalTA file.",
      "x" = "Expected {.code X_Arena<a>_<target>} and
             {.code Y_Arena<a>_<target>}, but found {.val {unknown}}."
    ))
  }
  parts <- animalta_target_parts(sub(pattern, "\\3", columns))

  data.frame(
    column = columns,
    coordinate = tolower(sub(pattern, "\\1", columns)),
    arena = sub(pattern, "\\2", columns),
    individual = parts$individual,
    keypoint = parts$keypoint
  )
}

#' Read AnimalTA's coordinates file for a variable number of targets
#'
#' @inheritParams read_animalta
#' @return A data frame of `frame`, `time`, `arena`, `individual`,
#'   `keypoint`, `x` and `y`.
#' @noRd
read_animalta_variable <- function(path) {
  validate_files(
    path,
    expected_suffix = "csv",
    expected_headers = c("Frame", "Time", "Arena", "Ind", "X", "Y")
  )
  # Tracking writes `Ind` as a number; once corrected, AnimalTA writes the
  # target's name (`Ind<i>`, or the name it was given).
  data <- vroom::vroom(
    path,
    delim = ";",
    na = c("", "NA"),
    col_types = vroom::cols(Arena = "c", Ind = "c", .default = "d"),
    show_col_types = FALSE
  )

  parts <- animalta_target_parts(data$Ind)

  data.frame(
    frame = data$Frame,
    time = data$Time,
    arena = data$Arena,
    individual = parts$individual,
    keypoint = parts$keypoint,
    x = data$X,
    y = data$Y
  )
}

#' Read AnimalTA's detailed data files
#'
#' Each file holds one target, with a row for every frame from the first
#' to the last in which it was tracked. AnimalTA writes `nan` where the
#' target was lost.
#'
#' @inheritParams read_animalta
#' @return A list of `data` (a data frame of `frame`, `time`, `arena`,
#'   `individual`, `keypoint`, `x` and `y`), `unit_time` and
#'   `sampling_rate`.
#' @noRd
read_animalta_detailed <- function(path) {
  files <- lapply(path, read_animalta_detailed_file)

  has_time <- vapply(files, \(f) "time" %in% names(f), logical(1))
  if (length(unique(has_time)) > 1) {
    cli::cli_abort(c(
      "The detailed files do not all have a {.field Time} column.",
      "i" = "Export them again with the same detailed data columns."
    ))
  }

  if (!has_time[[1]]) {
    # Timed by frame number; there is no time to take a rate from.
    files <- lapply(files, \(f) dplyr::mutate(f, time = .data$frame))
    unit_time <- "frame"
    sampling_rate <- NA_real_
  } else {
    unit_time <- "s"
    # Per file: without a Frame column, the frames are counted from each
    # file's first row, which is a different frame for each target.
    rates <- vapply(
      files,
      \(f) rate_from_frames(f$frame, f$time),
      numeric(1)
    )
    sampling_rate <- if (length(unique(rates)) == 1) rates[[1]] else NA_real_
  }

  data <- do.call(rbind, files) |>
    dplyr::select(
      "frame",
      "time",
      "arena",
      "individual",
      "keypoint",
      "x",
      "y"
    )
  list(data = data, unit_time = unit_time, sampling_rate = sampling_rate)
}

#' Read one AnimalTA detailed data file
#'
#' @param path Path to the file.
#' @return A data frame of `frame`, `arena`, `individual`, `keypoint`, `x`,
#'   `y`, and `time` when the file has a `Time` column.
#' @noRd
read_animalta_detailed_file <- function(path) {
  validate_files(path, expected_suffix = "csv")
  header <- peek_header(path, delim = ";")
  xy <- animalta_detailed_xy(header)
  if (is.null(xy)) {
    cli::cli_abort(c(
      "{.path {basename(path)}} has no positions to read.",
      "x" = "A detailed file needs its {.field X} and {.field Y} columns
             ({.field X_Smoothed} and {.field Y_Smoothed} when smoothed).",
      "i" = "Tick {.val X-Y_Coordinates} under \"Detailed data columns\" in
             AnimalTA and run the analyses again."
    ))
  }
  if (!any(c("Frame", "Time") %in% header)) {
    cli::cli_abort(c(
      "{.path {basename(path)}} has no time to read.",
      "x" = "A detailed file needs its {.field Time} or {.field Frame}
             column."
    ))
  }

  target <- animalta_detailed_target(path)
  # AnimalTA names a `Dist_to_<target>` column for every other target in the
  # arena, but writes the distances only when the arena was tracked with more
  # than one target. The head and tail of a lone target are two targets of a
  # one-target arena, so their rows are one value short of the header. That
  # is expected; anything else vroom could not parse is still reported.
  data <- withCallingHandlers(
    vroom::vroom(
      path,
      delim = ";",
      na = c("", "NA", "nan"),
      col_select = tidyselect::any_of(c("Frame", "Time", xy)),
      col_types = vroom::cols(.default = "d"),
      show_col_types = FALSE,
      altrep = FALSE
    ),
    vroom_parse_issue = function(w) invokeRestart("muffleWarning")
  )
  problems <- vroom::problems(data)
  problems <- problems[!grepl("columns$", problems$expected), ]
  if (nrow(problems) > 0) {
    rows <- unique(problems$row)
    cli::cli_warn(c(
      "Some values in {.path {basename(path)}} could not be read and are
       {.val NA}.",
      "i" = "See {cli::qty(length(rows))}line{?s} {rows} of the file."
    ))
  }

  out <- data.frame(
    # One row per frame, so the row is the frame when `Frame` is not there.
    frame = if ("Frame" %in% names(data)) {
      data$Frame
    } else {
      seq_len(nrow(data)) - 1
    },
    arena = target$arena,
    individual = target$individual,
    keypoint = target$keypoint,
    x = data[[xy[[1]]]],
    y = data[[xy[[2]]]]
  )
  if ("Time" %in% names(data)) {
    out$time <- data$Time
  }
  out
}

#' The position columns of an AnimalTA detailed file
#'
#' @param header The file's column names.
#' @return `c("X", "Y")`, `c("X_Smoothed", "Y_Smoothed")`, or `NULL` when
#'   the file has neither.
#' @noRd
animalta_detailed_xy <- function(header) {
  for (xy in list(c("X", "Y"), c("X_Smoothed", "Y_Smoothed"))) {
    if (all(xy %in% header)) {
      return(xy)
    }
  }
  NULL
}

#' The arena and target of an AnimalTA detailed file
#'
#' AnimalTA names the file `Arena_<a><target>.csv`, with no separator
#' between the arena number and the target's name.
#'
#' @param path Path to the file.
#' @return A list of `arena`, `individual` and `keypoint`: the arena number,
#'   and the target as `animalta_target_parts()` splits it. When the file name
#'   is not in that form, the arena is `NA`, the individual is the file name
#'   without its extension, and the keypoint is `centroid`.
#' @noRd
animalta_detailed_target <- function(path) {
  stem <- sub("\\.[^.]*$", "", basename(path))
  pattern <- "^Arena_([0-9]+)(\\D.*)$"
  if (!grepl(pattern, stem)) {
    return(list(
      arena = NA_character_,
      individual = stem,
      keypoint = "centroid"
    ))
  }
  c(
    list(arena = sub(pattern, "\\1", stem)),
    animalta_target_parts(sub(pattern, "\\2", stem))
  )
}

#' Split an AnimalTA target into its individual and keypoint
#'
#' A target is the one position AnimalTA tracks for an animal, which it
#' calls its centroid. With "Separate head from tail", a target alone in its
#' arena is tracked as two positions instead, and no centroid is written:
#'
#' * the coordinates file written by tracking names them `Ind<i>_Head` and
#'   `Ind<i>_Tail` (`Treat_cnts_fixed()`);
#' * AnimalTA then holds them as two targets, `Ind<i>_part0` for the head
#'   columns and `Ind<i>_part1` for the tail ones, in that order, and writes
#'   those names into the corrected coordinates file and into the names of
#'   the detailed data files.
#'
#' Both become the keypoints `head` and `tail` of `Ind<i>`. A target renamed
#' in AnimalTA is kept as written.
#'
#' @param target The target as AnimalTA writes it: a number (the variable
#'   layout during tracking), `Ind<i>`, one of the head and tail names above,
#'   or a name given in AnimalTA.
#' @return A list of `individual` (as `animalta_target()` names it) and
#'   `keypoint` (`centroid`, `head` or `tail`).
#' @noRd
animalta_target_parts <- function(target) {
  target <- as.character(target)
  keypoint <- rep("centroid", length(target))

  named <- "^(Ind[0-9]+)_(Head|Tail)$"
  is_named <- grepl(named, target)
  keypoint[is_named] <- tolower(sub(named, "\\2", target[is_named]))
  target[is_named] <- sub(named, "\\1", target[is_named])

  numbered <- "^(Ind[0-9]+)_part([01])$"
  is_numbered <- grepl(numbered, target)
  keypoint[is_numbered] <- c("head", "tail")[
    as.integer(sub(numbered, "\\2", target[is_numbered])) + 1
  ]
  target[is_numbered] <- sub(numbered, "\\1", target[is_numbered])

  list(individual = animalta_target(target), keypoint = keypoint)
}

#' Name an AnimalTA target as AnimalTA does
#'
#' @param target The target as AnimalTA writes it: a number (the variable
#'   layout during tracking), `Ind<i>`, or a name given in AnimalTA.
#' @return `Ind<i>` for a numbered target, and the name, case kept, for a
#'   named one.
#' @noRd
animalta_target <- function(target) {
  sub("^([0-9]+)$", "Ind\\1", target)
}

#' AnimalTA's arena numbers as an identity key
#'
#' @param arena The arena numbers, as AnimalTA writes them.
#' @return A factor of the numbers as text, with its levels in numeric order
#'   so that arena 10 comes after arena 9.
#' @noRd
animalta_arena <- function(arena) {
  arena <- as.character(arena)
  values <- unique(arena[!is.na(arena)])
  factor(arena, levels = values[order(as.numeric(values))])
}


#' Work out which AnimalTA export layout a file uses
#'
#' AnimalTA's layouts are separable from their first line, so `"auto"`
#' reads the layout from the header rather than asking for it. Before it
#' looked, a file read with the wrong default gave a header error naming
#' columns the user had never heard of rather than pointing at the argument
#' (#88).
#'
#' @param path Path to the file, or several detailed files.
#' @param format `"auto"`, or the layout to require.
#'
#' @return `"fixed"`, `"variable"` or `"detailed"`.
#' @keywords internal
resolve_animalta_layout <- function(path, format) {
  format <- rlang::arg_match(
    format,
    c("auto", "fixed", "variable", "detailed"),
    error_arg = "format"
  )
  if (format != "auto") {
    return(format)
  }

  detected <- detect_animalta_format(path[[1]])
  if (is.na(detected)) {
    cli::cli_abort(c(
      "{.path {basename(path[[1]])}} is not a file AnimalTA writes.",
      "x" = "Its header matches none of AnimalTA's layouts.",
      "i" = "See {.fun aniread::read_animalta} for the layouts AnimalTA
             writes."
    ))
  }
  detected
}

#' Which AnimalTA layout a file's header belongs to
#'
#' @param path Path to the file.
#' @return `"fixed"`, `"variable"`, `"detailed"`, or `NA` when the header
#'   is none of them.
#' @noRd
detect_animalta_format <- function(path) {
  header <- peek_header(path, delim = ";")
  if (length(header) < 2) {
    return(NA_character_)
  }
  coordinates <- identical(header[1:2], c("Frame", "Time"))
  if (coordinates && all(c("Arena", "Ind", "X", "Y") %in% header)) {
    return("variable")
  }
  if (coordinates && any(grepl("^[XY]_Arena[0-9]+_", header))) {
    return("fixed")
  }
  # A detailed file starts with Frame or Time, whichever columns were
  # ticked, and positions follow.
  if (
    header[[1]] %in%
      c("Frame", "Time") &&
      !is.null(animalta_detailed_xy(header))
  ) {
    return("detailed")
  }
  NA_character_
}

#' The layout the deprecated `detailed` argument named
#'
#' @param detailed `TRUE`, `FALSE` or `"auto"`.
#' @return The matching `format`.
#' @noRd
animalta_format_from_detailed <- function(detailed) {
  if (identical(detailed, "auto")) {
    return("auto")
  }
  if (!rlang::is_bool(detailed)) {
    cli::cli_abort(c(
      "{.arg detailed} must be {.val auto}, {.val TRUE} or {.val FALSE}.",
      "x" = "Got {.val {detailed}}.",
      "i" = "{.arg detailed} is deprecated; use {.arg format}."
    ))
  }
  if (detailed) "variable" else "fixed"
}
