# aniread 0.5.0 (development version)

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
