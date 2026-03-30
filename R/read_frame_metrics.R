# --- Public API ---------------------------------------------------------------

#' Read per-frame visual metrics from a video file
#'
#' A wrapper around [read_frame_metrics_fast()] and [read_frame_metrics_full()]
#' that selects the appropriate implementation via the `method` argument.
#'
#' The `"fast"` method delegates to ffprobe's built-in `signalstats` filter and
#' never moves pixel data into R, making it suitable for quick passes or very
#' long videos. The `"full"` method pipes raw RGB frames from ffmpeg into R and
#' computes a richer set of statistics.
#'
#' @section BehaveAI motion frames:
#' BehaveAI's exponential colour-from-motion encoding maps temporal lags onto
#' RGB channels (B = recent, G = intermediate, R = older trail). On these
#' frames, the per-channel statistics returned by `method = "full"` carry direct
#' temporal meaning: e.g. a high R mean relative to B mean indicates sustained
#' rather than newly initiated motion. The `"fast"` method collapses this
#' temporal structure into YUV-based summaries and should be treated as a
#' coarse motion energy index only.
#'
#' @param video_path Path to the video file.
#' @param every_n_frames Integer. Extract every nth frame. Default `1L`.
#' @param method One of `"full"` (default) or `"fast"`. See Details.
#' @param pixel_subsample Passed to [read_frame_metrics_full()]. Ignored when
#'   `method = "fast"`.
#' @param metrics Passed to [read_frame_metrics_full()]. Ignored when
#'   `method = "fast"`.
#' @param active_threshold Passed to [read_frame_metrics_full()]. Ignored when
#'   `method = "fast"`.
#' @param hwaccel Passed to [read_frame_metrics_full()]. Ignored when
#'   `method = "fast"`.
#' @param ffmpeg_path Path or command for ffmpeg. Passed to
#'   [read_frame_metrics_full()].
#' @param ffprobe_path Path or command for ffprobe. Passed to
#'   [read_frame_metrics_fast()].
#'
#' @return A [tibble::tibble()] with one row per extracted frame. The `time`
#'   column contains the 1-based frame number and can be used to join directly
#'   with centroid tracking data from the same video. Remaining columns depend
#'   on `method`; see [read_frame_metrics_fast()] and
#'   [read_frame_metrics_full()] for details.
#'
#' @seealso [read_frame_metrics_fast()], [read_frame_metrics_full()]
#'
#' @export
read_frame_metrics <- function(
  video_path,
  every_n_frames = 1L,
  method = c("full", "fast"),
  pixel_subsample = 1.0,
  metrics = c("rgb", "luminance", "hsv", "activity", "spatial"),
  active_threshold = 10L,
  hwaccel = NULL,
  ffmpeg_path = "ffmpeg",
  ffprobe_path = "ffprobe"
) {
  method <- match.arg(method)

  if (method == "fast") {
    read_frame_metrics_fast(
      video_path = video_path,
      every_n_frames = every_n_frames,
      ffprobe_path = ffprobe_path
    )
  } else {
    read_frame_metrics_full(
      video_path = video_path,
      every_n_frames = every_n_frames,
      pixel_subsample = pixel_subsample,
      metrics = metrics,
      active_threshold = active_threshold,
      hwaccel = hwaccel,
      ffmpeg_path = ffmpeg_path
    )
  }
}


#' Fast per-frame metrics via ffprobe signalstats
#'
#' Extracts per-frame luminance, saturation, and hue statistics by running
#' ffprobe's built-in `signalstats` filter. Because statistics are computed
#' inside ffprobe's own frame loop, no pixel data is transferred into R, making
#' this substantially faster than [read_frame_metrics_full()] at the cost of a
#' reduced and YUV-based metric set.
#'
#' @section BehaveAI motion frames:
#' On BehaveAI exponential motion frames the Y (luminance) channel captures
#' aggregate motion energy but collapses the temporal decomposition encoded
#' across R, G, and B. `hue_mean` provides a coarse proxy for the dominant
#' temporal phase of motion (i.e. whether activity is primarily recent or
#' trailing), and `sat_mean` reflects how temporally structured the motion is.
#' For full temporal channel decomposition use [read_frame_metrics_full()].
#'
#' @param video_path Path to the video file.
#' @param every_n_frames Integer. Extract every nth frame. Default `1L`.
#' @param ffprobe_path Path or command name for ffprobe. Default `"ffprobe"`
#'   assumes it is on the system `PATH`.
#'
#' @return A [tibble::tibble()] with one row per extracted frame. `time`
#'   contains the 1-based frame number. Additional columns: `y_min`, `y_p10`,
#'   `y_mean`, `y_p90`, `y_max`, `sat_min`, `sat_mean`, `sat_max`, `hue_mean`.
#'   Y and saturation values are in \[0, 255\]; hue in \[0, 360).
#'
#' @seealso [read_frame_metrics_full()], [read_frame_metrics()]
#'
#' @export
read_frame_metrics_fast <- function(
  video_path,
  every_n_frames = 1L,
  ffprobe_path = "ffprobe"
) {
  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.path {video_path}}")
  }
  if (!nzchar(Sys.which(ffprobe_path))) {
    cli::cli_abort(c(
      "ffprobe not found.",
      "i" = "Install ffmpeg or supply the full path via {.arg ffprobe_path}."
    ))
  }

  ffprobe_path <- Sys.which(ffprobe_path)
  info <- av::av_video_info(video_path)
  fps <- info$video$framerate

  n_frames_est <- ceiling(info$duration * fps / every_n_frames)

  lavfi_input <- if (every_n_frames == 1L) {
    sprintf("movie=%s,signalstats", video_path)
  } else {
    sprintf(
      "movie=%s,select='not(mod(n\\,%d))',signalstats",
      video_path,
      every_n_frames
    )
  }

  tag_fields <- paste0(
    "lavfi.signalstats.",
    c(
      "YMIN",
      "YLOW",
      "YAVG",
      "YHIGH",
      "YMAX",
      "SATMIN",
      "SATAVG",
      "SATMAX",
      "HUEAVG"
    )
  )

  args <- c(
    "-f",
    "lavfi",
    "-i",
    lavfi_input,
    "-show_entries",
    paste0("frame_tags=", paste(tag_fields, collapse = ",")),
    "-of",
    "csv=p=0",
    "-v",
    "quiet"
  )

  proc <- processx::process$new(
    command = ffprobe_path,
    args = args,
    stdout = "|",
    stderr = NULL
  )
  on.exit(try(proc$kill(), silent = TRUE), add = TRUE)

  cli::cli_inform(c(
    "i" = "Video: {info$video$width}x{info$video$height} @ {fps} fps",
    "i" = "Estimated frames: {n_frames_est}"
  ))

  cli::cli_progress_bar(
    "Extracting frame metrics",
    total = n_frames_est,
    format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} | {cli::pb_rate} | ETA {cli::pb_eta}",
    clear = TRUE
  )

  out <- matrix(NA_real_, nrow = n_frames_est, ncol = 9L)
  frame_i <- 1L

  repeat {
    proc$poll_io(timeout = 5000L)
    lines <- proc$read_output_lines()

    if (length(lines) == 0L) {
      if (!proc$is_alive()) {
        break
      }
      next
    }

    for (line in lines) {
      if (!nzchar(line)) {
        next
      }

      if (frame_i > nrow(out)) {
        extra <- matrix(NA_real_, nrow = ceiling(nrow(out) * 0.2), ncol = 9L)
        out <- rbind(out, extra)
      }

      out[frame_i, ] <- as.numeric(strsplit(line, ",")[[1L]])
      frame_i <- frame_i + 1L
      cli::cli_progress_update()
    }
  }

  cli::cli_progress_done()

  actual_frames <- frame_i - 1L

  if (actual_frames == 0L) {
    cli::cli_abort(
      "ffprobe returned no output. Verify {.arg video_path} and that ffprobe supports signalstats."
    )
  }

  cli::cli_inform("Extracted {actual_frames} frames.")

  out <- out[seq_len(actual_frames), ]

  tibble::tibble(
    time = seq_len(actual_frames),
    y_min = out[, 1L],
    y_p10 = out[, 2L],
    y_mean = out[, 3L],
    y_p90 = out[, 4L],
    y_max = out[, 5L],
    sat_min = out[, 6L],
    sat_mean = out[, 7L],
    sat_max = out[, 8L],
    hue_mean = out[, 9L]
  )
}


#' Full per-frame metrics via raw RGB pipe
#'
#' Extracts per-frame visual statistics by decoding raw RGB frames from ffmpeg
#' and computing per-channel summary statistics via a compiled C++ backend.
#' Returns a richer metric set than [read_frame_metrics_fast()] including
#' distributional shape, spatial centroid, and activity counts.
#'
#' @section BehaveAI motion frames:
#' BehaveAI's exponential colour-from-motion encoding maps temporal lags of
#' frame differences onto RGB channels: B captures the most recent motion
#' (t vs t-1), G the intermediate lag, and R the older motion trail. The
#' per-channel statistics returned here therefore carry direct temporal meaning.
#' For example, `r_mean` vs `b_mean` indicates whether motion is sustained or
#' newly initiated; `hue_concentration` from the `"hsv"` metric group reflects
#' how temporally consistent the motion pattern is within a frame.
#'
#' @param video_path Path to the video file.
#' @param every_n_frames Integer. Extract every nth frame. Default `1L`.
#' @param pixel_subsample Numeric in `(0, 1]`. Proportion of pixels sampled for
#'   per-frame statistics. When less than 1, ffmpeg rescales the frame
#'   (nearest-neighbour) rather than piping full-resolution data. Default `1.0`.
#' @param metrics Character vector of metric groups to compute. Any combination
#'   of `"rgb"`, `"luminance"`, `"hsv"`, `"activity"`, and `"spatial"`. All
#'   groups are computed by default.
#' @param active_threshold Integer (0--255). Luminance threshold defining
#'   "active" pixels, used by `"activity"`, `"hsv"`, and `"spatial"` groups.
#'   Default `10L`.
#' @param hwaccel Optional character string specifying an ffmpeg hardware
#'   acceleration backend. Passed directly as `-hwaccel <value>`. Common values:
#'
#'   - `"cuda"` -- NVIDIA GPU (Windows/Linux). Requires a CUDA-capable GPU and
#'     ffmpeg built with `--enable-cuda-llvm` or `--enable-cuvid`.
#'   - `"videotoolbox"` -- macOS (Apple Silicon benefits most; Intel Macs may
#'     see no improvement or even a slowdown due to GPU-to-CPU transfer cost).
#'   - `"vaapi"` -- Linux with Intel/AMD integrated graphics.
#'   - `"auto"` -- Let ffmpeg pick the best available backend.
#'
#'   Default `NULL` uses software decoding, which is reliable across all
#'   platforms. Hardware acceleration can significantly speed up decode for
#'   high-resolution or high-framerate video, but gains depend on the GPU, codec,
#'   and filter chain. If the specified backend is unavailable, ffmpeg silently
#'   falls back to software decode.
#' @param ffmpeg_path Path or command name for ffmpeg. Default `"ffmpeg"`
#'   assumes it is on the system `PATH`.
#'
#' @details
#' Metric groups:
#'
#' - **rgb**: Per-channel (R, G, B) statistics: mean, sd, median, min, max,
#'   5th and 95th percentiles, skewness, excess kurtosis.
#' - **luminance**: The same nine statistics on `0.299R + 0.587G + 0.114B`.
#' - **hsv**: Saturation mean/sd, value mean/sd, and circular hue statistics
#'   (mean, concentration, sd) over pixels exceeding `active_threshold`.
#' - **activity**: Count and proportion of pixels above `active_threshold`.
#' - **spatial**: Luminance-weighted centroid (`mot_cx`, `mot_cy`) and weighted
#'   spread (`mot_spread_x`, `mot_spread_y`) in original pixel coordinates.
#'
#' @return A [tibble::tibble()] with one row per extracted frame. `time`
#'   contains the 1-based frame number, followed by columns for each requested
#'   metric group as described in Details.
#'
#' @seealso [read_frame_metrics_fast()], [read_frame_metrics()],
#'   [av::av_video_info()]
#'
#' @export
read_frame_metrics_full <- function(
  video_path,
  every_n_frames = 1L,
  pixel_subsample = 1.0,
  metrics = c("rgb", "luminance", "hsv", "activity", "spatial"),
  active_threshold = 10L,
  hwaccel = NULL,
  ffmpeg_path = "ffmpeg"
) {
  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.path {video_path}}")
  }
  if (!nzchar(Sys.which(ffmpeg_path))) {
    cli::cli_abort(c(
      "ffmpeg not found.",
      "i" = "Install ffmpeg or supply the full path via {.arg ffmpeg_path}."
    ))
  }
  if (pixel_subsample <= 0 || pixel_subsample > 1) {
    cli::cli_abort("{.arg pixel_subsample} must be in (0, 1].")
  }

  metrics <- match.arg(metrics, several.ok = TRUE)

  info <- av::av_video_info(video_path)
  orig_width <- info$video$width
  orig_height <- info$video$height
  fps <- info$video$framerate

  # ---- Determine decode resolution ------------------------------------------
  # When pixel_subsample < 1, scale in ffmpeg (nearest-neighbour) so we pipe
  # fewer bytes and the C++ side processes all pixels sequentially.
  if (pixel_subsample < 1.0) {
    scale_factor <- sqrt(pixel_subsample)
    # Round to even (required by many codecs / ffmpeg filters)
    dec_width <- max(2L, as.integer(floor(orig_width * scale_factor / 2) * 2))
    dec_height <- max(2L, as.integer(floor(orig_height * scale_factor / 2) * 2))
  } else {
    dec_width <- orig_width
    dec_height <- orig_height
  }

  n_pixels <- dec_width * dec_height
  duration_s <- info$duration
  n_frames_est <- ceiling(duration_s * fps / every_n_frames)

  cli::cli_inform(c(
    "i" = "Video: {orig_width}x{orig_height} @ {fps} fps, ~{round(duration_s / 3600, 1)} hours",
    if (pixel_subsample < 1.0) {
      c(
        "i" = "Decode resolution: {dec_width}x{dec_height} (pixel_subsample={pixel_subsample})"
      )
    },
    "i" = "Estimated frames to extract: {n_frames_est}",
    "i" = "Metrics: {paste(metrics, collapse = ', ')}"
  ))

  do_rgb <- "rgb" %in% metrics
  do_luminance <- "luminance" %in% metrics
  do_hsv <- "hsv" %in% metrics
  do_activity <- "activity" %in% metrics
  do_spatial <- "spatial" %in% metrics

  px_col <- if (do_spatial) {
    rep(seq_len(dec_width), times = dec_height)
  } else {
    integer(0L)
  }
  px_row <- if (do_spatial) {
    rep(seq_len(dec_height), each = dec_width)
  } else {
    integer(0L)
  }

  # All pixels are used -- subsampling is handled by ffmpeg scale
  subsample_idx <- seq_len(n_pixels)

  n_metric_cols <- 0L
  if (do_rgb) {
    n_metric_cols <- n_metric_cols + 27L
  }
  if (do_luminance) {
    n_metric_cols <- n_metric_cols + 9L
  }
  if (do_hsv) {
    n_metric_cols <- n_metric_cols + 7L
  }
  if (do_activity) {
    n_metric_cols <- n_metric_cols + 2L
  }
  if (do_spatial) {
    n_metric_cols <- n_metric_cols + 4L
  }

  # ---- Build ffmpeg filter chain --------------------------------------------
  filters <- character(0L)
  if (every_n_frames > 1L) {
    filters <- c(filters, sprintf("select='not(mod(n\\,%d))'", every_n_frames))
  }
  if (pixel_subsample < 1.0) {
    filters <- c(
      filters,
      sprintf("scale=%d:%d:flags=neighbor", dec_width, dec_height)
    )
  }
  filters <- c(filters, "format=rgb24")
  filter_str <- paste(filters, collapse = ",")

  hwaccel_flag <- if (!is.null(hwaccel)) paste("-hwaccel", hwaccel) else ""

  cmd <- sprintf(
    '%s %s -i "%s" -vf "%s" -vsync vfr -f rawvideo pipe:1 2>/dev/null',
    ffmpeg_path,
    hwaccel_flag,
    video_path,
    filter_str
  )

  con <- pipe(cmd, open = "rb")
  on.exit(close(con), add = TRUE)

  bytes_per_frame <- n_pixels * 3L

  # Target ~128 MB per read, clamped to [64, 2048] frames
  buffer_n <- max(64L, min(2048L, as.integer(128e6 / bytes_per_frame)))
  buffer_size <- bytes_per_frame * buffer_n

  cli::cli_progress_bar(
    "Extracting frames",
    total = n_frames_est,
    format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} | {cli::pb_rate} | ETA {cli::pb_eta}",
    clear = TRUE
  )

  chunks <- vector("list", max(1L, ceiling(n_frames_est / buffer_n)))
  chunk_i <- 0L
  total_frames <- 0L

  repeat {
    raw_buffer <- readBin(con, what = "raw", n = buffer_size)
    if (length(raw_buffer) == 0L) {
      break
    }

    n_complete <- length(raw_buffer) %/% bytes_per_frame
    if (n_complete == 0L) {
      break
    }

    metrics_mat <- compute_buffer_metrics_cpp(
      raw_buffer,
      n_complete,
      n_pixels,
      subsample_idx,
      do_rgb,
      do_luminance,
      do_hsv,
      do_activity,
      do_spatial,
      active_threshold,
      px_col,
      px_row,
      n_metric_cols
    )

    chunk_i <- chunk_i + 1L
    chunks[[chunk_i]] <- metrics_mat
    total_frames <- total_frames + n_complete

    cli::cli_progress_update(set = total_frames)
  }

  cli::cli_inform("Extracted {total_frames} frames.")

  if (total_frames == 0L) {
    cli::cli_abort("No frames were extracted from {.path {video_path}}.")
  }

  combined <- do.call(rbind, chunks[seq_len(chunk_i)])

  col_names <- character(0L)
  if (do_rgb) {
    col_names <- c(
      col_names,
      .stat_names("r_"),
      .stat_names("g_"),
      .stat_names("b_")
    )
  }
  if (do_luminance) {
    col_names <- c(col_names, .stat_names("lum_"))
  }
  if (do_hsv) {
    col_names <- c(
      col_names,
      "sat_mean",
      "sat_sd",
      "val_mean",
      "val_sd",
      "hue_mean_circ",
      "hue_concentration",
      "hue_sd_circ"
    )
  }
  if (do_activity) {
    col_names <- c(col_names, "act_n_active", "act_prop_active")
  }
  if (do_spatial) {
    col_names <- c(
      col_names,
      "mot_cx",
      "mot_cy",
      "mot_spread_x",
      "mot_spread_y"
    )
  }

  colnames(combined) <- col_names

  out <- tibble::as_tibble(combined)
  out <- tibble::add_column(out, time = seq_len(total_frames), .before = 1L)

  # ---- Rescale spatial metrics to original resolution -----------------------
  if (do_spatial && pixel_subsample < 1.0) {
    x_scale <- orig_width / dec_width
    y_scale <- orig_height / dec_height
    out$mot_cx <- out$mot_cx * x_scale
    out$mot_cy <- out$mot_cy * y_scale
    out$mot_spread_x <- out$mot_spread_x * x_scale
    out$mot_spread_y <- out$mot_spread_y * y_scale
  }

  # Scale activity count back to original pixel count
  if (do_activity && pixel_subsample < 1.0) {
    pixel_ratio <- (orig_width * orig_height) / n_pixels
    out$act_n_active <- out$act_n_active * pixel_ratio
  }

  out
}

#' Full per-frame metrics via raw RGB pipe (pure R implementation)
#'
#' A pure R implementation of [read_frame_metrics_full()], retained for
#' performance benchmarking. Functionally identical but slower due to
#' interpreted per-frame pixel arithmetic. For production use, prefer
#' [read_frame_metrics_full()].
#'
#' @inheritParams read_frame_metrics_full
#'
#' @return Identical structure to [read_frame_metrics_full()].
#'
#' @seealso [read_frame_metrics_full()]
#'
#' @export
read_frame_metrics_full_r <- function(
  video_path,
  every_n_frames = 1L,
  pixel_subsample = 1.0,
  metrics = c("rgb", "luminance", "hsv", "activity", "spatial"),
  active_threshold = 10L,
  ffmpeg_path = "ffmpeg"
) {
  if (!file.exists(video_path)) {
    cli::cli_abort("Video file not found: {.path {video_path}}")
  }
  if (!nzchar(Sys.which(ffmpeg_path))) {
    cli::cli_abort(c(
      "ffmpeg not found.",
      "i" = "Install ffmpeg or supply the full path via {.arg ffmpeg_path}."
    ))
  }
  if (pixel_subsample <= 0 || pixel_subsample > 1) {
    cli::cli_abort("{.arg pixel_subsample} must be in (0, 1].")
  }

  metrics <- match.arg(metrics, several.ok = TRUE)

  info <- av::av_video_info(video_path)
  width <- info$video$width
  height <- info$video$height
  fps <- info$video$framerate
  n_pixels <- width * height

  duration_s <- info$duration
  n_frames_est <- ceiling(duration_s * fps / every_n_frames)

  cli::cli_inform(c(
    "i" = "Video: {width}x{height} @ {fps} fps, ~{round(duration_s / 3600, 1)} hours",
    "i" = "Estimated frames to extract: {n_frames_est}",
    "i" = "Metrics: {paste(metrics, collapse = ', ')}"
  ))

  if ("spatial" %in% metrics) {
    px_col <- rep(seq_len(width), times = height)
    px_row <- rep(seq_len(height), each = width)
  }

  subsample_idx <- if (pixel_subsample < 1.0) {
    sort(sample(n_pixels, size = floor(n_pixels * pixel_subsample)))
  } else {
    seq_len(n_pixels)
  }

  col_names <- "time"
  if ("rgb" %in% metrics) {
    col_names <- c(
      col_names,
      .stat_names("r_"),
      .stat_names("g_"),
      .stat_names("b_")
    )
  }
  if ("luminance" %in% metrics) {
    col_names <- c(col_names, .stat_names("lum_"))
  }
  if ("hsv" %in% metrics) {
    col_names <- c(
      col_names,
      "sat_mean",
      "sat_sd",
      "val_mean",
      "val_sd",
      "hue_mean_circ",
      "hue_concentration",
      "hue_sd_circ"
    )
  }
  if ("activity" %in% metrics) {
    col_names <- c(col_names, "act_n_active", "act_prop_active")
  }
  if ("spatial" %in% metrics) {
    col_names <- c(
      col_names,
      "mot_cx",
      "mot_cy",
      "mot_spread_x",
      "mot_spread_y"
    )
  }

  out <- matrix(NA_real_, nrow = n_frames_est, ncol = length(col_names))
  colnames(out) <- col_names

  select_filter <- if (every_n_frames == 1L) {
    "format=rgb24"
  } else {
    sprintf("select='not(mod(n\\,%d))',format=rgb24", every_n_frames)
  }

  cmd <- sprintf(
    '%s -i "%s" -vf "%s" -vsync vfr -f rawvideo pipe:1 2>/dev/null',
    ffmpeg_path,
    video_path,
    select_filter
  )

  con <- pipe(cmd, open = "rb")
  on.exit(close(con), add = TRUE)

  frame_i <- 1L
  bytes_per_frame <- n_pixels * 3L
  buffer_n <- 32L
  buffer_size <- bytes_per_frame * buffer_n

  cli::cli_progress_bar(
    "Extracting frames",
    total = n_frames_est,
    format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} | {cli::pb_rate} | ETA {cli::pb_eta}",
    clear = TRUE
  )

  repeat {
    raw_buffer <- readBin(con, what = "raw", n = buffer_size)
    if (length(raw_buffer) == 0L) {
      break
    }

    n_complete <- length(raw_buffer) %/% bytes_per_frame

    for (buf_i in seq_len(n_complete)) {
      if (frame_i > nrow(out)) {
        extra <- matrix(
          NA_real_,
          nrow = ceiling(nrow(out) * 0.2),
          ncol = ncol(out)
        )
        colnames(extra) <- col_names
        out <- rbind(out, extra)
      }

      start <- (buf_i - 1L) * bytes_per_frame + 1L
      raw_data <- raw_buffer[start:(start + bytes_per_frame - 1L)]

      px_mat <- matrix(as.integer(raw_data), nrow = 3L)
      r_all <- px_mat[1L, ]
      g_all <- px_mat[2L, ]
      b_all <- px_mat[3L, ]

      r <- r_all[subsample_idx]
      g <- g_all[subsample_idx]
      b <- b_all[subsample_idx]

      row_vals <- numeric(length(col_names))
      names(row_vals) <- col_names

      row_vals["time"] <- frame_i

      if ("rgb" %in% metrics) {
        row_vals[.stat_names("r_")] <- .channel_stats_vec(r)
        row_vals[.stat_names("g_")] <- .channel_stats_vec(g)
        row_vals[.stat_names("b_")] <- .channel_stats_vec(b)
      }

      if ("luminance" %in% metrics) {
        lum <- 0.299 * r + 0.587 * g + 0.114 * b
        row_vals[.stat_names("lum_")] <- .channel_stats_vec(lum)
      }

      if ("hsv" %in% metrics) {
        hsv <- .rgb_to_hsv(r, g, b)
        row_vals["sat_mean"] <- mean(hsv$s)
        row_vals["sat_sd"] <- sd(hsv$s)
        row_vals["val_mean"] <- mean(hsv$v)
        row_vals["val_sd"] <- sd(hsv$v)

        active_mask <- hsv$v > (active_threshold / 255)
        if (sum(active_mask) > 1L) {
          hue_rad <- hsv$h[active_mask] * (pi / 180)
          sc <- c(mean(sin(hue_rad)), mean(cos(hue_rad)))
          row_vals["hue_mean_circ"] <- atan2(sc[1], sc[2]) * (180 / pi)
          row_vals["hue_concentration"] <- sqrt(sc[1]^2 + sc[2]^2)
          row_vals["hue_sd_circ"] <- sqrt(
            -2 * log(row_vals["hue_concentration"])
          ) *
            (180 / pi)
        }
      }

      if ("activity" %in% metrics) {
        lum_all <- 0.299 * r_all + 0.587 * g_all + 0.114 * b_all
        active <- lum_all > active_threshold
        row_vals["act_n_active"] <- sum(active)
        row_vals["act_prop_active"] <- mean(active)
      }

      if ("spatial" %in% metrics) {
        lum_all <- 0.299 * r_all + 0.587 * g_all + 0.114 * b_all
        lum_sub <- lum_all[subsample_idx]
        col_sub <- px_col[subsample_idx]
        row_sub <- px_row[subsample_idx]
        weights <- pmax(lum_sub - active_threshold, 0)
        wsum <- sum(weights)

        if (wsum > 0) {
          cx <- sum(weights * col_sub) / wsum
          cy <- sum(weights * row_sub) / wsum
          row_vals["mot_cx"] <- cx
          row_vals["mot_cy"] <- cy
          row_vals["mot_spread_x"] <- sqrt(
            sum(weights * (col_sub - cx)^2) / wsum
          )
          row_vals["mot_spread_y"] <- sqrt(
            sum(weights * (row_sub - cy)^2) / wsum
          )
        }
      }

      out[frame_i, ] <- row_vals
      frame_i <- frame_i + 1L
      cli::cli_progress_update()
    }
  }

  cli::cli_progress_done()

  actual_frames <- frame_i - 1L
  cli::cli_inform("Extracted {actual_frames} frames.")

  tibble::as_tibble(out[seq_len(actual_frames), ])
}


# --- Helpers ------------------------------------------------------------------

#' Column name vector for channel stats (order must match .channel_stats_vec)
#' @noRd
.stat_names <- function(prefix) {
  paste0(
    prefix,
    c("mean", "sd", "median", "min", "max", "p05", "p95", "skew", "kurt")
  )
}

#' Per-channel stats returned as a named numeric vector
#' @noRd
.channel_stats_vec <- function(x) {
  n <- length(x)
  mu <- mean(x)
  s <- sd(x)
  c(
    mean = mu,
    sd = s,
    median = median(x),
    min = min(x),
    max = max(x),
    p05 = unname(quantile(x, 0.05)),
    p95 = unname(quantile(x, 0.95)),
    skew = if (s > 0) (sum((x - mu)^3) / n) / s^3 else NA_real_,
    kurt = if (s > 0) (sum((x - mu)^4) / n) / s^4 - 3 else NA_real_
  )
}

#' Vectorised RGB (0-255) to HSV
#' @noRd
.rgb_to_hsv <- function(r, g, b) {
  r <- r / 255
  g <- g / 255
  b <- b / 255
  v <- pmax(r, g, b)
  mn <- pmin(r, g, b)
  delta <- v - mn
  s <- ifelse(v == 0, 0, delta / v)
  h <- rep(0, length(r))
  mask_r <- delta > 0 & v == r
  mask_g <- delta > 0 & v == g & !mask_r
  mask_b <- delta > 0 & v == b & !mask_r & !mask_g
  h[mask_r] <- (60 * ((g[mask_r] - b[mask_r]) / delta[mask_r])) %% 360
  h[mask_g] <- 60 * ((b[mask_g] - r[mask_g]) / delta[mask_g]) + 120
  h[mask_b] <- 60 * ((r[mask_b] - g[mask_b]) / delta[mask_b]) + 240
  list(h = h, s = s, v = v)
}
