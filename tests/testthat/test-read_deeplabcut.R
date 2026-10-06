# Tests for read_deeplabcut()
#
# Testing:
# - read_deeplabcut(): file validation, dispatch by extension, metadata,
#   reflection of 2D data and none of 3D data
# - read_deeplabcut_csv() and read_deeplabcut_h5(): the column header is
#   read from the file's levels, so single- and multi-animal, 2D and 3D,
#   pandas "table" and "fixed" h5, and the `df_with_missing` and `tracks`
#   keys all read, and the csv and h5 of the same data agree
# - dlc_points_long(): every value lands on its own row
# - parse_pickle(): the protocol 0 pickles pandas stores its labels in
#
# Fixtures in data/deeplabcut:
# - mouse_single.csv, mouse_multi.csv, wasp_single.csv: DeepLabCut output
#   already in the package (the older layouts).
# - dlc3_*.csv/.h5, movement_*.h5: synthetic, written by make_fixtures.py in
#   the same directory, which builds each DataFrame the way DeepLabCut 3.0.2
#   (video predictions, stitched tracklets, triangulation) or movement's
#   to_dlc_file() does and saves it with the same pandas call. Each value
#   encodes the frame, individual, bodypart and coord it belongs to; see
#   make_fixtures.py.
# - Downloaded when online: DLC_single-mouse_EPM.predictions.h5 and
#   DLC_single-wasp.predictions.h5 (table format), and
#   DLC_single-mouse_DBTravelator_2D/_3D.predictions.h5 (fixed format), from
#   movement's sample data on SWC GIN, CC BY 4.0.

# --- Setup ---
# Download H5 sample data once at the start. Wrap so a failed download
# (offline, slow GIN server, etc.) doesn't error out the whole test file
# — tests that need the file skip individually below.
h5_path <- tryCatch(
  get_sample_data("deeplabcut", cache_dir = test_cache_dir(), quiet = TRUE),
  error = function(e) NULL
)

gin_poses <- function(filename) {
  paste0(
    "https://gin.swc.ucl.ac.uk/neuroinformatics/movement-sample-data/raw/master/poses/",
    filename
  )
}

# --- Fixtures ---
fixture_path <- function(filename) {
  test_path("data", "deeplabcut", filename)
}

# The value make_fixtures.py wrote for each row of a reading, by the
# encoding documented there.
encoded_value <- function(result, coord) {
  individual <- if ("individual" %in% names(result)) {
    c(mouse1 = 1, mouse2 = 2, single = 3)[as.character(result$individual)]
  } else {
    0
  }
  bodypart <- c(
    snout = 1,
    left_ear = 2,
    tail_base = 3,
    food_dish = 4,
    "øre" = 5
  )[as.character(result$keypoint)]
  if (coord == "likelihood") {
    return(unname((10 * individual + bodypart) / 100))
  }
  offset <- c(x = 1, y = 2, z = 3)[[coord]]
  unname(1000 * result$time + 100 * individual + 10 * bodypart + offset)
}

expect_encoded_values <- function(result) {
  for (coord in intersect(c("x", "y", "z"), names(result))) {
    expect_equal(result[[coord]], encoded_value(result, coord), info = coord)
  }
  if (!all(is.na(result$confidence))) {
    expect_equal(result$confidence, encoded_value(result, "likelihood"))
  }
}

synthetic_h5 <- function(setup) {
  path <- tempfile(fileext = ".h5")
  rhdf5::h5createFile(path)
  setup(path)
  rhdf5::h5closeAll()
  path
}

# --- read_deeplabcut() ---

test_that("read_deeplabcut rejects invalid file extensions", {
  expect_error(
    read_deeplabcut("data.txt")
  )
  expect_error(
    read_deeplabcut("data.xlsx")
  )
})

test_that("read_deeplabcut rejects non-existent files", {
  expect_error(
    read_deeplabcut("nonexistent.csv")
  )
})

test_that("read_deeplabcut returns an aniframe", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))

  expect_s3_class(result, "anipoint")
})

test_that("read_deeplabcut sets correct metadata", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))
  meta <- anicore::get_metadata(result)

  expect_equal(meta$source, "deeplabcut")
  expect_equal(meta$filename, "mouse_single.csv")
})

test_that("read_deeplabcut dispatches to CSV reader for .csv files", {
  result <- read_deeplabcut(fixture_path("mouse_single.csv"))

  expect_s3_class(result, "anipoint")
  expect_true("time" %in% names(result))
})

test_that("read_deeplabcut dispatches to H5 reader for .h5 files", {
  skip_if_not_installed("rhdf5")
  skip_if(is.null(h5_path), "deeplabcut sample download unavailable")

  result <- read_deeplabcut(h5_path)

  expect_s3_class(result, "anipoint")
  expect_true("time" %in% names(result))
})

test_that("read_deeplabcut reflects 2D data to bottom_left", {
  skip_if_not_installed("rhdf5")
  result <- read_deeplabcut(
    fixture_path("dlc3_single.h5"),
    video_height = 10000
  )

  expect_equal(result$y, 10000 - encoded_value(result, "y"))
  expect_equal(
    anicore::get_metadata(result)$axis_directions[["y"]],
    "up"
  )
})

# --- CSV ---

test_that("single-animal CSV has no individual column", {
  result <- read_deeplabcut_points(fixture_path("mouse_single.csv"))
  expected_cols <- c("time", "keypoint", "x", "y", "confidence")

  expect_true(all(expected_cols %in% names(result)))
  expect_false("individual" %in% names(result))
  expect_s3_class(result$keypoint, "factor")
  expect_type(result$x, "double")
  expect_type(result$y, "double")
  expect_type(result$confidence, "double")
})

test_that("multi-animal CSV has a factor individual column", {
  result <- read_deeplabcut_points(fixture_path("mouse_multi.csv"))
  expected_cols <- c("time", "individual", "keypoint", "x", "y", "confidence")

  expect_true(all(expected_cols %in% names(result)))
  expect_s3_class(result$individual, "factor")
  expect_s3_class(result$keypoint, "factor")
  expect_type(result$confidence, "double")
})

test_that("multi-animal output has multiple individuals", {
  result <- read_deeplabcut(fixture_path("mouse_multi.csv"))

  n_individuals <- length(unique(result$individual))
  expect_gt(n_individuals, 1)
})

test_that("multi-animal CSV keeps bodyparts with underscores whole", {
  # Column names were pasted together with `_` and split on it again, which
  # split `left_ear` across the individual and keypoint.
  result <- read_deeplabcut_points(fixture_path("dlc3_multi_unique.csv"))

  expect_setequal(
    levels(result$keypoint),
    c("snout", "left_ear", "tail_base", "food_dish")
  )
  expect_setequal(levels(result$individual), c("mouse1", "mouse2", "single"))
  expect_encoded_values(result)
})

test_that("a CSV without DeepLabCut's levels is refused", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("scorer,s", "bodyparts,nose", "0,1"), path)
  expect_error(read_deeplabcut(path), "No \"coords\" level")

  # A second file rather than rewriting the first: on Windows the file just
  # read can stay open, so writing to it fails.
  path_z <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("scorer,s", "bodyparts,nose", "coords,z", "0,1"), path_z)
  expect_error(read_deeplabcut(path_z), "no \"x\" and \"y\" coords")
})

test_that("a file with the same point twice is refused", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "scorer,a,a,b,b",
      "bodyparts,nose,nose,nose,nose",
      "coords,x,y,x,y",
      "0,1,2,3,4"
    ),
    path
  )
  expect_error(read_deeplabcut(path), "More than one column")
})

# --- H5 ---

test_that("DeepLabCut 3 single-animal h5 reads, with no individual", {
  skip_if_not_installed("rhdf5")
  result <- read_deeplabcut_points(fixture_path("dlc3_single.h5"))

  expect_false("individual" %in% names(result))
  expect_setequal(levels(result$keypoint), c("snout", "left_ear", "tail_base"))
  expect_equal(nrow(result), 4 * 3)
  expect_encoded_values(result)
})

test_that("multi-animal h5 is read as multi-animal", {
  # The check looked for the level names in the table's attributes, where
  # pandas does not put them, so it never found them.
  skip_if_not_installed("rhdf5")
  result <- read_deeplabcut_points(fixture_path("dlc3_multi_unique.h5"))

  expect_s3_class(result$individual, "factor")
  expect_setequal(levels(result$individual), c("mouse1", "mouse2", "single"))
  expect_encoded_values(result)
})

test_that("unique bodyparts are kept under the individual 'single'", {
  skip_if_not_installed("rhdf5")
  result <- read_deeplabcut_points(fixture_path("dlc3_multi_unique.h5"))
  points <- unique(paste(result$individual, result$keypoint))

  expect_setequal(
    points,
    c(
      paste("mouse1", c("snout", "left_ear", "tail_base")),
      paste("mouse2", c("snout", "left_ear", "tail_base")),
      "single food_dish"
    )
  )
  expect_equal(nrow(result), 4 * 7)
})

test_that("DeepLabCut 3 scorer names do not leak into the points", {
  # `DLC_Resnet50_..._snapshot_best-200`, and for top-down models
  # `..._detector_best-150_snapshot_best-200`.
  skip_if_not_installed("rhdf5")
  for (f in c("dlc3_single", "dlc3_multi_unique")) {
    for (ext in c(".csv", ".h5")) {
      result <- read_deeplabcut(fixture_path(paste0(f, ext)))
      expect_false(
        any(grepl("snapshot|detector|DLC", levels(result$keypoint))),
        info = paste0(f, ext)
      )
    }
  }
})

test_that("CSV and h5 of the same data read the same", {
  skip_if_not_installed("rhdf5")
  for (f in c("dlc3_single", "dlc3_multi_unique", "dlc3_3d")) {
    from_csv <- read_deeplabcut_points(fixture_path(paste0(f, ".csv")))
    from_h5 <- read_deeplabcut_points(fixture_path(paste0(f, ".h5")))
    expect_equal(from_h5, from_csv, info = f)
  }
})

test_that("stitched tracklets under the key 'tracks' read", {
  skip_if_not_installed("rhdf5")
  result <- read_deeplabcut_points(fixture_path("dlc3_tracks_el.h5"))

  expect_equal(sort(unique(result$time)), 0:5)
  expect_setequal(levels(result$individual), c("mouse1", "mouse2", "single"))
  # Frame 0 is before every track, and is NA rather than NaN
  frame_0 <- result[result$time == 0, ]
  expect_true(all(is.na(frame_0$x)))
  expect_false(any(is.nan(result$x)))
  # mouse2 starts at frame 2; the unique bodypart runs to frame 5
  expect_true(all(is.na(result$x[
    result$individual == "mouse2" & result$time == 1
  ])))
  expect_true(all(is.na(result$x[
    result$individual != "single" & result$time == 5
  ])))
  present <- !is.na(result$x)
  expect_equal(sum(present), 3 * 4 + 3 * 3 + 5)
  expect_encoded_values(result[present, ])
})

test_that("pandas' fixed format reads the same as its table format", {
  skip_if_not_installed("rhdf5")
  table <- read_deeplabcut_points(fixture_path("dlc3_tracks_el.h5"))
  fixed <- read_deeplabcut_points(fixture_path("dlc3_tracks_fixed_el.h5"))

  expect_equal(fixed, table)
})

test_that("files saved by movement's to_dlc_file() read", {
  skip_if_not_installed("rhdf5")
  multi <- read_deeplabcut_points(fixture_path("movement_multi.h5"))
  expect_setequal(levels(multi$individual), c("mouse1", "mouse2"))
  expect_equal(nrow(multi), 4 * 2 * 2)
  expect_encoded_values(multi)

  three_d <- read_deeplabcut_points(fixture_path("movement_3d.h5"))
  expect_true(all(is.na(three_d$confidence)))
  expect_encoded_values(three_d)
})

test_that("bodypart names keep their encoding", {
  skip_if_not_installed("rhdf5")
  for (f in c("dlc3_3d.csv", "dlc3_3d.h5", "movement_3d.h5")) {
    result <- read_deeplabcut_points(fixture_path(f))
    expect_true("øre" %in% levels(result$keypoint), info = f)
  }
})

test_that("an h5 without a DeepLabCut DataFrame is refused", {
  skip_if_not_installed("rhdf5")
  no_key <- synthetic_h5(\(path) rhdf5::h5createGroup(path, "other"))
  expect_error(read_deeplabcut(no_key), "not a DeepLabCut h5 file")

  not_pandas <- synthetic_h5(\(path) rhdf5::h5createGroup(path, "tracks"))
  expect_error(read_deeplabcut(not_pandas), "does not hold a pandas DataFrame")

  flat_columns <- synthetic_h5(\(path) {
    rhdf5::h5createGroup(path, "df_with_missing")
    fid <- rhdf5::H5Fopen(path)
    gid <- rhdf5::H5Gopen(fid, "df_with_missing")
    rhdf5::h5writeAttribute("frame", gid, "pandas_type")
    rhdf5::h5writeAttribute("regular", gid, "axis0_variety")
    rhdf5::H5Gclose(gid)
    rhdf5::H5Fclose(fid)
  })
  expect_error(read_deeplabcut(flat_columns), "multi-level header")
})

# --- 3D ---

test_that("DeepLabCut's 3D output reads with z and no confidence", {
  skip_if_not_installed("rhdf5")
  for (f in c("dlc3_3d.h5", "dlc3_3d.csv")) {
    result <- read_deeplabcut(fixture_path(f))

    expect_true("z" %in% names(result), info = f)
    expect_true(all(is.na(result$confidence)), info = f)
    expect_equal(anicore::get_coordinate_system(result), "cartesian_3d")
    # Not in image pixels, so returned as stored
    expect_encoded_values(result)
    expect_length(anicore::get_metadata(result)$axis_directions, 0)
  }
})

test_that("video_height is not used for 3D data", {
  skip_if_not_installed("rhdf5")
  expect_warning(
    result <- read_deeplabcut(fixture_path("dlc3_3d.h5"), video_height = 100),
    "not used for 3D data"
  )
  expect_encoded_values(result)
})

# --- Helpers ---

test_that("block_matrix lays out a one-column block by frame", {
  expect_equal(block_matrix(c(1, 2, 3), 3), matrix(c(1, 2, 3), ncol = 1))
  expect_equal(
    block_matrix(matrix(1:6, nrow = 2), 3),
    matrix(1:6, nrow = 3, byrow = TRUE)
  )
})

test_that("dlc_columns names levels in DeepLabCut's order when unnamed", {
  three <- list("s", "nose", "x")
  expect_named(dlc_columns(three, NULL), c("scorer", "bodyparts", "coords"))
  expect_named(
    dlc_columns(c(list("s"), three[-1], list("x")), c("a", NA, "b", "c")),
    c("scorer", "individuals", "bodyparts", "coords")
  )
  expect_named(dlc_columns(three, c("a", "b", "c")), c("a", "b", "c"))
  expect_error(
    ensure_dlc_levels(dlc_columns(list("s", "x"), NULL), "f.h5"),
    "column header"
  )
})

# --- parse_pickle() ---

test_that("parse_pickle reads what pandas stores", {
  # pandas' `info` and a block's `_kind`, as written by pandas 2.2
  info <- paste0(
    "(dp0\nI1\n(dp1\nVnames\np2\n(lp3\nVscorer\np4\naVbodyparts\np5\n",
    "aVcoords\np6\nasVtype\np7\nVMultiIndex\np8\nssVindex\np9\n(dp10\n",
    "sVvalues_block_0\np11\n(dp12\ns."
  )
  parsed <- parse_pickle(info)
  expect_equal(
    unlist(parsed[["1"]][["names"]]),
    c("scorer", "bodyparts", "coords")
  )
  expect_equal(parsed[["1"]][["type"]], "MultiIndex")
  expect_equal(parsed[["index"]], stats::setNames(list(), character()))

  kind <- paste0(
    "(lp0\n(Vs\np1\nVnose\np2\nVx\np3\ntp4\na(g1\ng2\nVy\np5\ntp6\na."
  )
  expect_equal(
    parse_pickle(kind),
    list(list("s", "nose", "x"), list("s", "nose", "y"))
  )
})

test_that("parse_pickle decodes raw-unicode-escape strings and None", {
  # Python: pickle.dumps(["øre", "→", "\U0001F42D", None], 0)
  bytes <- c(
    charToRaw("(lp0\nV"),
    as.raw(0xf8),
    charToRaw("re\np1\naV\\u2192\np2\naV\\U0001f42d\np3\naNa.")
  )
  parsed <- parse_pickle(rawToChar(bytes))

  expect_equal(parsed[1:3], list("øre", "→", "\U0001F42D"))
  expect_null(parsed[[4]])
})

test_that("parse_pickle refuses opcodes it does not read", {
  expect_error(parse_pickle("cnumpy\ndtype\n."), "Cannot read pickle opcode")
})

# --- Sample data (network) ---

test_that("read_deeplabcut_h5 returns expected columns for single-animal", {
  skip_if_not_installed("rhdf5")
  skip_if(is.null(h5_path), "deeplabcut sample download unavailable")

  result <- read_deeplabcut_points(h5_path)
  expected_cols <- c("time", "keypoint", "x", "y", "confidence")

  expect_true(all(expected_cols %in% names(result)))
  expect_false("individual" %in% names(result))
  expect_type(result$x, "double")
  expect_type(result$y, "double")
  expect_type(result$confidence, "double")
})

test_that("single-animal CSV and H5 produce consistent column names", {
  skip_if_not_installed("rhdf5")
  skip_if(is.null(h5_path), "deeplabcut sample download unavailable")

  csv_result <- read_deeplabcut(fixture_path("mouse_single.csv"))
  h5_result <- read_deeplabcut(h5_path)

  shared_cols <- c("time", "keypoint", "x", "y", "confidence")
  expect_true(all(shared_cols %in% names(csv_result)))
  expect_true(all(shared_cols %in% names(h5_result)))
})

test_that("fixed-format sample files from GIN read (#168)", {
  skip_if_not_installed("rhdf5")
  skip_if_no_network()
  paths <- tryCatch(
    vapply(
      c(
        "DLC_single-mouse_DBTravelator_2D.predictions.h5",
        "DLC_single-mouse_DBTravelator_3D.predictions.h5",
        "DLC_single-wasp.predictions.h5"
      ),
      \(f) {
        get_sample_data(
          gin_poses(f),
          cache_dir = test_cache_dir(),
          quiet = TRUE
        )
      },
      character(1)
    ),
    error = function(e) NULL
  )
  skip_if(is.null(paths), "GIN sample download unavailable")

  two_d <- read_deeplabcut(paths[[1]])
  expect_equal(anicore::get_coordinate_system(two_d), "cartesian_2d")
  expect_equal(nlevels(two_d$keypoint), 50)
  expect_equal(nrow(two_d), 418 * 50)

  # Written with a likelihood per point, which DeepLabCut's own
  # triangulation does not write
  three_d <- read_deeplabcut(paths[[2]])
  expect_equal(anicore::get_coordinate_system(three_d), "cartesian_3d")
  expect_equal(nrow(three_d), 418 * 50)
  expect_false(anyNA(three_d$confidence))

  wasp <- read_deeplabcut(paths[[3]])
  expect_setequal(levels(wasp$keypoint), c("head", "stinger"))
})
