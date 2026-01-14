#' Read an aniframe from a Parquet file
#'
#' Reads movement data from a Parquet file and returns an aniframe object.
#' Parquet files are required as they preserve the metadata necessary for
#' aniframe objects.
#'
#' @param path Path to a Parquet file.
#'
#' @return An aniframe object.
#' @export
#'
#' @examples
#' \dontrun{
#' data <- read_aniframe("movement_data.parquet")
#' }
read_aniframe <- function(path) {
  # Check for the arrow package
  check_arrow()

  # Validate file
  validate_files(path)

  # Check file extension
  if (!grepl("\\.parquet$", path, ignore.case = TRUE)) {
    cli::cli_abort(
      c(
        "File must be a Parquet file.",
        "x" = "Got file with extension {.file {tools::file_ext(path)}}.",
        "i" = "CSV files are not supported as they do not preserve metadata. Use `read_custom` for other file formats."
      )
    )
  }

  # Read file
  data <- arrow::read_parquet(path)

  # Check for aniframe metadata (class is stripped by arrow, but metadata survives)
  if (is.null(attr(data, "metadata"))) {
    cli::cli_abort(
      c(
        "File does not contain a valid aniframe.",
        "i" = "No aniframe metadata found in the file."
      )
    )
  }

  # Restore the aniframe class (arrow strips custom classes)
  class(data) <- c("aniframe", class(data))

  data
}
