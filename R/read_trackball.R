#' Read trackball data
#'
#' Read trackball data from a variety of setups and configurations.
#'
#' @param paths Two file paths, one for each sensor (although one is allowed for a fixed setup, `of_fixed`).
#' @param setup Which type of experimental setup was used. Expects either `of_free` or `of_fixed`.
#' @param sampling_rate Sampling rate tells the function how long time it should integrate over. A sampling rate of 60(Hz) will mean windows of 1/60 sec are used to integrate over.
#' @param col_time Which column contains the information about time. Can be
#'   specified either by the column number (numeric) or the name of the column if
#'   it has one (character). Should either be a datetime (POSIXt) or seconds
#'   (numeric). **With two sensors, this must be a clock the two sensors share.**
#'   In a Bonsai capture that is the PC datetime (column 4), not the per-board
#'   device counter (column 3), whose origin is sensor-local and therefore
#'   cannot be used to cross-reference the two files. A warning is emitted if
#'   `col_time` resolves to a non-datetime column with two sensors.
#' @param col_dx Column name for x-axis values
#' @param col_dy Column name for y-axis values
#' @param counts_per_rotation For `of_fixed` setup: the sensor count for a full 360 degree rotation. Can be obtained using `calibrate_trackball()`.
#' @param ball_diameter For `of_fixed` setup: the ball diameter (in same units as desired output). Required if using `dots_per_cm` instead of `counts_per_rotation`.
#' @param dots_per_cm For `of_fixed` setup: sensor dots-per-cm. Use with `ball_diameter` as an alternative to `counts_per_rotation`.
#' @param quiet If `TRUE` (default), suppresses informational messages such as
#'   the count of malformed rows dropped from each file.
#'
#' @details
#' Raw Bonsai optical-flow captures are headerless CSV files, optionally preceded
#' by a single line of serial-port junk, with the layout
#' `dx, dy, device_clock_us, pc_datetime, interval_s`. Address their columns by
#' number (`col_dx = 1`, `col_dy = 2`, `col_time = 4`).
#'
#' Such captures are not gap-free: on this rig the COM port emits no row while
#' the ball is still, so multi-second gaps are normal. Readings are integrated
#' into `1 / sampling_rate` windows, and windows containing no reading are
#' filled with zero motion so the returned time grid is regular regardless of
#' the gaps in the input. Note that this treats a missing sample as *no motion*,
#' which is a property of this logger rather than of optical flow in general; a
#' sensor that drops samples for other reasons would need its gaps treated as
#' missing data instead.
#'
#' With two sensors the output covers only the intersection of the two
#' recordings - readings from before the second sensor started, or after the
#' first stopped, are discarded rather than zero-filled. `time = 0` is the first
#' shared sample, and the `start_datetime` metadata is the wall-clock instant of
#' that sample.
#'
#' @return a movement dataframe
#' @export
read_trackball <- function(
  paths,
  setup = c("of_free", "of_fixed"),
  sampling_rate,
  col_time = "time",
  col_dx = "x",
  col_dy = "y",
  counts_per_rotation = NULL,
  ball_diameter = NULL,
  dots_per_cm = NULL,
  quiet = TRUE
) {
  setup <- match.arg(setup)
  validate_files(paths, expected_suffix = "csv")
  validate_trackball(paths, setup = setup, col_time = col_time)
  n_sensors <- length(paths)

  # Read data
  if (n_sensors == 2) {
    data_list <- list()
    start_datetimes <- list()
    for (i in 1:n_sensors) {
      data_list[[i]] <- read_opticalflow(
        paths[i],
        col_time = col_time,
        col_dx = col_dx,
        col_dy = col_dy,
        quiet = quiet
      ) |>
        dplyr::mutate(sensor_n = i)
      start_datetimes[[i]] <- attr(data_list[[i]], "start_datetime")
    }
    # `start_datetime` is only non-NA when the time column was a real clock.
    # A per-board counter has a sensor-local origin, so it cannot align the two
    # files - warn rather than silently return a misaligned trajectory.
    has_clock <- !vapply(start_datetimes, \(x) all(is.na(x)), logical(1))
    if (!all(has_clock)) {
      cli::cli_warn(
        c(
          "{.arg col_time} does not resolve to a datetime column.",
          "!" = "With two sensors, {.arg col_time} must be a clock both sensors
               share; a per-board device counter has a sensor-local origin and
               cannot align the two files.",
          "i" = "For a Bonsai capture, use the PC datetime column
               ({.code col_time = 4}) rather than the device counter
               ({.code col_time = 3})."
        ),
        class = "aniread_sensor_local_clock"
      )
    }
    # Shared start is the later of the two (max of mins)
    if (all(has_clock)) {
      start_datetime <- max(do.call(c, start_datetimes))
    } else {
      start_datetime <- NA
    }
    data <- join_trackball_files(data_list, sampling_rate = sampling_rate)
  } else {
    data <- read_opticalflow(
      paths,
      col_time = col_time,
      col_dx = col_dx,
      col_dy = col_dy,
      quiet = quiet
    )
    start_datetime <- attr(data, "start_datetime")
    # `read_opticalflow()` returns time on an absolute scale, so zero it here.
    data <- data |>
      dplyr::mutate(
        time_group = floor((.data$time - min(.data$time)) * sampling_rate)
      ) |>
      dplyr::group_by(.data$time_group) |>
      dplyr::summarise(
        x_1 = sum(.data$dx),
        y_1 = sum(.data$dy)
      ) |>
      fill_missing_time_groups(zero_cols = c("x_1", "y_1"))
  }

  # Calculate coordinates (free/fixed)
  if (setup == "of_free") {
    data <- data |>
      compute_xy_coordinates_free()
  } else if (setup == "of_fixed") {
    data <- data |>
      compute_xy_coordinates_fixed(
        n_sensors = n_sensors,
        counts_per_rotation = counts_per_rotation,
        ball_diameter = ball_diameter,
        dots_per_cm = dots_per_cm
      )
  }

  # Scale distance and time and select output columns
  data <- data |>
    dplyr::mutate(
      time = .data$time / sampling_rate,
      keypoint = "centroid"
    ) |>
    dplyr::select(
      "keypoint",
      "time",
      "x",
      "y"
    )

  # Init metadata
  data <- data |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(
      source = "trackball_bonsai",
      filename = paths,
      sampling_rate = sampling_rate,
      unit_space = "none",
      unit_time = "s",
      start_datetime = start_datetime
    )

  return(data)
}

#' Read optical flow sensor file
#'
#' @description
#' Read a single optical flow sensor file.
#'
#' Time is returned on an **absolute** scale (epoch seconds when the time column
#' is a datetime, otherwise the raw device clock scaled to seconds). Choosing an
#' origin is left to the caller: with two sensors, the offset between the files
#' is the only thing [join_trackball_files()] has to align them on, so zeroing
#' each file to its own start here would destroy it.
#'
#' @param path Path to the file.
#' @inheritParams read_trackball
#' @return A data frame with columns `time`, `dx` and `dy`, carrying a
#'   `start_datetime` attribute. The attribute is `NA` when the time column was
#'   not a real clock, which is also how the caller detects a sensor-local
#'   device counter.
#' @keywords internal
read_opticalflow <- function(path, col_time, col_dx, col_dy, quiet = TRUE) {
  layout <- detect_opticalflow_layout(path)

  # `altrep = FALSE` so parsing happens here rather than on first use of a
  # column. Serial capture drops characters, so short rows are normal; they are
  # reported below by count instead of as a vroom parsing problem raised from
  # whichever downstream verb happens to materialise the column.
  data <- vroom::vroom(
    path,
    delim = ",",
    skip = layout$skip,
    col_names = layout$has_header,
    show_col_types = FALSE,
    altrep = FALSE,
    .name_repair = "unique"
  ) |>
    suppressMessages() |>
    suppressWarnings()

  # Resolve column identifiers to names
  col_time <- resolve_column(data, col_time)
  col_dx <- resolve_column(data, col_dx)
  col_dy <- resolve_column(data, col_dy)

  # Change column names
  data <- data |>
    dplyr::rename(
      "dx" = dplyr::all_of(col_dx),
      "dy" = dplyr::all_of(col_dy),
      "time" = dplyr::all_of(col_time)
    ) |>
    dplyr::select("time", "dx", "dy")

  # Drop malformed rows. A short row shifts every field after the gap, so it
  # lands as NA in at least one of the three columns we care about. Filtering
  # explicitly (rather than relying on NA-dropping in downstream maths) also
  # sidesteps vroom's ALTREP columns.
  n_before <- nrow(data)
  data <- data |>
    dplyr::filter(
      !is.na(.data$time) & !is.na(.data$dx) & !is.na(.data$dy)
    )
  n_dropped <- n_before - nrow(data)
  if (n_dropped > 0 && !quiet) {
    cli::cli_inform(
      "Dropped {n_dropped} malformed row{?s} from {.file {basename(path)}}."
    )
  }
  if (nrow(data) == 0) {
    cli::cli_abort(
      "No usable rows left in {.file {basename(path)}} after dropping
       malformed rows."
    )
  }

  if (inherits(data$time, "POSIXt")) {
    start_datetime <- min(data$time)
    data <- data |>
      dplyr::mutate(time = as.numeric(.data$time))
  } else if (is.character(data$time)) {
    # vroom auto-parses ISO datetime strings to POSIXct, so this branch is
    # only reachable for non-ISO timestamp strings.
    parsed <- as.POSIXct(data$time)
    start_datetime <- min(parsed)
    data <- data |>
      dplyr::mutate(time = as.numeric(parsed))
  } else {
    # Numeric timestamps - no real datetime available
    start_datetime <- NA
    divisor <- detect_time_divisor(data$time)
    data <- data |>
      dplyr::mutate(time = as.numeric(.data$time) / divisor)
  }

  attr(data, "start_datetime") <- start_datetime
  return(data)
}

#' Detect the layout of an optical flow file
#'
#' @description
#' Bonsai writes headerless CSV, sometimes preceded by a line of serial-port
#' junk (a partial row, or a run of noise characters). Rather than assuming a
#' fixed number of leading lines, take the modal field count over the start of
#' the file as the true record width and skip everything before the first line
#' that matches it.
#'
#' @param path Path to the file.
#' @param n_peek Number of leading lines to inspect.
#' @return A list with `skip` (lines to discard) and `has_header` (`TRUE` when
#'   the first kept line names the columns, `FALSE` when it is already data).
#' @keywords internal
detect_opticalflow_layout <- function(path, n_peek = 20) {
  lines <- readLines(path, n = n_peek, warn = FALSE)
  if (length(lines) == 0) {
    return(list(skip = 0, has_header = FALSE)) # nocov
  }

  con <- textConnection(lines)
  on.exit(close(con), add = TRUE)
  n_fields <- utils::count.fields(con, sep = ",", quote = "\"")
  n_fields <- n_fields[!is.na(n_fields)]
  if (length(n_fields) == 0) {
    return(list(skip = 0, has_header = FALSE)) # nocov
  }

  # Modal field count, breaking ties towards the wider record.
  counts <- table(n_fields)
  width <- max(as.integer(names(counts)[counts == max(counts)]))
  skip <- match(width, n_fields) - 1L

  fields <- strsplit(lines[skip + 1L], ",", fixed = TRUE)[[1]]
  list(skip = skip, has_header = is_header_row(fields))
}

#' Is a row of fields a header rather than data?
#' @param fields Character vector of the row's fields.
#' @keywords internal
is_header_row <- function(fields) {
  fields <- trimws(fields)
  fields <- fields[nzchar(fields)]
  if (length(fields) == 0) {
    return(FALSE)
  }
  numeric_like <- !is.na(suppressWarnings(as.numeric(fields)))
  datetime_like <- !is.na(suppressWarnings(as.POSIXct(
    fields,
    format = "%Y-%m-%dT%H:%M:%OS"
  )))
  !any(numeric_like | datetime_like)
}

#' Detect whether a numeric clock is in microseconds
#'
#' @description
#' A device clock in microseconds ticks in the thousands between samples, so the
#' median positive step separates it from a clock already in seconds. Zero-length
#' steps (duplicated timestamps) and `NA`s are excluded: with enough repeats the
#' plain median is 0, microseconds are never detected, and the resulting time
#' groups explode.
#'
#' @param t Numeric timestamps.
#' @return `1e6` for a microsecond clock, otherwise `1`.
#' @keywords internal
detect_time_divisor <- function(t) {
  d <- diff(sort(as.numeric(t)))
  d <- d[is.finite(d) & d > 0]
  if (length(d) > 0 && stats::median(d) > 1000) 1e6 else 1
}

#' Join data files with non-matching time stamps
#'
#' @description
#' Bin both sensors onto a shared time grid. Expects time on the absolute scale
#' returned by [read_opticalflow()] - the offset between the two files is what
#' the shared window is derived from, so pre-zeroed input would collapse every
#' recording onto the same origin.
#'
#' @param data_list List of 2 dataframes
#' @param sampling_rate Sampling rate
#' @keywords internal
join_trackball_files <- function(data_list, sampling_rate) {
  ## Find shared time frame between both sensors
  highest_min_time <- max(c(min(data_list[[1]]$time), min(data_list[[2]]$time)))
  lowest_max_time <- min(c(max(data_list[[1]]$time), max(data_list[[2]]$time)))
  if (highest_min_time > lowest_max_time) {
    cli::cli_abort(c(
      "The two sensor recordings do not overlap in time.",
      "i" = "Sensor 1 spans {.val {max(data_list[[1]]$time) -
             min(data_list[[1]]$time)}} s and sensor 2 spans {.val
             {max(data_list[[2]]$time) - min(data_list[[2]]$time)}} s, but
             they share no window.",
      "i" = "Check that {.arg col_time} is a clock both sensors share."
    ))
  }

  # We use the provided sampling rate to create shared a shared time frame
  for (i in seq_along(data_list)) {
    data_list[[i]] <- data_list[[i]] |>
      dplyr::filter(
        .data$time >= highest_min_time & .data$time <= lowest_max_time
      ) |>
      dplyr::mutate(time = as.numeric(.data$time - highest_min_time)) |>
      dplyr::mutate(time_group = floor(.data$time * sampling_rate)) |>
      dplyr::group_by(.data$time_group) |>
      dplyr::summarise(
        x = sum(.data$dx),
        y = sum(.data$dy)
      )
  }

  # We then merge the two data frames
  data <- dplyr::full_join(
    data_list[[1]],
    data_list[[2]],
    by = "time_group",
    suffix = c("_1", "_2")
  ) |>
    dplyr::mutate(
      x_1 = dplyr::if_else(is.na(.data$x_1), 0, .data$x_1),
      x_2 = dplyr::if_else(is.na(.data$x_2), 0, .data$x_2),
      y_1 = dplyr::if_else(is.na(.data$y_1), 0, .data$y_1),
      y_2 = dplyr::if_else(is.na(.data$y_2), 0, .data$y_2)
    )

  # Some times do not have any sensor data, so we add those in with zeros
  fill_missing_time_groups(data, zero_cols = c("x_1", "x_2", "y_1", "y_2"))
}

#' Fill empty time bins with zero motion
#'
#' @description
#' The COM port emits no row while the ball is still, so binned data has holes.
#' Back-fill them with zeros so the returned time grid is regular. Used by both
#' the one- and two-sensor paths, which would otherwise disagree on the grid for
#' the same gappy input.
#'
#' @param data Binned data with a `time_group` column.
#' @param zero_cols Columns to set to zero in the inserted rows.
#' @keywords internal
fill_missing_time_groups <- function(data, zero_cols) {
  min_t <- min(data$time_group)
  max_t <- max(data$time_group)
  if (!is.finite(min_t) || !is.finite(max_t)) {
    cli::cli_abort(
      "Could not determine the time range; no finite time values were found."
    )
  }

  # A stalled clock, or a time column in the wrong unit, can imply a grid far
  # larger than memory. Fail with a diagnosis rather than exhausting the heap.
  n_bins <- max_t - min_t + 1
  max_bins <- 1e8
  if (n_bins > max_bins) {
    cli::cli_abort(c(
      "The time column implies {.val {n_bins}} time bins, which is
       implausibly many.",
      "i" = "Check that {.arg sampling_rate} matches the data and that
             {.arg col_time} is in seconds or a datetime."
    ))
  }

  full_t_seq <- seq(from = min_t, to = max_t, by = 1)
  missing_times <- dplyr::tibble(
    time_group = setdiff(full_t_seq, data$time_group)
  )
  for (col in zero_cols) {
    missing_times[[col]] <- 0
  }

  dplyr::bind_rows(data, missing_times) |>
    dplyr::arrange(.data$time_group)
}

#' @inheritParams read_trackball
#' @keywords internal
compute_xy_coordinates_free <- function(data) {
  data |>
    dplyr::rename(
      time = "time_group",
      dx = "y_1",
      dy = "y_2"
    ) |>
    dplyr::mutate(
      x = cumsum(.data$dx),
      y = cumsum(.data$dy)
    )
}

#' @inheritParams read_trackball
#' @keywords internal
compute_xy_coordinates_fixed <- function(
  data,
  n_sensors,
  counts_per_rotation,
  ball_diameter,
  dots_per_cm
) {
  if (n_sensors == 2) {
    data <- data |>
      dplyr::rename(time = "time_group") |>
      dplyr::mutate(
        sensor_dx = (.data$x_1 + .data$x_2) / 2,
        sensor_dy = .data$y_1
      )
  } else if (n_sensors == 1) {
    data <- data |>
      dplyr::rename(
        time = "time_group",
        sensor_dx = "x_1",
        sensor_dy = "y_1"
      )
  }

  # Compute angle from sensor reading
  if (!is.null(counts_per_rotation)) {
    data <- data |>
      dplyr::mutate(d_angle = (.data$sensor_dx / counts_per_rotation) * 2 * pi)
  } else if (!is.null(dots_per_cm) && !is.null(ball_diameter)) {
    data <- data |>
      dplyr::mutate(
        d_angle = (.data$sensor_dx / (ball_diameter * pi * dots_per_cm)) *
          2 *
          pi
      )
  } else {
    cli::cli_abort(
      "For {.arg setup} = 'of_fixed', provide either {.arg counts_per_rotation} or both {.arg ball_diameter} and {.arg dots_per_cm}."
    )
  }

  # Compute xy coordinates from angle and displacement
  data |>
    dplyr::mutate(
      dx = .data$sensor_dy * cos(.data$d_angle),
      dy = .data$sensor_dy * sin(.data$d_angle),
      x = cumsum(.data$dx),
      y = cumsum(.data$dy)
    )
}

#' Resolve column identifier to column name
#' @param data Data frame
#' @param col Column identifier (name or index)
#' @return Column name as character
#' @keywords internal
resolve_column <- function(data, col) {
  if (is.numeric(col)) {
    if (col < 1 || col > ncol(data)) {
      cli::cli_abort("Column index {col} is out of bounds (1-{ncol(data)}).")
    }
    return(names(data)[col])
  }
  if (!col %in% names(data)) {
    cli::cli_abort("Column {.val {col}} not found in data.")
  }
  col
}
