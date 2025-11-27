#' @keywords internal
.get_file_ext <- function(filename) {
  nameSplit <- strsplit(x = filename, split = "\\.")[[1]]
  return(nameSplit[length(nameSplit)])
}

#' @keywords internal
.is.POSIXt <- function(x) {
  inherits(x, "POSIXt")
}

#' @keywords internal
.scale_values <- function(data, variables, scaling_factor) {
  # Adjust distances for mouse sensor "dots-per-cm"
  if (!is.null(scaling_factor)) {
    data <- data |>
      dplyr::mutate(dplyr::across(
        dplyr::all_of(variables),
        ~ .x / scaling_factor
      ))
  }
}

#' @keywords internal
convert_nan_to_na <- function(data) {
  dplyr::mutate(
    data,
    dplyr::across(dplyr::where(is.numeric), function(x) {
      ifelse(is.nan(x), NA, x)
    })
  )
}

# For TRex files
#' @keywords internal
get_individual_from_path <- function(path) {
  strsplit(tools::file_path_sans_ext(basename(path)), "_(?!.*_)", perl = TRUE)[[
    1
  ]]
}
