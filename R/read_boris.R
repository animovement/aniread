#' Read events from a BORIS export
#'
#' @description Read behavioural events from a
#'   [BORIS](https://www.boris.unito.it/) export into an
#'   [aniframe::anievent()]. Two flat-text BORIS exports are
#'   supported: **aggregated events** (one row per bout, the default
#'   export shape) and **tabular events** (one row per START / STOP /
#'   POINT transition; paired into bouts by the reader).
#'
#'   Time units come from the columns BORIS provides. The default
#'   `unit_time = "s"` uses `Start (s)` / `Stop (s)` and works on any
#'   BORIS export. With `unit_time = "frame"` the reader uses the
#'   `Image index start` / `Image index stop` columns instead; frames
#'   stay aligned with rows of a host [aniframe::aniframe()], which
#'   makes [aniframe::add_events()] safe against effective-FPS drift
#'   when the export is paired with movement data. If `"frame"` is
#'   requested but the export carries no image-index columns, the
#'   reader falls back to `"s"` with an informational message. FPS is
#'   recorded as `sampling_rate` metadata without rescaling the
#'   timestamps; call [aniframe::set_sampling_rate()] later if you
#'   need to convert between frames and seconds.
#'
#'   Channels: each row's `channel` is the value of BORIS's
#'   `Behavioral category` column when populated, falling back to the
#'   literal `"behavior"` otherwise; `value` is the behaviour name.
#'   Channels are conventionally mutually exclusive within a subject
#'   — [aniframe::validate_anievent()] is called at the end of
#'   reading and warns (rather than errors) when bouts overlap.
#'   Modifiers travel via the optional `modifiers` list-column; both
#'   single-column pipe-separated (`a|b|None`) and multi-column
#'   (`Modifier #1`, `Modifier #2`, ...) layouts are accepted.
#'
#' @param path Path to a BORIS export (`.tsv` or `.csv`).
#' @param format One of `"auto"`, `"aggregated"`, `"tabular"`. The
#'   default `"auto"` sniffs the format from the first row of the
#'   file.
#' @param unit_time One of `"s"`, `"frame"`. Default `"s"`. `"frame"`
#'   uses the BORIS image-index columns; pass it when pairing the
#'   anievent with an aniframe to keep frame-aligned semantics.
#'
#' @return An [aniframe::anievent()] with metadata fields `source`,
#'   `filename`, `unit_time`, `sampling_rate` (when FPS is a single
#'   numeric in the export), and `variables_event` populated.
#'
#' @references
#' - Friard, O., & Gamba, M. (2016). BORIS: a free, versatile open-source
#'   event-logging software for video/audio coding and live observations.
#'   *Methods in Ecology and Evolution*, 7(11), 1325-1330.
#'   \doi{10.1111/2041-210X.12584}.
#'
#' @export
read_boris <- function(
  path,
  format = c("auto", "aggregated", "tabular"),
  unit_time = c("s", "frame")
) {
  format <- match.arg(format)
  unit_time <- match.arg(unit_time)

  validate_files(path, expected_suffix = c("tsv", "csv"))

  if (format == "auto") {
    format <- detect_boris_format(path)
  }

  events <- switch(
    format,
    aggregated = read_boris_aggregated(path),
    tabular = read_boris_tabular(path)
  )

  finalise_boris(events, path = path, unit_time = unit_time)
}


# ---- Format dispatch ----

#' @keywords internal
detect_boris_format <- function(path) {
  delim <- boris_delim(path)
  lines <- readLines(path, n = 30, warn = FALSE)
  if (length(lines) == 0 || !nzchar(lines[[1]])) {
    cli::cli_abort("BORIS file appears empty: {.path {path}}")
  }
  first_cols <- strsplit(lines[[1]], delim, fixed = TRUE)[[1]]
  if (any(c("Subject", "Behavior") %in% first_cols)) {
    return("aggregated")
  }
  # Tabular: header block first, then a `Time<delim>...<delim>Status` row.
  has_tabular_marker <- any(grepl("^Time(\t|,)", lines))
  if (has_tabular_marker) {
    return("tabular")
  }
  cli::cli_abort(c(
    "Could not detect BORIS export format from {.path {basename(path)}}.",
    "i" = "Aggregated exports must have a header row containing {.val Subject} / {.val Behavior}.",
    "i" = "Tabular exports must contain a {.val Time ... Status} row.",
    "i" = "If you have a headerless export, re-export from BORIS with headers enabled."
  ))
}

#' @keywords internal
boris_delim <- function(path) {
  if (identical(tolower(get_file_ext(path)), "csv")) "," else "\t"
}


# ---- Aggregated events ----

#' @keywords internal
read_boris_aggregated <- function(path) {
  delim <- boris_delim(path)
  raw <- vroom::vroom(
    path,
    delim = delim,
    show_col_types = FALSE,
    .name_repair = "minimal"
  ) |>
    suppressMessages()
  attributes(raw)$spec <- NULL
  attributes(raw)$problems <- NULL

  # Parse modifiers first — the multi-column form (`Modifier #1`,
  # `Modifier #2`, ...) needs the original names before janitor
  # rewrites them into something like `modifier_number_1`.
  raw <- parse_boris_modifiers(raw)
  raw <- standardise_boris_columns(raw)
  raw
}


# ---- Tabular events ----

#' @keywords internal
read_boris_tabular <- function(path) {
  delim <- boris_delim(path)
  lines <- readLines(path, warn = FALSE)
  split_idx <- find_tabular_split(lines)

  header_block <- lines[seq_len(split_idx - 1)]
  data_lines <- lines[seq(split_idx, length(lines))]
  data_lines <- data_lines[!is_empty_row(data_lines, delim)]

  meta <- parse_tabular_header_block(header_block, delim)

  data_text <- paste(data_lines, collapse = "\n")
  events <- vroom::vroom(
    I(data_text),
    delim = delim,
    show_col_types = FALSE,
    .name_repair = "minimal"
  ) |>
    suppressMessages()
  attributes(events)$spec <- NULL
  attributes(events)$problems <- NULL

  events <- broadcast_tabular_metadata(events, meta)
  events <- parse_boris_modifiers(events)
  events <- standardise_boris_columns(events)
  pair_tabular_events(events)
}

#' @keywords internal
find_tabular_split <- function(lines) {
  data_header <- which(grepl("^Time(\t|,)", lines))
  if (length(data_header) == 0) {
    cli::cli_abort(
      "Could not locate the data-table header (a line starting with `Time`) in the tabular BORIS export."
    )
  }
  data_header[[1]]
}

#' @keywords internal
is_empty_row <- function(lines, delim) {
  stripped <- gsub(delim, "", lines, fixed = TRUE)
  !nzchar(trimws(stripped))
}

#' @keywords internal
parse_tabular_header_block <- function(header_block, delim) {
  meta <- list()
  for (line in header_block) {
    if (!nzchar(line)) {
      next
    }
    parts <- strsplit(line, delim, fixed = TRUE)[[1]]
    parts <- parts[nzchar(parts)]
    if (length(parts) < 2) {
      next
    }
    key <- parts[[1]]
    value <- parts[[2]]
    if (key %in% c("variable", "independent variables")) {
      next
    }
    # Player #1, Player #2, ... are media-file slot names in the BORIS
    # UI — redundant with the per-row `Media file path` column in the
    # data table, so we drop them rather than emit awkwardly-cleaned
    # `player_number_1` columns.
    if (grepl("^Player #", key)) {
      next
    }
    meta[[key]] <- value
  }
  meta
}

#' @keywords internal
broadcast_tabular_metadata <- function(events, meta) {
  # Lift the header-block key/value pairs into per-row columns so the
  # downstream pipeline is the same shape as the aggregated path.
  for (key in names(meta)) {
    if (!key %in% names(events)) {
      events[[key]] <- rep(meta[[key]], nrow(events))
    }
  }
  events
}

#' @keywords internal
pair_tabular_events <- function(events) {
  if (!"status" %in% names(events)) {
    cli::cli_abort(
      "Tabular BORIS export is missing the {.field Status} column."
    )
  }
  if (!"time" %in% names(events)) {
    cli::cli_abort(
      "Tabular BORIS export is missing the {.field Time} column."
    )
  }

  events$time <- as.numeric(events$time)
  events$.row_idx <- seq_len(nrow(events))

  group_cols <- intersect(
    c("observation", "subject", "behavior"),
    names(events)
  )
  fp <- if ("modifiers" %in% names(events)) {
    vapply(
      events$modifiers,
      function(x) paste(x, collapse = ""),
      character(1)
    )
  } else {
    rep("", nrow(events))
  }
  events$.group_key <- paste(
    do.call(paste, c(events[group_cols], list(sep = "\r"))),
    fp,
    sep = "\r"
  )

  events <- events[
    order(events$.group_key, events$time, events$.row_idx),
    ,
    drop = FALSE
  ]

  start_buf <- list()
  bouts <- vector("list", nrow(events))
  n_bouts <- 0L
  unmatched_starts <- integer()
  unmatched_stops <- integer()

  for (i in seq_len(nrow(events))) {
    status <- events$status[i]
    key <- events$.group_key[i]

    if (identical(status, "POINT")) {
      row <- events[i, , drop = FALSE]
      row$start_s <- events$time[i]
      row$stop_s <- events$time[i]
      row$behavior_type <- "POINT"
      n_bouts <- n_bouts + 1L
      bouts[[n_bouts]] <- row
    } else if (identical(status, "START")) {
      start_buf[[key]] <- c(start_buf[[key]], i)
    } else if (identical(status, "STOP")) {
      if (!is.null(start_buf[[key]]) && length(start_buf[[key]]) > 0) {
        start_i <- start_buf[[key]][[1]]
        start_buf[[key]] <- start_buf[[key]][-1]
        row <- events[start_i, , drop = FALSE]
        row$start_s <- events$time[start_i]
        row$stop_s <- events$time[i]
        row$behavior_type <- "STATE"
        n_bouts <- n_bouts + 1L
        bouts[[n_bouts]] <- row
      } else {
        unmatched_stops <- c(unmatched_stops, events$.row_idx[i])
      }
    }
  }

  for (key in names(start_buf)) {
    leftover <- start_buf[[key]]
    if (length(leftover) > 0) {
      unmatched_starts <- c(unmatched_starts, events$.row_idx[leftover])
    }
  }

  if (length(unmatched_starts) > 0) {
    cli::cli_warn(c(
      "Dropped {length(unmatched_starts)} unmatched {.val START} event{?s} (no following {.val STOP}).",
      "i" = "Input row{?s}: {sort(unmatched_starts)}"
    ))
  }
  if (length(unmatched_stops) > 0) {
    cli::cli_warn(c(
      "Dropped {length(unmatched_stops)} unmatched {.val STOP} event{?s} (no preceding {.val START}).",
      "i" = "Input row{?s}: {sort(unmatched_stops)}"
    ))
  }

  if (n_bouts == 0L) {
    out <- events[0, , drop = FALSE]
    out$start_s <- numeric()
    out$stop_s <- numeric()
    out$behavior_type <- character()
  } else {
    out <- dplyr::bind_rows(bouts[seq_len(n_bouts)])
  }

  out$.row_idx <- NULL
  out$.group_key <- NULL
  out$time <- NULL
  out$status <- NULL
  out
}


# ---- Shared column standardisation ----

#' @keywords internal
boris_column_renames <- function() {
  c(
    "Observation id" = "observation",
    "Observation date" = "observation_date",
    "Description" = "description",
    "Observation type" = "observation_type",
    "Source" = "source_media",
    "Time offset (s)" = "time_offset",
    "Coding duration" = "coding_duration",
    "Total duration" = "total_duration",
    "Total length" = "total_length",
    "Media duration (s)" = "media_duration",
    "FPS" = "fps",
    "FPS (frame/s)" = "fps",
    "Subject" = "subject",
    "Observation duration by subject by observation" = "duration_by_subject",
    "Behavior" = "behavior",
    "Behavioral category" = "behavioral_category",
    "Behavior type" = "behavior_type",
    "Start (s)" = "start_s",
    "Stop (s)" = "stop_s",
    "Duration (s)" = "duration_s",
    "Media file" = "media_file",
    "Media file name" = "media_file",
    "Media file path" = "media_file",
    "Image index start" = "image_index_start",
    "Image index stop" = "image_index_stop",
    "Image file path start" = "image_file_path_start",
    "Image file path stop" = "image_file_path_stop",
    "Comment start" = "comment_start",
    "Comment stop" = "comment_stop",
    "Comment" = "comment",
    "Time" = "time",
    "Status" = "status"
  )
}

#' @keywords internal
standardise_boris_columns <- function(data) {
  renames <- boris_column_renames()
  for (i in seq_along(renames)) {
    src <- names(renames)[[i]]
    dst <- renames[[i]]
    if (src %in% names(data) && !dst %in% names(data)) {
      names(data)[match(src, names(data))] <- dst
    }
  }
  # Snake-case any leftover columns (independent variables, etc.)
  remaining <- setdiff(names(data), unname(renames))
  if (length(remaining) > 0) {
    cleaned <- janitor::make_clean_names(remaining)
    names(data)[match(remaining, names(data))] <- cleaned
  }
  data
}

#' @keywords internal
parse_boris_modifiers <- function(data) {
  mod_cols <- grep("^Modifier #", names(data), value = TRUE)
  if (length(mod_cols) > 0) {
    mod_matrix <- as.matrix(data[, mod_cols, drop = FALSE])
    mods <- lapply(seq_len(nrow(mod_matrix)), function(i) {
      clean_modifier_tokens(mod_matrix[i, ])
    })
    for (col in mod_cols) {
      data[[col]] <- NULL
    }
    data$modifiers <- mods
  } else if ("Modifiers" %in% names(data) || "modifiers" %in% names(data)) {
    col <- if ("Modifiers" %in% names(data)) "Modifiers" else "modifiers"
    raw <- data[[col]]
    mods <- lapply(raw, function(cell) {
      if (is.na(cell) || !nzchar(cell)) {
        return(character())
      }
      tokens <- unlist(strsplit(as.character(cell), "|", fixed = TRUE))
      clean_modifier_tokens(tokens)
    })
    data[[col]] <- NULL
    data$modifiers <- mods
  }
  data
}

#' @keywords internal
clean_modifier_tokens <- function(tokens) {
  if (length(tokens) == 0) {
    return(character())
  }
  tokens <- trimws(as.character(tokens))
  tokens <- tokens[!is.na(tokens) & nzchar(tokens) & tokens != "None"]
  tokens
}


# ---- Finalisation: unit_time, channels, metadata ----

#' @keywords internal
finalise_boris <- function(data, path, unit_time) {
  unit_time <- choose_unit_time(data, unit_time)

  if (unit_time == "frame") {
    data$start <- as.numeric(data$image_index_start)
    data$stop <- as.numeric(data$image_index_stop)
  } else {
    data$start <- as.numeric(data$start_s)
    data$stop <- as.numeric(data$stop_s)
  }
  # Capture FPS before dropping the column.
  fps <- extract_boris_fps(data)

  data$start_s <- NULL
  data$stop_s <- NULL
  data$image_index_start <- NULL
  data$image_index_stop <- NULL
  data$duration_s <- NULL
  # FPS is captured in metadata$sampling_rate; total_length has no
  # current metadata home (see animovement/aniframe#73) — drop both
  # to avoid redundancy / dishonest data columns.
  data$fps <- NULL
  data$total_length <- NULL

  if ("behavioral_category" %in% names(data)) {
    cat_vec <- as.character(data$behavioral_category)
    cat_vec[is.na(cat_vec) | !nzchar(cat_vec)] <- NA_character_
    data$channel <- ifelse(is.na(cat_vec), "behavior", cat_vec)
  } else {
    data$channel <- "behavior"
  }
  data$value <- as.character(data$behavior)

  variables_event <- classify_boris_channels(data)

  data$behavior <- NULL
  data$behavioral_category <- NULL
  data$behavior_type <- NULL

  ae <- aniframe::anievent(data)

  ae <- aniframe::set_metadata(
    ae,
    source = "boris",
    filename = basename(path),
    unit_time = unit_time,
    variables_event = variables_event,
    # Spatial fields are inherited from the shared metadata substrate
    # but don't apply to event data. Set what we can to neutral values
    # (`none` / `unknown`); the rest stay at the aniframe default
    # until animovement/aniframe#73 lands.
    unit_space = "none",
    coordinate_system = "unknown"
  )
  if (!is.null(fps)) {
    ae <- aniframe::set_metadata(ae, sampling_rate = fps)
  }

  aniframe::validate_anievent(ae)
  ae
}

#' @keywords internal
choose_unit_time <- function(data, requested) {
  if (requested == "frame") {
    has_idx <- all(
      c("image_index_start", "image_index_stop") %in% names(data)
    ) &&
      any(!is.na(data$image_index_start) & !is.na(data$image_index_stop))
    if (!has_idx) {
      cli::cli_inform(c(
        "i" = "No populated image-index columns in this BORIS export.",
        "i" = "Falling back to {.field unit_time = \"s\"}."
      ))
      return("s")
    }
    return("frame")
  }
  "s"
}

#' @keywords internal
classify_boris_channels <- function(data) {
  if (!"behavior_type" %in% names(data) || !"channel" %in% names(data)) {
    return(list(state = character(), point = character()))
  }
  by_channel <- split(
    as.character(data$behavior_type),
    as.character(data$channel)
  )
  state_channels <- character()
  point_channels <- character()
  for (ch in names(by_channel)) {
    types <- by_channel[[ch]]
    has_state <- any(types == "STATE", na.rm = TRUE)
    has_point <- any(types == "POINT", na.rm = TRUE)
    if (has_point && !has_state) {
      point_channels <- c(point_channels, ch)
    } else {
      state_channels <- c(state_channels, ch)
    }
  }
  list(state = state_channels, point = point_channels)
}

#' @keywords internal
extract_boris_fps <- function(data) {
  if (!"fps" %in% names(data)) {
    return(NULL)
  }
  vals <- unique(suppressWarnings(as.numeric(data$fps)))
  vals <- vals[!is.na(vals)]
  if (length(vals) == 1) vals else NULL
}
