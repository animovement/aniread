#' Read a movement or event dataset from any supported format
#'
#' @description
#' One entry point for every format `aniread` supports. By default the source
#' software is worked out from the file itself, so you do not have to know
#' which reader a file needs before opening it.
#'
#' @param paths Path to the file to read. A few readers take more than one
#'   path - [read_trackball()] takes one per sensor - in which case pass them
#'   all; detection inspects the first.
#' @param source Which source software wrote the file. `"auto"` (the default)
#'   detects it with [detect_source()]. Otherwise one of the names in
#'   [get_supported_sources()].
#' @param ... Passed on to the reader for `source`. This is how arguments that
#'   only some readers take are supplied, e.g. `sampling_rate` for
#'   [read_trackball()] or `path_probabilities` for [read_idtracker()].
#'
#' @details
#' `read_dataset()` is a dispatcher, not a new reader: it works out which
#' reader to call and calls it. The object you get back is exactly what the
#' underlying reader returns - an [anipoint][anicore::anipoint] for tracking
#' data, or an [anievent][anicore::anievent] for behavioural events from
#' [read_boris()].
#'
#' DeepLabCut and LightningPose CSV exports are structurally identical, so a
#' file in that format cannot be attributed to one or the other. Such a file is
#' read with [read_deeplabcut()] - the parse is the same either way - and its
#' `source` metadata is set to `"deeplabcut/lightningpose"` to record that the
#' distinction is undetermined. Pass `source` explicitly to override this.
#'
#' @section Time:
#' Every reader gives `time` as the time elapsed since the first frame of the
#' video, so the first frame of the video is at `time = 0`, whatever the unit
#' ([#150](https://github.com/animovement/aniread/issues/150)):
#'
#' * In frames, `time` is the frame number counted from 0: the first frame of
#'   the video is 0, the next 1, and so on. Converting to seconds is then a
#'   division by the frame rate, with no offset.
#' * In seconds, the first frame of the video is at 0 s.
#' * Offsets are kept. A file whose first row is frame 500 of the video has
#'   `time = 500` there, not 0, so it stays aligned with the video.
#'
#' Sources that count frames from 0 are read as they are. Sources that count
#' them from 1 are shifted by one. Where a source gives times in seconds,
#' they are kept. The table lists each source's own convention, what
#' `time` was before aniread 0.8.0 and what it is now. Sources not marked as
#' changed read as before.
#'
#' | Source (reader) | The source's own time | `time` before | `time` now |
#' |---|---|---|---|
#' | aniframe ([read_aniframe()]) | As written by [write_aniframe()] | As written | Unchanged |
#' | AnimalTA ([read_animalta()]) | `Frame` counts the video's frames from 0, keeping a cropped start; `Time` is the frame over the frame rate, in s | `Time` in s; a detailed file without `Time` in frames, from its `Frame` | Unchanged |
#' | Anipose ([read_anipose()]) | `fnum` counts frames from 0 | `fnum` | Unchanged |
#' | Bonsai ([read_bonsai()]) | A clock time per row, set by the workflow; no frame number | Seconds from the first row | Unchanged |
#' | BORIS ([read_boris()]) | `Start (s)`/`Stop (s)` are media time in s. The image index counts a video's frames from 0 (mpv's frame number), and the images of an observation of images from 1 | In s, or the image index as written | In s unchanged; in frames, an observation of images is **shifted by 1** so its first image is 0, and a video's frames are unchanged |
#' | C3D ([read_c3d()]) | Frames count from 1; the header records the recording frame the file starts at | Seconds from the file's first frame, which was always 0 | **Seconds from the recording's first frame**: 0 for a file that starts at frame 1, `(first frame - 1) / rate` for a trimmed one |
#' | DeepLabCut ([read_deeplabcut()]) | The row index counts frames from 0 | The index | Unchanged |
#' | FastTrack ([read_fasttrack()]) | `imageNumber` is the video's frame, from 0 | `imageNumber` | Unchanged |
#' | FicTrac ([read_fictrac()]) | A clock time per row, in ms | Seconds from the first row | Unchanged |
#' | FreeMoCap ([read_freemocap()]) | `frame` counts from 0, or the row is the frame; v1 also writes timestamps | Seconds from the first frame's timestamp, or the frame from 0 | Unchanged |
#' | idtracker.ai `.h5` ([read_idtracker()]) | Rows are the video's frames, from 0 | The row, counted from 1 | **The frame, from 0** |
#' | idtracker.ai CSV, with a time column | `time` (or `seconds`) is the frame over the frame rate, in s | The time in s | Unchanged |
#' | idtracker.ai CSV, without a time column | Rows are the video's frames, from 0 | The row, counted from 1 | **The frame, from 0** |
#' | idtracker.ai tidy CSV and Parquet | `frame` counts from 0; `time` is the frame over the frame rate, or over 1 when the rate is unknown | The time in s, or the frame + 1 | In s unchanged; **without a rate, the frame, from 0** |
#' | Lightning Pose ([read_lightningpose()]) | The row index counts frames from 0 | The index | Unchanged |
#' | movement ([read_movement()]) | The `time` coordinate: frames from 0, or the frame over the frame rate in s | As written | Unchanged |
#' | OCTRON ([read_octron()]) | `frame_idx` is the video's frame, from 0 | `frame_idx` | Unchanged |
#' | SLEAP `.h5` ([read_sleap()]) | The frame axis starts at `frame_idx` 0 | The position on the axis, counted from 1 | **`frame_idx`, from 0** |
#' | SLEAP CSV | `frame_idx` counts from 0 | `frame_idx + 1` | **`frame_idx`** |
#' | Trackball ([read_trackball()]) | Sensor samples with a clock or counter; no video | Seconds from the first shared sample | Unchanged |
#' | TrackMate ([read_trackmate()]) | `FRAME` counts from 0; `POSITION_T` is the frame times the frame interval | `POSITION_T` | Unchanged |
#' | TRex ([read_trex()]) | `frame` counts from 0; `time` is in s, 0 at frame 0 | `time` | Unchanged |
#' | [read_custom()] | Whatever the file holds | As in the file | Unchanged |
#'
#' Where a source keeps only clock times (Bonsai, FicTrac, the FreeMoCap v1
#' timestamps), nothing in the file marks the first frame of the video, so
#' the first row is taken as 0. That is the first frame the tool logged:
#' FicTrac writes no row for a frame it could not match, so if it lost its
#' first frames, 0 is the first one it matched. A SLEAP `.h5` written without its leading untracked frames
#' (sleap-io's `all_frames = FALSE`) does not record where it starts, so its
#' first row reads as frame 0.
#'
#' @return An [anipoint][anicore::anipoint] or
#'   [anievent][anicore::anievent], depending on the reader. `time` (or an
#'   event's `start` and `stop`) follows the convention in the Time section.
#'
#' @seealso [detect_source()] to detect the format without reading,
#'   [get_supported_sources()] for what is supported, and the individual
#'   `read_*()` functions for format-specific arguments.
#'
#' @examples
#' \dontrun{
#' # Let aniread work out the format
#' data <- read_dataset("mouse.h5")
#'
#' # Name it explicitly
#' data <- read_dataset("mouse.h5", source = "sleap")
#'
#' # Reader-specific arguments pass straight through
#' data <- read_dataset(
#'   c("sensor1.csv", "sensor2.csv"),
#'   sampling_rate = 60,
#'   col_time = 4,
#'   col_dx = 1,
#'   col_dy = 2
#' )
#' }
#' @export
read_dataset <- function(paths, source = "auto", ...) {
  if (!rlang::is_string(source)) {
    cli::cli_abort(
      "{.arg source} must be a single source name or {.val auto}, not
       {.obj_type_friendly {source}}."
    )
  }

  if (identical(source, "auto")) {
    source <- detect_source(paths)
  }

  # The ambiguous DeepLabCut/LightningPose CSV parses identically either way.
  ambiguous <- identical(source, AMBIGUOUS_DLC_LP)
  lookup <- if (ambiguous) "deeplabcut" else source

  entry <- registry_entry(lookup)
  if (is.null(entry)) {
    supported <- get_supported_sources()$source
    cli::cli_abort(c(
      "Unsupported {.arg source}: {.val {source}}.",
      "i" = "Supported sources are {.val {supported}}, or {.val auto} to
             detect the format from the file."
    ))
  }

  reader <- get(entry$reader, envir = asNamespace("aniread"), mode = "function")
  data <- reader(paths, ...)

  if (ambiguous) {
    data <- anicore::set_metadata(data, source = AMBIGUOUS_DLC_LP)
  }

  data
}
