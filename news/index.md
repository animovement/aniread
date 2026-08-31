# Changelog

## aniread (development version)

### Added

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  reads TRex’s native `.npz` export
  ([\#116](https://github.com/animovement/aniread/issues/116)). It is a
  zip of `.npy` arrays, one file per tracked individual, so a whole
  recording is the vector of paths `get_sample_data("trex")` returns —
  which previously errored, because the registry declared TRex a
  CSV-only source. The arrays are parsed directly rather than through a
  new dependency: `.npy` is a short header over a raw buffer, and
  [`unz()`](https://rdrr.io/r/base/connections.html) reads zip members
  without unpacking.

  The `.npz` carries what the CSV export does not, so three of this
  reader’s documented limitations turn out to be limitations of the CSV
  rather than of TRex: `individual` is the identity TRex assigned
  instead of `NA`, `confidence` is its per-frame `detection_p` instead
  of `NA`, and the pose keypoints are present at all. The frame rate and
  frame size are recorded too, so `sampling_rate` is set and the
  reflection to `bottom_left` no longer has to guess the frame height
  from `max(y)`.

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  gains a `format` argument, defaulting to `"auto"`, which reads the
  export from the file rather than its extension.

### Changed

- `get_sample_data("trex")` defaults to `"five-locusts"`
  ([\#116](https://github.com/animovement/aniread/issues/116)). The
  previous default, `"beetles"`, is a 19-frame CSV excerpt with one
  unnamed individual and no confidence — too small to carry an example
  or a tutorial. `"five-locusts"` is a real 2845-frame recording of five
  individuals with pose and detection probability. `"beetles"` is still
  available, and is still the fixture exercising the CSV path.

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  treats `Inf` as missing in both exports. TRex marks a frame it could
  not track with an infinity rather than a `NaN` — its own documentation
  masks `np.inf` out before plotting — so these were reaching the
  aniframe and propagating through every downstream calculation. Uses
  [`anicore::convert_inf_to_na()`](https://animovement.dev/anicore/reference/convert_inf_to_na.html),
  added for this.

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  no longer requires the CSV’s optional columns. `VX`, `VY` and
  `timestamp` were dropped by name, which errors on a file that does not
  have them — and which columns a TRex CSV carries is set per run by its
  `output_fields` parameter.

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  declares `unit_time` as `"s"`. TRex reports seconds in both exports,
  and leaving it unset meant
  [`anicore::set_sampling_rate()`](https://animovement.dev/anicore/reference/set_sampling_rate.html)
  treated the column as frames and divided it by the frame rate.

### Added

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  reads the 9-column tidy export
  ([\#117](https://github.com/animovement/aniread/issues/117)).
  FreeMoCap added a `reprojection_error` column at v1.8.0; the reader
  accepted a file with fewer than ten columns and rejected everything
  else, so the current export was read only by accident of that
  threshold. Both the 8- and the 9-column form are now read
  deliberately.

- FreeMoCap data gains a `confidence` column, from `reprojection_error`
  where the file has one and all-`NA` where it does not. The two run in
  opposite directions — an error is a distance in pixels, so zero is
  best, while `confidence` everywhere else in aniread comes from a
  likelihood or probability where larger is best — so it is mapped
  through `1 / (1 + error)` rather than renamed. That is monotone onto
  `(0, 1]`, gives 1 for a perfect reprojection, and is invertible: the
  original error is `1 / confidence - 1`. Renaming it would have made
  `aniprocess::filter_na_across(method = "confidence")` discard the
  best-tracked points.

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  reads the `by_trajectory` export and the per-model wide files in
  `output_data/` (`mediapipe_body_3d_xyz.csv` and siblings), which it
  previously rejected
  ([\#117](https://github.com/animovement/aniread/issues/117)). Neither
  carries a frame column — the row position is the frame — and neither
  names its models in the data, so point names are parsed the way
  FreeMoCap’s own `DataSaver._parse_keypoint_name()` parses them. One
  recording therefore gives the same `model` and `keypoint` values
  whichever of the three layouts it is read from, and identical
  coordinates: checked across all 126,096 rows of the v1.8.0 release
  asset.

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  gains a `format` argument, defaulting to `"auto"`, which reads the
  layout from the column names. It follows
  [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md),
  whose `format = c("auto", ...)` is the pattern the other readers
  should converge on
  ([\#118](https://github.com/animovement/aniread/issues/118)).

- The layout a file was read as is recorded in the `source_format`
  metadata field, as `"by_frame_8col"` or `"by_frame_9col"`, so drift
  between FreeMoCap releases is visible on the aniframe rather than only
  in whether reading happened to work.

### Fixed

- `detect_freemocap_format()` no longer mistakes a `by_trajectory` file
  for a wide one. It told them apart by a `frame` column that FreeMoCap
  does not write in either; they are distinguished by the timestamps,
  which only `by_trajectory` carries.

- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  recognises FreeMoCap files written by v1.8.0 and later
  ([\#117](https://github.com/animovement/aniread/issues/117)). It
  compared the header for exact equality with the eight columns of the
  older export, so a file with `reprojection_error` was not identified
  as FreeMoCap at all and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  failed on it. The header is now matched by inclusion, which also
  survives the next column FreeMoCap appends.

### Changed

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)’s
  error names the layout it found rather than only the one it wanted.
  Told a `by_trajectory.csv` or a per-model `mediapipe_body_3d_xyz.csv`,
  it said to look for a file ending in `by_frame.csv` — unhelpful when
  the recording never produced one. Neither layout is read yet; both are
  now recognised well enough to say so.

## aniread 0.7.0 (2026-08-28)

### Added

- [`read_custom()`](https://animovement.dev/aniread/reference/read_custom.md)
  takes an `index` argument, so a frame indexed by something other than
  `time` can be read
  ([\#107](https://github.com/animovement/aniread/issues/107)). The
  index used to be smuggled in through `variables_when` and told apart
  by the literal string `"time"`; since these became separate roles in
  anicore,
  [`read_custom()`](https://animovement.dev/aniread/reference/read_custom.md)’s
  own documented example — a frame indexed by `frame` within `trial` —
  could not be expressed at all. `c("trial", "frame")` normalised to
  `"trial"`, leaving the frame indexed by a `time` column the data does
  not have.

### Changed

- The core data structures come from `anicore`, which is what the
  `aniframe` package was renamed to in its 0.8.0
  (animovement/anicore#84). The `aniframe` class keeps its name; only
  the package providing it changed, so `anicore` replaces `aniframe` in
  `Imports` and in every `aniframe::` call.

- The minimum `anicore` is 0.8.0, which is the first version published
  under that name. The constraint read `>= 0.6.0` — a version of
  `anicore` that never existed, carried over unchanged from `aniframe`
  when the dependency was renamed.

- Axis geometry is declared through `anicore`’s axis directions and
  extents, replacing `set_origin()` and `set_y_height()`, and
  `default_metadata()` follows its rename to `list_default_metadata()`.

### Fixed

- [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  and
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  cope with a run of serial-port junk before the first complete record,
  not just a single partial row
  ([\#94](https://github.com/animovement/aniread/issues/94)). The skip
  was computed from
  [`utils::count.fields()`](https://rdrr.io/r/utils/count.fields.html),
  which silently drops blank lines, so on a capture with blank lines
  among the junk it landed early — on a noise line, which was then
  accepted as a header, and the read failed with
  `Column index 4 is out of bounds`.

## aniread 0.6.0 (2026-08-18)

### Added

- [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  reads any supported format through one entry point, working out which
  source software wrote the file rather than requiring you to know in
  advance ([\#73](https://github.com/animovement/aniread/issues/73)).
  Pass `source` to name the format explicitly, or `...` to reach a
  reader’s own arguments. It returns whatever the underlying reader
  returns — an `aniframe`, or an `anievent` for
  [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md).

- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  reports which software wrote a file without reading it. Candidates are
  narrowed by suffix, then each detector inspects the contents, which
  matters because twelve sources read `.csv`. DeepLabCut and
  LightningPose export structurally identical files, so it returns the
  combined name `"deeplabcut/lightningpose"` rather than guessing.
  Detectors needing an optional package (`rhdf5`, `arrow`, `xml2`,
  `c3dr`) are skipped when it is absent, and the error names what was
  skipped.

- [`?read_trackball`](https://animovement.dev/aniread/reference/read_trackball.md)
  documents the raw Bonsai layout, the requirement that `col_time` be a
  shared clock with two sensors, and that empty time bins are filled
  with zero motion — an assumption about this logger rather than about
  optical flow generally.

### Changed

- [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
  no longer lists `csv` as a SLEAP suffix —
  [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  cannot read it, and auto-detection would have routed such files
  straight into that error. Restored when the reader gains support
  ([\#87](https://github.com/animovement/aniread/issues/87)).

- [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
  renames the `trackball` source to `trackball_bonsai`, matching the
  `source` metadata
  [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  actually stamps.

### Fixed

- [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  reads real two-sensor Bonsai optical-flow captures
  ([\#85](https://github.com/animovement/aniread/issues/85)). It
  previously either aborted with an error pointing nowhere near the
  cause, or silently returned a misaligned trajectory. Sensor alignment,
  `start_datetime`, corrupt rows, leading junk, microsecond clocks, gap
  filling and argument handling were each at fault; see the PR for the
  breakdown.

- [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  warns when `col_time` resolves to a non-datetime column and two
  sensors are given — a per-board counter has a sensor-local origin and
  cannot align two files. Warning class `aniread_sensor_local_clock`.

- [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  works out which export layout a file uses instead of being told
  ([\#88](https://github.com/animovement/aniread/issues/88)). `detailed`
  defaults to `"auto"` and reads the answer from the header. This was
  the one case where
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  identified a file correctly and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  then failed on it.

- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  recognises a Bonsai optical-flow capture whether or not it carries a
  header row.

- `ensure_header_match()` no longer rejects a character `col_time` on
  files that do have named headers.

## aniread 0.5.1

### Added

- [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
  returns the source software `aniread` can read as a tibble of `source`
  / `reader` / `suffix`, so downstream packages can discover supported
  formats programmatically instead of hard-coding them. Closes
  [\#74](https://github.com/animovement/aniread/issues/74).

### Fixed

- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
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

### Added

- [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  imports behavioural events from a [BORIS](https://www.boris.unito.it/)
  export into an
  [`anicore::anievent()`](https://animovement.dev/anicore/reference/anievent.html).
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

### Fixed

- File validation no longer rejects readable files on Windows network
  (UNC) shares.
  [`file.access()`](https://rdrr.io/r/base/file.access.html) returns
  false negatives for read permission on such paths; the read check now
  falls back to a non-destructive open attempt when
  [`file.access()`](https://rdrr.io/r/base/file.access.html) reports no
  access.

### Changed

- `aniframe (>= 0.6.0)` is now required, since
  [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  produces an `anievent` object — a new class added in aniframe 0.6.0.

## aniread 0.4.1

### Added

- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  gains a `properties` argument for picking which region-property
  columns to read (`"all"` by default; pass a character vector for a
  subset or `NULL` to skip them). `area` is auto-included when
  `method = "weighted"`.
- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  normalises hyphens to underscores in column names (`moments_hu-0` →
  `moments_hu_0`).

### Changed

- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  is now substantially faster on large multi-segment files, especially
  when only a few `properties` are requested.

### Fixed

- `read_octron(method = "weighted")` no longer silently recycles `v * a`
  when a row’s value and area columns have different segment counts; it
  falls back to the arithmetic mean for those rows and emits a single
  warning naming the affected `frame_idx` values.

## aniread 0.4.0

### Changed

- Readers whose source data uses image (top-left) origin now reflect `y`
  so the returned aniframe is in the conventional `bottom_left` origin.
  This fixes plots being upside-down without manual reorientation.
  Affects
  [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md),
  [`read_bonsai()`](https://animovement.dev/aniread/reference/read_bonsai.md),
  [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md),
  [`read_fasttrack()`](https://animovement.dev/aniread/reference/read_fasttrack.md),
  [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md),
  [`read_lightningpose()`](https://animovement.dev/aniread/reference/read_lightningpose.md),
  [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md),
  [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md),
  [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md),
  [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md),
  and
  [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  ([\#61](https://github.com/animovement/aniread/issues/61)).
- `aniframe (>= 0.5.0)` is now required, since the reflection uses the
  new `set_origin()` / `set_y_height()` API.

### Added

- All affected readers gain an optional `video_height` argument for
  supplying the source frame height when the format does not record it
  (DeepLabCut, LightningPose, SLEAP, AnimalTA, Bonsai, FastTrack, TRex,
  idtracker.ai CSV, movement netCDF). When omitted, the reader falls
  back to source-extracted values where available, and finally to
  `max(y)`.
- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  now reads `/height` from the trajectories h5 file by default.
- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  now reads the frame height from `Settings/ImageData/@height` in the
  XML by default.
- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  continues to read `video_height:` from the CSV header, but now also
  accepts a `video_height` override and stores the value in the aniframe
  metadata.
- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  gains a `method` argument to handle frames where Octron emitted
  multiple mask segments for the same track
  ([\#67](https://github.com/animovement/aniread/issues/67)). One of
  `"weighted"` (default; area-weighted mean of position and shape props,
  sum of areas), `"largest"` (single largest segment per row), or
  `"segments"` (one row per segment, with a new `segment` identity
  variable).

### Fixed

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  now accepts both the legacy `seconds` and the newer `time` leading
  column in idtracker.ai CSV exports
  ([\#60](https://github.com/animovement/aniread/issues/60)).

## aniread 0.3.2

### Added

- [`read_c3d()`](https://animovement.dev/aniread/reference/read_c3d.md)
  for C3D motion-capture data, and
  [`read_fasttrack()`](https://animovement.dev/aniread/reference/read_fasttrack.md)
  for FastTrack data.
- [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md)
  reads HDF5 exports as well as CSV.

### Fixed

- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  handles the newer Octron output format.

## aniread 0.3.1

### Added

- [`read_aniframe()`](https://animovement.dev/aniread/reference/read_aniframe.md)
  reads a saved aniframe back from parquet.
- [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  imports data from the
  [movement](https://movement.neuroinformatics.dev) Python package.
- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  reads TrackMate XML. Adapted from the reader in TrackMateR, with
  thanks to [@quantixed](https://github.com/quantixed).
- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  reads Octron CSV.
- [`calibrate_trackball()`](https://animovement.dev/aniread/reference/calibrate_trackball.md)
  for trackball calibration.

## aniread 0.3.0

### Added

- [`write_aniframe()`](https://animovement.dev/aniread/reference/write_aniframe.md)
  writes an aniframe to parquet, and
  [`write_intracktive()`](https://animovement.dev/aniread/reference/write_intracktive.md)
  exports for intracktive.
- [`read_anipose()`](https://animovement.dev/aniread/reference/read_anipose.md),
  [`read_fictrac()`](https://animovement.dev/aniread/reference/read_fictrac.md),
  [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  and
  [`read_custom()`](https://animovement.dev/aniread/reference/read_custom.md).
- [`get_sample_data()`](https://animovement.dev/aniread/reference/get_sample_data.md)
  fetches example files for the readers.

### Changed

- Adapted to the tidy movement data model introduced in aniframe 0.4.0.

## aniread 0.2.0

### Added

- The first readers:
  [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md),
  [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md),
  [`read_lightningpose()`](https://animovement.dev/aniread/reference/read_lightningpose.md),
  [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md),
  [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md),
  [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md),
  [`read_bonsai()`](https://animovement.dev/aniread/reference/read_bonsai.md),
  [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  and
  [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md),
  with
  [`validate_trackball()`](https://animovement.dev/aniread/reference/validate_trackball.md).
- A `NEWS.md` file, to track changes to the package.

## aniread 0.1.0

Package skeleton. No readers yet.
