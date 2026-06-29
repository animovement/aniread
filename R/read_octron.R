#' Read Octron Segmentation Data
#'
#' Reads CSV files exported from Octron video segmentation software.
#' The function parses the metadata header and returns tracking data
#' as an aniframe with centroid positions, bounding box corners, and
#' shape descriptors. Octron stores positions in image (top-left)
#' coordinates; the reader reflects y so the returned aniframe is in
#' the conventional `bottom_left` origin. The frame height is read
#' from the CSV header (`video_height:`) by default.
#'
#' Newer Octron exports (>= the multi-blob handling in
#' [OCTRON-GUI #63](https://github.com/OCTRON-tracking/OCTRON-GUI/issues/63))
#' may emit per-segment columns as tuple-strings, e.g. `"(120.5, 85.3)"`,
#' when YOLO detects multiple disconnected mask segments belonging to
#' the same track in a single frame. The `method` argument controls
#' how those rows are reduced to scalar values, or whether they are
#' expanded into one row per segment.
#'
#' @param path Path to the Octron CSV file.
#' @param keep_bbox Keep bounding box coordinates? Default FALSE.
#' @param video_height Optional numeric height of the source video frame
#'   in pixels. Overrides the value parsed from the CSV header when both
#'   are available.
#' @param method Strategy for resolving frames where Octron emitted
#'   multiple mask segments per track. One of:
#'   \itemize{
#'     \item `"weighted"` (default): area-weighted mean across all
#'       segments per row. `area` becomes the sum of segment areas;
#'       `orientation` falls back to `"largest"` (circular quantity,
#'       weighted mean is undefined).
#'     \item `"largest"`: take values from the single largest segment
#'       per row.
#'     \item `"segments"`: expand each multi-segment row into one row
#'       per segment, adding a `segment` identity variable. Segments
#'       are not matched across frames, so filtering on `segment` is
#'       generally not meaningful.
#'   }
#'   When the source CSV contains no tuple-valued rows, all three
#'   methods produce identical numeric output.
#' @param properties Which scikit-image / Octron region-property columns
#'   to read. Newer Octron exports include dozens of per-segment shape,
#'   intensity and moment descriptors that can dominate read time on
#'   tuple-heavy files. One of:
#'   \itemize{
#'     \item `"all"` (default): read every property column found in the
#'       file. Backwards-compatible with prior `read_octron()` behaviour.
#'     \item a character vector of column names, e.g.
#'       `c("area", "orientation")`: read only the listed properties.
#'       Unknown names are warned about and ignored.
#'     \item `NULL` or `character(0)`: skip all property columns; the
#'       result contains only id columns and the centroid (and bbox
#'       when `keep_bbox = TRUE`).
#'   }
#'   When `method = "weighted"` and `area` exists in the file but is
#'   absent from this argument, it is added automatically (the
#'   area-weighted mean has no meaning otherwise) and an info message
#'   is emitted.
#'
#' @return An aniframe
#'
#' @export
read_octron <- function(
  path,
  keep_bbox = FALSE,
  video_height = NULL,
  method = c("weighted", "largest", "segments"),
  properties = "all"
) {
  method <- match.arg(method)
  validate_files(path)

  if (!is.null(properties) && !is.character(properties)) {
    cli::cli_abort(
      "{.arg properties} must be {.val all}, a character vector of column names, or {.val NULL}."
    )
  }

  header <- readLines(path, n = 6)
  if (is.null(video_height)) {
    video_height <- parse_octron_header_value(header, "video_height")
  }
  # Number of frames Octron actually analysed — used to reinstate frames
  # that carry no detection as all-NA rows (#80).
  frame_count <- parse_octron_header_value(header, "frame_count_analyzed")

  keep_cols <- octron_columns_to_read(
    path = path,
    keep_bbox = keep_bbox,
    method = method,
    properties = properties
  )

  # `altrep = FALSE` returns plain character vectors instead of ALTREP
  # proxies. Octron files are tuple-heavy (~60 character columns × 1.85M
  # rows on the user's file), and every operation in the parser pipeline
  # (`is.na`, `startsWith`, `substring`, `as.numeric`) pays a per-element
  # ALTREP dispatch cost. Disabling it cuts end-to-end read time by
  # ~35% on tuple-heavy files at the cost of doing the column reads
  # eagerly (which we end up doing anyway).
  data <- vroom::vroom(
    path,
    skip = 6,
    show_col_types = FALSE,
    altrep = FALSE,
    col_select = dplyr::all_of(keep_cols)
  ) |>
    suppressMessages()
  # Strip vroom-specific attributes — `problems` is an externalptr that
  # makes two reads of the same file inequal under `expect_equal`, and
  # neither is meaningful in the final aniframe. Previously these were
  # implicitly dropped when the data flowed through `pivot_longer`.
  attr(data, "problems") <- NULL
  attr(data, "spec") <- NULL

  # Octron uses scikit-image's expanded names verbatim — `moments_hu-0`,
  # `weighted_centroid-0-0` etc. — which contain hyphens. R conventions
  # (and aniframe) prefer underscores, so swap them in the output so
  # callers can refer to columns as bare identifiers.
  names(data) <- gsub("-", "_", names(data), fixed = TRUE)

  data <- data |>
    dplyr::rename(
      track = "track_id",
      time = "frame_idx",
      centroid_x = "pos_x",
      centroid_y = "pos_y"
    )

  if (keep_bbox) {
    data <- dplyr::rename(
      data,
      bbox_min_x = "bbox_x_min",
      bbox_min_y = "bbox_y_min",
      bbox_max_x = "bbox_x_max",
      bbox_max_y = "bbox_y_max"
    )
  }

  # Resolve multi-segment (tuple-valued) rows into scalar columns or
  # explode them into per-segment rows.
  data <- resolve_octron_segments(data, method)

  # Octron omits any frame in which nothing was detected, so a gap in
  # `frame_idx` means "no observation", not "frame absent from the video".
  # Reinstate the missing frames as all-NA rows across the full
  # track × frame grid (#80) so downstream code sees a rectangular,
  # gap-free time axis.
  data <- complete_octron_frames(data, frame_count)

  id_cols <- c("track", "time", "label", "confidence")
  if (method == "segments") {
    id_cols <- c(id_cols, "segment")
  }
  spatial_cols <- c(
    "centroid_x",
    "centroid_y",
    "bbox_min_x",
    "bbox_min_y",
    "bbox_max_x",
    "bbox_max_y"
  )
  descriptor_cols <- setdiff(names(data), c(id_cols, spatial_cols))

  if (keep_bbox) {
    data <- data |>
      tidyr::pivot_longer(
        cols = dplyr::all_of(spatial_cols),
        names_to = c("keypoint", ".value"),
        names_pattern = "(.+)_(x|y)"
      ) |>
      dplyr::mutate(
        dplyr::across(
          dplyr::all_of(descriptor_cols),
          \(col) dplyr::if_else(.data$keypoint == "centroid", col, NA)
        )
      )
  } else {
    # Fast path for the default `keep_bbox = FALSE`: skip pivoting (which
    # would inflate to 3x rows just to filter back down) and skip blanking
    # descriptors on bbox rows that are about to be dropped. On a
    # 1.85M-row file with ~60 descriptor columns this avoids ~330M
    # pointless `if_else` evaluations. The bbox columns weren't read in
    # the first place (excluded by `col_select` in the vroom call above).
    data <- data |>
      dplyr::rename(x = "centroid_x", y = "centroid_y") |>
      dplyr::mutate(keypoint = "centroid")
  }

  variables_what <- c("label", "track", "keypoint")
  if (method == "segments") {
    variables_what <- c("label", "track", "segment", "keypoint")
  }

  aniframe::as_aniframe(
    data,
    variables_what = variables_what
  ) |>
    aniframe::set_metadata(
      source = "octron",
      filename = basename(path)
    ) |>
    reflect_to_bottom_left(video_height = video_height)
}


# ---------------------------------------------------------------------------
# Internal helpers for handling Octron's tuple-valued multi-segment rows.
# ---------------------------------------------------------------------------

#' Parse a single `key: value` line from an Octron CSV header
#'
#' Returns the numeric value following `key:` in the metadata header, or
#' `NA_real_` when the key is absent.
#' @keywords internal
#' @noRd
parse_octron_header_value <- function(header, key) {
  line <- grep(paste0("^", key, ":"), header, value = TRUE)
  if (length(line) == 0) {
    return(NA_real_)
  }
  as.numeric(trimws(sub(paste0(key, ":"), "", line[[1]], fixed = TRUE)))
}

#' Reinstate frames with no detection as all-NA rows
#'
#' Completes the full `track` × `frame` grid so that every analysed frame
#' appears for every track. Frames Octron dropped (because nothing was
#' detected) come back as rows that are NA in every measurement column.
#' The per-track class `label` is carried onto the reinstated rows so a
#' track keeps a consistent identity rather than gaining NA identity
#' values.
#'
#' The frame range runs from 0 to `frame_count - 1` (the analysed-frame
#' count from the CSV header). When the header lacks that field the
#' observed `time` range is used instead. Frames present in the data but
#' beyond `frame_count` are preserved.
#' @keywords internal
complete_octron_frames <- function(data, frame_count) {
  if (nrow(data) == 0L) {
    return(data)
  }

  data$time <- as.numeric(data$time)
  observed_max <- max(data$time, na.rm = TRUE)
  if (is.na(frame_count) || frame_count <= 0) {
    frame_count <- observed_max + 1L
  }

  # Union with any observed frames past the header count so we never drop
  # real data to a stale/short header.
  full_time <- sort(union(
    seq.int(0L, frame_count - 1L),
    data$time[!is.na(data$time)]
  ))

  grid <- expand.grid(
    track = unique(data$track),
    time = full_time,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )

  out <- dplyr::left_join(grid, data, by = c("track", "time"))

  # Keep the per-track `label` consistent on the reinstated rows.
  if ("label" %in% names(out)) {
    known <- data[!is.na(data$label), c("track", "label"), drop = FALSE]
    known <- known[!duplicated(known$track), , drop = FALSE]
    filled <- known$label[match(out$track, known$track)]
    out$label <- dplyr::coalesce(out$label, filled)
  }

  out[order(out$track, out$time), , drop = FALSE]
}

#' Decide which columns to read from an Octron CSV
#'
#' Probes the file for its column header, categorises the columns into
#' id / centroid / bbox / property buckets, and resolves the user's
#' `properties` request against the available property columns. The
#' returned vector is suitable for passing to `vroom::vroom(col_select)`.
#'
#' Octron writes scikit-image's expanded property names verbatim — e.g.
#' `moments_hu-0`. Matching is done in *clean* (underscored) form so the
#' user-facing API matches what they'll see in the output, but the
#' returned vector uses the original on-disk names so vroom can find
#' them.
#'
#' @keywords internal
#' @noRd
octron_columns_to_read <- function(path, keep_bbox, method, properties) {
  probe <- vroom::vroom(
    path,
    skip = 6,
    show_col_types = FALSE,
    altrep = FALSE,
    n_max = 0L
  ) |>
    suppressMessages()
  file_cols <- names(probe)
  clean_cols <- gsub("-", "_", file_cols, fixed = TRUE)
  clean_to_file <- stats::setNames(file_cols, clean_cols)

  id_cols <- intersect(
    c("frame_idx", "track_id", "label", "confidence"),
    clean_cols
  )
  centroid_cols <- intersect(c("pos_x", "pos_y"), clean_cols)
  bbox_cols <- intersect(
    c("bbox_x_min", "bbox_x_max", "bbox_y_min", "bbox_y_max"),
    clean_cols
  )
  consumed <- c(id_cols, centroid_cols, bbox_cols, "frame_counter")
  property_cols_available <- setdiff(clean_cols, consumed)

  properties_to_read <- if (identical(properties, "all")) {
    property_cols_available
  } else if (is.null(properties) || length(properties) == 0L) {
    character(0)
  } else {
    unknown <- setdiff(properties, property_cols_available)
    if (length(unknown) > 0L) {
      cli::cli_warn(c(
        "Unknown {.arg properties} ignored: {.val {unknown}}.",
        i = "Available: {.val {property_cols_available}}."
      ))
    }
    intersect(properties, property_cols_available)
  }

  # `method = "weighted"` weights every other property by `area`, so
  # silently dropping it would change the math. Re-add it and tell the
  # caller why it appeared in the output.
  if (
    method == "weighted" &&
      "area" %in% property_cols_available &&
      !"area" %in% properties_to_read
  ) {
    cli::cli_inform(c(
      i = "Including {.field area} (used as weights for {.code method = \"weighted\"})."
    ))
    properties_to_read <- c("area", properties_to_read)
  }

  keep_clean <- c(id_cols, centroid_cols, properties_to_read)
  if (keep_bbox) {
    keep_clean <- c(keep_clean, bbox_cols)
  }

  unname(clean_to_file[keep_clean])
}

#' Resolve multi-segment Octron rows by the selected method
#' @keywords internal
resolve_octron_segments <- function(data, method) {
  tuple_cols <- detect_octron_tuple_cols(data)

  if (method == "segments") {
    if (length(tuple_cols) > 0) {
      data <- dplyr::mutate(
        data,
        dplyr::across(
          dplyr::all_of(tuple_cols),
          \(col) parse_octron_column(col)
        )
      )
      data$segment <- lapply(data[[tuple_cols[1]]], seq_along)
      data <- tidyr::unnest(
        data,
        cols = c(dplyr::all_of(tuple_cols), "segment")
      )
    } else {
      data$segment <- 1L
    }
    data$segment <- factor(data$segment)
    return(data)
  }

  if (length(tuple_cols) == 0) {
    return(data)
  }

  has_area <- "area" %in% names(data)
  parsed_area <- if (has_area) parse_octron_column(data$area) else NULL
  area_lens <- if (has_area) lengths(parsed_area) else NULL

  # Track per-row mismatch across all value columns so we can emit a
  # SINGLE summarised warning per file (rather than one per affected
  # column — for the user's 60-tuple-column file that meant ~26 dupes).
  any_mismatch <- if (has_area) logical(length(parsed_area)) else NULL

  for (col in tuple_cols) {
    vals <- if (has_area && col == "area") {
      parsed_area
    } else {
      parse_octron_column(data[[col]])
    }
    # When no `area` column exists, build a synthetic per-column area
    # whose lengths match this column's values. This routes resolvers
    # to their NA / mean fallbacks without firing the segment-count
    # mismatch warning that would otherwise compare a length-1 NA
    # placeholder against a multi-segment value vector.
    areas <- if (has_area) {
      parsed_area
    } else {
      lapply(lengths(vals), function(k) rep(NA_real_, k))
    }

    if (has_area && !(col == "area")) {
      v_lens <- lengths(vals)
      any_mismatch <- any_mismatch | (v_lens > 0L & v_lens != area_lens)
    }

    data[[col]] <- if (method == "weighted") {
      if (has_area && col == "area") {
        resolve_area_sum(vals)
      } else if (col == "orientation") {
        resolve_largest(vals, areas)
      } else {
        resolve_weighted(vals, areas, .warn_mismatch = FALSE)
      }
    } else {
      # method == "largest"
      resolve_largest(vals, areas)
    }
  }

  if (!is.null(any_mismatch) && any(any_mismatch)) {
    rows <- which(any_mismatch)
    # Report frame_idx values when available so the user can inspect the
    # offending frames directly; fall back to row indices otherwise.
    locator <- if ("time" %in% names(data)) {
      paste0(
        "frame_idx ",
        paste(utils::head(data$time[rows], 10L), collapse = ", ")
      )
    } else {
      paste0("row ", paste(utils::head(rows, 10L), collapse = ", "))
    }
    if (length(rows) > 10L) {
      locator <- paste0(locator, ", ...")
    }
    cli::cli_warn(c(
      "Octron: {length(rows)} row{?s} {?has/have} differing segment counts in value vs. area columns.",
      i = "Affected: {locator}.",
      i = "Falling back to the arithmetic mean of values for those rows."
    ))
  }

  data
}

#' Detect columns that contain tuple-strings (e.g. "(120.5, 85.3)")
#'
#' Walks each character column once with a fast `is.na` + `startsWith`
#' bulk pass and stops at the first hit. Avoids `stats::na.omit`, which
#' allocates a `na.action` attribute over every NA index — measurable on
#' a 1.85M-row file with ~60 character columns.
#' @keywords internal
detect_octron_tuple_cols <- function(data) {
  names(data)[vapply(
    data,
    function(col) {
      if (!is.character(col)) {
        return(FALSE)
      }
      any(!is.na(col) & startsWith(col, "("))
    },
    logical(1)
  )]
}

#' Parse a column of mixed scalars and tuple-strings into a list of
#' numeric vectors (one per row).
#'
#' Vectorised: tuple entries are stripped of parentheses and split on `,`
#' in one shot, then converted with `as.numeric` (which trims whitespace).
#' Scalar entries are converted in bulk. NA entries map to `NA_real_`.
#' @keywords internal
parse_octron_column <- function(col) {
  if (is.numeric(col)) {
    return(as.list(col))
  }

  na_mask <- is.na(col)
  is_tuple <- !na_mask & startsWith(col, "(")
  is_scalar <- !na_mask & !is_tuple

  result <- vector("list", length(col))

  if (any(is_tuple)) {
    # Tuple form is exactly "(...)", so chop the parens with substring
    # (much cheaper than `gsub("[()]", ...)` regex on millions of short
    # strings) and split on `,` in one C-level call. `as.numeric` trims
    # surrounding whitespace internally so no separate `trimws` pass is
    # needed. The bulk-as.numeric / .mapply re-list trick *looks*
    # tempting but loses to `lapply(parts, as.numeric)` on real Octron
    # data once the per-row segment count is small (≤ ~5) — `as.numeric`
    # is .Internal so its per-call cost is below the `unlist` + slicing
    # overhead at this batch size.
    tcol <- col[is_tuple]
    cleaned <- substring(tcol, 2L, nchar(tcol) - 1L)
    parts <- strsplit(cleaned, ",", fixed = TRUE)
    result[is_tuple] <- lapply(parts, as.numeric)
  }

  if (any(is_scalar)) {
    result[is_scalar] <- as.list(as.numeric(col[is_scalar]))
  }

  if (any(na_mask)) {
    result[na_mask] <- list(NA_real_)
  }

  result
}

#' Pick the value of the segment with the largest area per row.
#'
#' Vectorised. When a row's `areas_list` length differs from its
#' `values_list` length, the area vector is padded with `NA` (or
#' truncated) to align — so out-of-range indices can never be picked.
#' @keywords internal
resolve_largest <- function(values_list, areas_list) {
  n <- length(values_list)
  if (n == 0L) {
    return(numeric(0))
  }

  v_lens <- lengths(values_list)
  out <- rep(NA_real_, n)
  if (!any(v_lens > 0L)) {
    return(out)
  }

  v_flat <- unlist(values_list, use.names = FALSE)
  a_lens <- lengths(areas_list)
  a_aligned <- if (identical(v_lens, a_lens)) {
    unlist(areas_list, use.names = FALSE)
  } else {
    unlist(
      .mapply(
        align_to_length,
        list(areas_list, v_lens),
        NULL
      ),
      use.names = FALSE
    )
  }

  v_grp <- rep.int(seq_len(n), v_lens)

  # Replace NA areas with -Inf so non-NA always beats NA; ties (including
  # all-NA rows) are broken by stable sort, matching the original
  # `which.max(a) || idx <- 1L` fallback (returns the first segment).
  a_rank <- a_aligned
  a_rank[is.na(a_rank)] <- -Inf

  ord <- order(v_grp, -a_rank, method = "radix")
  sorted_grp <- v_grp[ord]
  first_in_grp <- !duplicated(sorted_grp)
  winners <- ord[first_in_grp]

  out[sorted_grp[first_in_grp]] <- as.numeric(v_flat[winners])
  out
}

#' Compute the area-weighted mean across segments per row.
#'
#' Vectorised via `rowsum`. Rows whose `values_list` and `areas_list`
#' have different segment counts trigger a single summarised warning and
#' fall back to the arithmetic mean of the value vector — protecting
#' callers from the silent recycling that would otherwise occur in
#' `v * a`. Falls back to the arithmetic mean when areas are absent or
#' sum to 0.
#' @keywords internal
resolve_weighted <- function(values_list, areas_list, .warn_mismatch = TRUE) {
  n <- length(values_list)
  if (n == 0L) {
    return(numeric(0))
  }

  v_lens <- lengths(values_list)
  a_lens <- lengths(areas_list)

  out <- rep(NA_real_, n)
  non_empty <- which(v_lens > 0L)
  if (length(non_empty) == 0L) {
    return(out)
  }

  mismatch <- v_lens > 0L & v_lens != a_lens
  if (any(mismatch)) {
    if (.warn_mismatch) {
      n_mismatch <- sum(mismatch)
      cli::cli_warn(c(
        "Octron: {n_mismatch} row{?s} {?has/have} differing segment counts in value vs. area columns.",
        i = "Falling back to the arithmetic mean of values for those rows."
      ))
    }
    # Replace mismatched-row areas with zeros aligned to the value
    # length; combined with the `total > 0` guard below, this triggers
    # the mean-fallback branch for those rows without recycling.
    areas_list[mismatch] <- lapply(v_lens[mismatch], numeric)
  }

  v_flat <- unlist(values_list, use.names = FALSE)
  a_flat <- unlist(areas_list, use.names = FALSE)
  v_grp <- rep.int(seq_len(n), v_lens)

  v_ok <- !is.na(v_flat)
  v_safe <- v_flat
  v_safe[!v_ok] <- 0
  va_safe <- v_flat * a_flat
  va_safe[is.na(va_safe)] <- 0

  n_v_ok <- as.numeric(rowsum(as.numeric(v_ok), v_grp))
  v_sum <- as.numeric(rowsum(v_safe, v_grp))
  a_sum <- as.numeric(rowsum(a_flat, v_grp, na.rm = TRUE))
  va_sum <- as.numeric(rowsum(va_safe, v_grp))

  use_weighted <- is.finite(a_sum) & a_sum > 0
  res <- ifelse(
    n_v_ok == 0,
    NA_real_,
    ifelse(use_weighted, va_sum / a_sum, v_sum / n_v_ok)
  )

  out[non_empty] <- res
  out
}

#' Sum all segment areas per row (used for `area` under `method = "weighted"`).
#' @keywords internal
resolve_area_sum <- function(areas_list) {
  n <- length(areas_list)
  if (n == 0L) {
    return(numeric(0))
  }

  a_lens <- lengths(areas_list)
  out <- rep(0, n)
  non_empty <- which(a_lens > 0L)
  if (length(non_empty) == 0L) {
    return(out)
  }

  a_flat <- unlist(areas_list, use.names = FALSE)
  a_grp <- rep.int(seq_len(n), a_lens)
  out[non_empty] <- as.numeric(rowsum(a_flat, a_grp, na.rm = TRUE))
  out
}

#' Pad with NA or truncate a numeric vector to the requested length.
#' @noRd
align_to_length <- function(x, target_len) {
  k <- length(x)
  if (k == target_len) {
    as.numeric(x)
  } else if (k < target_len) {
    c(as.numeric(x), rep(NA_real_, target_len - k))
  } else {
    as.numeric(x[seq_len(target_len)])
  }
}
