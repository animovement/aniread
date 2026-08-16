# Changelog

## aniread 0.5.1.9000 (development version)

### Bug fixes

- [`read_trackball()`](http://animovement.dev/aniread/reference/read_trackball.md)
  can now read real two-sensor Bonsai optical-flow captures
  ([\#85](https://github.com/animovement/aniread/issues/85)). Previously
  it either aborted with an error pointing nowhere near the cause, or
  silently returned a misaligned trajectory. In detail:

  - **Sensor alignment.**
    [`read_opticalflow()`](http://animovement.dev/aniread/reference/read_opticalflow.md)
    zeroed each file to its own start time, which destroyed the offset
    between the two sensors — the only thing
    [`join_trackball_files()`](http://animovement.dev/aniread/reference/join_trackball_files.md)
    can align them on. Its shared-window logic could therefore never
    fire, and a sensor that started 4.2 s late was silently shifted to t
    = 0.
    [`read_opticalflow()`](http://animovement.dev/aniread/reference/read_opticalflow.md)
    now returns time on an absolute scale and the caller chooses the
    origin.
  - **`start_datetime` agrees with `time`.** `time = 0` is the first
    sample both sensors recorded, and the `start_datetime` metadata is
    the wall-clock instant of that sample. The two previously disagreed
    by the sensor offset.
  - **Corrupt rows.** Serial capture drops characters, so short rows are
    normal. One such row used to abort the read with
    `missing value where TRUE/FALSE needed` or
    `'from' must be a finite number`. Malformed rows are now dropped,
    with the count reported when `quiet = FALSE`.
  - **Leading junk.** The reader hardcoded `skip = 2` and then took the
    next line as a header, discarding two real data rows from a file
    with one junk line and three from a file with none. The leading junk
    is now detected by field count, and headerless files are read as
    such.
  - **Microsecond clocks.** Auto-detection divided by the median
    timestamp step, which is 0 when more than half the timestamps repeat
    — the microsecond clock was then never scaled and the time grid
    exploded. Zero-length and missing steps are now excluded.
  - **Gap filling.** The one-sensor path did not back-fill empty time
    bins while the two-sensor path did, so the same gappy input produced
    different time grids. Both now produce a regular grid.
  - **Argument handling.** `setup` is now
    [`match.arg()`](https://rdrr.io/r/base/match.arg.html)d, so omitting
    it no longer fails with `the condition has length > 1` and a typo
    gives an informative error.
    [`read_trackball()`](http://animovement.dev/aniread/reference/read_trackball.md)
    now calls the previously orphaned
    [`validate_trackball()`](http://animovement.dev/aniread/reference/validate_trackball.md),
    so `of_free` with a single file errors up front instead of failing
    later in `compute_xy_coordinates_free()`. `quiet` is now honoured.

- [`read_trackball()`](http://animovement.dev/aniread/reference/read_trackball.md)
  warns when `col_time` resolves to a non-datetime column and two
  sensors are given. A per-board device counter has a sensor-local
  origin and cannot cross-reference two files — in the dataset behind
  [\#85](https://github.com/animovement/aniread/issues/85) the two
  counters differ by 36.8 s while the true offset is 4.2 s. Use the PC
  datetime column instead. The warning has class
  `aniread_sensor_local_clock`.

- `ensure_header_match()` no longer rejects a character `col_time` on
  files that *do* have named headers; it now aborts only when the file
  is headerless.

### Documentation

- [`?read_trackball`](http://animovement.dev/aniread/reference/read_trackball.md)
  documents the raw Bonsai layout
  (`dx, dy, device_clock_us, pc_datetime, interval_s`), the requirement
  that `col_time` be a shared clock when two sensors are given, and that
  empty time bins are filled with zero motion — a deliberate assumption
  about this logger, which emits no row while the ball is still, rather
  than a general claim about optical flow.

## aniread 0.5.1

### New features

- [`get_supported_sources()`](http://animovement.dev/aniread/reference/get_supported_sources.md)
  returns the source software `aniread` can read as a tibble of `source`
  / `reader` / `suffix`, so downstream packages can discover supported
  formats programmatically instead of hard-coding them. Closes
  [\#74](https://github.com/animovement/aniread/issues/74).

### Bug fixes

- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  no longer drops frames in which nothing was detected. Octron omits
  such frames entirely; the reader now reinstates them as all-NA rows
  across the full track × frame grid (using the analysed-frame count
  from the CSV header) so the time axis is gap-free. Closes
  [\#80](https://github.com/animovement/aniread/issues/80).
- `read_boris(unit_time = "frame")` no longer fails on exports with an
  inconsistent image index (e.g. a STOP on the last video frame recorded
  as frame 1, giving `stop < start`). When FPS is known, the offending
  frame interval is recovered from `round(time_s * fps)`. Closes
  [\#81](https://github.com/animovement/aniread/issues/81).

## aniread 0.5.0

### New features

- [`read_boris()`](http://animovement.dev/aniread/reference/read_boris.md)
  imports behavioural events from a [BORIS](https://www.boris.unito.it/)
  export into an
  [`aniframe::anievent()`](https://animovement.dev/aniframe/reference/anievent.html).
  Supports the two flat-text BORIS exports — **aggregated events** (one
  row per bout) and **tabular events** (one row per START / STOP / POINT
  transition; paired into bouts by the reader) — and auto-detects the
  format from the file’s first row. Channels are taken from BORIS’s
  `Behavioral category` when populated, falling back to the literal
  `"behavior"`; modifiers travel via the `modifiers` list-column in both
  the newer multi-column
  (`Modifier `[`#1`](https://github.com/animovement/aniread/issues/1),
  `Modifier `[`#2`](https://github.com/animovement/aniread/issues/2), …)
  and the legacy single-column pipe-separated layouts. State-vs-point
  classification is recorded in `metadata$variables_event`.
  `unit_time = "s"` (default) reads `Start (s)` / `Stop (s)`; pass
  `unit_time = "frame"` to use the image-index columns instead, which
  keeps event timestamps row-aligned with a host aniframe (and falls
  back to seconds when no image-index columns are present). FPS is
  recorded as `sampling_rate` metadata without rescaling timestamps.
  Closes [\#76](https://github.com/animovement/aniread/issues/76).

### Bug fixes

- File validation no longer rejects readable files on Windows network
  (UNC) shares.
  [`file.access()`](https://rdrr.io/r/base/file.access.html) returns
  false negatives for read permission on such paths; the read check now
  falls back to a non-destructive open attempt when
  [`file.access()`](https://rdrr.io/r/base/file.access.html) reports no
  access.

### Dependencies

- `aniframe (>= 0.6.0)` is now required, since
  [`read_boris()`](http://animovement.dev/aniread/reference/read_boris.md)
  produces an `anievent` object — a new class added in aniframe 0.6.0.

## aniread 0.4.1

### New features

- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  gains a `properties` argument for picking which region-property
  columns to read (`"all"` by default; pass a character vector for a
  subset or `NULL` to skip them). `area` is auto-included when
  `method = "weighted"`.
- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  normalises hyphens to underscores in column names (`moments_hu-0` →
  `moments_hu_0`).

### Performance

- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  is now substantially faster on large multi-segment files, especially
  when only a few `properties` are requested.

### Bug fixes

- `read_octron(method = "weighted")` no longer silently recycles `v * a`
  when a row’s value and area columns have different segment counts; it
  falls back to the arithmetic mean for those rows and emits a single
  warning naming the affected `frame_idx` values.

## aniread 0.4.0

### Breaking changes

- Readers whose source data uses image (top-left) origin now reflect `y`
  so the returned aniframe is in the conventional `bottom_left` origin.
  This fixes plots being upside-down without manual reorientation.
  Affects
  [`read_animalta()`](http://animovement.dev/aniread/reference/read_animalta.md),
  [`read_bonsai()`](http://animovement.dev/aniread/reference/read_bonsai.md),
  [`read_deeplabcut()`](http://animovement.dev/aniread/reference/read_deeplabcut.md),
  [`read_fasttrack()`](http://animovement.dev/aniread/reference/read_fasttrack.md),
  [`read_idtracker()`](http://animovement.dev/aniread/reference/read_idtracker.md),
  [`read_lightningpose()`](http://animovement.dev/aniread/reference/read_lightningpose.md),
  [`read_movement()`](http://animovement.dev/aniread/reference/read_movement.md),
  [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md),
  [`read_sleap()`](http://animovement.dev/aniread/reference/read_sleap.md),
  [`read_trackmate()`](http://animovement.dev/aniread/reference/read_trackmate.md),
  and
  [`read_trex()`](http://animovement.dev/aniread/reference/read_trex.md)
  ([\#61](https://github.com/animovement/aniread/issues/61)).
- `aniframe (>= 0.5.0)` is now required, since the reflection uses the
  new `set_origin()` / `set_y_height()` API.

### New features

- All affected readers gain an optional `video_height` argument for
  supplying the source frame height when the format does not record it
  (DeepLabCut, LightningPose, SLEAP, AnimalTA, Bonsai, FastTrack, TRex,
  idtracker.ai CSV, movement netCDF). When omitted, the reader falls
  back to source-extracted values where available, and finally to
  `max(y)`.
- [`read_idtracker()`](http://animovement.dev/aniread/reference/read_idtracker.md)
  now reads `/height` from the trajectories h5 file by default.
- [`read_trackmate()`](http://animovement.dev/aniread/reference/read_trackmate.md)
  now reads the frame height from `Settings/ImageData/@height` in the
  XML by default.
- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  continues to read `video_height:` from the CSV header, but now also
  accepts a `video_height` override and stores the value in the aniframe
  metadata.
- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  gains a `method` argument to handle frames where Octron emitted
  multiple mask segments for the same track
  ([\#67](https://github.com/animovement/aniread/issues/67)). One of
  `"weighted"` (default; area-weighted mean of position and shape props,
  sum of areas), `"largest"` (single largest segment per row), or
  `"segments"` (one row per segment, with a new `segment` identity
  variable).

### Bug fixes

- [`read_idtracker()`](http://animovement.dev/aniread/reference/read_idtracker.md)
  now accepts both the legacy `seconds` and the newer `time` leading
  column in idtracker.ai CSV exports
  ([\#60](https://github.com/animovement/aniread/issues/60)).

## aniread 0.3.1

- Adds `read_aniframe` that allows you to read your saved aniframes (in
  `.parquet` format) back into R!
- Adds `read_movement` for importing data from the awesome *movement*
  Python package.
- Adds `read_c3d` for importing C3D motion capture data.
- Adds `read_fasttrack` for importing FastTrack data.
- Adds support for HDF5 DeepLabCut files in `read_deeplabcut`.

## aniread 0.3.0

- Adapt to the tidy movement data ethos implemented in *aniframe* 0.4.0.
- Adds `read_trackmate` for TrackMate XML files. Thanks to
  [@quantixed](https://github.com/quantixed) for writing the reader
  function in TrackMateR, which has been adapted here.
- Adds `read_octron` for Octron CSV files.

## aniread 0.2.0

- Added a `NEWS.md` file to track changes to the package.
- Added `write_aniframe` and tests
