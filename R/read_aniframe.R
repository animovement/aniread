#' Read an aniframe from a Parquet file
#'
#' Reads movement data from a Parquet file and returns an aniframe object.
#' Parquet files are required as they preserve the metadata necessary for
#' aniframe objects.
#'
#' @param path Path to a Parquet file.
#'
#' @return An anipoint, or an anievent if that is what was written.
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

  # Arrow strips the class but keeps the attribute, so presence is all there is to test.
  stored <- attr(data, "metadata") # anicore: allow-metadata
  if (is.null(stored)) {
    cli::cli_abort(
      c(
        "File does not contain a valid aniframe.",
        "i" = "No aniframe metadata found in the file."
      )
    )
  }

  # arrow keeps the class of an ungrouped frame but strips it from a grouped one
  if (!anicore::is_aniframe(data)) {
    class(data) <- c("aniframe", class(data))
    interval <- anicore::get_metadata(data, "variables")$when$interval
    class(data) <- c(
      if (is.null(interval)) "anipoint" else "anievent",
      class(data)
    )
  }

  data
}
