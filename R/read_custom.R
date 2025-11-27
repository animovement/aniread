#' Read a custom file format
#'
#' Reads a file and selects/renames specified columns to create an aniframe.
#'
#' @param path Character string specifying the path to the file to read.
#' @param cols A named vector specifying which columns to keep and how to rename
#'   them, e.g. `c(time = "time", x = "x", y = "y")`. Names should be the desired
#'   output column names, and values can be either the original column names (as
#'   characters) or column positions (as integers, e.g. `c(time = 1, x = 2, y = 3)`).
#'   .
#' @param metadata A list of metadata to attach to the resulting aniframe.
#'   Default is an empty list. To see which metadata fields can be set, see aniframe::default_metadata().
#'
#' @return An aniframe with the selected and renamed columns, and attached
#'   metadata.
#'
#' @examples
#' \dontrun{
#' # Using column names
#' read_custom("data.csv", cols = c(time = "frame", x = "pos_x", y = "pos_y"))
#'
#' # Using column positions
#' read_custom("data.csv", cols = c(time = 1, x = 2, y = 3))
#' }
#' @export
read_custom <- function(path, cols, metadata = list()) {
  # Validate input file
  validate_files(path)

  data <- vroom::vroom(path, show_col_types = FALSE) |>
    suppressMessages()

  # Convert numeric column indices to column names
  if (is.numeric(cols)) {
    col_names <- names(data)[cols]
    cols <- stats::setNames(col_names, names(cols))
  }

  # Keep only the columns specified in cols (the values), and change the names
  data <- data |>
    dplyr::select(dplyr::all_of(cols))

  # Make aniframe
  data <- data |>
    aniframe::as_aniframe() |>
    aniframe::set_metadata(metadata = metadata)

  data
}
