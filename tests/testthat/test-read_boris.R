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
# - state-vs-point classification onto per-row `type` column
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
  expect_setequal(as.character(unique(ae$label)), c("s", "p"))
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

test_that("trivially uniform admin columns are dropped from the result", {
  # `comment_start` / `comment_stop` are all-NA in this fixture; the
  # newer columns (observation_type / source_media / time_offset /
  # image_file_path*) aren't present in this older export so should
  # not appear on the output either. `description` IS populated in
  # this fixture and should be preserved.
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  for (col in c(
    "comment",
    "comment_start",
    "comment_stop",
    "image_file_path",
    "image_file_path_start",
    "image_file_path_stop",
    "time_offset",
    "observation_type",
    "source_media"
  )) {
    expect_false(col %in% names(ae), info = paste("column kept:", col))
  }
  expect_true("description" %in% names(ae))
})

test_that("admin columns are preserved when they carry per-row signal", {
  # Construct a fixture where two rows have different observation_type
  # and a non-zero time_offset — these columns should survive.
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(
    c(
      paste(
        "Observation id",
        "Observation date",
        "Description",
        "Observation type",
        "Source",
        "Time offset (s)",
        "Media duration (s)",
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
        "MEDIA",
        "video1.mp4",
        "0.5",
        "30.0",
        "30.0",
        "A",
        "walk",
        "loco",
        "",
        "STATE",
        "1.0",
        "5.0",
        "4.0",
        sep = "\t"
      ),
      paste(
        "obs2",
        "2024-01-15 13:00:00",
        "",
        "LIVE",
        "n/a",
        "0.5",
        "30.0",
        "30.0",
        "A",
        "walk",
        "loco",
        "",
        "STATE",
        "10.0",
        "15.0",
        "5.0",
        sep = "\t"
      )
    ),
    path
  )
  ae <- read_boris(path)
  # observation_type varies → kept; time_offset is non-zero → kept.
  expect_true("observation_type" %in% names(ae))
  expect_true("time_offset" %in% names(ae))
})

test_that("aggregated TSV preserves media_file as a data column", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  expect_true("media_file" %in% names(ae))
  expect_setequal(
    unique(ae$media_file),
    c("video_test_25fps_180s.mp4", "video_test_25fps_360s.mp4")
  )
})

test_that("state/point classification lands on the per-row `type` column", {
  ae <- read_boris(agg_path("test_export_aggregated_events_test_full_1.tsv"))
  # The fixture's "behavior" channel has BORIS STATE rows (label `s`)
  # and POINT rows (label `p`) — these should be tagged per row.
  expect_true("type" %in% names(ae))
  expect_identical(levels(ae$type), c("state", "point"))
  s_rows <- ae$label == "s"
  p_rows <- ae$label == "p"
  expect_true(all(ae$type[s_rows] == "state"))
  expect_true(all(ae$type[p_rows] == "point"))
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
  walking_row <- which(as.character(ae$label) == "walking")
  chirp_rows <- which(as.character(ae$label) == "chirp")
  expect_identical(ae$channel[walking_row], "locomotion")
  expect_identical(unique(ae$channel[chirp_rows]), "vocalisation")
})

test_that("type is `state` for durative bouts and `point` for instants", {
  ae <- read_boris(agg_synth_path("modifiers_pipe_separated.tsv"))
  walking_row <- which(as.character(ae$label) == "walking")
  chirp_rows <- which(as.character(ae$label) == "chirp")
  expect_identical(as.character(ae$type[walking_row]), "state")
  expect_true(all(as.character(ae$type[chirp_rows]) == "point"))
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


# Newer flat tabular path -------------------------------------------------

test_that("flat tabular CSV (no header block) pairs START/STOP correctly", {
  # The newer BORIS tabular export has Subject/Behavior in row 1 with
  # all observation metadata broadcast as repeating columns; the
  # transition status lives in the `Behavior type` column.
  ae <- read_boris(tab_path("flat_dslr_subject.csv"))

  expect_s3_class(ae, "anievent")
  # 4 rows: Awake (STATE), Wake Modifiers (POINT), REM (STATE), Twitch (POINT)
  expect_equal(nrow(ae), 4)
  expect_equal(ae$start, c(0, 0, 200, 210))
  expect_equal(ae$stop, c(100, 0, 300, 210))
})

test_that("flat tabular CSV splits comma-separated modifiers per cell", {
  ae <- read_boris(tab_path("flat_dslr_subject.csv"))
  expect_identical(ae$modifiers[[1]], character()) # Awake has none
  expect_identical(ae$modifiers[[2]], c("Locomotion", "Cleaning"))
  expect_identical(ae$modifiers[[3]], character()) # REM has none
  expect_identical(ae$modifiers[[4]], c("Leg", "Pedipalps"))
})

test_that("flat tabular CSV maps Behavioral category onto channel", {
  ae <- read_boris(tab_path("flat_dslr_subject.csv"))
  expect_setequal(
    unique(ae$channel),
    c("Active phase", "Asleep", "Sign of REM-like sleep")
  )
})

test_that("flat tabular CSV propagates singular Image index into frame start/stop", {
  ae <- read_boris(tab_path("flat_dslr_subject.csv"), unit_time = "frame")
  expect_identical(
    as.character(aniframe::get_metadata(ae, "unit_time")),
    "frame"
  )
  expect_equal(ae$start, c(0, 0, 6000, 6300))
  expect_equal(ae$stop, c(3000, 0, 9000, 6300))
})

test_that("flat tabular CSV does not warn on state-vs-point overlap", {
  # The fixture has Awake (STATE, 0-100) and Wake Modifiers (POINT,
  # 0-0) in the same channel ("Active phase") at the same time.
  # POINT events are conceptually independent and downstream verbs
  # (`add_events()`, plotting) handle them separately — the overlap
  # check should ignore them.
  expect_no_warning(
    read_boris(tab_path("flat_dslr_subject.csv"))
  )
})


# Trailing whitespace -----------------------------------------------------

test_that("BORIS behaviour names get trimmed of trailing whitespace", {
  # Some BORIS exports emit behaviour names padded with trailing spaces
  # (this varies by version). The reader should strip them so factor
  # levels are clean.
  path <- withr::local_tempfile(fileext = ".tsv")
  writeLines(
    c(
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
        "subj1 ",
        "walking ",
        "locomotion ",
        "",
        "STATE",
        "1.0",
        "5.0",
        "4.0",
        sep = "\t"
      )
    ),
    path
  )
  ae <- read_boris(path)
  expect_identical(as.character(ae$label), "walking")
  expect_identical(as.character(ae$subject), "subj1")
  expect_identical(ae$channel, "locomotion")
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
      "obsA",
      "2024-01-15 12:00:00",
      "",
      "a.mp4",
      "30.0",
      "25.0",
      "A",
      "x",
      "",
      "",
      "STATE",
      "1.0",
      "5.0",
      "4.0",
      sep = "\t"
    ),
    paste(
      "obsB",
      "2024-01-15 13:00:00",
      "",
      "b.mp4",
      "30.0",
      "50.0",
      "A",
      "x",
      "",
      "",
      "STATE",
      "10.0",
      "15.0",
      "5.0",
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
