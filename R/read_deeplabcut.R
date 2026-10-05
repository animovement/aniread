#' Read DeepLabCut data
#'
#' Read files from DeepLabCut (DLC) in either csv or h5 format.
#' DeepLabCut stores predictions in image (top-left) coordinates; the
#' reader reflects y so the returned aniframe is in the conventional
#' `bottom_left` origin. DLC's csv/h5 exports do not contain the source
#' video resolution (it lives in the project's `config.yaml`), so pass
#' `video_height` to get an accurate flip; otherwise `max(y)` is used
#' as a fallback.
#'
#' @section Layouts read:
#' The file is read from its column header, the `scorer`, `individuals`
#' (multi-animal projects only), `bodyparts` and `coords` levels, so the
#' same data reads the same from a csv and an h5. An h5 is read whichever
#' way pandas stored it: DeepLabCut writes the "table" format, while a file
#' saved again with pandas' defaults, as movement's `to_dlc_file()` does,
#' is in the "fixed" format. Predictions are read from the HDF key
#' `df_with_missing`, and the stitched tracklets of a multi-animal project
#' (`*_el.h5`) from the key `tracks`.
#'
#' Of the coords, `x`, `y`, `z` and `likelihood` are read, and `likelihood`
#' becomes `confidence`. Any other coords, such as the variances the
#' Ensemble Kalman Smoother adds, are not read.
#'
#' A multi-animal project tracks the bodyparts it does not assign to an
#' animal (its `uniquebodyparts`) under the pseudo-individual `single`.
#' They are kept as the keypoints of an `individual` called `"single"`.
#'
#' @section 3D files:
#' DeepLabCut's triangulation writes `x`, `y` and `z` and no likelihood, so
#' `confidence` is `NA`. Triangulated positions are in the units and frame
#' of the stereo calibration rather than in image pixels, so they are
#' returned as stored: y is not reflected and `video_height` is not used.
#' The aniframe is 3D from its `z` column.
#'
#' @param path Path to a DeepLabCut data file
#' @param video_height Optional numeric height of the source video frame
#'   in pixels. Not used for 3D files.
#' @return an aniframe
#' @examples
#' path <- system.file("extdata", "deeplabcut.csv", package = "aniread")
#' read_deeplabcut(path)
#' @export
read_deeplabcut <- function(path, video_height = NULL) {
  validate_files(path, expected_suffix = c("csv", "h5"))

  data <- read_deeplabcut_points(path) |>
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = "deeplabcut",
      filename = basename(path)
    )

  if ("z" %in% names(data)) {
    if (!is.null(video_height)) {
      cli::cli_warn(c(
        "{.arg video_height} is not used for 3D data.",
        "i" = "Triangulated positions are not in image pixels, so y is not reflected."
      ))
    }
    return(data)
  }

  reflect_to_bottom_left(data, video_height = video_height)
}

#' Read the points of a DeepLabCut file into long format
#'
#' @param path Path to a DeepLabCut `.csv` or `.h5` file.
#' @return A tibble with `time`, `individual` (multi-animal files only),
#'   `keypoint`, `x`, `y`, `z` (3D files only) and `confidence`.
#' @keywords internal
read_deeplabcut_points <- function(path) {
  wide <- if (get_file_ext(path) == "csv") {
    read_deeplabcut_csv(path)
  } else {
    read_deeplabcut_h5(path)
  }
  dlc_points_long(wide)
}

#' The coords the DeepLabCut reader keeps
#' @keywords internal
dlc_coords <- function() {
  c("x", "y", "z", "likelihood")
}

#' Read a DeepLabCut csv file
#'
#' The header rows are the column levels, each named in the first column;
#' the data rows follow, with the frame index in the first column.
#'
#' @param path Path to a DeepLabCut `.csv` file.
#' @return A list of `columns`, a data frame with one row per kept column
#'   and one column per level; `values`, a frames-by-columns matrix; and
#'   `index`, the frame index.
#' @keywords internal
read_deeplabcut_csv <- function(path) {
  head <- vroom::vroom(
    path,
    delim = ",",
    col_names = FALSE,
    n_max = 5,
    col_types = vroom::cols(.default = vroom::col_character()),
    show_col_types = FALSE,
    progress = FALSE
  )

  is_header <- head[[1]] %in% c("scorer", "individuals", "bodyparts", "coords")
  n_header <- match(FALSE, is_header, nomatch = length(is_header) + 1L) - 1L
  header <- head[seq_len(n_header), -1]
  columns <- as.data.frame(
    t(as.matrix(header)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  names(columns) <- head[[1]][seq_len(n_header)]
  ensure_dlc_levels(columns, path)

  keep <- columns$coords %in% dlc_coords()
  data <- vroom::vroom(
    path,
    delim = ",",
    col_names = FALSE,
    skip = n_header,
    col_types = paste0(c("?", ifelse(keep, "d", "_")), collapse = ""),
    show_col_types = FALSE,
    progress = FALSE
  )

  list(
    columns = columns[keep, , drop = FALSE],
    values = as.matrix(data[-1]),
    index = data[[1]]
  )
}

#' Read a DeepLabCut h5 file
#'
#' Reads the pandas DataFrame under the key `df_with_missing` (predictions)
#' or `tracks` (stitched tracklets), stored in pandas' "table" format, as
#' DeepLabCut writes it, or its "fixed" format, as pandas writes by default.
#'
#' @param path Path to a DeepLabCut `.h5` file.
#' @inherit read_deeplabcut_csv return
#' @keywords internal
read_deeplabcut_h5 <- function(path) {
  check_rhdf5()
  on.exit(rhdf5::h5closeAll(), add = TRUE)

  key <- dlc_h5_key(path)
  if (is.na(key)) {
    cli::cli_abort(c(
      "{.file {path}} is not a DeepLabCut h5 file.",
      "i" = "Expected a {.val df_with_missing} or {.val tracks} group at its root."
    ))
  }

  attrs <- rhdf5::h5readAttributes(path, key)
  wide <- switch(
    attrs$pandas_type %||% "",
    frame_table = read_pandas_table(path, key, attrs),
    frame = read_pandas_fixed(path, key, attrs),
    cli::cli_abort(
      "{.file {path}} does not hold a pandas DataFrame under {.val {key}}."
    )
  )
  ensure_dlc_levels(wide$columns, path)

  keep <- wide$columns$coords %in% dlc_coords()
  wide$columns <- wide$columns[keep, , drop = FALSE]
  wide$values <- wide$values[, keep, drop = FALSE]
  wide
}

#' The HDF key a DeepLabCut h5 keeps its DataFrame under
#'
#' @param path Path to an `.h5` file.
#' @return `"df_with_missing"` or `"tracks"`, whichever is a group at the
#'   root of the file, or `NA` when neither is. SLEAP's analysis files
#'   have a `tracks` dataset rather than a group.
#' @keywords internal
dlc_h5_key <- function(path) {
  contents <- rhdf5::h5ls(path, recursive = FALSE)
  on.exit(rhdf5::h5closeAll(), add = TRUE)
  groups <- contents$name[contents$otype == "H5I_GROUP"]
  key <- intersect(c("df_with_missing", "tracks"), groups)
  if (length(key) == 0) NA_character_ else key[[1]]
}

#' Read a DataFrame stored in pandas' "table" format
#'
#' The values sit in a compound dataset `<key>/table`, one field per block
#' of columns. The column labels of each block are a pickled list of tuples
#' in the block's `_kind` attribute, and the level names a pickled dict in
#' the group's `info` attribute.
#'
#' @param path Path to the `.h5` file.
#' @param key The HDF key of the DataFrame.
#' @param attrs The attributes of the group at `key`.
#' @inherit read_deeplabcut_csv return
#' @keywords internal
read_pandas_table <- function(path, key, attrs) {
  table <- paste0(key, "/table")
  raw <- rhdf5::h5read(path, table, compoundAsDataFrame = FALSE)
  table_attrs <- rhdf5::h5readAttributes(path, table)

  index <- as.vector(raw$index)
  blocks <- unlist(parse_pickle(attrs$values_cols))
  labels <- unlist(
    lapply(blocks, \(b) parse_pickle(table_attrs[[paste0(b, "_kind")]])),
    recursive = FALSE
  )
  values <- lapply(blocks, \(b) block_matrix(raw[[b]], length(index)))
  level_names <- unlist(parse_pickle(attrs$info)[["1"]][["names"]])

  levels <- lapply(seq_along(labels[[1]]), \(i) {
    vapply(labels, \(label) as.character(label[[i]]), character(1))
  })

  list(
    columns = dlc_columns(levels, level_names),
    values = do.call(cbind, values),
    index = index
  )
}

#' Read a DataFrame stored in pandas' "fixed" format
#'
#' Each block of columns has its values in `<key>/block<k>_values` and its
#' labels as a MultiIndex: per level, the unique values in
#' `block<k>_items_level<i>` and the codes into them in
#' `block<k>_items_label<i>`. The frame index is `<key>/axis1`.
#'
#' @inheritParams read_pandas_table
#' @inherit read_deeplabcut_csv return
#' @keywords internal
read_pandas_fixed <- function(path, key, attrs) {
  if (!identical(attrs$axis0_variety, "multi")) {
    cli::cli_abort(
      "The columns of {.file {path}} are not DeepLabCut's multi-level header."
    )
  }

  index <- as.vector(rhdf5::h5read(path, paste0(key, "/axis1")))
  blocks <- lapply(seq_len(attrs$nblocks) - 1L, \(k) {
    prefix <- paste0(key, "/block", k, "_items")
    n_levels <- attrs[[paste0("block", k, "_items_nlevels")]]
    levels <- lapply(seq_len(n_levels) - 1L, \(i) {
      level <- as.character(rhdf5::h5read(path, paste0(prefix, "_level", i)))
      Encoding(level) <- "UTF-8"
      codes <- as.vector(rhdf5::h5read(path, paste0(prefix, "_label", i)))
      level[replace(codes + 1L, codes < 0L, NA)]
    })
    level_names <- vapply(
      seq_len(n_levels) - 1L,
      \(i) {
        # rhdf5 warns about the `transposed` attribute, which it cannot read
        level_attrs <- suppressWarnings(
          rhdf5::h5readAttributes(path, paste0(prefix, "_level", i))
        )
        level_attrs$name %||% NA_character_
      },
      character(1)
    )
    values <- rhdf5::h5read(path, paste0(key, "/block", k, "_values"))
    list(
      columns = dlc_columns(levels, level_names),
      values = block_matrix(values, length(index))
    )
  })

  list(
    columns = do.call(rbind, lapply(blocks, \(b) b$columns)),
    values = do.call(cbind, lapply(blocks, \(b) b$values)),
    index = index
  )
}

#' Arrange one block of values as frames by columns
#'
#' @param values A block as rhdf5 reads it: columns by frames, or a vector
#'   when the block has a single column.
#' @param n_frames Number of frames.
#' @return A numeric matrix with one row per frame.
#' @keywords internal
block_matrix <- function(values, n_frames) {
  matrix(as.vector(values), nrow = n_frames, byrow = TRUE)
}

#' Name the column levels of a DeepLabCut header
#'
#' @param levels List of character vectors, one per level, each with one
#'   element per column.
#' @param level_names The level names pandas stored, or `NULL`/`NA` where it
#'   stored none. DeepLabCut's own order is assumed then.
#' @return A data frame with one row per column and one column per level.
#' @keywords internal
dlc_columns <- function(levels, level_names) {
  dlc_order <- list(
    c("scorer", "bodyparts", "coords"),
    c("scorer", "individuals", "bodyparts", "coords")
  )
  if (length(level_names) != length(levels) || anyNA(level_names)) {
    default <- Filter(\(o) length(o) == length(levels), dlc_order)
    level_names <- if (length(default) == 1) default[[1]] else NULL
  }
  names(levels) <- level_names
  as.data.frame(levels, stringsAsFactors = FALSE, optional = TRUE)
}

#' Check that a header has the levels DeepLabCut writes
#'
#' @param columns Column levels, as from [dlc_columns()].
#' @param path The file they were read from, for the message.
#' @keywords internal
ensure_dlc_levels <- function(columns, path) {
  missing <- setdiff(c("bodyparts", "coords"), names(columns))
  if (length(missing) > 0) {
    cli::cli_abort(c(
      "{.file {path}} does not have DeepLabCut's column header.",
      "x" = "No {.val {missing}} level."
    ))
  }
  coords <- unique(columns$coords)
  if (!all(c("x", "y") %in% coords)) {
    cli::cli_abort(c(
      "{.file {path}} has no {.val x} and {.val y} coords.",
      "i" = "Its coords are {.val {coords}}."
    ))
  }
}

#' Turn DeepLabCut's wide layout into one row per point and frame
#'
#' @param wide A list of `columns`, `values` and `index`, as from
#'   [read_deeplabcut_csv()] or [read_deeplabcut_h5()].
#' @return A tibble with `time`, `individual` (when the header has an
#'   `individuals` level), `keypoint`, `x`, `y`, `z` (when present) and
#'   `confidence`, which is `NA` when the file has no likelihood.
#' @keywords internal
dlc_points_long <- function(wide) {
  columns <- wide$columns
  multianimal <- "individuals" %in% names(columns)
  point <- if (multianimal) {
    paste(columns$individuals, columns$bodyparts, sep = "\u001f")
  } else {
    columns$bodyparts
  }
  key <- paste(point, columns$coords, sep = "\u001f")
  if (anyDuplicated(key)) {
    cli::cli_abort(c(
      "More than one column holds the same point.",
      "i" = "The file may hold several scorers: {.val {unique(columns$scorer)}}."
    ))
  }

  points <- unique(point)
  first <- match(points, point)
  n_frames <- length(wide$index)
  n_points <- length(points)

  out <- list(time = rep(wide$index, each = n_points))
  if (multianimal) {
    out$individual <- factor(rep(columns$individuals[first], times = n_frames))
  }
  out$keypoint <- factor(rep(columns$bodyparts[first], times = n_frames))

  # pandas writes a missing value as NaN to h5 and as an empty field to csv
  values <- wide$values
  values[is.nan(values)] <- NA_real_
  coord_values <- function(coord) {
    i <- match(paste(points, coord, sep = "\u001f"), key)
    as.vector(t(values[, i, drop = FALSE]))
  }
  axes <- intersect(c("x", "y", "z"), columns$coords)
  out[axes] <- lapply(axes, coord_values)
  out$confidence <- if ("likelihood" %in% columns$coords) {
    coord_values("likelihood")
  } else {
    rep(NA_real_, n_frames * n_points)
  }

  dplyr::as_tibble(out)
}

#' Read a protocol 0 pickle
#'
#' PyTables stores the Python objects pandas keeps as HDF5 attributes as
#' protocol 0 pickles: lists, tuples and dicts of strings, integers and
#' `None`. This reads that subset, without Python. Lists and tuples become
#' unnamed lists, dicts named lists, `None` `NULL`.
#'
#' @param x A pickle, as a single string.
#' @return The unpickled object.
#' @keywords internal
parse_pickle <- function(x) {
  bytes <- charToRaw(x)
  newlines <- which(bytes == as.raw(10L))
  stack <- list()
  marks <- integer()
  memo <- list()
  pos <- 1L

  pop_mark <- function() {
    mark <- marks[[length(marks)]]
    marks <<- marks[-length(marks)]
    items <- stack[seq_along(stack) > mark]
    stack <<- stack[seq_len(mark)]
    items
  }
  push <- function(value) {
    # Force `value` first: it may be pop_mark(), which shortens the stack.
    force(value)
    stack <<- c(stack, list(value))
  }

  repeat {
    op <- rawToChar(bytes[pos])
    if (op %in% c("V", "I", "p", "g")) {
      end <- newlines[[findInterval(pos, newlines) + 1L]]
      arg <- bytes[seq_len(end - pos - 1L) + pos]
      pos <- end + 1L
    } else {
      pos <- pos + 1L
    }

    if (op == ".") {
      break
    }
    switch(
      op,
      "(" = marks <- c(marks, length(stack)),
      "l" = ,
      "t" = push(pop_mark()),
      "d" = {
        items <- pop_mark()
        is_key <- seq_along(items) %% 2L == 1L
        keys <- vapply(items[is_key], as.character, character(1))
        push(stats::setNames(items[!is_key], keys))
      },
      "a" = {
        n <- length(stack)
        stack[[n - 1L]] <- c(stack[[n - 1L]], stack[n])
        stack <- stack[-n]
      },
      "s" = {
        n <- length(stack)
        stack[[n - 2L]][as.character(stack[[n - 1L]])] <- stack[n]
        stack <- stack[seq_len(n - 2L)]
      },
      "p" = memo[[rawToChar(arg)]] <- stack[[length(stack)]],
      "g" = push(memo[[rawToChar(arg)]]),
      "V" = push(decode_pickle_unicode(arg)),
      "I" = push(as.integer(rawToChar(arg))),
      "N" = push(NULL),
      cli::cli_abort("Cannot read pickle opcode {.val {op}}.")
    )
  }

  stack[[1]]
}

#' Decode a protocol 0 pickle's unicode string
#'
#' Python writes these as "raw-unicode-escape": characters below 256 as
#' their Latin-1 byte, the rest as `\uXXXX` or `\UXXXXXXXX`.
#'
#' @param bytes The string's bytes.
#' @return A UTF-8 string.
#' @keywords internal
decode_pickle_unicode <- function(bytes) {
  x <- rawToChar(bytes)
  Encoding(x) <- "latin1"
  x <- enc2utf8(x)
  escapes <- gregexpr("\\\\u[0-9a-fA-F]{4}|\\\\U[0-9a-fA-F]{8}", x)
  regmatches(x, escapes) <- lapply(regmatches(x, escapes), \(e) {
    vapply(
      e,
      \(s) intToUtf8(strtoi(substring(s, 3), 16L)),
      character(1),
      USE.NAMES = FALSE
    )
  })
  x
}
