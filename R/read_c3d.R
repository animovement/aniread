#' Read a C3D motion capture file
#'
#' Reads a C3D file and returns the data as an aniframe with associated
#' metadata including source software, units, and sampling rate.
#'
#' @param path Path to a `.c3d` file.
#'
#' C3D numbers frames from 1, and a file's header records the frame of the
#' recording its first frame is, which is not frame 1 when the recording was
#' trimmed. `time` is in seconds from the first frame of the recording, so
#' a file that starts at frame 1 starts at `time = 0`, and one trimmed to
#' start at frame 705 of a 200 Hz recording starts at 3.52 s. A recording
#' longer than 65535 frames records its first frame in the `TRIAL` group's
#' `ACTUAL_START_FIELD` parameter instead, which is used when it is there.
#'
#' @return An aniframe with columns `time`, `keypoint`, `x`, `y`, and `z`.
#'   Metadata includes source software, filename, time/space units, and
#'   sampling rate. `time` is in seconds, with the first frame of the
#'   recording at 0; see "Time" in [read_dataset()].
#'
#' @seealso [c3dr::c3d_read()] for lower-level C3D access.
#'
#' @export
read_c3d <- function(path) {
  # Check c3dr is installed
  check_c3dr()

  # Validate files
  validate_files(path, expected_suffix = "c3d")

  # Read data
  all_data <- c3dr::c3d_read(path)

  data <- c3dr::c3d_data(all_data, format = "longest") |>
    tidyr::pivot_wider(
      values_from = "value",
      names_from = "type"
    ) |>
    dplyr::rename(keypoint = "point", time = "frame") |>
    anicore::as_anipoint() |>
    anicore::set_metadata(
      source = all_data$parameters$MANUFACTURER$SOFTWARE,
      source_version = paste(
        all_data$parameters$MANUFACTURER$VERSION,
        collapse = "."
      ),
      filename = basename(path),
      unit_time = "frame",
      unit_space = all_data$parameters$POINT$UNITS
    ) |>
    # c3dr numbers the file's frames from 1.
    dplyr::mutate(
      time = .data$time - 1 + c3d_first_frame(path, all_data$parameters)
    ) |>
    anicore::set_metadata(sampling_rate = all_data$header$framerate) |>
    anicore::convert_unit_time("s")

  data
}

#' The frame of the recording a C3D file starts at, counted from 0
#'
#' The header's fourth word is the number of the file's first frame in the
#' recording, counted from 1 (ezc3d, which c3dr reads with, says so, and
#' reads a 0 there as a file that counts from 0). It is a 16-bit word, so
#' a recording longer than 65535 frames keeps it in the `TRIAL` group's
#' `ACTUAL_START_FIELD` parameter, two 16-bit words, low word first, which
#' is used when the file has it.
#'
#' The header's integers are in the byte order of the processor type the
#' parameter section records in its fourth byte: 86 is big-endian (MIPS),
#' 84 (Intel) and 85 (DEC) are little-endian.
#'
#' @param path Path to the `.c3d` file.
#' @param parameters The `parameters` of the file as [c3dr::c3d_read()]
#'   returns them.
#' @return A single number, 0 for a file that starts at the start of the
#'   recording.
#' @noRd
c3d_first_frame <- function(path, parameters) {
  start <- parameters$TRIAL$ACTUAL_START_FIELD
  if (is.numeric(start) && length(start) == 2 && !anyNA(start)) {
    # Stored as signed words; read them as unsigned.
    start <- start %% 65536
    first <- start[[1]] + start[[2]] * 65536
  } else {
    header <- readBin(path, "raw", 512)
    parameter_block <- as.integer(header[[1]])
    processor <- readBin(path, "raw", 512 * parameter_block)[[
      512 * (parameter_block - 1) + 4
    ]]
    first <- readBin(
      header[7:8],
      "integer",
      size = 2,
      signed = FALSE,
      endian = if (as.integer(processor) == 86) "big" else "little"
    )
  }
  max(first - 1, 0)
}
