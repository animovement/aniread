# Manual benchmark for read_octron on a synthetic Octron-style CSV.
#
# Not part of the automated test suite — run interactively with:
#   pkgload::load_all()
#   source("tests/perf/bench-read_octron.R")
#   bench_read_octron()
#
# The synthetic file is tuple-heavy (50% multi-segment rows) with the
# same column layout the user reported on the 1.85M-row Portia file.
#
# Reference numbers on a Windows laptop, n_rows = 100_000:
#   parse_octron_column   ~48x faster  (5.8s -> 0.12s)
#   resolve_weighted      ~4.5x faster
#   resolve_largest       ~10x faster
#   resolve_area_sum      ~2.7x faster
# End-to-end read_octron drops to a few seconds on the 100k fixture and
# from "unusably slow" (>>1 hour) to a few minutes on the user's 2.5 GB
# / 1.85M-row file.

bench_read_octron <- function(n_rows = 100000L, multi_frac = 0.5) {
  withr::local_options(scipen = 100)
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)

  is_multi <- runif(n_rows) < multi_frac

  tup2 <- function(a, b) sprintf('"(%s, %s)"', a, b)
  pos_x <- ifelse(
    is_multi,
    tup2(runif(n_rows, 0, 1000), runif(n_rows, 0, 1000)),
    as.character(runif(n_rows, 0, 1000))
  )
  pos_y <- ifelse(
    is_multi,
    tup2(runif(n_rows, 0, 1000), runif(n_rows, 0, 1000)),
    as.character(runif(n_rows, 0, 1000))
  )
  bbox_area <- ifelse(
    is_multi,
    tup2(runif(n_rows, 1000, 5000), runif(n_rows, 1000, 5000)),
    as.character(runif(n_rows, 1000, 5000))
  )
  bxmin <- ifelse(
    is_multi,
    tup2(runif(n_rows, 0, 1000), runif(n_rows, 0, 1000)),
    as.character(runif(n_rows, 0, 1000))
  )
  bxmax <- ifelse(
    is_multi,
    tup2(runif(n_rows, 0, 1000), runif(n_rows, 0, 1000)),
    as.character(runif(n_rows, 0, 1000))
  )
  bymin <- ifelse(
    is_multi,
    tup2(runif(n_rows, 0, 1000), runif(n_rows, 0, 1000)),
    as.character(runif(n_rows, 0, 1000))
  )
  bymax <- ifelse(
    is_multi,
    tup2(runif(n_rows, 0, 1000), runif(n_rows, 0, 1000)),
    as.character(runif(n_rows, 0, 1000))
  )
  area <- ifelse(
    is_multi,
    tup2(runif(n_rows, 100, 1000), runif(n_rows, 100, 1000)),
    as.character(runif(n_rows, 100, 1000))
  )
  ecc <- ifelse(
    is_multi,
    tup2(runif(n_rows), runif(n_rows)),
    as.character(runif(n_rows))
  )
  sol <- ifelse(
    is_multi,
    tup2(runif(n_rows), runif(n_rows)),
    as.character(runif(n_rows))
  )
  ori <- ifelse(
    is_multi,
    tup2(runif(n_rows, -1, 1), runif(n_rows, -1, 1)),
    as.character(runif(n_rows, -1, 1))
  )

  rows <- paste(
    seq_len(n_rows) - 1L,
    seq_len(n_rows) - 1L,
    1L,
    "worm",
    runif(n_rows, 0.5, 1),
    pos_x,
    pos_y,
    bbox_area,
    bxmin,
    bxmax,
    bymin,
    bymax,
    area,
    ecc,
    sol,
    ori,
    sep = ","
  )

  writeLines(
    c(
      "video_name: bench.mp4",
      paste0("frame_count: ", n_rows),
      paste0("frame_count_analyzed: ", n_rows),
      "video_height: 1000",
      "video_width: 1000",
      "created_at: 2026-05-07 00:00:00",
      "frame_counter,frame_idx,track_id,label,confidence,pos_x,pos_y,bbox_area,bbox_x_min,bbox_x_max,bbox_y_min,bbox_y_max,area,eccentricity,solidity,orientation",
      rows
    ),
    path
  )

  message(sprintf(
    "Synthetic CSV: %d rows (%d multi-segment) at %s",
    n_rows,
    sum(is_multi),
    path
  ))

  for (method in c("weighted", "largest", "segments")) {
    elapsed <- system.time(
      result <- read_octron(path, method = method)
    )["elapsed"]
    message(sprintf(
      "  %-9s  %.2fs   (%d output rows)",
      method,
      elapsed,
      nrow(result)
    ))
  }
}
