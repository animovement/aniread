# Tests for detect_source()
#
# The load-bearing test here is the confusion matrix: every fixture against
# every detector. Twelve sources read .csv, so a detector firing on another
# source's file is the failure mode that matters, and only the full
# cross-product catches it.

fixture <- function(...) testthat::test_path("data", ...)

# Fixtures paired with the source they must detect as.
detection_cases <- list(
  list(source = "animalta", path = fixture("animalta", "single_individual_multi_arena.csv")),
  list(source = "animalta", path = fixture("animalta", "variable_individuals_single_arena.csv")),
  list(source = "bonsai", path = fixture("bonsai", "LI850.csv")),
  list(source = "boris", path = fixture("boris", "tabular", "test_export_events_tabular.csv")),
  list(source = "boris", path = fixture("boris", "tabular", "test_export_events_tabular.tsv")),
  list(source = "boris", path = fixture("boris", "tabular", "flat_dslr_subject.csv")),
  list(source = "boris", path = fixture("boris", "aggregated", "test_export_aggregated_events_test_full_1.tsv")),
  list(source = "freemocap", path = fixture("freemocap", "freemocap_test_data_by_frame.csv")),
  list(source = "idtrackerai", path = fixture("idtrackerai", "trajectories_csv", "trajectories.csv")),
  list(source = "octron", path = fixture("octron", "octron_sample.csv")),
  list(source = "octron", path = fixture("octron", "octron_sample_bytetrack.csv")),
  list(source = "trex", path = fixture("trex", "beetle.csv")),
  list(source = "fasttrack", path = fixture("fasttrack", "fasttrack-tracking.txt")),
  list(source = "trackball_bonsai", path = fixture("multi", "GB_COM6_2021-08-05T15_37_55.csv")),
  list(source = "trackball_bonsai", path = fixture("single", "opticalflow_sensor_1.csv")),
  list(source = "deeplabcut/lightningpose", path = fixture("deeplabcut", "mouse_single.csv")),
  list(source = "deeplabcut/lightningpose", path = fixture("deeplabcut", "mouse_multi.csv")),
  list(source = "deeplabcut/lightningpose", path = fixture("deeplabcut", "wasp_single.csv")),
  list(source = "deeplabcut/lightningpose", path = fixture("lightningpose", "mouse_single.csv")),
  list(source = "deeplabcut/lightningpose", path = fixture("lightningpose", "mouse_twoview.csv"))
)

test_that("every fixture detects as its own source", {
  for (case in detection_cases) {
    expect_identical(
      detect_source(case$path),
      case$source,
      info = basename(case$path)
    )
  }
})

test_that("no detector fires on another source's file", {
  # The cross-product. Each detector is run directly (bypassing the suffix
  # narrowing in detect_source()) so that a detector matching a file it should
  # not is caught even when the suffixes differ.
  registry <- source_registry()

  for (case in detection_cases) {
    expected <- strsplit(case$source, "/", fixed = TRUE)[[1]]
    suffix <- tolower(get_file_ext(case$path))

    for (entry in registry) {
      pkg <- registry_requires(entry, suffix)
      if (!is.na(pkg) && !rlang::is_installed(pkg)) next

      matched <- isTRUE(run_detector(entry$detector, case$path))
      should_match <- entry$source %in% expected

      expect_equal(
        matched,
        should_match,
        info = paste0(
          basename(case$path), " vs detector for '", entry$source, "'"
        )
      )
    }
  }
})

test_that("files that are not datasets detect as nothing", {
  # The idtracker.ai probabilities CSV is read via read_idtracker()'s
  # `path_probabilities`, never on its own, and shares its `seconds` column
  # with the trajectories file.
  expect_error(
    detect_source(fixture("idtrackerai", "trajectories_csv", "id_probabilities.csv")),
    "Cannot detect the source software"
  )
  expect_error(
    detect_source(fixture("bbox", "single-crab.csv")),
    "Cannot detect the source software"
  )
})

test_that("detection declines exactly the BORIS exports the reader declines", {
  # Headerless BORIS exports cannot be read by read_boris() either - it aborts
  # with the same "could not detect format" message - so detection refusing
  # them keeps the two consistent rather than promising a read that would fail.
  headerless <- fixture(
    "boris",
    "aggregated",
    "test_export_aggregated_events_test_full_2.tsv"
  )

  expect_error(detect_source(headerless), "Cannot detect the source software")
  expect_error(read_boris(headerless), "Could not detect BORIS export format")
})

test_that("detect_source errors on a suffix no source reads", {
  path <- withr::local_tempfile(fileext = ".sqlite")
  writeLines("not a dataset", path)

  expect_error(detect_source(path), "No supported source reads")
})

test_that("detect_source names the candidates when content matches none", {
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b,c", "1,2,3"), path)

  expect_error(detect_source(path), "match none of the sources")
})

test_that("detect_source inspects the first of several paths", {
  path1 <- fixture("multi", "GB_COM6_2021-08-05T15_37_55.csv")
  path2 <- fixture("multi", "GB_COM7_2021-08-05T15_37_55.csv")

  expect_identical(detect_source(c(path1, path2)), "trackball_bonsai")
})

test_that("SLEAP HDF5 files are detected", {
  skip_if_not_installed("rhdf5")
  expect_identical(
    detect_source(fixture("sleap", "SLEAP_single-mouse_EPM.analysis.h5")),
    "sleap"
  )
  expect_identical(
    detect_source(fixture("sleap", "SLEAP_three-mice_Aeon_mixed-labels.analysis.h5")),
    "sleap"
  )
})

test_that("idtracker.ai HDF5 is told apart from SLEAP HDF5", {
  skip_if_not_installed("rhdf5")
  expect_identical(
    detect_source(fixture("idtrackerai", "trajectories.h5")),
    "idtrackerai"
  )
})

test_that("a detector that errors counts as a non-match", {
  expect_false(run_detector(function(path) stop("boom"), "any/path"))
  expect_false(run_detector(function(path) FALSE, "any/path"))
  expect_true(run_detector(function(path) TRUE, "any/path"))
})

test_that("detect_source reports sources skipped for a missing package", {
  # Pretend rhdf5 is absent so the HDF5 sources are skipped, and check the
  # error says so rather than claiming the format is unknown.
  local_mocked_bindings(
    is_installed = function(pkg, ...) FALSE,
    .package = "rlang"
  )
  path <- withr::local_tempfile(fileext = ".h5")
  writeLines("not really hdf5", path)

  expect_error(detect_source(path), "not installed")
})
