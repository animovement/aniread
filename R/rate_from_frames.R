#' The sampling rate a frame number and a time in seconds agree on
#'
#' Some exports carry a frame number and a time in seconds for every row, but
#' no frame rate. When every time is the frame number divided by one rate, to
#' within the rounding of the time column, that rate is what the file states.
#'
#' The rate is taken from the span, the frames between the first and last row
#' over the seconds between them, since the interval between two adjacent rows
#' carries the whole rounding error of the time column. A whole number of
#' frames per second is used when it fits every row as well: a 28 fps
#' recording with times rounded to 1 ms has a span rate of 28.0002, which is
#' the same recording described less exactly.
#'
#' The times must also fit the rate: each must lie within one rounding step
#' of where the rate puts it (half a step for its own rounding, half for the
#' first row's). Times that jitter by more, such as software timestamps,
#' state no single rate, and the rate is `NA`.
#'
#' The rounding step is read from the times: the coarsest of 1, 0.1, ...,
#' 1e-6 s that every time is a multiple of, and 1e-6 s when none is.
#'
#' @param frame,time Numeric vectors, one value per row. Rows may repeat a
#'   frame, as when it holds several individuals.
#'
#' @return The rate of the rows in Hz: the frame rate, divided by the step
#'   between frames when only every k-th frame was kept. `NA` when there are
#'   fewer than two frames or the times do not follow one rate.
#' @noRd
rate_from_frames <- function(frame, time) {
  keep <- is.finite(frame) & is.finite(time)
  frame <- frame[keep]
  time <- time[keep]
  frames <- sort(unique(frame))
  if (length(frames) < 2) {
    return(NA_real_)
  }

  first <- which.min(frame)
  last <- which.max(frame)
  time_span <- time[[last]] - time[[first]]
  if (time_span <= 0) {
    return(NA_real_)
  }

  tolerance <- time_resolution(time) + sqrt(.Machine$double.eps)
  fits <- function(rate) {
    expected <- time[[first]] + (frame - frame[[first]]) / rate
    all(abs(time - expected) <= tolerance)
  }

  frame_rate <- (frame[[last]] - frame[[first]]) / time_span
  whole <- round(frame_rate)
  if (whole >= 1 && fits(whole)) {
    frame_rate <- whole
  } else if (!fits(frame_rate)) {
    return(NA_real_)
  }

  frame_rate / min(diff(frames))
}

#' The step a time column is rounded to
#'
#' @param time A numeric vector without missing values.
#'
#' @return The coarsest of 1, 0.1, ..., 1e-6 that every value is a multiple
#'   of, or 1e-6 when none is.
#' @noRd
time_resolution <- function(time) {
  for (digits in 0:5) {
    scaled <- time * 10^digits
    if (all(abs(scaled - round(scaled)) < 1e-6)) {
      return(10^-digits)
    }
  }
  1e-6
}
