#' Read trackball data
#'
#' Read trackball data from a variety of setups and configurations.
#'
#' @param paths Two file paths, one for each sensor (although one is allowed for a fixed setup, `of_fixed`).
#' @param setup Which type of experimental setup was used. Expects either `of_free` or `of_fixed`.
#' @param sampling_rate Sampling rate tells the function how long time it should integrate over. A sampling rate of 60(Hz) will mean windows of 1/60 sec are used to integrate over.
#' @param col_time Which column contains the information about time. Can be specified either by the column number (numeric) or the name of the column if it has one (character). Should either be a datetime (POSIXt) or seconds (numeric).
#' @param col_dx Column name for x-axis values
#' @param col_dy Column name for y-axis values
#' @param counts_per_rotation For `of_fixed` setup: the sensor count for a full 360 degree rotation. Can be obtained using `calibrate_trackball()`.
#' @param ball_diameter For `of_fixed` setup: the ball diameter (in same units as desired output). Required if using `dots_per_cm` instead of `counts_per_rotation`.
#' @param dots_per_cm For `of_fixed` setup: sensor dots-per-cm. Use with `ball_diameter` as an alternative to `counts_per_rotation`.
#' @param quiet If `TRUE` (default), suppresses most warning messages.
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
  validate_files(paths, expected_suffix = "csv")
  n_sensors <- length(paths)

  # Read data
  if (n_sensors == 2) {
    data_list <- list()
    for (i in 1:n_sensors) {
      data_list[[i]] <- read_opticalflow(
        paths[i],
        col_time = col_time,
        col_dx = col_dx,
        col_dy = col_dy
      ) |>
        dplyr::mutate(sensor_n = i)
    }
    data <- join_trackball_files(data_list, sampling_rate = sampling_rate)
  } else {
    data <- read_opticalflow(
      paths,
      col_time = col_time,
      col_dx = col_dx,
      col_dy = col_dy
    ) |>
      dplyr::mutate(time_group = floor(.data$time * sampling_rate)) |>
      dplyr::group_by(.data$time_group) |>
      dplyr::summarise(
        x_1 = sum(.data$dx),
        y_1 = sum(.data$dy)
      )
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
      sampling_rate = sampling_rate
    )

  return(data)
}

#' Read optical flow sensor file
#' @description Read optical flow sensor data.
#' @param path Path to the file.
#' @inheritParams read_trackball
#' @keywords internal
read_opticalflow <- function(path, col_time, col_dx, col_dy, quiet = TRUE) {
  # Read file
  if (
    is.character(col_time) &&
      is.character(col_dx) &&
      is.character(col_dy) &&
      does_file_have_expected_headers(path, c(col_time, col_dx, col_dy))
  ) {
    data <- vroom::vroom(
      path,
      delim = ",",
      show_col_types = FALSE
    ) |>
      suppressMessages()
  } else {
    data <- vroom::vroom(
      path,
      skip = 2,
      delim = ",",
      show_col_types = FALSE,
      .name_repair = "unique"
    ) |>
      suppressMessages()
  }

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
    )

  # If time is a datetime stamp, convert it into seconds from start
  if (inherits(data$time, "POSIXt")) {
    data <- data |>
      dplyr::mutate(
        time = as.numeric(.data$time),
        time = .data$time - min(.data$time)
      )
  } else if (is.character(data$time)) {
    data <- data |>
      dplyr::mutate(
        time = as.numeric(as.POSIXct(.data$time)),
        time = .data$time - min(.data$time)
      )
  } else {
    med_diff <- stats::median(diff(sort(data$time)))
    divisor <- if (med_diff > 1000) 1e6 else 1

    data <- data |>
      dplyr::mutate(
        time = (as.numeric(.data$time) - min(as.numeric(.data$time))) / divisor
      )
  }
  return(data)
}

#' Join data files with non-matching time stamps
#' @description Join data files with non-matching time stamps
#' @param data_list List of 2 dataframes
#' @param sampling_rate Sampling rate
#' @keywords internal
join_trackball_files <- function(data_list, sampling_rate) {
  ## Find shared time frame between both sensors
  highest_min_time <- max(c(min(data_list[[1]]$time), min(data_list[[2]]$time)))
  lowest_max_time <- min(c(max(data_list[[1]]$time), max(data_list[[2]]$time)))
  data_list[[1]] <- data_list[[1]] |>
    dplyr::filter(
      .data$time >= highest_min_time & .data$time <= lowest_max_time
    )
  data_list[[2]] <- data_list[[2]] |>
    dplyr::filter(
      .data$time >= highest_min_time & .data$time <= lowest_max_time
    )

  # We use the provided sampling rate to create shared a shared time frame
  data_list[[1]] <- data_list[[1]] |>
    dplyr::mutate(time = as.numeric(.data$time - highest_min_time)) |>
    dplyr::mutate(time_group = floor(.data$time * sampling_rate)) |>
    dplyr::group_by(.data$time_group) |>
    dplyr::summarise(
      x = sum(.data$dx),
      y = sum(.data$dy)
    )
  data_list[[2]] <- data_list[[2]] |>
    dplyr::mutate(time = as.numeric(.data$time - highest_min_time)) |>
    dplyr::mutate(time_group = floor(.data$time * sampling_rate)) |>
    dplyr::group_by(.data$time_group) |>
    dplyr::summarise(
      x = sum(.data$dx),
      y = sum(.data$dy)
    )

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
  min_t <- min(data$time_group)
  max_t <- max(data$time_group)
  full_t_seq <- seq(from = min_t, to = max_t, by = 1)
  missing_times <- dplyr::tibble(
    time_group = setdiff(full_t_seq, data$time_group),
    x_1 = 0,
    x_2 = 0,
    y_1 = 0,
    y_2 = 0
  )

  data <- dplyr::bind_rows(data, missing_times) |>
    dplyr::arrange(.data$time_group)
  return(data)
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
