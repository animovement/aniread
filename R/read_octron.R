#' Read Octron Segmentation Data
#'
#' Reads CSV files exported from Octron video segmentation software.
#' The function parses the metadata header and returns tracking data
#' as an aniframe with centroid positions, bounding box corners, and
#' shape descriptors.
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
#'
#' @return An aniframe
#'
#' @export
read_octron <- function(
  path,
  keep_bbox = FALSE,
  method = c("weighted", "largest", "segments")
) {
  method <- match.arg(method)
  validate_files(path)

  header <- readLines(path, n = 6)
  video_height <- as.numeric(
    trimws(sub(
      "video_height:",
      "",
      grep("^video_height:", header, value = TRUE)
    ))
  )

  data <- vroom::vroom(path, skip = 6, show_col_types = FALSE) |>
    suppressMessages()

  data <- data |>
    dplyr::rename(
      track = "track_id",
      time = "frame_idx",
      x = "pos_x",
      y = "pos_y",
      confidence = "confidence"
    ) |>
    dplyr::select(-dplyr::any_of("frame_counter")) |>
    dplyr::rename(
      centroid_x = "x",
      centroid_y = "y",
      bbox_min_x = "bbox_x_min",
      bbox_min_y = "bbox_y_min",
      bbox_max_x = "bbox_x_max",
      bbox_max_y = "bbox_y_max"
    )

  # Resolve multi-segment (tuple-valued) rows into scalar columns or
  # explode them into per-segment rows.
  data <- resolve_octron_segments(data, method)

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
      ),
      y = video_height - .data$y
    )

  if (keep_bbox == FALSE) {
    data <- data |>
      dplyr::filter(!.data$keypoint %in% c("bbox_min", "bbox_max"))
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
    )
}


# ---------------------------------------------------------------------------
# Internal helpers for handling Octron's tuple-valued multi-segment rows.
# ---------------------------------------------------------------------------

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

  parsed_area <- if ("area" %in% names(data)) {
    parse_octron_column(data$area)
  } else {
    # No `area` column — fall back to NA so resolve_weighted hits its
    # arithmetic-mean branch and resolve_largest defaults to the first
    # segment.
    rep(list(NA_real_), nrow(data))
  }

  for (col in tuple_cols) {
    vals <- parse_octron_column(data[[col]])
    data[[col]] <- if (method == "weighted") {
      if (col == "area") {
        resolve_area_sum(vals)
      } else if (col == "orientation") {
        resolve_largest(vals, parsed_area)
      } else {
        resolve_weighted(vals, parsed_area)
      }
    } else {
      # method == "largest"
      resolve_largest(vals, parsed_area)
    }
  }

  data
}

#' Detect columns that contain tuple-strings (e.g. "(120.5, 85.3)")
#' @keywords internal
detect_octron_tuple_cols <- function(data) {
  names(data)[vapply(
    data,
    function(col) {
      is.character(col) && any(startsWith(stats::na.omit(col), "("))
    },
    logical(1)
  )]
}

#' Parse a column of mixed scalars and tuple-strings into a list of
#' numeric vectors (one per row).
#' @keywords internal
parse_octron_column <- function(col) {
  if (is.numeric(col)) {
    return(as.list(col))
  }
  lapply(col, function(v) {
    if (is.na(v)) {
      return(NA_real_)
    }
    if (startsWith(v, "(")) {
      inner <- gsub("[()]", "", v)
      parts <- strsplit(inner, ",", fixed = TRUE)[[1]]
      as.numeric(trimws(parts))
    } else {
      as.numeric(v)
    }
  })
}

#' Pick the value of the segment with the largest area per row.
#' @keywords internal
resolve_largest <- function(values_list, areas_list) {
  vapply(
    seq_along(values_list),
    function(i) {
      v <- values_list[[i]]
      a <- areas_list[[i]]
      if (length(v) == 0L || all(is.na(v))) {
        return(NA_real_)
      }
      if (length(v) == 1L) {
        return(as.numeric(v))
      }
      idx <- which.max(a)
      if (length(idx) == 0L) {
        idx <- 1L
      }
      as.numeric(v[idx])
    },
    numeric(1)
  )
}

#' Compute the area-weighted mean across segments per row.
#' Falls back to the arithmetic mean when areas are absent or sum to 0.
#' @keywords internal
resolve_weighted <- function(values_list, areas_list) {
  vapply(
    seq_along(values_list),
    function(i) {
      v <- values_list[[i]]
      a <- areas_list[[i]]
      if (length(v) == 0L || all(is.na(v))) {
        return(NA_real_)
      }
      if (length(v) == 1L) {
        return(as.numeric(v))
      }
      total <- sum(a, na.rm = TRUE)
      if (is.finite(total) && total > 0) {
        sum(v * a, na.rm = TRUE) / total
      } else {
        mean(v, na.rm = TRUE)
      }
    },
    numeric(1)
  )
}

#' Sum all segment areas per row (used for `area` under `method = "weighted"`).
#' @keywords internal
resolve_area_sum <- function(areas_list) {
  vapply(
    areas_list,
    function(a) sum(a, na.rm = TRUE),
    numeric(1)
  )
}
