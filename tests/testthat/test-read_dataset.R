# Tests for read_dataset()
#
# read_dataset() is a dispatcher, so the invariant that matters is that it
# returns exactly what the underlying reader returns. Format-specific
# behaviour is covered by that reader's own tests.

fixture <- function(...) testthat::test_path("data", ...)

test_that("read_dataset returns what the direct reader returns", {
  cases <- list(
    list(path = fixture("octron", "octron_sample.csv"), reader = read_octron),
    list(path = fixture("trex", "beetle.csv"), reader = read_trex),
    list(
      path = fixture("freemocap", "freemocap_test_data_by_frame.csv"),
      reader = read_freemocap
    ),
    list(
      path = fixture("fasttrack", "fasttrack-tracking.txt"),
      reader = read_fasttrack
    ),
    list(
      path = fixture("bonsai", "LI850.csv"),
      reader = read_bonsai
    ),
    list(
      path = fixture("idtrackerai", "trajectories_csv", "trajectories.csv"),
      reader = read_idtracker
    )
  )

  for (case in cases) {
    expect_equal(
      as.data.frame(read_dataset(case$path)),
      as.data.frame(case$reader(case$path)),
      info = basename(case$path)
    )
  }
})

test_that("read_dataset detects the source by default", {
  result <- read_dataset(fixture("trex", "beetle.csv"))

  expect_s3_class(result, "aniframe")
  expect_identical(anicore::get_metadata(result)$source, "trex")
})

test_that("an explicit source bypasses detection", {
  path <- fixture("deeplabcut", "mouse_single.csv")

  # The same file, read as either of the two sources it is compatible with.
  as_dlc <- read_dataset(path, source = "deeplabcut")
  as_lp <- read_dataset(path, source = "lightningpose")

  expect_identical(anicore::get_metadata(as_dlc)$source, "deeplabcut")
  expect_identical(anicore::get_metadata(as_lp)$source, "lightningpose")
})

test_that("an ambiguous DeepLabCut/LightningPose CSV records the ambiguity", {
  for (path in c(
    fixture("deeplabcut", "mouse_single.csv"),
    fixture("lightningpose", "mouse_single.csv")
  )) {
    result <- read_dataset(path)

    # Read via read_deeplabcut(), but the source is recorded as undetermined
    # rather than silently resolved to one of the two.
    expect_equal(
      as.data.frame(result),
      as.data.frame(read_deeplabcut(path)),
      info = basename(path)
    )
    expect_identical(
      anicore::get_metadata(result)$source,
      "deeplabcut/lightningpose"
    )
  }
})

test_that("read_dataset forwards ... to the reader", {
  paths <- fixture(
    "multi",
    c("GB_COM6_2021-08-05T15_37_55.csv", "GB_COM7_2021-08-05T15_37_55.csv")
  )

  result <- read_dataset(
    paths,
    sampling_rate = 60,
    col_time = 4,
    col_dx = 1,
    col_dy = 2
  )

  expect_equal(
    as.data.frame(result),
    as.data.frame(read_trackball(
      paths,
      setup = "of_free",
      sampling_rate = 60,
      col_time = 4,
      col_dx = 1,
      col_dy = 2
    ))
  )
})

test_that("read_dataset errors on an unsupported source", {
  expect_error(
    read_dataset(fixture("trex", "beetle.csv"), source = "not_a_source"),
    "Unsupported"
  )
})

test_that("read_dataset requires source to be a single string", {
  path <- fixture("trex", "beetle.csv")

  expect_error(
    read_dataset(path, source = c("trex", "octron")),
    "single source"
  )
  expect_error(read_dataset(path, source = 1), "single source")
})

test_that("read_dataset surfaces the detection error for an unknown file", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b,c", "1,2,3"), path)

  expect_error(read_dataset(path), "Cannot detect the source software")
})

test_that("every reader in the registry exists and is exported", {
  for (entry in source_registry()) {
    expect_true(
      entry$reader %in% getNamespaceExports("aniread"),
      info = entry$reader
    )
    expect_true(is.function(entry$detector), info = entry$source)
  }
})

test_that("registry source names match the metadata the readers stamp", {
  # read_trackball() stamps "trackball_bonsai", so that is what the registry
  # calls it and what `source` accepts.
  result <- read_dataset(
    fixture(
      "multi",
      c("GB_COM6_2021-08-05T15_37_55.csv", "GB_COM7_2021-08-05T15_37_55.csv")
    ),
    source = "trackball_bonsai",
    sampling_rate = 60,
    col_time = 4,
    col_dx = 1,
    col_dy = 2
  )

  expect_identical(
    anicore::get_metadata(result)$source,
    "trackball_bonsai"
  )
})

test_that("the registry no longer advertises SLEAP CSV", {
  # read_sleap() aborts on CSV input (#87); the registry must not claim
  # otherwise, or auto-detection would route CSVs straight into that error.
  sleap <- get_supported_sources()[get_supported_sources()$source == "sleap", ]

  expect_identical(sleap$suffix[[1]], "h5")
})
