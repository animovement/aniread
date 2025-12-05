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
  quiet = TRUE
) {
  validate_files(paths, expected_suffix = "csv") #expected_headers = c("x", "y", "time")
  #validate_trackball(paths, setup, col_time)
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
      paths[i],
      col_time = col_time,
      col_dx = col_dx,
      col_dy = col_dy
    )
  }

  # Calculate coordinates (free/fixed)
  if (setup == "of_free") {
    data <- data |>
      compute_xy_coordinates_free()
  } else if (setup == "of_fixed") {
    data <- data |>
      compute_xy_coordinates_fixed(n_sensors)
  }

  # Scale distance and time and select output columns
  data <- data |>
    dplyr::mutate(keypoint = "centroid") |>
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
  if (does_file_have_expected_headers(path, c(col_time, col_dx, col_dy))) {
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
      show_col_types = TRUE,
      .name_repair = "unique"
    ) |>
      suppressMessages()
  }

  # Change column names
  data <- data |>
    dplyr::rename("dx" := dplyr::all_of(col_dx)) |>
    dplyr::rename("dy" := dplyr::all_of(col_dy)) |>
    dplyr::rename("time" := dplyr::all_of(col_time))

  # If time is a datetime stamp, convert it into seconds from start
  # NEEDS TO GO INTO THE TIME VALIDATOR
  if (is.character(data$time)) {
    data <- data |>
      dplyr::mutate(
        time = as.numeric(as.POSIXct(.data$time)),
        time = .data$time - min(.data$time)
      )
  } else {
    med_diff <- median(diff(sort(data$time)))
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
    dplyr::filter(.data$time > highest_min_time & .data$time < lowest_max_time)
  data_list[[2]] <- data_list[[2]] |>
    dplyr::filter(.data$time > highest_min_time & .data$time < lowest_max_time)

  # We use the provided sampling rate to create shared a shared time frame
  data_list[[1]] <- data_list[[1]] |>
    dplyr::mutate(time = as.numeric(.data$time - highest_min_time)) |>
    dplyr::filter(.data$time > 0) |>
    dplyr::mutate(time_group = floor(.data$time * sampling_rate)) |>
    dplyr::group_by(.data$time_group) |>
    dplyr::summarise(
      x = sum(.data$dx),
      y = sum(.data$dy)
    )
  data_list[[2]] <- data_list[[2]] |>
    dplyr::mutate(time = as.numeric(.data$time - highest_min_time)) |>
    dplyr::filter(.data$time > 0) |>
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
  # Convert time back to seconds
  data <- data |>
    dplyr::rename(
      time = "time_group",
      dx = "y_1",
      dy = "y_2"
    )

  data <- data |>
    dplyr::mutate(
      x = cumsum(.data$dx),
      y = cumsum(.data$dy)
    )
  return(data)
}

#' @inheritParams read_trackball
#' @keywords internal
compute_xy_coordinates_fixed <- function(
  data,
  n_sensors
) {
  if (n_sensors == 2) {
    data <- data |>
      dplyr::rename(time = "time_group") |>
      dplyr::mutate(
        sensor_dx = mean(c(.data$x_1, .data$x_2)), # Takes the mean of the x reading on both sensors
        sensor_dy = .data$y_1
      )
  } else if (n_sensors == 1) {
    data <- data |>
      dplyr::rename(
        time = "time_group",
        sensor_dx = .data$x_1,
        sensor_dy = .data$y_1
      )
  }

  # Compute the xy coordinates by calculating the angle turned and displacement in every bin
  data <- data |>
    dplyr::mutate(
      d_angle = .data$sensor_dx * 2 * pi, # in radians
      dx = .data$sensor_dy * cos(.data$d_angle),
      dy = .data$sensor_dy * sin(.data$d_angle)
    ) |>
    dplyr::mutate(
      x = cumsum(.data$dx),
      y = cumsum(.data$dy)
    )

  data
}
