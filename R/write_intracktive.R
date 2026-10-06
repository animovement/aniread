#' Write aniframe data to inTRACKtive CSV format
#'
#' Converts an aniframe to the CSV format required by inTRACKtive for
#' browser-based interactive visualization of tracking data. The function
#' creates unique integer track identifiers from combinations of the
#' aniframe's identity keys, and writes the lineage of dividing tracks.
#'
#' @param data An aniframe containing tracking data with its index (usually
#'   `time`) and `x` and `y`. Optional columns are `z` for 3D data, `parent`
#'   for lineage and `frame` for recorded frame numbers (see Details).
#' @param filename File path to write the CSV.
#' @param quiet Suppress messages. TRUE/FALSE. Defaults to FALSE.
#'
#' @details
#' inTRACKtive requires tracking data with a unique integer `track_id` for each
#' tracked object. This function numbers the tracks from 1, one for each
#' combination of the aniframe's identity keys ([anicore::get_keys()]), such
#' as `individual` and `keypoint`, or `track` and `keypoint` for a frame read
#' by [read_trackmate()].
#'
#' The output format includes:
#' - `track_id`: Integer identifier for each unique track
#' - `t`: The frame number of each row, counted from 0 (see below)
#' - `x`, `y`: Spatial coordinates
#' - `z`: Optional third dimension if present
#' - `parent_track_id`: Only when `data` has a `parent` column, as
#'   [read_trackmate()] gives a frame with dividing tracks. `parent` names the
#'   `track` a track divided from, and `parent_track_id` is that track's
#'   `track_id` (with the same values of the other keys), so inTRACKtive draws
#'   the lineage. A track with no parent gets `-1`, inTRACKtive's value for
#'   one, as does a track whose parent is not in `data` (with a warning).
#'   Without a `parent` column the column is left out, which inTRACKtive
#'   reads as no divisions.
#'
#' inTRACKtive reads `t` as whole frames counted from 0, so the index is
#' written in frames, as [anicore::convert_unit_time()] gives them with
#' `"frame"`:
#' - A frame whose `unit_time` is `"frame"` is written as it is. Its times must
#'   be whole numbers.
#' - A frame whose time is in another unit, such as seconds or minutes, is
#'   converted to frames with its `sampling_rate`, so that the frame at time 0
#'   is `t = 0`: at 30 Hz, times of 0, 1/30 and 2/30 seconds are written as 0,
#'   1 and 2. A frame with a column named `frame` holding the recorded frame
#'   numbers, as [anicore::set_index()] keeps them, is written with those.
#'
#' The writer stops rather than write frame numbers it would have to invent:
#' when the time is not in frames and no `sampling_rate` is declared, or when
#' the times are not regularly spaced at that rate. Declare the rate with
#' `anicore::set_metadata(data, sampling_rate = )`, or keep the recorded frame
#' numbers in a column named `frame`. `data` itself is not changed.
#'
#' The resulting CSV can be converted to inTRACKtive's Zarr format using their
#' command-line tools or Python package.
#'
#' @return Returns the input data unchanged.
#'
#' @references
#' Huijben, T.A.P.M., Anderson, A.G., Sweet, A. et al. (2025). inTRACKtive: a
#' web-based tool for interactive cell tracking visualization. Nature Methods.
#'
#' @examples
#' \dontrun{
#' # Write aniframe to inTRACKtive CSV
#' write_intracktive(my_data, "tracks.csv")
#'
#' # Get formatted data without writing
#' formatted <- write_intracktive(my_data)
#' }
#'
#' @export
write_intracktive <- function(data, filename, quiet = FALSE) {
  # A track is one combination of the frame's identity keys
  keys <- if (anicore::is_aniframe(data)) anicore::get_keys(data)
  keys <- keys[keys %in% names(data)]

  if (length(keys) == 0) {
    cli::cli_abort(c(
      "No grouping columns found.",
      "i" = "Tracks are numbered by the identity keys of an aniframe
             ({.fun anicore::get_keys}), and {.arg data} declares none."
    ))
  }

  # inTRACKtive's `t` is the frame number
  frames <- intracktive_frames(data)
  index <- anicore::get_index(frames)

  # Create track_id from the combination of keys
  intracktive_data <- as.data.frame(frames) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::mutate(track_id = dplyr::cur_group_id()) |>
    dplyr::ungroup()

  has_parent <- "parent" %in% names(intracktive_data)
  if (has_parent) {
    intracktive_data <- add_parent_track_id(intracktive_data, keys)
  }

  intracktive_data <- intracktive_data |>
    dplyr::rename(t = dplyr::all_of(index)) |>
    dplyr::select(
      "track_id",
      "t",
      "x",
      "y",
      dplyr::any_of(c("z", "parent_track_id"))
    )

  # Write to CSV
  vroom::vroom_write(intracktive_data, filename, delim = ",")
  if (quiet == FALSE) {
    cli::cli_alert_success("Wrote inTRACKtive CSV to {.path {filename}}")
  }

  invisible(data)
}

#' The frame indexed by frame numbers, as inTRACKtive's `t` needs
#'
#' A frame in frames is checked for whole numbers; any other is converted
#' with [anicore::convert_unit_time()], whose errors explain an irregular
#' sampling or a missing rate.
#'
#' @param data An aniframe.
#' @param call The caller's environment, for the error.
#'
#' @return `data`, with its index in whole frames.
#' @noRd
intracktive_frames <- function(data, call = rlang::caller_env()) {
  unit <- as.character(anicore::get_metadata(data, "unit_time"))

  if (!identical(unit, "frame")) {
    return(rlang::try_fetch(
      anicore::convert_unit_time(data, "frame"),
      error = function(cnd) {
        cli::cli_abort(
          c(
            "Cannot write the time, in {.val {unit}}, as inTRACKtive's frame numbers.",
            "i" = "inTRACKtive reads {.field t} as whole frames counted from 0.",
            "i" = "Declare the frame rate with
                   {.code anicore::set_metadata(data, sampling_rate = )}, or
                   keep the recorded frame numbers in a column named
                   {.field frame}."
          ),
          parent = cnd,
          call = call
        )
      }
    ))
  }

  index <- anicore::get_index(data)
  time <- data[[index]]
  partial <- !is.na(time) & time != round(time)
  if (any(partial)) {
    cli::cli_abort(
      c(
        "Cannot write {.field {index}} as inTRACKtive's frame numbers.",
        "x" = "{.field {index}} is in frames but has values that are not
               whole, such as {.val {unique(time[partial])[1]}}.",
        "i" = "inTRACKtive reads {.field t} as whole frames counted from 0.
               Declare the unit {.field {index}} is in with
               {.code anicore::set_metadata(data, unit_time = )}, and its
               {.field sampling_rate}, to convert it to frames."
      ),
      call = call
    )
  }
  data
}

#' Map each track's parent to the parent's inTRACKtive track id
#'
#' `parent` names the `track` a track divided from. Its `track_id` is that of
#' the track with that name and the same values of every other key, so a
#' keypoint's lineage stays within that keypoint.
#'
#' @param data A data frame with `track_id`, `parent` and the columns `keys`.
#' @param keys The identity keys `track_id` numbers.
#'
#' @return `data` with `parent_track_id`: the parent's `track_id`, or `-1`
#'   (inTRACKtive's value for no parent) for a root or a parent not in `data`.
#' @noRd
add_parent_track_id <- function(data, keys) {
  if (!"track" %in% keys) {
    cli::cli_abort(c(
      "{.arg data} has a {.field parent} column but no {.field track} key.",
      "i" = "{.field parent} names the {.field track} a track divided from."
    ))
  }

  others <- setdiff(keys, "track")
  parents <- data |>
    dplyr::distinct(
      dplyr::across(dplyr::all_of(others)),
      parent = as.character(.data$track),
      parent_track_id = .data$track_id
    )

  data <- data |>
    dplyr::mutate(parent = as.character(.data$parent)) |>
    dplyr::left_join(parents, by = c(others, "parent"))

  missing <- !is.na(data$parent) & is.na(data$parent_track_id)
  if (any(missing)) {
    cli::cli_warn(c(
      "Some parents are not tracks in {.arg data}.",
      "i" = "Writing {.val {-1}} as the parent of
             {.val {unique(as.character(data$track[missing]))}}, whose parent
             {cli::qty(length(unique(data$parent[missing])))}track{?s}
             {.val {unique(data$parent[missing])}} {?is/are} missing."
    ))
  }

  data |>
    dplyr::mutate(
      parent_track_id = dplyr::coalesce(.data$parent_track_id, -1L)
    )
}
