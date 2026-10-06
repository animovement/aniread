#' Read TrackMate XML into an aniframe
#'
#' Parses a TrackMate XML file and returns spot data from filtered tracks
#' as an aniframe. TrackMate stores spot coordinates in image (top-left)
#' coordinates; the reader reflects y so the returned aniframe is in the
#' conventional `bottom_left` origin. The frame height is read from
#' `Settings/ImageData` in the XML by default: `height` is in pixels and
#' `pixelheight` in `spatialunits`, so their product is the height in the
#' unit of the positions. Without a `pixelheight`, `height` is used as it is.
#'
#' Each track is identified in `track` by the name TrackMate gave it.
#' TrackMate names tracks `Track_0`, `Track_1`, ..., and the column already
#' says they are tracks, so a name of that form becomes its number alone:
#' `Track_12` is read as `12`. A name you gave a track in TrackMate, anything
#' not of the form `Track_<number>`, is kept as written. Each track's name is
#' read on its own, so a file in which you renamed some tracks gives, say,
#' `0`, `2` and `Cell A`. The numeric `TRACK_ID` is used instead when any
#' track has no name, or, with a warning, when two tracks would get the same
#' id (such as a track you renamed `3` beside `Track_3`). The levels of
#' `track` are the numbers in numeric order, `2` before `10`, followed by
#' any names sorted as text (capitals first, in every locale).
#'
#' A track that divides, as a cell lineage does, holds more than one spot in
#' a frame from its first division on, which a frame keyed by `track` and
#' `time` cannot hold. Such a track is split into its branches, each the
#' stretch of the track between divisions, and each branch becomes a track
#' of its own. The `parent` column records the lineage, as cell tracking
#' does (the `P` of the Cell Tracking Challenge's `res_track.txt`, Ultrack's
#' `parent_track_id`): it holds the id of the track a track divided from,
#' and is `NA` for a track that did not divide from another, so for every
#' track of a file without divisions. The branch before the first division
#' keeps the track's id. The other branches are numbered on from the
#' largest number that identifies any track in the file, by `TRACK_ID` or
#' by name, so a new id never names another track you can see in TrackMate.
#' They are numbered track by track, in the order of the tracks' ids, and
#' within a track by the frame they start in, then by the id of the track
#' they divided from, so sisters are numbered together, then by x and y. A
#' daughter starts at its first spot after the division, so nothing is
#' measured across it. A track whose branches also merge, or whose spots
#' share a frame in any other way, is left whole, with a warning about the
#' duplicate track-frame combinations. A split or merge that never puts two
#' spots in one frame, as when a link skips a frame beside another that does
#' not, needs no splitting.
#'
#' `parent` is not an identity key: the keys are `track` and `keypoint`. It
#' is a factor with the same levels as `track`, so its values match the
#' ids in `track`. One row per track gives the lineage, as the Cell Tracking
#' Challenge's `L B E P` table (label, first and last time, parent). The
#' frame is grouped by its keys, so drop to a plain tibble first:
#'
#' ```
#' data |>
#'   dplyr::as_tibble() |>
#'   dplyr::summarise(
#'     start = min(time),
#'     end = max(time),
#'     parent = dplyr::first(parent),
#'     .by = track
#'   )
#' ```
#'
#' The XML also records how the image was calibrated, and the reader keeps
#' what has a place in the metadata:
#'
#' * `timeunits` and `spatialunits`, from the `Model` element, become
#'   `unit_time` and `unit_space`. TrackMate takes them from the image's
#'   calibration in ImageJ, where they are free text, so the usual spellings
#'   are recognised: `"sec"`, `"msec"`, `"min"`, `"frame"` and so on for time,
#'   `"pixel"`, `"micron"`, `"um"` (with or without the micro sign), `"mm"`
#'   and so on for space. A unit with no equivalent in anicore (days or
#'   inches, say) becomes `"unknown"` or `"none"`, with a warning, rather
#'   than stopping the read. A blank spatial unit, which TrackMate writes for
#'   an image whose length unit is a space, is read as pixels when the pixel
#'   size in `Settings/ImageData` is 1 or not recorded, as ImageJ calls an
#'   image with no length unit `"pixel"`. With any other pixel size the
#'   positions are scaled by a unit nobody named, so it becomes `"none"`
#'   with a warning.
#' * `timeinterval`, from `Settings/ImageData`, is the time between frames in
#'   `timeunits`. Its reciprocal, converted to Hz, becomes `sampling_rate`.
#'   It stays `NA` when the interval is missing or not positive, or when the
#'   time unit is frames or not recognised.
#' * `version`, from the root element, is the TrackMate version that wrote
#'   the file and becomes `source_version`.
#'
#' TrackMate cannot tell an uncalibrated image from one calibrated at one
#' second per frame. An image with no time calibration has a frame interval
#' of 0, which TrackMate replaces with 1, and ImageJ's default time unit is
#' `"sec"`. A file with `timeunits = "sec"` and `timeinterval = 1` may
#' therefore really count frames, in which case `time` is the frame number
#' and the 1 Hz `sampling_rate` is not the camera's. If you know the real
#' rate, set it with [anicore::set_metadata()].
#'
#' @param path Path to the TrackMate XML file.
#' @param slim If TRUE, return only essential columns (default TRUE).
#' @param video_height Optional numeric height of the source frame in the
#'   spatial unit reported by the XML. Overrides the height read from
#'   `Settings/ImageData` when both are available.
#'
#' @return An aniframe with columns including `time`, `track`, `keypoint`,
#'   `parent`, `x`, `y`, `z` and `frame`.
#'
#' @examplesIf rlang::is_installed("xml2")
#' # A cell that divides into tracks 1 and 2, whose parent is track 0
#' path <- system.file("extdata", "trackmate.xml", package = "aniread")
#' data <- read_trackmate(path)
#' data
#'
#' # The lineage: one row per track, with the track it divided from
#' data |>
#'   dplyr::as_tibble() |>
#'   dplyr::summarise(
#'     start = min(time),
#'     end = max(time),
#'     parent = dplyr::first(parent),
#'     .by = track
#'   )
#'
#' @export
read_trackmate <- function(path, slim = TRUE, video_height = NULL) {
  # Check the file
  validate_files(path, expected_suffix = "xml")

  # Check that the xml2 package is installed
  check_xml2()

  # Read file
  xml <- xml2::read_xml(path)

  track_nodes <- xml2::xml_find_all(xml, ".//Track")
  if (length(track_nodes) == 0) {
    cli::cli_abort("No tracks found in XML file.")
  }

  filtered_ids <- xml2::xml_find_all(xml, ".//TrackID") |>
    xml2::xml_attr("TRACK_ID")

  if (length(filtered_ids) == 0) {
    cli::cli_abort("No filtered tracks found in XML file.")
  }

  # Units, frame interval and version
  model_node <- xml2::xml_find_first(xml, ".//Model")
  image_data <- xml2::xml_find_first(xml, ".//Settings/ImageData")
  unit_space <- trackmate_unit_space(
    xml2::xml_attr(model_node, "spatialunits"),
    pixel_size = suppressWarnings(as.numeric(
      xml2::xml_attr(image_data, c("pixelwidth", "pixelheight"))
    ))
  )
  unit_time <- trackmate_unit_time(xml2::xml_attr(model_node, "timeunits"))
  sampling_rate <- trackmate_sampling_rate(
    xml2::xml_attr(image_data, "timeinterval"),
    unit_time
  )
  source_version <- xml2::xml_attr(xml2::xml_root(xml), "version")

  # Frame height for the y-axis reflection (top_left -> bottom_left), in the
  # spatial unit of the positions
  video_height <- video_height %||% trackmate_image_height(image_data)

  # if (spatial_units == "pixel") {
  # 	cli::cli_warn(
  # 		"Spatial units are in pixels. Consider transforming to real units."
  # 	)
  # }
  # cli::cli_alert_info("Units: {spatial_units}, {time_units}")

  # Extract all spot attributes in one call
  spot_nodes <- xml2::xml_find_all(xml, ".//AllSpots//SpotsInFrame//Spot")
  spots <- extract_spot_attrs(spot_nodes, slim)

  # Build spot-to-track mapping (only for filtered tracks)
  spot_track_map <- build_spot_track_map(track_nodes, filtered_ids)

  # Join, split dividing tracks into their branches, and order the ids
  result <- spot_track_map$spots |>
    dplyr::inner_join(spots, by = "spot_id") |>
    split_dividing_tracks(spot_track_map$edges, spot_track_map$next_id) |>
    dplyr::select(-"spot_id")
  ids <- trackmate_sort_ids(unique(result$track))
  result$track <- factor(result$track, levels = ids)
  result$parent <- factor(result$parent, levels = ids)

  # Check for duplicates
  dupe_count <- sum(duplicated(result[, c("track", "frame")]))
  if (dupe_count > 0) {
    cli::cli_warn(
      "Detected {dupe_count} duplicate track-frame combinations."
    )
  }

  cli::cli_alert_success(
    "Loaded {nrow(result)} spots from {dplyr::n_distinct(result$track)} tracks."
  )

  data <- anicore::as_anipoint(
    result,
    variables_what = c("track", "keypoint")
  ) |>
    anicore::set_metadata(
      source = "trackmate",
      filename = basename(path),
      unit_time = unit_time,
      unit_space = unit_space
    )

  if (!is.na(sampling_rate)) {
    data <- anicore::set_metadata(data, sampling_rate = sampling_rate)
  }
  if (!is.na(source_version) && nzchar(source_version)) {
    data <- anicore::set_metadata(data, source_version = source_version)
  }

  if (length(unique(data$z)) == 1) {
    data <- data |>
      dplyr::select(-"z") |>
      anicore::set_metadata(
        coordinate_system = "cartesian_2d"
      )
  } else {
    data <- data |>
      anicore::set_metadata(
        coordinate_system = "cartesian_3d"
      )
  }

  # Remove the frame column if there are time stamps
  if (!all(is.na(data$time))) {
    data <- data |>
      dplyr::select(-"frame")
  }

  data <- reflect_to_bottom_left(data, video_height = video_height)

  data
}


#' Map a TrackMate time unit onto anicore's
#'
#' @param unit The `timeunits` attribute, free text from ImageJ's calibration.
#'
#' @return One of anicore's `unit_time` levels, `"unknown"` when the unit has
#'   no equivalent.
#' @noRd
trackmate_unit_time <- function(unit) {
  units <- list(
    frame = c("frame", "frames"),
    ns = c("ns", "nsec", "nanosecond", "nanoseconds"),
    us = c(
      "us",
      "\u00b5s",
      "\u03bcs",
      "usec",
      "\u00b5sec",
      "\u03bcsec",
      "microsecond",
      "microseconds"
    ),
    ms = c("ms", "msec", "millisecond", "milliseconds"),
    s = c("s", "sec", "secs", "second", "seconds"),
    m = c("min", "mins", "minute", "minutes"),
    h = c("h", "hr", "hrs", "hour", "hours")
  )
  trackmate_match_unit(unit, units, fallback = "unknown", field = "unit_time")
}

#' Map a TrackMate spatial unit onto anicore's
#'
#' @param unit The `spatialunits` attribute, free text from ImageJ's
#'   calibration.
#'
#' @param pixel_size The `pixelwidth` and `pixelheight` of
#'   `Settings/ImageData`, `NA` where not recorded.
#'
#' @return One of anicore's `unit_space` levels, `"none"` when the unit has
#'   no equivalent.
#' @noRd
trackmate_unit_space <- function(unit, pixel_size = NA_real_) {
  # ImageJ names a missing length unit "pixel", but keeps one that is blank.
  if (!is.na(unit) && !nzchar(trimws(unit)) && all(pixel_size %in% c(1, NA))) {
    return("px")
  }
  units <- list(
    px = c("pixel", "pixels", "px"),
    nm = c("nm", "nanometer", "nanometers", "nanometre", "nanometres"),
    um = c(
      "um",
      "\u00b5m",
      "\u03bcm",
      "micron",
      "microns",
      "micrometer",
      "micrometers",
      "micrometre",
      "micrometres"
    ),
    mm = c("mm", "millimeter", "millimeters", "millimetre", "millimetres"),
    cm = c("cm", "centimeter", "centimeters", "centimetre", "centimetres"),
    m = c("m", "meter", "meters", "metre", "metres"),
    km = c("km", "kilometer", "kilometers", "kilometre", "kilometres")
  )
  trackmate_match_unit(unit, units, fallback = "none", field = "unit_space")
}

#' Look a unit up among its spellings
#'
#' @param unit A unit as written in the file, or `NA`.
#' @param units A named list: anicore's level, then the spellings that mean it.
#' @param fallback The level to use when nothing matches.
#' @param field The metadata field, for the warning.
#'
#' @return A single anicore level.
#' @noRd
trackmate_match_unit <- function(unit, units, fallback, field) {
  if (is.na(unit)) {
    return(fallback)
  }
  key <- tolower(trimws(unit))
  for (level in names(units)) {
    if (key %in% units[[level]]) {
      return(level)
    }
  }
  cli::cli_warn(c(
    "TrackMate unit {.val {unit}} has no equivalent in anicore.",
    "i" = "Setting {.field {field}} to {.val {fallback}}."
  ))
  fallback
}

#' Sampling rate from TrackMate's frame interval
#'
#' @param interval The `timeinterval` attribute of `Settings/ImageData`, the
#'   time between frames in `unit_time`, as a string or `NA`.
#' @param unit_time The anicore time unit the interval is in.
#'
#' @return The rate in Hz, or `NA` when the interval is not a positive number
#'   or the unit is not a unit of time.
#' @noRd
trackmate_sampling_rate <- function(interval, unit_time) {
  seconds <- c(ns = 1e-9, us = 1e-6, ms = 1e-3, s = 1, m = 60, h = 3600)
  interval <- suppressWarnings(as.numeric(interval))
  if (
    is.na(interval) ||
      !is.finite(interval) ||
      interval <= 0 ||
      !unit_time %in% names(seconds)
  ) {
    return(NA_real_)
  }
  1 / (interval * seconds[[unit_time]])
}

#' Extract spot attributes efficiently
#'
#' @param spot_nodes XML nodeset of Spot elements.
#' @param slim If TRUE, extract only essential columns.
#'
#' @return A data.frame of spot attributes.
#' @noRd
extract_spot_attrs <- function(spot_nodes, slim) {
  # Pull all attributes at once - much faster than multiple xml_attr calls
  all_attrs <- xml2::xml_attrs(spot_nodes)

  # Define columns to extract
  core_cols <- c(
    "ID",
    "POSITION_X",
    "POSITION_Y",
    "POSITION_Z",
    "POSITION_T",
    "FRAME"
  )
  extra_cols <- c("RADIUS", "QUALITY")
  cols <- if (slim) core_cols else c(core_cols, extra_cols)

  # Extract as matrix then convert
  mat <- vapply(all_attrs, function(x) x[cols], character(length(cols)))
  spots <- as.data.frame(t(mat), stringsAsFactors = FALSE)
  names(spots) <- c(
    "spot_id",
    "x",
    "y",
    "z",
    "time",
    "frame",
    if (!slim) c("radius", "quality")
  )

  # Type conversion
  num_cols <- setdiff(names(spots), "spot_id")
  spots[num_cols] <- lapply(spots[num_cols], as.numeric)
  spots$frame <- as.integer(spots$frame)

  spots
}


#' Height of the image in the spatial unit of the positions
#'
#' @param image_data The `Settings/ImageData` node, possibly missing.
#'
#' @return `height` (pixels) times `pixelheight` (spatial unit per pixel), or
#'   `height` alone when there is no usable `pixelheight`. `NULL` when there
#'   is no `height`.
#' @noRd
trackmate_image_height <- function(image_data) {
  height <- suppressWarnings(
    as.numeric(xml2::xml_attr(image_data, "height"))
  )
  if (is.na(height)) {
    return(NULL)
  }
  pixel_height <- suppressWarnings(
    as.numeric(xml2::xml_attr(image_data, "pixelheight"))
  )
  if (is.na(pixel_height) || !is.finite(pixel_height) || pixel_height <= 0) {
    return(height)
  }
  height * pixel_height
}

#' Label tracks by name, or by ID when the names cannot identify them
#'
#' @param track_names The `name` attribute of each track, `NA` where absent.
#' @param track_ids The `TRACK_ID` attribute of each track.
#'
#' @return `track_names`, with TrackMate's default names `Track_<n>` cut to
#'   `<n>`, when every track has one and no two share it, otherwise
#'   `track_ids`.
#' @noRd
trackmate_track_labels <- function(track_names, track_ids) {
  if (anyNA(track_names) || !all(nzchar(track_names))) {
    return(track_ids)
  }
  labels <- sub("^Track_([0-9]+)$", "\\1", track_names)
  if (anyDuplicated(labels)) {
    cli::cli_warn(c(
      "TrackMate track names do not tell every track apart.",
      "i" = "Labelling tracks by {.field TRACK_ID} instead."
    ))
    return(track_ids)
  }
  labels
}

#' Sort track ids, numbers first in numeric order
#'
#' @param ids A character vector of track ids.
#'
#' @return `ids` sorted: the whole numbers in numeric order, then the rest
#'   as text, in the same order in every locale.
#' @noRd
trackmate_sort_ids <- function(ids) {
  number <- suppressWarnings(as.numeric(ifelse(
    grepl("^[0-9]+$", ids),
    ids,
    NA
  )))
  ids[order(is.na(number), number, ids, method = "radix")]
}

#' Build a mapping from spot IDs to tracks
#'
#' @param track_nodes XML nodeset of Track elements.
#' @param filtered_ids Character vector of filtered track IDs to include.
#'
#' @return A list of `spots`, a data.frame with spot_id, track and keypoint
#'   columns, where track is the track's name or ID (see
#'   `trackmate_track_labels()`); `edges`, a data.frame of each link's
#'   track, `source` and `target` spot; and `next_id`, one more than the
#'   largest number among the `TRACK_ID`s and names of all tracks in the
#'   file, the first id free for a branch.
#' @noRd
build_spot_track_map <- function(track_nodes, filtered_ids) {
  # Pre-filter to only process tracks we care about
  track_ids <- xml2::xml_attr(track_nodes, "TRACK_ID")
  track_names <- xml2::xml_attr(track_nodes, "name")
  keep <- track_ids %in% filtered_ids

  # Numbers that identify a track anywhere in the file
  numbers <- c(track_ids, sub("^Track_", "", track_names))
  numbers <- as.numeric(numbers[grepl("^[0-9]+$", numbers)])
  next_id <- if (length(numbers) > 0) max(numbers) + 1 else 0

  track_nodes <- track_nodes[keep]
  track_labels <- trackmate_track_labels(track_names[keep], track_ids[keep])

  # Process each track
  edges <- lapply(seq_along(track_nodes), function(i) {
    edge_nodes <- xml2::xml_find_all(track_nodes[[i]], ".//Edge")
    data.frame(
      track = rep(track_labels[[i]], length(edge_nodes)),
      source = xml2::xml_attr(edge_nodes, "SPOT_SOURCE_ID"),
      target = xml2::xml_attr(edge_nodes, "SPOT_TARGET_ID"),
      stringsAsFactors = FALSE
    )
  }) |>
    dplyr::bind_rows()

  spots <- lapply(split(edges, factor(edges$track, unique(edges$track))), \(e) {
    data.frame(
      spot_id = unique(c(e$source, e$target)),
      track = e$track[[1]],
      keypoint = "centroid",
      stringsAsFactors = FALSE
    )
  }) |>
    dplyr::bind_rows()

  list(spots = spots, edges = edges, next_id = next_id)
}

#' Split tracks that divide into their branches
#'
#' @param spots The spots of the filtered tracks: spot_id, track, frame, x
#'   and y at least.
#' @param edges The links of those tracks, as `build_spot_track_map()`
#'   returns them.
#' @param next_id The first id free for a branch.
#'
#' @return `spots`, with a `parent` column, and with `track` and `parent`
#'   giving the branch of each spot of a track that holds more than one spot
#'   in a frame, where that track is a tree of divisions (see
#'   `trackmate_branches()`). The branch before the first division keeps the
#'   track's id, and the others are numbered from `next_id`, track by track
#'   in the order of their ids, and within a track by the frame they start
#'   in, then the branch they divided from, then x and y.
#' @noRd
split_dividing_tracks <- function(spots, edges, next_id) {
  spots$parent <- NA_character_
  shared <- unique(spots$track[duplicated(spots[c("track", "frame")])])
  for (label in trackmate_sort_ids(shared)) {
    rows <- which(spots$track == label)
    branches <- trackmate_branches(
      spots[rows, ],
      edges[edges$track == label, ]
    )
    if (is.null(branches)) {
      next
    }
    # Number the branches after the root by the frame they start in, then
    # the branch they divided from, then x and y (y as returned, after the
    # reflection). A branch starts after the one it divided from, so that
    # one is numbered first.
    track_spots <- spots[rows, ]
    first <- track_spots[match(names(branches$parent), track_spots$spot_id), ]
    first$mother <- unname(branches$parent[first$spot_id])
    rank <- stats::setNames(0, branches$root)
    for (f in sort(unique(first$frame))) {
      start <- first[first$frame == f, ]
      start <- start[order(rank[start$mother], start$x, -start$y), ]
      rank[start$spot_id] <- length(rank) + seq_len(nrow(start)) - 1
    }
    ids <- stats::setNames(
      c(label, sprintf("%.0f", next_id + seq_len(length(rank) - 1) - 1)),
      names(rank)
    )
    next_id <- next_id + length(rank) - 1

    spots$track[rows] <- unname(ids[branches$branch])
    spots$parent[rows] <- unname(ids[branches$parent[branches$branch]])
  }
  spots
}

#' Find the branches of a dividing track
#'
#' A branch is a stretch of the track between divisions: it starts at the
#' track's first spot or at a spot just after a division, and ends at a
#' division or the track's end.
#'
#' @param spots The track's spots: spot_id and frame.
#' @param edges The track's links: source and target.
#'
#' @return A list of `branch`, the first spot of each spot's branch, named by
#'   spot; `root`, the first spot of the branch before the first division;
#'   and `parent`, the first spot of the branch each other branch divided
#'   from, named by the first spot of that branch. `NULL` when the track is
#'   not a tree of divisions forward in time: when a link joins two spots of
#'   one frame or a spot outside the track, or a spot has two parents (a
#'   merge).
#' @noRd
trackmate_branches <- function(spots, edges) {
  frame <- stats::setNames(spots$frame, spots$spot_id)
  forward <- frame[edges$source] < frame[edges$target]
  backward <- frame[edges$source] > frame[edges$target]
  if (!isTRUE(all(forward | backward))) {
    return(NULL)
  }
  # TrackMate links a spot to a later one, but the reader does not rely on it.
  parent <- ifelse(forward, edges$source, edges$target)
  child <- ifelse(forward, edges$target, edges$source)
  if (anyDuplicated(child)) {
    return(NULL)
  }

  # Parents come before their children in time, so in time order each
  # parent's branch is known before its children's.
  in_time <- order(frame[child])
  parent <- parent[in_time]
  child <- child[in_time]
  n_children <- table(parent)
  branch <- stats::setNames(spots$spot_id, spots$spot_id)
  branch_parent <- character()
  for (i in seq_along(child)) {
    if (n_children[[parent[[i]]]] == 1) {
      branch[[child[[i]]]] <- branch[[parent[[i]]]]
    } else {
      branch_parent[[child[[i]]]] <- branch[[parent[[i]]]]
    }
  }
  list(
    branch = branch,
    root = setdiff(spots$spot_id, child),
    parent = branch_parent
  )
}
