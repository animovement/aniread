#' Read an aniframe from a Parquet file
#'
#' Reads movement data from a Parquet file and returns an aniframe object.
#' Parquet files are required as they preserve the metadata necessary for
#' aniframe objects.
#'
#' @param path Path to a Parquet file.
#'
#' @return The aniframe that was written, with its class: an anipoint, an
#'   anievent, or another frame built on them, such as an anijoint. `time` is
#'   as it was written; see "Time" in [read_dataset()].
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
  table <- arrow::read_parquet(path, as_data_frame = FALSE)
  key <- read_animovement_key(table$metadata[[ANIMOVEMENT_KEY]])
  data <- dplyr::collect(table)

  if (!is.null(key$metadata)) {
    return(rebuild_aniframe(data, key))
  }

  # Written before the metadata moved to our key: arrow restores it from "r",
  # so presence is all there is to test.
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
    subclass <- if (!is.null(key$class)) {
      unlist(key$class)
    } else {
      # Written before the class was recorded: tell the two apart by metadata
      interval <- anicore::get_metadata(data, "variables")$when$interval
      if (is.null(interval)) "anipoint" else "anievent"
    }
    class(data) <- c(subclass, class(data))
  }

  data
}

#' Parse animovement's Parquet metadata key
#' @param json The key's value, or `NULL` when the file has none.
#' @return A list, empty when there is no key, parsed without simplifying so
#'   [anicore::set_metadata_json()] can tell an empty array from an empty
#'   object.
#' @keywords internal
read_animovement_key <- function(json) {
  if (is.null(json)) {
    return(list())
  }
  rlang::check_installed(
    "jsonlite",
    reason = "to read the aniframe's metadata from a Parquet file."
  )
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

#' Rebuild an aniframe from its table and animovement's key
#'
#' arrow restores the table with its grouping and base class; the aniframe
#' classes and the metadata come from the key.
#'
#' @param data The table arrow read.
#' @param key The parsed key, with `class` and `metadata`.
#' @return The aniframe.
#' @keywords internal
rebuild_aniframe <- function(data, key) {
  class(data) <- c(unlist(key$class), "aniframe", class(data))
  anicore::set_metadata_json(data, key$metadata)
}
