# ---- Layout auto-detection (#88) ---------------------------------------

test_that("the fixed layout is detected without being told", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  result <- read_animalta(path)

  expect_equal(
    as.data.frame(result),
    as.data.frame(read_animalta(path, format = "fixed"))
  )
  expect_equal(anicore::get_metadata(result, "source_format"), "fixed")
})

test_that("the variable layout is detected without being told", {
  # Reading this file with the old default gave a header error naming
  # columns the user had never heard of, rather than pointing at the
  # argument (#88).
  path <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )

  expect_no_error(result <- read_animalta(path))
  expect_s3_class(result, "anipoint")
  expect_equal(
    as.data.frame(result),
    as.data.frame(read_animalta(path, format = "variable"))
  )
  expect_equal(anicore::get_metadata(result, "source_format"), "variable")
})

test_that("an explicit layout is still honoured", {
  variable <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )
  fixed <- testthat::test_path(
    "data/animalta/single_individual_multi_arena.csv"
  )

  # Naming the wrong layout still fails, and says which headers it wanted.
  expect_error(read_animalta(variable, format = "fixed"), "X_Arena")
  expect_error(read_animalta(fixed, format = "variable"), "headers")
  expect_error(read_animalta(fixed, format = "detailed"), "no positions")
})

test_that("a layout that is not one of AnimalTA's errors", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")

  expect_error(read_animalta(path, format = "yes"), "must be one of")
})

test_that("a file in none of AnimalTA's layouts errors on auto", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a;b;c", "1;2;3"), path)
  expect_error(read_animalta(path), "not a file AnimalTA writes")
  expect_false(detect_animalta_file(path))

  writeLines("Frame", path)
  expect_true(is.na(detect_animalta_format(path)))
})

test_that("read_dataset reads a variable-layout export", {
  # The case that motivated #88: detect_source() identified the file
  # correctly, but the dispatcher had no way to pass the layout.
  path <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )

  expect_equal(detect_source(path), "animalta")
  expect_no_error(result <- read_dataset(path))
  expect_s3_class(result, "anipoint")
})

# ---- Deprecated `detailed` ---------------------------------------------

test_that("detailed = TRUE and FALSE still read, with a deprecation warning", {
  variable <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )
  fixed <- testthat::test_path(
    "data/animalta/single_individual_multi_arena.csv"
  )

  lifecycle::expect_deprecated(old <- read_animalta(variable, detailed = TRUE))
  expect_equal(as.data.frame(old), as.data.frame(read_animalta(variable)))
  lifecycle::expect_deprecated(old <- read_animalta(fixed, detailed = FALSE))
  expect_equal(as.data.frame(old), as.data.frame(read_animalta(fixed)))
  lifecycle::expect_deprecated(read_animalta(fixed, detailed = "auto"))
})

test_that("a logical given by position is taken as the old `detailed`", {
  # `detailed` used to be the second argument.
  fixed <- testthat::test_path(
    "data/animalta/single_individual_multi_arena.csv"
  )

  lifecycle::expect_deprecated(old <- read_animalta(fixed, FALSE))
  expect_equal(as.data.frame(old), as.data.frame(read_animalta(fixed)))
})

test_that("a deprecated `detailed` that is neither auto nor logical errors", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")

  withr::local_options(lifecycle_verbosity = "quiet")
  expect_error(read_animalta(path, detailed = "yes"), "must be")
})

# ---- Head and tail -----------------------------------------------------

test_that("head and tail columns become keypoints of one individual", {
  # A target alone in its arena tracked with "Separate head from tail" gets
  # X_Arena<a>_Ind<i>_Head/_Tail columns; the other arenas keep their pair.
  path <- testthat::test_path("data/animalta/head_tail_two_arenas.csv")
  raw <- utils::read.csv(path, sep = ";")
  result <- read_animalta(path)

  expect_equal(detect_source(path), "animalta")
  expect_equal(anicore::get_metadata(result, "source_format"), "fixed")
  expect_equal(anicore::get_keys(result), c("arena", "individual", "keypoint"))
  expect_equal(levels(result$arena), c("0", "1"))
  expect_setequal(
    unique(paste(result$arena, result$individual)),
    c("0 Ind0", "1 Ind0", "1 Ind1")
  )
  expect_setequal(levels(result$keypoint), c("head", "tail", "centroid"))
  expect_equal(nrow(result), 4 * nrow(raw))

  arena0 <- result$arena == "0" & result$individual == "Ind0"
  head <- result[arena0 & result$keypoint == "head", ]
  tail <- result[arena0 & result$keypoint == "tail", ]
  expect_equal(head$x, raw$X_Arena0_Ind0_Head)
  expect_equal(tail$x, raw$X_Arena0_Ind0_Tail)
  expect_true(all(is.na(head$x[raw$Frame == 2])))
  expect_equal(
    unique(result$keypoint[result$arena == "1"]),
    factor("centroid", levels = levels(result$keypoint))
  )
  expect_identical(anicore::get_metadata(result, "sampling_rate"), 30)
})

test_that("a corrected head-and-tail file reads as the tracked one", {
  # Once corrected, AnimalTA holds the head and tail as the targets
  # Ind0_part0 and Ind0_part1, filled from the _Head and _Tail columns in
  # that order, and saves them under those names. The fixture is the tracked
  # file put through AnimalTA's load_fixed() and save_fixed().
  tracked <- read_animalta(
    testthat::test_path("data/animalta/head_tail_two_arenas.csv")
  )
  path <- testthat::test_path(
    "data/animalta/head_tail_two_arenas_corrected.csv"
  )
  corrected <- read_animalta(path)

  expect_equal(detect_source(path), "animalta")
  arena0 <- corrected[corrected$arena == "0", ]
  expect_equal(unique(as.character(arena0$individual)), "Ind0")
  expect_setequal(as.character(arena0$keypoint), c("head", "tail"))
  expect_equal(
    as.data.frame(corrected),
    as.data.frame(tracked),
    ignore_attr = TRUE
  )
})

test_that("renamed targets keep their name", {
  # AnimalTA lets a target be renamed before the coordinates are saved
  # again, and writes the name into the column, or into `Ind` once a
  # variable-layout file is corrected.
  fixed <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "Frame;Time;X_Arena0_Ind0;Y_Arena0_Ind0;X_Arena0_Fish A;Y_Arena0_Fish A",
      "0;0.0;1;2;3;4",
      "1;0.03;1;2;3;4"
    ),
    fixed
  )
  expect_setequal(levels(read_animalta(fixed)$individual), c("Ind0", "Fish A"))

  variable <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "Frame;Time;Arena;Ind;X;Y",
      "0;0.0;0;Ind0;1;2",
      "0;0.0;0;Fish A;3;4"
    ),
    variable
  )
  expect_setequal(
    levels(read_animalta(variable)$individual),
    c("Ind0", "Fish A")
  )
})

test_that("coordinate columns AnimalTA does not write are rejected", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c("Frame;Time;X_Arena0_Ind0;Y_Arena0_Ind0;Speed", "0;0.0;1;2;3"),
    path
  )
  expect_error(read_animalta(path), "Speed")
})

# ---- Detailed data -----------------------------------------------------

test_that("a detailed data file is read with AnimalTA's default columns", {
  path <- testthat::test_path("data/animalta/detailed/video1/Arena_0Ind0.csv")
  raw <- utils::read.csv(path, sep = ";")
  result <- read_animalta(path)

  expect_equal(detect_source(path), "animalta")
  expect_equal(anicore::get_metadata(result, "source_format"), "detailed")
  expect_equal(anicore::get_keys(result), c("arena", "individual", "keypoint"))
  expect_equal(levels(result$arena), "0")
  expect_equal(levels(result$individual), "Ind0")
  expect_equal(levels(result$keypoint), "centroid")
  expect_equal(result$time, raw$Time)
  expect_equal(result$x, raw$X)
  # AnimalTA writes `nan` where the target was lost.
  expect_true(is.na(result$x[[4]]))
  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_identical(anicore::get_metadata(result, "sampling_rate"), 25)
  # Derived measures are not kept.
  expect_false(any(c("Distance", "Speed", "Moving") %in% names(result)))
})

test_that("a smoothed detailed file with a Frame column is read", {
  path <- testthat::test_path("data/animalta/detailed/video2/Arena_1Ind2.csv")
  raw <- utils::read.csv(path, sep = ";")
  result <- read_animalta(path, format = "detailed")

  expect_equal(levels(result$arena), "1")
  expect_equal(levels(result$individual), "Ind2")
  expect_equal(result$time, raw$Time)
  expect_equal(result$x, raw$X_Smoothed)
  expect_identical(anicore::get_metadata(result, "sampling_rate"), 30)
})

test_that("several detailed files read as one recording", {
  dir <- testthat::test_path("data/animalta/detailed/video2")
  paths <- file.path(dir, c("Arena_1Ind0.csv", "Arena_1Ind2.csv"))
  result <- read_animalta(paths)

  expect_equal(levels(result$arena), "1")
  expect_setequal(levels(result$individual), c("Ind0", "Ind2"))
  expect_equal(nrow(result), 8 + 5)
  expect_identical(anicore::get_metadata(result, "sampling_rate"), 30)
  expect_equal(anicore::get_metadata(result, "filename"), "Arena_1Ind0.csv")
  expect_equal(as.data.frame(read_dataset(paths)), as.data.frame(result))
})

test_that("detailed files at different rates leave the rate NA", {
  paths <- testthat::test_path(
    "data/animalta/detailed",
    c("video1/Arena_0Ind0.csv", "video2/Arena_1Ind2.csv")
  )
  result <- read_animalta(paths)
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))
  expect_equal(levels(result$arena), c("0", "1"))
})

test_that("only detailed files can be read several at once", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  expect_error(read_animalta(c(path, path)), "Only detailed files")
})

test_that("a detailed file without Time is timed by frame", {
  path <- file.path(withr::local_tempdir(), "Arena_2Ind1.csv")
  writeLines(c("Frame;X;Y;Speed", "3;1.5;2.5;nan", "4;2.0;3.0;0.5"), path)
  result <- read_animalta(path)

  expect_equal(anicore::get_metadata(result, "source_format"), "detailed")
  expect_equal(levels(result$arena), "2")
  expect_equal(levels(result$individual), "Ind1")
  expect_equal(result$time, c(3, 4))
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_time")),
    "frame"
  )
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))
})

test_that("detailed files must agree on having a Time column", {
  dir <- withr::local_tempdir()
  with_time <- file.path(dir, "Arena_0Ind0.csv")
  without <- file.path(dir, "Arena_0Ind1.csv")
  writeLines(c("Time;X;Y", "0.0;1;2"), with_time)
  writeLines(c("Frame;X;Y", "0;1;2"), without)
  expect_error(read_animalta(c(with_time, without)), "Time")
})

test_that("a detailed file without positions or time says so", {
  dir <- withr::local_tempdir()
  no_xy <- file.path(dir, "Arena_0Ind0.csv")
  writeLines(c("Time;Speed", "0.0;1"), no_xy)
  expect_error(read_animalta(no_xy, format = "detailed"), "no positions")

  no_time <- file.path(dir, "Arena_0Ind1.csv")
  writeLines(c("X;Y", "1;2"), no_time)
  expect_error(read_animalta(no_time, format = "detailed"), "no time")
})

test_that("the head and tail files of a target read as its keypoints", {
  # "Run analyses" writes one file per target, and the head and tail are the
  # targets Ind0_part0 and Ind0_part1. It names a Dist_to_ column for the
  # other one but writes no distance in a one-target arena, so each row is
  # one value short of the header.
  dir <- testthat::test_path("data/animalta/detailed/video3")
  paths <- file.path(dir, c("Arena_0Ind0_part0.csv", "Arena_0Ind0_part1.csv"))
  raw <- lapply(paths, utils::read.csv, sep = ";", row.names = NULL)

  expect_equal(detect_source(paths[[1]]), "animalta")
  expect_no_warning(result <- read_animalta(paths))
  expect_equal(levels(result$arena), "0")
  expect_equal(levels(result$individual), "Ind0")
  expect_setequal(levels(result$keypoint), c("head", "tail"))
  expect_equal(result$x[result$keypoint == "head"], raw[[1]][[2]])
  expect_equal(result$x[result$keypoint == "tail"], raw[[2]][[2]])
  expect_identical(anicore::get_metadata(result, "sampling_rate"), 30)
})

test_that("values a detailed file does not parse are reported", {
  path <- file.path(withr::local_tempdir(), "Arena_0Ind0.csv")
  writeLines(c("Time;X;Y", "0.0;abc;2", "0.04;2;3"), path)

  expect_warning(result <- read_animalta(path), "could not be read")
  expect_equal(result$x, c(NA, 2))
})

test_that("a renamed detailed file is named after the file", {
  path <- file.path(withr::local_tempdir(), "my_fish.csv")
  writeLines(c("Time;X;Y", "0.0;1;2", "0.04;2;3"), path)
  result <- read_animalta(path)
  expect_equal(levels(result$individual), "my_fish")
  # The arena is not known, but the column is still there.
  expect_true(all(is.na(result$arena)))
  expect_equal(anicore::get_keys(result), c("arena", "individual", "keypoint"))
})

# ---- Time ---------------------------------------------------------------

test_that("time is AnimalTA's Time column, in seconds", {
  # AnimalTA writes seconds, so leaving unit_time at its default of frames
  # misread every time downstream.
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  raw <- utils::read.csv(path, sep = ";")
  result <- read_animalta(path)

  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_equal(sort(unique(result$time)), raw$Time)
})

test_that("the variable-individuals layout keeps its time in seconds too", {
  path <- testthat::test_path(
    "data/animalta/variable_individuals_single_arena.csv"
  )
  result <- read_animalta(path)

  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_equal(result$time, round(0:18 / 30, 2))
})

# ---- Sampling rate ------------------------------------------------------

test_that("the rate is read from the Frame and Time columns", {
  raw <- read_animalta(
    testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  )
  variable <- read_animalta(
    testthat::test_path("data/animalta/variable_individuals_single_arena.csv")
  )

  expect_identical(anicore::get_metadata(raw, "sampling_rate"), 30)
  expect_identical(anicore::get_metadata(variable, "sampling_rate"), 30)
  expect_false("frame" %in% names(raw))
  expect_false("frame" %in% names(variable))
})

test_that("a Time column that disagrees with Frame leaves the rate NA", {
  # As the variable-individuals fixture was before it was repaired: a
  # spreadsheet had rewritten 0.1 as 00.01, so Time no longer followed Frame.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "Frame;Time;Arena;Ind;X;Y",
      "0.0;0.0;0;0;514;133",
      "1.0;0.03;0;0;518;132",
      "2.0;0.07;0;0;518;133",
      "3.0;0.01;0;0;519;132",
      "4.0;0.13;0;0;521;130"
    ),
    path
  )

  data <- read_animalta(path)
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
})

# ---- Arenas ------------------------------------------------------------

test_that("the variable layout keeps individuals in different arenas apart", {
  # AnimalTA numbers individuals from 0 within each arena. Dropping the
  # arena merged Ind 0 of arena 0 and Ind 0 of arena 1 into one individual
  # with two rows per time.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "Frame;Time;Arena;Ind;X;Y",
      "0.0;0.0;0;0;10;20",
      "0.0;0.0;1;0;30;40",
      "1.0;0.03;0;0;11;21",
      "1.0;0.03;1;0;31;41"
    ),
    path
  )
  result <- read_animalta(path)

  expect_equal(anicore::get_keys(result), c("arena", "individual", "keypoint"))
  expect_equal(levels(result$arena), c("0", "1"))
  expect_equal(levels(result$individual), "Ind0")
  expect_equal(nrow(result), 4)
  expect_equal(anyDuplicated(result[c("arena", "individual", "time")]), 0)
  arena1 <- result[result$arena == "1", ]
  expect_equal(arena1$x, c(30, 31))
})

test_that("the fixed layout gives each arena its own key", {
  path <- testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  raw <- utils::read.csv(path, sep = ";")
  result <- read_animalta(path)

  expect_equal(anicore::get_keys(result), c("arena", "individual", "keypoint"))
  expect_equal(levels(result$arena), as.character(0:8))
  expect_equal(levels(result$individual), "Ind0")
  expect_equal(result$x[result$arena == "3"], raw$X_Arena3_Ind0)
})

test_that("arenas sort by number, not as text", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "Frame;Time;Arena;Ind;X;Y",
      "0.0;0.0;10;0;10;20",
      "0.0;0.0;2;0;30;40"
    ),
    path
  )

  expect_equal(levels(read_animalta(path)$arena), c("2", "10"))
})

test_that("every layout names arenas and individuals the same way", {
  fixed <- read_animalta(
    testthat::test_path("data/animalta/single_individual_multi_arena.csv")
  )
  variable <- read_animalta(
    testthat::test_path("data/animalta/variable_individuals_single_arena.csv")
  )
  detailed <- read_animalta(
    testthat::test_path("data/animalta/detailed/video1/Arena_0Ind0.csv")
  )
  head_tail <- read_animalta(
    testthat::test_path("data/animalta/head_tail_two_arenas.csv")
  )

  # The arena is there for a file with a single arena too, so the columns do
  # not depend on the file.
  expect_equal(names(variable), names(fixed))
  expect_equal(names(detailed), names(fixed))
  expect_equal(names(head_tail), names(fixed))
  expect_true("0" %in% levels(fixed$arena))
  expect_equal(levels(variable$arena), "0")
  expect_equal(levels(detailed$arena), "0")
  expect_equal(levels(variable$individual), "Ind0")
  expect_equal(levels(detailed$individual), "Ind0")
})
