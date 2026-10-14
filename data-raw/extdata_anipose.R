# Write inst/extdata/anipose.csv: a synthetic Anipose 3D output, 5 frames of
# two keypoints, in the column layout Anipose's triangulation writes (as in
# tests/testthat/test-read_anipose.R). No Anipose output was copied.
#
#   Rscript data-raw/extdata_anipose.R

set.seed(1)
n <- 5
keypoint_columns <- function(name, x, y, z) {
  columns <- list(
    x = round(rnorm(n, x, 1), 3),
    y = round(rnorm(n, y, 0.5), 3),
    z = round(rnorm(n, z, 2), 3),
    error = round(runif(n, 0, 5), 3),
    ncams = rep(2, n),
    score = round(runif(n, 0.8, 1), 3)
  )
  stats::setNames(columns, paste0(name, "_", names(columns)))
}

anipose <- data.frame(
  keypoint_columns("l-base", -5, 3, 308),
  keypoint_columns("r-base", -6, 3.5, 310),
  M_00 = 1,
  M_01 = 0,
  M_02 = 0,
  M_10 = 0,
  M_11 = 1,
  M_12 = 0,
  M_20 = 0,
  M_21 = 0,
  M_22 = 1,
  center_0 = 0,
  center_1 = 0,
  center_2 = 0,
  fnum = seq_len(n) - 1,
  check.names = FALSE
)

# Unquoted, as pandas writes it
utils::write.csv(
  anipose,
  "inst/extdata/anipose.csv",
  row.names = FALSE,
  quote = FALSE
)
