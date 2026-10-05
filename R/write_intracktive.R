#' Write aniframe data to inTRACKtive CSV format
#'
#' Converts an aniframe to the CSV format required by inTRACKtive for
#' browser-based interactive visualization of tracking data. The function
#' creates unique integer track identifiers from combinations of the
#' aniframe's identity keys, and writes the lineage of dividing tracks.
#'
#' @param data An aniframe containing tracking data with required columns
#'   `time`, `x`, and `y`. Optional columns are `z` for 3D data and `parent`
#'   for lineage (see Details).
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
#' - `t`: Time values (renamed from `time`)
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
#' inTRACKtive reads `t` as whole frames counted from 0. `time` is written as
#' it is, so a frame whose time is in seconds or minutes should be converted
#' to frames first.
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

  # Create track_id from the combination of keys
  intracktive_data <- as.data.frame(data) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::mutate(track_id = dplyr::cur_group_id()) |>
    dplyr::ungroup()

  has_parent <- "parent" %in% names(intracktive_data)
  if (has_parent) {
    intracktive_data <- add_parent_track_id(intracktive_data, keys)
  }

  intracktive_data <- intracktive_data |>
    dplyr::rename(t = "time") |>
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
