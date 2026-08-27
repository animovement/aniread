#' Read events from a BORIS export
#'
#' @description Read behavioural events from a
#'   [BORIS](https://www.boris.unito.it/) export into an
#'   [anicore::anievent()]. Two flat-text BORIS exports are
#'   supported: **aggregated events** (one row per bout, the default
#'   export shape) and **tabular events** (one row per START / STOP /
#'   POINT transition; paired into bouts by the reader).
#'
#'   Time units come from the columns BORIS provides. The default
#'   `unit_time = "s"` uses `Start (s)` / `Stop (s)` and works on any
#'   BORIS export. With `unit_time = "frame"` the reader uses the
#'   `Image index start` / `Image index stop` columns instead; frames
#'   stay aligned with rows of a host [anicore::aniframe()], which
#'   keeps event timing robust against effective-FPS drift when the
#'   export is paired with movement data. If `"frame"` is
#'   requested but the export carries no image-index columns, the
#'   reader falls back to `"s"` with an informational message. FPS is
#'   recorded as `sampling_rate` metadata without rescaling the
#'   timestamps; call [anicore::set_sampling_rate()] later if you
#'   need to convert between frames and seconds.
#'
#'   Channels: each row's `channel` is the value of BORIS's
#'   `Behavioral category` column when populated, falling back to the
#'   literal `"behavior"` otherwise; `label` is the behaviour name,
#'   and `type` is `"state"` or `"point"` mapped from BORIS's
#'   `Behavior type` column. Overlap between bouts of the same channel
#'   is permitted on the `anievent` side; [anicore::validate_anievent()]
#'   flags overlapping state bouts with a warning rather than rejecting
#'   them. Modifiers travel via the optional
#'   `modifiers` list-column; the multi-column (`Modifier #1`,
#'   `Modifier #2`, ...) layout, the legacy pipe-separated
#'   single-column (`a|b|None`) layout, and comma-separated values
#'   within a single slot are all accepted.
#'
#' @param path Path to a BORIS export (`.tsv` or `.csv`).
#' @param format One of `"auto"`, `"aggregated"`, `"tabular"`. The
#'   default `"auto"` sniffs the format from the first row of the
#'   file.
#' @param unit_time One of `"s"`, `"frame"`. Default `"s"`. `"frame"`
#'   uses the BORIS image-index columns; pass it when pairing the
#'   anievent with an aniframe to keep frame-aligned semantics.
#'
#' @return An [anicore::anievent()] with metadata fields `source`,
#'   `filename`, `unit_time`, and `sampling_rate` (when FPS is a
#'   single numeric in the export) populated.
#'
#' @references
#' - Friard, O., & Gamba, M. (2016). BORIS: a free, versatile open-source
#'   event-logging software for video/audio coding and live observations.
#'   *Methods in Ecology and Evolution*, 7(11), 1325-1330.
#'   \doi{10.1111/2041-210X.12584}.
#'
#' @examples
#' path <- system.file("extdata", "boris.csv", package = "aniread")
#' read_boris(path)
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
  # nocov start - validate_files() already rejects empty files; this
  # guard catches the pathological case of a one-line whitespace-only
  # file that gets past the size check.
  if (length(lines) == 0 || !nzchar(lines[[1]])) {
    cli::cli_abort("BORIS file appears empty: {.path {path}}")
  }
  # nocov end
  first_cols <- strsplit(lines[[1]], delim, fixed = TRUE)[[1]]
  has_subject_or_behavior <- any(c("Subject", "Behavior") %in% first_cols)
  has_paired_times <- any(c("Start (s)", "Stop (s)") %in% first_cols)
  has_transition_time <- "Time" %in% first_cols

  # Aggregated export: one row per bout, carries paired Start/Stop columns.
  if (has_subject_or_behavior && has_paired_times) {
    return("aggregated")
  }
  # Newer tabular export: flat header from row 1, one row per transition
  # (`Behavior type` column then holds START / STOP / POINT).
  if (has_subject_or_behavior && has_transition_time) {
    return("tabular")
  }
  # Older tabular export: 2-column key/value header block, then a
  # `Time<delim>...<delim>Status` row.
  has_tabular_marker <- any(grepl("^Time(\t|,)", lines))
  if (has_tabular_marker) {
    return("tabular")
  }
  cli::cli_abort(c(
    "Could not detect BORIS export format from {.path {basename(path)}}.",
    "i" = "Aggregated exports must have a header row containing {.val Subject} / {.val Behavior} plus {.val Start (s)} / {.val Stop (s)}.",
    "i" = "Tabular exports either have a flat header (with a {.val Time} column) or a 2-column key/value header block followed by a {.val Time ... Status} row.",
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

  # Parse modifiers first - the multi-column form (`Modifier #1`,
  # `Modifier #2`, ...) needs the original names before janitor
  # rewrites them into something like `modifier_number_1`.
  raw <- parse_boris_modifiers(raw)
  raw <- standardise_boris_columns(raw)
  raw
}


# ---- Tabular events ----

#' Read a tabular BORIS export
#'
#' Dispatches between the two flavours BORIS produces:
#'
#' * **Flat header** (newer): row 1 is a full data header containing
#'   `Subject` / `Behavior` plus all observation-level metadata
#'   broadcast as repeating per-row columns. The transition status
#'   (`START` / `STOP` / `POINT`) lives in the `Behavior type` column.
#' * **Header-block** (older): rows 1..N are a 2-column key/value
#'   block of observation metadata, a blank-ish separator follows,
#'   then a `Time<delim>...<delim>Status` data header.
#'
#' @keywords internal
read_boris_tabular <- function(path) {
  delim <- boris_delim(path)
  first_line <- readLines(path, n = 1, warn = FALSE)
  first_cols <- strsplit(first_line, delim, fixed = TRUE)[[1]]
  if (any(c("Subject", "Behavior") %in% first_cols)) {
    return(read_boris_tabular_flat(path))
  }
  read_boris_tabular_header_block(path)
}

#' @keywords internal
read_boris_tabular_flat <- function(path) {
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

  raw <- parse_boris_modifiers(raw)
  raw <- standardise_boris_columns(raw)
  # The flat tabular export reuses the `Behavior type` column to hold
  # the START / STOP / POINT transition status (instead of STATE /
  # POINT as in aggregated). Rename it to `status` so the rest of the
  # pairing pipeline doesn't need to know which export it came from.
  if ("behavior_type" %in% names(raw)) {
    raw$status <- raw$behavior_type
    raw$behavior_type <- NULL
  }
  pair_tabular_events(raw)
}

#' @keywords internal
read_boris_tabular_header_block <- function(path) {
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
  # nocov start - unreachable through read_boris(): detect_boris_format()
  # only routes a file here when it has already seen a `Time<delim>...`
  # row in the first 30 lines.
  if (length(data_header) == 0) {
    cli::cli_abort(
      "Could not locate the data-table header (a line starting with `Time`) in the tabular BORIS export."
    )
  }
  # nocov end
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
    # UI - redundant with the per-row `Media file path` column in the
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
  # nocov start - both columns are required by the tabular format and
  # the file would have failed format detection without them.
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
  # nocov end

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

  has_image_index <- "image_index" %in% names(events)

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
      if (has_image_index) {
        row$image_index_start <- events$image_index[i]
        row$image_index_stop <- events$image_index[i]
      }
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
        if (has_image_index) {
          row$image_index_start <- events$image_index[start_i]
          row$image_index_stop <- events$image_index[i]
        }
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
    n <- length(unmatched_starts)
    rows <- sort(unmatched_starts)
    cli::cli_warn(c(
      "Dropped {n} unmatched {.val START} event{?s} (no following {.val STOP}).",
      "i" = "Input row{cli::qty(n)}{?s}: {rows}"
    ))
  }
  if (length(unmatched_stops) > 0) {
    n <- length(unmatched_stops)
    rows <- sort(unmatched_stops)
    cli::cli_warn(c(
      "Dropped {n} unmatched {.val STOP} event{?s} (no preceding {.val START}).",
      "i" = "Input row{cli::qty(n)}{?s}: {rows}"
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
  out$image_index <- NULL
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
    "Observation duration" = "total_duration",
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
    "Image index" = "image_index",
    "Image file path start" = "image_file_path_start",
    "Image file path stop" = "image_file_path_stop",
    "Image file path" = "image_file_path",
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
  # nocov start - call sites always pass a non-empty vector; this is
  # belt-and-braces in case a future modifier layout sneaks an empty
  # row through.
  if (length(tokens) == 0) {
    return(character())
  }
  # nocov end
  # BORIS multi-select modifiers within a single column slot are
  # comma-separated (e.g. a `Modifier #1` cell of `"Leg,Pedipalps"`
  # is two distinct modifier values). Split before trimming so we
  # treat each value separately downstream.
  tokens <- unlist(
    strsplit(as.character(tokens), ",", fixed = TRUE),
    use.names = FALSE
  )
  tokens <- trimws(tokens)
  tokens <- tokens[!is.na(tokens) & nzchar(tokens) & tokens != "None"]
  tokens
}


# ---- Finalisation: unit_time, channels, metadata ----

#' @keywords internal
finalise_boris <- function(data, path, unit_time) {
  unit_time <- choose_unit_time(data, unit_time)

  # Capture FPS before dropping the column - also needed for the
  # frame-fallback calculation below.
  fps <- extract_boris_fps(data)

  if (unit_time == "frame") {
    frames <- backcalculate_boris_frames(
      start = as.numeric(data$image_index_start),
      stop = as.numeric(data$image_index_stop),
      start_s = as.numeric(data$start_s),
      stop_s = as.numeric(data$stop_s),
      fps = fps
    )
    data$start <- frames$start
    data$stop <- frames$stop
  } else {
    data$start <- as.numeric(data$start_s)
    data$stop <- as.numeric(data$stop_s)
  }

  data$start_s <- NULL
  data$stop_s <- NULL
  data$image_index_start <- NULL
  data$image_index_stop <- NULL
  data$duration_s <- NULL
  # FPS is captured in metadata$sampling_rate; total_length /
  # total_duration / media_duration / coding_duration have no current
  # metadata home (see animovement/aniframe#73) - drop them to avoid
  # redundancy / dishonest data columns.
  data$fps <- NULL
  data$total_length <- NULL
  data$total_duration <- NULL
  data$media_duration <- NULL
  data$coding_duration <- NULL

  # BORIS often emits behaviour / subject / category strings with
  # trailing whitespace - strip it here so downstream factor levels
  # don't carry it.
  for (col in c("subject", "behavior", "behavioral_category")) {
    if (col %in% names(data)) {
      data[[col]] <- trimws(as.character(data[[col]]))
    }
  }

  if ("behavioral_category" %in% names(data)) {
    cat_vec <- data$behavioral_category
    cat_vec[is.na(cat_vec) | !nzchar(cat_vec)] <- NA_character_
    data$channel <- ifelse(is.na(cat_vec), "behavior", cat_vec)
  } else {
    data$channel <- "behavior"
  }
  data$label <- data$behavior

  # Map BORIS's `Behavior type` (uppercase STATE / POINT) onto the
  # aniframe contract (lowercase state / point). When the column is
  # absent (some exports), let aniframe auto-derive `type` per
  # (channel, label) group from bout duration.
  if ("behavior_type" %in% names(data)) {
    bt <- as.character(data$behavior_type)
    bt[bt == "STATE"] <- "state"
    bt[bt == "POINT"] <- "point"
    data$type <- bt
  }

  data$behavior <- NULL
  data$behavioral_category <- NULL
  data$behavior_type <- NULL

  data <- drop_uninformative_boris_columns(data)

  ae <- anicore::anievent(data)

  ae <- anicore::set_metadata(
    ae,
    source = "boris",
    filename = basename(path),
    unit_time = unit_time,
    # Spatial fields are inherited from the shared metadata substrate
    # but don't apply to event data. Set what we can to neutral values
    # (`none` / `unknown`); the rest stay at the aniframe default
    # until animovement/aniframe#73 lands.
    unit_space = "none",
    coordinate_system = "unknown"
  )
  if (!is.null(fps)) {
    ae <- anicore::set_metadata(ae, sampling_rate = fps)
  }

  # Overlap checks: aniframe's `validate_anievent()` is intentionally
  # lenient on the anievent side - it warns on overlapping bouts within
  # a channel rather than rejecting them. Point events legitimately
  # coexist with a containing state bout in BORIS, though, so filter to
  # durative bouts before the call so only true state-state overlaps
  # surface.
  state_only <- ae[ae$type == "state", , drop = FALSE]
  anicore::validate_anievent(state_only)
  ae
}

#' Recover frame numbers from timestamps when the image index is bad
#'
#' Some BORIS exports emit a bogus image index on boundary frames - e.g.
#' a STOP recorded on the very last frame of the video carries
#' `Image index stop = 1` while its `Stop (s)` is the true end time. That
#' makes the frame-based `stop` smaller than `start`, which fails
#' aniframe's non-negative-interval invariant even though the
#' second-based timestamps are perfectly consistent.
#'
#' BORIS derives `Time` from `frame / fps`, so when fps is known the true
#' frame number is `round(Time * fps)`. We only rewrite the rows whose
#' frame interval is negative *and* whose second interval is
#' non-negative, leaving every other row on the verbatim image-index
#' values (which keeps the documented frame-alignment guarantee intact).
#'
#' @return A list with `start` and `stop` numeric vectors.
#' @keywords internal
backcalculate_boris_frames <- function(start, stop, start_s, stop_s, fps) {
  if (is.null(fps)) {
    return(list(start = start, stop = stop))
  }
  bad <- !is.na(start) &
    !is.na(stop) &
    stop < start &
    !is.na(start_s) &
    !is.na(stop_s) &
    stop_s >= start_s
  if (!any(bad)) {
    return(list(start = start, stop = stop))
  }
  start[bad] <- round(start_s[bad] * fps)
  stop[bad] <- round(stop_s[bad] * fps)
  n <- sum(bad)
  cli::cli_inform(c(
    "i" = "Recalculated {n} BORIS frame interval{?s} from {.field Time} and fps ({fps}).",
    "i" = "The export's image-index column was inconsistent (stop frame < start frame); recovered via {.code round(time_s * fps)}."
  ))
  list(start = start, stop = stop)
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

#' Drop columns that carry no per-row information
#'
#' Trims a handful of BORIS-administrative columns when they're
#' trivially uniform across the export - keeps the resulting
#' anievent compact for the common single-observation case while
#' still preserving these columns when they actually vary (e.g.
#' across observations stacked into a single file).
#'
#' @keywords internal
drop_uninformative_boris_columns <- function(data) {
  drops <- character()

  na_only <- c(
    "description",
    "comment",
    "comment_start",
    "comment_stop",
    "image_file_path",
    "image_file_path_start",
    "image_file_path_stop"
  )
  for (col in intersect(na_only, names(data))) {
    if (all(is.na(data[[col]]))) {
      drops <- c(drops, col)
    }
  }

  if ("time_offset" %in% names(data)) {
    vals <- suppressWarnings(as.numeric(data$time_offset))
    if (all(is.na(vals) | vals == 0)) {
      drops <- c(drops, "time_offset")
    }
  }

  constant_only <- c("observation_type", "source_media")
  for (col in intersect(constant_only, names(data))) {
    if (length(unique(data[[col]])) <= 1) {
      drops <- c(drops, col)
    }
  }

  data[, setdiff(names(data), drops), drop = FALSE]
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
