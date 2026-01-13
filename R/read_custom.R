#' Read a custom file format
#'
#' Reads a file and selects/renames specified columns to create an aniframe.
#'
#' @param path Character string specifying the path to the file to read.
#' @param cols A named vector specifying which columns to keep and how to rename
#'   them, e.g. `c(time = "time", x = "x", y = "y")`. Names should be the desired
#'   output column names, and values can be either the original column names (as
#'   characters) or column positions (as integers, e.g. `c(time = 1, x = 2, y = 3)`).
#' @param variables_what Character vector of identity columns that together
#'   define a unique entity. Uses aniframe defaults if NULL.
#' @param variables_when Character vector of temporal columns that together
#'   define a unique timepoint. Uses aniframe defaults if NULL.
#' @param variables_where Character vector of spatial columns that together
#'   define position. If NULL, detected from data.
#' @param metadata A list of metadata to attach to the resulting aniframe.
#'   Default is an empty list.
#'
#' @return An aniframe with the selected and renamed columns, and attached
#'   metadata.
#'
#' @examples
#' \dontrun{
#' # Simple case: rename columns to standard names, use defaults
#' read_custom("data.csv", cols = c(time = "frame", x = "pos_x", y = "pos_y"))
#'
#' # With identity variable
#' read_custom(
#'   "data.csv",
#'   cols = c(track = "track_id", time = "frame", x = "pos_x", y = "pos_y"),
#'   variables_what = "track"
#' )
#'
#' # Full specification with trials
#' read_custom(
#'   "data.csv",
#'   cols = c(
#'     id = "animal_id",
#'     trial = "trial_num",
#'     frame = "frame_idx",
#'     x = "x_coord",
#'     y = "y_coord"
#'   ),
#'   variables_what = "id",
#'   variables_when = c("trial", "frame")
#' )
#'
#' # Using column positions
#' read_custom("data.csv", cols = c(time = 1, x = 2, y = 3))
#' }
#' @export
read_custom <- function(
  path,
  cols,
  variables_what = NULL,
  variables_when = NULL,
  variables_where = NULL,
  metadata = list()
) {
  validate_files(path)

  data <- vroom::vroom(path, show_col_types = FALSE) |>
    suppressMessages()

  # Convert numeric column indices to column names
  if (is.numeric(cols)) {
    col_names <- names(data)[cols]
    cols <- stats::setNames(col_names, names(cols))
  }

  # Keep only the columns specified in cols (the values), and rename
  data <- data |>
    dplyr::select(dplyr::all_of(cols))

  # Make aniframe with specified variables
  data |>
    aniframe::as_aniframe(
      metadata = metadata,
      variables_what = variables_what,
      variables_when = variables_when,
      variables_where = variables_where
    )
}
