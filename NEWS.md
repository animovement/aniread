# aniread 0.5.1.9001 (development version)

## New features

* `read_dataset()` reads any supported format through a single entry point, working out which source software wrote the file rather than requiring you to know in advance (#73). `read_dataset("mouse.h5")` is enough; pass `source` to name the format explicitly, and `...` to reach a reader's own arguments (`read_dataset(paths, sampling_rate = 60)` for a trackball pair). The object returned is exactly what the underlying reader returns — an `aniframe`, or an `anievent` for `read_boris()`.

* `detect_source()` reports which source software wrote a file without reading it. Candidates are narrowed by file suffix, then each candidate's detector inspects the contents — a header block, a set of HDF5 datasets, or a magic number — and exactly one match is required. This matters because twelve of the supported sources read `.csv`, so the suffix decides almost nothing on its own.

  DeepLabCut and LightningPose export structurally identical CSV files. Rather than guess, `detect_source()` returns the combined name `"deeplabcut/lightningpose"`, and `read_dataset()` reads such a file with `read_deeplabcut()` — the parse is the same either way — while recording the combined name as its source, so the ambiguity is preserved rather than silently resolved. This follows `movement`'s handling of the same collision.

  Detectors for HDF5, Parquet, XML and C3D files need an optional package (`rhdf5`, `arrow`, `xml2`, `c3dr`). When one is missing those sources are skipped, and if nothing is detected the error names both the skipped sources and the packages that would have been consulted.

## Breaking changes

* `get_supported_sources()` no longer lists `csv` as a SLEAP suffix. `read_sleap()` aborts on CSV input with "We hope to support SLEAP CSV import soon!", so the registry was advertising a format the reader cannot read; auto-detection would have routed such files straight into that error. Restored when the reader gains support (#87).

* `get_supported_sources()` renames the `trackball` source to `trackball_bonsai`, matching the `source` metadata that `read_trackball()` actually stamps. The two names previously disagreed, which becomes visible now that `source` is an argument matched against the registry.

## Bug fixes

* `read_trackball()` can now read real two-sensor Bonsai optical-flow captures (#85). Previously it either aborted with an error pointing nowhere near the cause, or silently returned a misaligned trajectory. In detail:

  * **Sensor alignment.** `read_opticalflow()` zeroed each file to its own start time, which destroyed the offset between the two sensors — the only thing `join_trackball_files()` can align them on. Its shared-window logic could therefore never fire, and a sensor that started 4.2 s late was silently shifted to t = 0. `read_opticalflow()` now returns time on an absolute scale and the caller chooses the origin.
  * **`start_datetime` agrees with `time`.** `time = 0` is the first sample both sensors recorded, and the `start_datetime` metadata is the wall-clock instant of that sample. The two previously disagreed by the sensor offset.
  * **Corrupt rows.** Serial capture drops characters, so short rows are normal. One such row used to abort the read with `missing value where TRUE/FALSE needed` or `'from' must be a finite number`. Malformed rows are now dropped, with the count reported when `quiet = FALSE`.
  * **Leading junk.** The reader hardcoded `skip = 2` and then took the next line as a header, discarding two real data rows from a file with one junk line and three from a file with none. The leading junk is now detected by field count, and headerless files are read as such.
  * **Microsecond clocks.** Auto-detection divided by the median timestamp step, which is 0 when more than half the timestamps repeat — the microsecond clock was then never scaled and the time grid exploded. Zero-length and missing steps are now excluded.
  * **Gap filling.** The one-sensor path did not back-fill empty time bins while the two-sensor path did, so the same gappy input produced different time grids. Both now produce a regular grid.
  * **Argument handling.** `setup` is now `match.arg()`d, so omitting it no longer fails with `the condition has length > 1` and a typo gives an informative error. `read_trackball()` now calls the previously orphaned `validate_trackball()`, so `of_free` with a single file errors up front instead of failing later in `compute_xy_coordinates_free()`. `quiet` is now honoured.

* `read_trackball()` warns when `col_time` resolves to a non-datetime column and two sensors are given. A per-board device counter has a sensor-local origin and cannot cross-reference two files — in the dataset behind #85 the two counters differ by 36.8 s while the true offset is 4.2 s. Use the PC datetime column instead. The warning has class `aniread_sensor_local_clock`.

* `ensure_header_match()` no longer rejects a character `col_time` on files that *do* have named headers; it now aborts only when the file is headerless.

## Documentation

* `?read_trackball` documents the raw Bonsai layout (`dx, dy, device_clock_us, pc_datetime, interval_s`), the requirement that `col_time` be a shared clock when two sensors are given, and that empty time bins are filled with zero motion — a deliberate assumption about this logger, which emits no row while the ball is still, rather than a general claim about optical flow.

# aniread 0.5.1

## New features

* `get_supported_sources()` returns the source software `aniread` can read as a tibble of `source` / `reader` / `suffix`, so downstream packages can discover supported formats programmatically instead of hard-coding them. Closes #74.

## Bug fixes

* `read_octron()` no longer drops frames in which nothing was detected. Octron omits such frames entirely; the reader now reinstates them as all-NA rows across the full track × frame grid (using the analysed-frame count from the CSV header) so the time axis is gap-free. Closes #80.
* `read_boris(unit_time = "frame")` no longer fails on exports with an inconsistent image index (e.g. a STOP on the last video frame recorded as frame 1, giving `stop < start`). When FPS is known, the offending frame interval is recovered from `round(time_s * fps)`. Closes #81.

# aniread 0.5.0

## New features

* `read_boris()` imports behavioural events from a [BORIS](https://www.boris.unito.it/) export into an [`aniframe::anievent()`](https://animovement.dev/aniframe/reference/anievent.html). Supports the two flat-text BORIS exports — **aggregated events** (one row per bout) and **tabular events** (one row per START / STOP / POINT transition; paired into bouts by the reader) — and auto-detects the format from the file's first row. Channels are taken from BORIS's `Behavioral category` when populated, falling back to the literal `"behavior"`; modifiers travel via the `modifiers` list-column in both the newer multi-column (`Modifier #1`, `Modifier #2`, ...) and the legacy single-column pipe-separated layouts. State-vs-point classification is recorded in `metadata$variables_event`. `unit_time = "s"` (default) reads `Start (s)` / `Stop (s)`; pass `unit_time = "frame"` to use the image-index columns instead, which keeps event timestamps row-aligned with a host aniframe (and falls back to seconds when no image-index columns are present). FPS is recorded as `sampling_rate` metadata without rescaling timestamps. Closes #76.

## Bug fixes

* File validation no longer rejects readable files on Windows network (UNC) shares. `file.access()` returns false negatives for read permission on such paths; the read check now falls back to a non-destructive open attempt when `file.access()` reports no access.

## Dependencies

* `aniframe (>= 0.6.0)` is now required, since `read_boris()` produces an `anievent` object — a new class added in aniframe 0.6.0.

# aniread 0.4.1

## New features

* `read_octron()` gains a `properties` argument for picking which region-property columns to read (`"all"` by default; pass a character vector for a subset or `NULL` to skip them). `area` is auto-included when `method = "weighted"`.
* `read_octron()` normalises hyphens to underscores in column names (`moments_hu-0` → `moments_hu_0`).

## Performance

* `read_octron()` is now substantially faster on large multi-segment files, especially when only a few `properties` are requested.

## Bug fixes

* `read_octron(method = "weighted")` no longer silently recycles `v * a` when a row's value and area columns have different segment counts; it falls back to the arithmetic mean for those rows and emits a single warning naming the affected `frame_idx` values.

# aniread 0.4.0

## Breaking changes

* Readers whose source data uses image (top-left) origin now reflect `y` so the returned aniframe is in the conventional `bottom_left` origin. This fixes plots being upside-down without manual reorientation. Affects `read_animalta()`, `read_bonsai()`, `read_deeplabcut()`, `read_fasttrack()`, `read_idtracker()`, `read_lightningpose()`, `read_movement()`, `read_octron()`, `read_sleap()`, `read_trackmate()`, and `read_trex()` (#61).
* `aniframe (>= 0.5.0)` is now required, since the reflection uses the new `set_origin()` / `set_y_height()` API.

## New features

* All affected readers gain an optional `video_height` argument for supplying the source frame height when the format does not record it (DeepLabCut, LightningPose, SLEAP, AnimalTA, Bonsai, FastTrack, TRex, idtracker.ai CSV, movement netCDF). When omitted, the reader falls back to source-extracted values where available, and finally to `max(y)`.
* `read_idtracker()` now reads `/height` from the trajectories h5 file by default.
* `read_trackmate()` now reads the frame height from `Settings/ImageData/@height` in the XML by default.
* `read_octron()` continues to read `video_height:` from the CSV header, but now also accepts a `video_height` override and stores the value in the aniframe metadata.
* `read_octron()` gains a `method` argument to handle frames where Octron emitted multiple mask segments for the same track (#67). One of `"weighted"` (default; area-weighted mean of position and shape props, sum of areas), `"largest"` (single largest segment per row), or `"segments"` (one row per segment, with a new `segment` identity variable).

## Bug fixes

* `read_idtracker()` now accepts both the legacy `seconds` and the newer `time` leading column in idtracker.ai CSV exports (#60).

# aniread 0.3.1

* Adds `read_aniframe` that allows you to read your saved aniframes (in `.parquet` format) back into R!
* Adds `read_movement` for importing data from the awesome *movement* Python package.
* Adds `read_c3d` for importing C3D motion capture data.
* Adds `read_fasttrack` for importing FastTrack data.
* Adds support for HDF5 DeepLabCut files in `read_deeplabcut`.

# aniread 0.3.0

* Adapt to the tidy movement data ethos implemented in *aniframe* 0.4.0.
* Adds `read_trackmate` for TrackMate XML files. Thanks to @quantixed for writing the reader function in TrackMateR, which has been adapted here.
* Adds `read_octron` for Octron CSV files.

# aniread 0.2.0

* Added a `NEWS.md` file to track changes to the package.
* Added `write_aniframe` and tests
