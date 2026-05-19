# Test suite for read_boris
#
# Tests cover both BORIS export formats supported in v1:
# - aggregated events (TSV/CSV)
# - tabular events (TSV/CSV; START/STOP pairing)
#
# And the cross-cutting concerns:
# - format auto-detection
# - unit_time selection (`"s"` vs `"frame"`) and fallback
# - modifier parsing (single-column pipe / multi-column `#N`)
# - channel mapping (Behavioral category → `"behavior"` fallback)
# - state-vs-point classification into variables_event metadata
# - metadata fields populated correctly
# - data columns dropped when redundant with metadata
# - error path for unrecognised / headerless files

agg_path <- function(file) {
  test_path("data", "boris", "aggregated", file)
}
agg_synth_path <- function(file) {
  test_path("data", "boris", "aggregated", "synthetic", file)
}
tab_path <- function(file) {
  test_path("data", "boris", "tabular", file)
}


# Aggregated path ---------------------------------------------------------

test_that("aggregated TSV reads into an anievent with expected shape", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))

  expect_s3_class(ae, "anievent")
  expect_equal(nrow(ae), 18)
  expect_setequal(
    as.character(unique(ae$subject)),
    c("No focal subject", "subject1", "subject2")
  )
  expect_setequal(unique(ae$channel), "behavior")
  expect_setequal(as.character(unique(ae$value)), c("s", "p"))
})

test_that("aggregated TSV populates metadata source/filename/unit_time", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  md <- aniframe::get_metadata(ae)

  expect_identical(md$source, "boris")
  expect_identical(
    md$filename,
    "test_export_aggregated_events_test_full_1.tsv"
  )
  expect_identical(as.character(md$unit_time), "s")
  expect_equal(md$sampling_rate, 25)
})

test_that("aggregated TSV sets neutral spatial metadata where possible", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  md <- aniframe::get_metadata(ae)

  expect_identical(as.character(md$unit_space), "none")
  expect_identical(as.character(md$coordinate_system), "unknown")
})

test_that("aggregated TSV drops fps and total_length columns from data", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  expect_false("fps" %in% names(ae))
  expect_false("total_length" %in% names(ae))
})

test_that("aggregated TSV preserves media_file as a data column", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  expect_true("media_file" %in% names(ae))
  expect_setequal(
    unique(ae$media_file),
    c("video_test_25fps_180s.mp4", "video_test_25fps_360s.mp4")
  )
})

test_that("state/point classification routes channels into variables_event", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  ve <- aniframe::get_metadata(ae, "variables_event")

  # The fixture's "behavior" channel carries both STATE and POINT bouts;
  # mixed channels route to `state` per our convention.
  expect_identical(ve$state, "behavior")
  expect_identical(ve$point, character())
})


# Modifier parsing --------------------------------------------------------

test_that("multi-column Modifier #N is gathered into a list-column", {
  ae <- read_boris(
    agg_synth_path("modifiers_multicol_with_image_index.tsv"),
    unit_time = "frame"
  )
  expect_true("modifiers" %in% names(ae))
  expect_type(ae$modifiers, "list")
  expect_identical(ae$modifiers[[1]], "left")
  expect_identical(ae$modifiers[[2]], character())
  expect_identical(ae$modifiers[[3]], c("long", "loud"))
  expect_identical(ae$modifiers[[4]], "short")
})

test_that("legacy single-column Modifiers (pipe-separated) parses + filters None", {
  ae <- read_boris(agg_synth_path("modifiers_pipe_separated.tsv"))
  expect_identical(ae$modifiers[[1]], "left")
  expect_identical(ae$modifiers[[2]], character())
  expect_identical(ae$modifiers[[3]], c("long", "loud"))
  expect_identical(ae$modifiers[[4]], "short")
})


# Channel mapping ---------------------------------------------------------

test_that("Behavioral category populates channel when set; falls back otherwise", {
  ae <- read_boris(agg_synth_path("modifiers_pipe_separated.tsv"))
  # walking + resting carry category "locomotion"; chirp carries "vocalisation".
  walking_row <- which(as.character(ae$value) == "walking")
  chirp_rows <- which(as.character(ae$value) == "chirp")
  expect_identical(ae$channel[walking_row], "locomotion")
  expect_identical(unique(ae$channel[chirp_rows]), "vocalisation")
})

test_that("classify routes pure-POINT channels to variables_event$point", {
  ae <- read_boris(agg_synth_path("modifiers_pipe_separated.tsv"))
  ve <- aniframe::get_metadata(ae, "variables_event")
  expect_identical(ve$state, "locomotion")
  expect_identical(ve$point, "vocalisation")
})


# Unit time ---------------------------------------------------------------

test_that("unit_time = 'frame' uses image-index columns when populated", {
  ae <- read_boris(
    agg_synth_path("modifiers_multicol_with_image_index.tsv"),
    unit_time = "frame"
  )
  expect_identical(
    as.character(aniframe::get_metadata(ae, "unit_time")),
    "frame"
  )
  expect_equal(ae$start, c(30, 180, 225, 255))
  expect_equal(ae$stop, c(150, 300, 225, 255))
})

test_that("unit_time = 'frame' falls back to 's' with cli_inform when no image-index", {
  expect_message(
    ae <- read_boris(
      agg_path("test_export_aggregated_events_test_full_1.tsv"),
      unit_time = "frame"
    ),
    "Falling back to"
  )
  expect_identical(
    as.character(aniframe::get_metadata(ae, "unit_time")),
    "s"
  )
})

test_that("unit_time = 's' (default) uses Start (s) / Stop (s)", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  expect_identical(
    as.character(aniframe::get_metadata(ae, "unit_time")),
    "s"
  )
  expect_equal(ae$start[1], 1.800)
  expect_equal(ae$stop[1], 8.125)
})


# Tabular path ------------------------------------------------------------

test_that("tabular TSV pairs START/STOP into bouts", {
  ae <- read_boris(tab_path("test_export_events_tabular.tsv"))
  expect_s3_class(ae, "anievent")
  expect_equal(nrow(ae), 4) # 8 START/STOP rows → 4 paired bouts
  expect_setequal(as.character(unique(ae$subject)), c("subject1", "subject2"))
  expect_setequal(unique(ae$channel), "behavior")
})

test_that("tabular CSV equivalent loads identically", {
  ae_tsv <- read_boris(tab_path("test_export_events_tabular.tsv"))
  ae_csv <- read_boris(tab_path("test_export_events_tabular.csv"))
  expect_equal(nrow(ae_csv), nrow(ae_tsv))
  expect_equal(ae_csv$start, ae_tsv$start)
  expect_equal(ae_csv$stop, ae_tsv$stop)
})

test_that("tabular reader drops Player #N header keys", {
  ae <- read_boris(tab_path("test_export_events_tabular.tsv"))
  expect_false(any(grepl("^player", names(ae))))
})


# Format dispatch ---------------------------------------------------------

test_that("explicit format = 'aggregated' bypasses auto-detection", {
  ae <- read_boris(
    agg_path("test_export_aggregated_events_test_full_1.tsv"),
    format = "aggregated"
  )
  expect_equal(nrow(ae), 18)
})

test_that("explicit format = 'tabular' bypasses auto-detection", {
  ae <- read_boris(
    tab_path("test_export_events_tabular.tsv"),
    format = "tabular"
  )
  expect_equal(nrow(ae), 4)
})

test_that("auto-detection rejects unrecognised files clearly", {
  expect_error(
    read_boris(
      agg_path(
        "test_export_aggregated_events_test_full_with_trailing_spaces_in_modifiers.tsv"
      )
    ),
    "Could not detect BORIS export format"
  )
})

test_that("read_boris rejects files with wrong suffix", {
  expect_error(
    read_boris(test_path(
      "data",
      "boris",
      "time_budget",
      "test_time_budget1.json"
    )),
    "suffix"
  )
})


# Edge cases (synthesised inline) -----------------------------------------

write_tsv_fixture <- function(lines, envir = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".tsv", .local_envir = envir)
  writeLines(lines, path)
  path
}

test_that("tabular reader warns about unmatched START events", {
  path <- write_tsv_fixture(c(
    "Observation id\tobs1",
    "",
    "Time\tSubject\tBehavior\tStatus",
    "1.0\tA\tx\tSTART",
    "2.0\tA\tx\tSTOP",
    "3.0\tA\tx\tSTART"
  ))
  expect_warning(
    ae <- read_boris(path, format = "tabular"),
    "unmatched.*START"
  )
  expect_equal(nrow(ae), 1)
})

test_that("tabular reader warns about unmatched STOP events", {
  path <- write_tsv_fixture(c(
    "Observation id\tobs1",
    "",
    "Time\tSubject\tBehavior\tStatus",
    "1.0\tA\tx\tSTOP",
    "2.0\tA\tx\tSTART",
    "3.0\tA\tx\tSTOP"
  ))
  expect_warning(
    ae <- read_boris(path, format = "tabular"),
    "unmatched.*STOP"
  )
  expect_equal(nrow(ae), 1)
})

test_that("tabular reader emits POINT events with start == stop", {
  path <- write_tsv_fixture(c(
    "Observation id\tobs1",
    "",
    "Time\tSubject\tBehavior\tStatus",
    "1.0\tA\tx\tPOINT",
    "2.5\tA\tx\tSTART",
    "4.0\tA\tx\tSTOP"
  ))
  ae <- read_boris(path, format = "tabular")
  expect_equal(nrow(ae), 2)
  point_row <- ae[ae$start == ae$stop, ]
  expect_equal(nrow(point_row), 1)
  expect_equal(point_row$start, 1.0)
})

test_that("tabular reader keeps modifiers in the pairing fingerprint", {
  # Two START/STOP pairs for the same subject+behaviour, distinguished
  # only by their modifiers — they must pair correctly (`a` with `a`,
  # `b` with `b`), not cross-pair on time order.
  path <- write_tsv_fixture(c(
    "Observation id\tobs1",
    "",
    "Time\tSubject\tBehavior\tModifiers\tStatus",
    "1.0\tA\tx\ta\tSTART",
    "2.0\tA\tx\tb\tSTART",
    "5.0\tA\tx\ta\tSTOP",
    "6.0\tA\tx\tb\tSTOP"
  ))
  ae <- read_boris(path, format = "tabular")
  expect_equal(nrow(ae), 2)
  # The bout with modifier `a` should have duration 4 (1→5); `b` 4 (2→6).
  for (i in seq_len(nrow(ae))) {
    expect_equal(ae$stop[i] - ae$start[i], 4)
  }
  mod_strings <- vapply(ae$modifiers, paste, collapse = ",", FUN.VALUE = "")
  expect_setequal(mod_strings, c("a", "b"))
})

test_that("tabular reader returns an empty anievent when all events are unmatched", {
  path <- write_tsv_fixture(c(
    "Observation id\tobs1",
    "",
    "Time\tSubject\tBehavior\tStatus",
    "1.0\tA\tx\tSTART",
    "2.0\tB\ty\tSTART"
  ))
  expect_warning(
    ae <- read_boris(path, format = "tabular"),
    "unmatched.*START"
  )
  expect_equal(nrow(ae), 0)
})

test_that("multiple distinct FPS values drop sampling_rate to NA", {
  # Two observations within a single aggregated file, each at a
  # different FPS — there's no single value to record on the anievent.
  path <- write_tsv_fixture(c(
    paste(
      "Observation id", "Observation date", "Description", "Media file",
      "Total length", "FPS", "Subject", "Behavior", "Behavioral category",
      "Modifiers", "Behavior type", "Start (s)", "Stop (s)", "Duration (s)",
      sep = "\t"
    ),
    paste(
      "obsA", "2024-01-15 12:00:00", "", "a.mp4", "30.0", "25.0",
      "A", "x", "", "", "STATE", "1.0", "5.0", "4.0",
      sep = "\t"
    ),
    paste(
      "obsB", "2024-01-15 13:00:00", "", "b.mp4", "30.0", "50.0",
      "A", "x", "", "", "STATE", "10.0", "15.0", "5.0",
      sep = "\t"
    )
  ))
  ae <- read_boris(path)
  expect_true(is.na(aniframe::get_metadata(ae, "sampling_rate")))
})

test_that("validator surfaces overlapping same-channel bouts as a warning", {
  # Two bouts of the same behaviour on the same subject overlap in
  # time — channels are conventionally mutually exclusive, so this
  # should trigger the aniframe::validate_anievent warning (not error).
  path <- write_tsv_fixture(c(
    paste(
      "Observation id",
      "Observation date",
      "Description",
      "Media file",
      "Total length",
      "FPS",
      "Subject",
      "Behavior",
      "Behavioral category",
      "Modifiers",
      "Behavior type",
      "Start (s)",
      "Stop (s)",
      "Duration (s)",
      sep = "\t"
    ),
    paste(
      "obs1",
      "2024-01-15 12:00:00",
      "",
      "video.mp4",
      "30.0",
      "30.0",
      "A",
      "walk",
      "",
      "",
      "STATE",
      "1.0",
      "5.0",
      "4.0",
      sep = "\t"
    ),
    paste(
      "obs1",
      "2024-01-15 12:00:00",
      "",
      "video.mp4",
      "30.0",
      "30.0",
      "A",
      "walk",
      "",
      "",
      "STATE",
      "3.0",
      "8.0",
      "5.0",
      sep = "\t"
    )
  ))
  expect_warning(
    read_boris(path),
    "overlap"
  )
})
