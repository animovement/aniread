# Tests for read_idtracker
#
# - Reads CSV exports that use the legacy `seconds` time column
# - Reads CSV exports that use the newer `time` time column (#60)
# - Probabilities CSV with either column name joins correctly
# - The h5 reader records the version, frame rate and frame height the file
#   carries, and leaves them NA when it does not (#146)

test_that("read_idtracker reads CSV with legacy `seconds` column", {
  trajectories <- test_path(
    "data/idtrackerai/trajectories_csv",
    "trajectories.csv"
  )
  probabilities <- test_path(
    "data/idtrackerai/trajectories_csv",
    "id_probabilities.csv"
  )

  result <- read_idtracker(
    trajectories,
    path_probabilities = probabilities
  )

  expect_s3_class(result, "anipoint")
  expect_true(all(
    c("time", "individual", "x", "y", "confidence") %in% names(result)
  ))
  expect_true(is.numeric(result$time))
})

test_that("read_idtracker reads CSV with renamed `time` column", {
  # Synthesise a tiny CSV in the newer format where idtracker.ai renamed
  # the leading column from `seconds` to `time` (issue #60).
  trajectories <- tempfile(fileext = ".csv")
  probabilities <- tempfile(fileext = ".csv")
  on.exit(unlink(c(trajectories, probabilities)), add = TRUE)

  writeLines(
    c(
      "time,x1,y1,x2,y2",
      "0.000,10.0,20.0,30.0,40.0",
      "0.036,11.0,21.0,31.0,41.0"
    ),
    trajectories
  )
  writeLines(
    c(
      "time,id_probabilities1,id_probabilities2",
      "0.000,1.0,1.0",
      "0.036,1.0,1.0"
    ),
    probabilities
  )

  result <- read_idtracker(
    trajectories,
    path_probabilities = probabilities
  )

  expect_s3_class(result, "anipoint")
  expect_true(all(
    c("time", "individual", "x", "y", "confidence") %in% names(result)
  ))
  expect_equal(sort(unique(result$time)), c(0.000, 0.036))
  expect_setequal(as.character(unique(result$individual)), c("1", "2"))
})

# A CSV export without a time column -----------------------------------

# idtracker.ai writes no time column when it could not read the video's
# frame rate (frames_per_second is None). These were written by its own
# _save_array_to_csv() with fps = None.
no_fps <- function(file) {
  test_path("data/idtrackerai/trajectories_csv_no_fps", file)
}

test_that("a CSV export without a time column is timed by frame", {
  data <- read_idtracker(
    no_fps("trajectories.csv"),
    path_probabilities = no_fps("id_probabilities.csv")
  )
  raw <- utils::read.csv(no_fps("trajectories.csv"))

  expect_s3_class(data, "anipoint")
  expect_equal(sort(unique(data$time)), seq_len(nrow(raw)))
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "frame")
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
  expect_setequal(levels(data$individual), c("1", "2"))

  first <- data[data$individual == "1", ]
  expect_equal(first$x, raw$x1)
  expect_equal(first$confidence, c(1, 1, 0.999, 1))
  second <- data[data$individual == "2", ]
  expect_true(is.na(second$x[[3]]))
  # idtracker.ai writes an identity probability of 0 where it lost one.
  expect_equal(second$confidence[[3]], 0)
})

test_that("frames are numbered from 1, as the h5 reader numbers them", {
  # aniread#150 proposes numbering every reader's frames from 0; until then
  # the two idtracker.ai exports of one recording agree with each other.
  skip_if_not_installed("rhdf5")
  csv <- read_idtracker(no_fps("trajectories.csv"))
  h5 <- read_idtracker(test_path("data/idtrackerai/trajectories.h5"))

  expect_equal(min(csv$time), min(h5$time))
  expect_equal(min(csv$time), 1)
})

test_that("read_dataset() detects and reads a CSV without a time column", {
  path <- no_fps("trajectories.csv")
  expect_equal(detect_source(path), "idtrackerai")
  expect_equal(
    as.data.frame(read_dataset(path)),
    as.data.frame(read_idtracker(path))
  )
})

# What the h5 records besides the tracks (#146) ------------------------

# A minimal idtracker.ai h5: two individuals over three frames, with the
# given root attributes. idtracker.ai writes its scalars as attributes of
# the root group and its arrays as datasets.
write_idtracker_h5 <- function(attributes = list()) {
  path <- withr::local_tempfile(fileext = ".h5", .local_envir = parent.frame())
  rhdf5::h5createFile(path)
  trajectories <- array(as.numeric(c(10, 20, 30, 40)), dim = c(2, 2, 3))
  rhdf5::h5write(trajectories, path, "trajectories")
  rhdf5::h5write(array(1, dim = c(1, 2, 3)), path, "id_probabilities")
  file <- rhdf5::H5Fopen(path)
  for (name in names(attributes)) {
    rhdf5::h5writeAttribute(
      attributes[[name]],
      file,
      name,
      asScalar = length(attributes[[name]]) == 1
    )
  }
  rhdf5::H5Fclose(file)
  path
}

test_that("the h5 reader records the idtracker.ai version and frame rate", {
  skip_if_not_installed("rhdf5")
  path <- test_path("data/idtrackerai/trajectories.h5")
  data <- read_idtracker(path)

  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
  expect_equal(anicore::get_metadata(data, "sampling_rate"), 28)
  # time stays the frame number; the frame rate is what converts it.
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "frame")
  expect_equal(sort(unique(data$time)), 1:508)
})

test_that("read_dataset() records them too", {
  skip_if_not_installed("rhdf5")
  data <- read_dataset(test_path("data/idtrackerai/trajectories.h5"))

  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
  expect_equal(anicore::get_metadata(data, "sampling_rate"), 28)
})

test_that("the CSV export's time is in seconds, the h5's in frames (#148)", {
  csv <- read_idtracker(
    test_path("data/idtrackerai/trajectories_csv", "trajectories.csv")
  )
  raw <- utils::read.csv(
    test_path("data/idtrackerai/trajectories_csv", "trajectories.csv")
  )

  expect_equal(as.character(anicore::get_metadata(csv, "unit_time")), "s")
  expect_equal(sort(unique(csv$time)), raw$seconds)

  skip_if_not_installed("rhdf5")
  h5 <- read_idtracker(test_path("data/idtrackerai/trajectories.h5"))
  expect_equal(as.character(anicore::get_metadata(h5, "unit_time")), "frame")
})

test_that("the CSV export states the frame rate but not the version", {
  # Both are in attributes.json beside it, which the reader does not read.
  # The frame rate is also in trajectories.csv: one row per frame, timed
  # at the row number over the frame rate, rounded to 1 ms. The span
  # alone gives 28.0002; attributes.json says 28.
  data <- read_idtracker(
    test_path("data/idtrackerai/trajectories_csv", "trajectories.csv")
  )

  expect_true(is.na(anicore::get_metadata(data, "source_version")))
  expect_identical(anicore::get_metadata(data, "sampling_rate"), 28)
})

test_that("a CSV whose rows are not evenly timed leaves the rate NA", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      "seconds,x1,y1",
      "0.000,10.0,20.0",
      "0.036,11.0,21.0",
      "0.100,12.0,22.0"
    ),
    path
  )

  data <- read_idtracker(path)
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
})

test_that("an h5 without the attributes still reads, leaving them NA", {
  skip_if_not_installed("rhdf5")
  data <- read_idtracker(write_idtracker_h5())

  expect_equal(nrow(data), 6L)
  expect_true(is.na(anicore::get_metadata(data, "source_version")))
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
  # With no height recorded, y is reflected around the furthest point.
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(y = 40))
})

test_that("attributes without a usable value are left NA", {
  skip_if_not_installed("rhdf5")
  recorded <- function(...) {
    data <- read_idtracker(write_idtracker_h5(list(...)))
    list(
      version = anicore::get_metadata(data, "source_version"),
      rate = anicore::get_metadata(data, "sampling_rate")
    )
  }
  unset <- list(version = NA_character_, rate = NA_real_)

  expect_equal(
    recorded(version = "6.1.0", frames_per_second = 29.97),
    list(version = "6.1.0", rate = 29.97)
  )
  expect_equal(recorded(version = "", frames_per_second = 0), unset)
  expect_equal(recorded(version = 6, frames_per_second = -1), unset)
  expect_equal(recorded(frames_per_second = "28"), unset)
  expect_equal(recorded(frames_per_second = NaN), unset)
})

test_that("the h5 reader reflects y around the frame height it records", {
  skip_if_not_installed("rhdf5")
  path <- write_idtracker_h5(list(height = 100L))

  data <- read_idtracker(path)
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(y = 100))
  expect_setequal(data$y, c(80, 60))

  # video_height still takes precedence over the file.
  data <- read_idtracker(path, video_height = 50)
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(y = 50))
})

test_that("the h5 reader names individuals by their identity labels", {
  skip_if_not_installed("rhdf5")
  # The labels are in identity order: the first names the first individual
  # in the trajectories.
  data <- read_idtracker(
    write_idtracker_h5(list(identities_labels = c("queen", "worker")))
  )
  expect_equal(levels(data$individual), c("queen", "worker"))
  expect_equal(data$x[data$individual == "queen"], c(10, 10, 10))
  expect_equal(data$x[data$individual == "worker"], c(30, 30, 30))

  # The fixture's labels are the defaults idtracker.ai writes.
  fixture <- read_idtracker(test_path("data/idtrackerai/trajectories.h5"))
  expect_equal(levels(fixture$individual), as.character(1:8))
})

test_that("labels that do not name every individual once are not used", {
  skip_if_not_installed("rhdf5")
  individuals <- function(labels) {
    data <- read_idtracker(
      write_idtracker_h5(list(identities_labels = labels))
    )
    levels(data$individual)
  }

  expect_equal(individuals(c("a", "a")), c("1", "2"))
  expect_equal(individuals(c("a", "b", "c")), c("1", "2"))
  expect_equal(individuals(c("a", "")), c("1", "2"))
  expect_equal(
    levels(label_idtracker_individuals(factor(1:2), NULL)),
    c("1", "2")
  )
})

test_that("the h5 reader records the frame width as the x extent", {
  skip_if_not_installed("rhdf5")
  data <- read_idtracker(write_idtracker_h5(list(height = 100L, width = 200L)))

  expect_equal(
    anicore::get_metadata(data, "axis_extents"),
    c(x = 200, y = 100)
  )
})

# The tidy CSV and Parquet exports (#165) -------------------------------

# Written by idtracker.ai 6.0.14's own writers, _save_trajectories_into_csv_tidy()
# and _save_trajectories_into_parquet() in src/idtrackerai/utils/trajectories_io.py
# (idtracker.ai is GPL-3.0-or-later), from the first 60 frames of
# trajectories.h5 as loaded by its _load_trajectories_from_h5(). That is what
# `idtrackerai_format trajectories.h5 --formats csv_tidy parquet` does, so the
# files keep the h5's attributes: version 6.0.0a0, 28 fps, and no height or
# width. The *_no_fps files are its first 4 frames of 2 individuals with
# frames_per_second set to None, as idtracker.ai records a video whose frame
# rate it could not read.
idt <- function(...) test_path("data/idtrackerai", ...)
tidy_csv <- idt("trajectories_tidy", "trajectories_tidy.csv")
tidy_csv_no_fps <- idt("trajectories_tidy_no_fps", "trajectories_tidy.csv")

# The first 60 frames of the h5, which the tidy exports were written from.
h5_first_60 <- function(...) {
  data <- read_idtracker(idt("trajectories.h5"), ...)
  data[data$time <= 60, ]
}

test_that("the Parquet export reads as the h5 it was written from", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("rhdf5")
  data <- read_idtracker(idt("trajectories.parquet"), video_height = 1000)
  h5 <- h5_first_60(video_height = 1000)

  expect_s3_class(data, "anipoint")
  expect_equal(levels(data$individual), levels(h5$individual))
  expect_equal(as.character(data$individual), as.character(h5$individual))
  expect_equal(data$keypoint, h5$keypoint)
  expect_equal(data$x, h5$x)
  expect_equal(data$y, h5$y)
  expect_equal(data$confidence, h5$confidence)
  # The frame over the frame rate, where the h5 has the frame from 1.
  expect_equal(data$time, (h5$time - 1) / 28)

  expect_equal(anicore::get_metadata(data, "source_format"), "parquet")
  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
  expect_identical(anicore::get_metadata(data, "sampling_rate"), 28)
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "s")
})

test_that("the tidy CSV export reads as the Parquet one, to 3 decimals", {
  skip_if_not_installed("arrow")
  data <- read_idtracker(tidy_csv)
  parquet <- read_idtracker(idt("trajectories.parquet"))

  expect_s3_class(data, "anipoint")
  expect_equal(data$individual, parquet$individual)
  expect_equal(data$x, round(parquet$x, 3))
  expect_equal(data$y, parquet$y, tolerance = 1e-3)
  expect_equal(data$time, round(parquet$time, 3))
  # Lost positions are written as nan, with a nan probability in this file.
  expect_equal(is.na(data$x), is.na(parquet$x))
  expect_equal(data$confidence, parquet$confidence)
  expect_true(anyNA(data$confidence))

  # attributes_tidy.json beside it records what the Parquet metadata does.
  expect_equal(anicore::get_metadata(data, "source_format"), "csv_tidy")
  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
  expect_identical(anicore::get_metadata(data, "sampling_rate"), 28)
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "s")
})

test_that("without a frame rate, time is the frame counted from 1", {
  skip_if_not_installed("arrow")
  for (path in c(idt("trajectories_no_fps.parquet"), tidy_csv_no_fps)) {
    data <- read_idtracker(path)
    expect_equal(sort(unique(data$time)), 1:4, info = path)
    expect_equal(
      as.character(anicore::get_metadata(data, "unit_time")),
      "frame",
      info = path
    )
    expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
    expect_equal(anicore::get_metadata(data, "source_version"), "6.0.0a0")
    expect_equal(levels(data$individual), c("1", "2"))
  }
})

test_that("a tidy CSV without its attributes takes the rate from its rows", {
  dir <- withr::local_tempdir()
  file.copy(tidy_csv, dir)
  data <- read_idtracker(file.path(dir, "trajectories_tidy.csv"))

  expect_true(is.na(anicore::get_metadata(data, "source_version")))
  expect_identical(anicore::get_metadata(data, "sampling_rate"), 28)
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "s")

  # Its time equals its frame in every row, so it had no frame rate. It gets
  # a folder of its own: on Windows the file read above can stay open, so
  # copying over it fails.
  dir_no_fps <- withr::local_tempdir()
  file.copy(tidy_csv_no_fps, dir_no_fps)
  data <- read_idtracker(file.path(dir_no_fps, "trajectories_tidy.csv"))
  expect_equal(sort(unique(data$time)), 1:4)
  expect_equal(as.character(anicore::get_metadata(data, "unit_time")), "frame")
  expect_true(is.na(anicore::get_metadata(data, "sampling_rate")))
})

# A minimal idtracker.ai Parquet export: two individuals over three frames at
# 25 fps, with the given attributes as JSON in its metadata.
write_idtracker_parquet <- function(attributes = list()) {
  path <- withr::local_tempfile(
    fileext = ".parquet",
    .local_envir = parent.frame()
  )
  frame <- rep(0:2, each = 2)
  table <- arrow::arrow_table(
    frame = frame,
    time = frame / 25,
    individual = rep(0:1, 3),
    x = rep(c(10, 30), 3),
    y = rep(c(20, 40), 3),
    probability = 1
  )
  table$metadata$idtrackerai_attributes <- jsonlite::toJSON(
    attributes,
    auto_unbox = TRUE
  )
  arrow::write_parquet(table, path)
  path
}

test_that("the Parquet export's frame size and labels are used", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("jsonlite")
  path <- write_idtracker_parquet(list(
    version = "6.0.14",
    frames_per_second = 25,
    height = 100,
    width = 200,
    identities_labels = c("queen", "worker")
  ))
  data <- read_idtracker(path)

  expect_equal(levels(data$individual), c("queen", "worker"))
  expect_equal(data$x[data$individual == "worker"], c(30, 30, 30))
  expect_equal(
    anicore::get_metadata(data, "axis_extents"),
    c(x = 200, y = 100)
  )
  expect_setequal(data$y, c(80, 60))
  expect_equal(anicore::get_metadata(data, "source_version"), "6.0.14")
  expect_identical(anicore::get_metadata(data, "sampling_rate"), 25)
  expect_equal(data$time[data$individual == "queen"], c(0, 0.04, 0.08))

  # video_height still takes precedence over the file.
  data <- read_idtracker(path, video_height = 50)
  expect_equal(anicore::get_metadata(data, "axis_extents"), c(x = 200, y = 50))
})

test_that("probabilities passed beside a tidy export are ignored", {
  skip_if_not_installed("arrow")
  expect_warning(
    data <- read_idtracker(
      tidy_csv,
      path_probabilities = idt("trajectories_csv", "id_probabilities.csv")
    ),
    "already contains the probabilities"
  )
  expect_equal(data$confidence, read_idtracker(tidy_csv)$confidence)
})

test_that("the export read is recorded, and can be named", {
  expect_equal(
    anicore::get_metadata(
      read_idtracker(idt("trajectories_csv", "trajectories.csv")),
      "source_format"
    ),
    "csv"
  )
  expect_equal(
    as.data.frame(read_idtracker(tidy_csv, format = "csv_tidy")),
    as.data.frame(read_idtracker(tidy_csv))
  )

  skip_if_not_installed("rhdf5")
  expect_equal(
    anicore::get_metadata(
      read_idtracker(idt("trajectories.h5")),
      "source_format"
    ),
    "h5"
  )
})

test_that("read_dataset() detects and reads both tidy exports", {
  expect_equal(detect_source(tidy_csv), "idtrackerai")
  expect_equal(
    as.data.frame(read_dataset(tidy_csv)),
    as.data.frame(read_idtracker(tidy_csv))
  )

  skip_if_not_installed("arrow")
  path <- idt("trajectories.parquet")
  # Every Parquet file opens with PAR1, which alone made it an aniframe.
  expect_equal(detect_source(path), "idtrackerai")
  expect_false(detect_aniframe_file(path))
  expect_equal(
    as.data.frame(read_dataset(path)),
    as.data.frame(read_idtracker(path))
  )
})

# NaN to NA no longer turns factors into their codes ---------------------

test_that("the h5 reader names its keypoint centroid", {
  skip_if_not_installed("rhdf5")
  data <- read_idtracker(idt("trajectories.h5"))
  # It was "1", the code of the factor's only level.
  expect_equal(levels(data$keypoint), "centroid")
})

test_that("a CSV export of ten or more individuals keeps them apart", {
  # The individuals' levels sort as text, "1", "10", "11", "2", ..., and
  # replacing their codes for them named "10" as "2".
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(
    c(
      paste0("time,", paste0(c("x", "y"), rep(1:11, each = 2), collapse = ",")),
      paste0("0.000,", paste(rep(1:11, each = 2) * 10, collapse = ","))
    ),
    path
  )
  data <- read_idtracker(path)

  expect_equal(levels(data$individual), as.character(1:11))
  expect_equal(data$x[data$individual == "10"], 100)
  expect_equal(data$x[data$individual == "2"], 20)
})
