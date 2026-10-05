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
#' Each track is named after its `name` attribute, which TrackMate sets to
#' `Track_0`, `Track_1`, ... and lets you edit, so the names you gave tracks in
#' TrackMate become the values of `track`. The numeric `TRACK_ID` is used
#' instead when any track has no name, or when two tracks share one, with a
#' warning in that case.
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
#'   than stopping the read.
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
#' @return An aniframe with columns including time, x, y, z, frame, and track_id.
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
  unit_space <- trackmate_unit_space(
    xml2::xml_attr(model_node, "spatialunits")
  )
  unit_time <- trackmate_unit_time(xml2::xml_attr(model_node, "timeunits"))
  image_data <- xml2::xml_find_first(xml, ".//Settings/ImageData")
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

  # Join and arrange
  result <- spot_track_map |>
    dplyr::inner_join(spots, by = "spot_id") |>
    dplyr::select(-"spot_id")

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
#' @return One of anicore's `unit_space` levels, `"none"` when the unit has
#'   no equivalent.
#' @noRd
trackmate_unit_space <- function(unit) {
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
#' @return `track_names` when every track has one and no two share it,
#'   otherwise `track_ids`.
#' @noRd
trackmate_track_labels <- function(track_names, track_ids) {
  if (anyNA(track_names) || !all(nzchar(track_names))) {
    return(track_ids)
  }
  if (anyDuplicated(track_names)) {
    cli::cli_warn(c(
      "TrackMate track names are not unique.",
      "i" = "Labelling tracks by {.field TRACK_ID} instead."
    ))
    return(track_ids)
  }
  track_names
}

#' Build a mapping from spot IDs to tracks
#'
#' @param track_nodes XML nodeset of Track elements.
#' @param filtered_ids Character vector of filtered track IDs to include.
#'
#' @return A data.frame with spot_id, track and keypoint columns, where track
#'   is the track's name or ID (see `trackmate_track_labels()`).
#' @noRd
build_spot_track_map <- function(track_nodes, filtered_ids) {
  # Pre-filter to only process tracks we care about
  track_ids <- xml2::xml_attr(track_nodes, "TRACK_ID")
  keep <- track_ids %in% filtered_ids
  track_nodes <- track_nodes[keep]
  track_labels <- trackmate_track_labels(
    xml2::xml_attr(track_nodes, "name"),
    track_ids[keep]
  )

  # Process each track
  lapply(seq_along(track_nodes), function(i) {
    edge_nodes <- xml2::xml_find_all(track_nodes[[i]], ".//Edge")
    source_ids <- xml2::xml_attr(edge_nodes, "SPOT_SOURCE_ID")
    target_ids <- xml2::xml_attr(edge_nodes, "SPOT_TARGET_ID")
    spot_ids <- unique(c(source_ids, target_ids))

    data.frame(
      spot_id = spot_ids,
      track = track_labels[[i]],
      keypoint = "centroid",
      stringsAsFactors = FALSE
    )
  }) |>
    dplyr::bind_rows()
}
