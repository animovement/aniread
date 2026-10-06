# Changelog

## aniread (development version)

- Works with anicore’s `anipoint` class and rebuilt accessor API
  (animovement/anicore#154). Readers return an `anipoint`,
  [`read_aniframe()`](https://animovement.dev/aniread/reference/read_aniframe.md)
  restores an `anievent` as well as an `anipoint`, and
  [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  no longer sets spatial metadata on its `anievent`.

### Breaking changes

- [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
  lists what can be written as well as read
  ([\#135](https://github.com/animovement/aniread/issues/135)). It now
  returns one row per source and direction, with the columns `source`,
  `direction` (`"read"` or `"write"`), `fun` and `suffix`; the `reader`
  column is now `fun`. To list readers as before, filter on
  `direction == "read"`.

### Removed

- The unused output validators, `ensure_output_header_names()`,
  `ensure_output_header_class()` and `ensure_output_no_nan()`
  ([\#123](https://github.com/animovement/aniread/issues/123)). No
  reader called them — their only callers were their own tests — so
  nothing they promised was ever enforced, and the tests passing gave
  the impression that it was.

  They could not be wired in as they stood: they require exactly `time`,
  `individual`, `keypoint`, `x`, `y` and `confidence`, which is a
  narrower contract than the aniframe has had for some time. Five of the
  seven sample sources fail it —
  [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md)
  returns no `individual`,
  [`read_anipose()`](https://animovement.dev/aniread/reference/read_anipose.md)
  and
  [`read_c3d()`](https://animovement.dev/aniread/reference/read_c3d.md)
  return `z`,
  [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  returns `model`, and
  [`read_fictrac()`](https://animovement.dev/aniread/reference/read_fictrac.md)
  and
  [`read_c3d()`](https://animovement.dev/aniread/reference/read_c3d.md)
  return no `confidence`.
  [`anicore::validate_aniframe()`](https://animovement.dev/anicore/reference/anicore-deprecated.html)
  is the metadata-aware successor: it checks the frame against what it
  declares rather than against a fixed column list.

### Added

- [`write_dataset()`](https://animovement.dev/aniread/reference/write_dataset.md)
  writes to any supported format, inferring it from the file suffix, as
  the counterpart of
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  ([\#135](https://github.com/animovement/aniread/issues/135)). A `.csv`
  is written as a plain table; inTRACKtive’s CSV needs
  `format = "intracktive"`.

- A Parquet file keeps the class it was written with
  ([\#135](https://github.com/animovement/aniread/issues/135)).
  [`read_aniframe()`](https://animovement.dev/aniread/reference/read_aniframe.md)
  gave back an `anisegment` or `anijoint` as an `anipoint`, because
  arrow strips the class from a grouped frame and the reader could only
  tell an `anipoint` from an `anievent`.
  [`write_aniframe()`](https://animovement.dev/aniread/reference/write_aniframe.md)
  now records the class in the file’s metadata, as JSON under the key
  `animovement` (`{"class":["anijoint"]}`), which any language can read,
  so
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  after
  [`write_dataset()`](https://animovement.dev/aniread/reference/write_dataset.md)
  returns the same class, grouping and metadata. Files written before
  this are read as they were.

- [`write_intracktive()`](https://animovement.dev/aniread/reference/write_intracktive.md)
  writes the lineage of dividing tracks. A frame with a `parent` column,
  as
  [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  gives one for a file with dividing tracks
  ([\#182](https://github.com/animovement/aniread/issues/182)), gets
  inTRACKtive’s `parent_track_id` column: the `track_id` of the track
  each track divided from, and `-1`, inTRACKtive’s value for no parent,
  for the tracks that start a lineage. A parent that is not in the frame
  is also written as `-1`, with a warning. A frame without `parent` is
  written as before.

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  reads FreeMoCap v2’s output
  ([\#171](https://github.com/animovement/aniread/issues/171)). The tidy
  `freemocap_data_by_frame.csv`, and the `.parquet` beside it (with
  arrow installed), are read as `source_format` `"v2_by_frame"`, and the
  per-trajectory files such as `output_data/mediapipe_body_3d_xyz.csv`
  as `"v2_trajectory"`. Those per-trajectory files keep the names of
  v1’s wide per-model files but are long, so they are told apart by
  their columns. Models are named `<tracker>_<aspect>` as in v1
  (`rtmpose.left_hand` becomes `rtmpose_left_hand`). Each keypoint
  appears once per trajectory in the tidy export: the new `trajectory`
  argument chooses `"3d_xyz"` (default) or `"rigid_3d_xyz"` for the
  positions, and the centres of mass become keypoints of a
  `<tracker>_com` model, as v1’s `mediapipe_com`. v2 writes no
  timestamps, so `time` is in frames.
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  recognise the tidy CSV. The 9-column v1.8 `by_frame.csv` already read;
  it now has a test fixture written by FreeMoCap v1.8.2’s own saver, and
  `model` and `keypoint` are now always read as text, so a face keypoint
  such as `0000` can no longer be guessed to be the number 0.

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md),
  and so
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  reads idtracker.ai’s tidy CSV export, `trajectories_tidy.csv`
  (idtracker.ai 6.0.14), and its Parquet export, `trajectories.parquet`
  (6.0.13), which idtracker.ai recommends for R and for large datasets
  ([\#165](https://github.com/animovement/aniread/issues/165)). Both
  hold one row per frame and individual. The Parquet file records the
  version, frame rate, frame size and identity labels in its own
  metadata, and the tidy CSV in `attributes_tidy.json` beside it, which
  the reader reads when it is there; both are then used as for the
  `.h5`. `time` is in seconds when the frame rate is known; when it is
  not, idtracker.ai writes the frame as the time, so `time` is the frame
  counted from 0, with `unit_time` `"frame"`, as for the other exports.
  A new `format` argument names the export when the suffix and header do
  not, and which one was read is recorded in `source_format` for every
  idtracker.ai file.
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  recognises both: an idtracker.ai Parquet file was detected as an
  `"aniframe"`, since every Parquet file opens with the same bytes, and
  is now told apart by the attributes in its metadata (with arrow
  installed).

- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md),
  and so
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  keeps what a TrackMate XML records about the recording
  ([\#149](https://github.com/animovement/aniread/issues/149)). The
  frame interval in `Settings/ImageData` becomes `sampling_rate`,
  converted to Hz, and the TrackMate version on the root element becomes
  `source_version`. `sampling_rate` stays `NA` when the time unit is
  frames or not recognised. TrackMate writes an image with no time
  calibration as one second per frame, so a 1 Hz rate from a file in
  seconds may really be frames.

- Readers keep orientation where the source records it rather than
  deriving it from positions (animovement/anicore#46):

  - [`read_fictrac()`](https://animovement.dev/aniread/reference/read_fictrac.md)
    keeps FicTrac’s “integrated animal heading” as `yaw` and declares it
    as the frame’s orientation. Its movement direction, which follows
    from the path, is still not kept.
  - [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
    keeps TRex’s `ANGLE`, the direction an individual faces from its
    posture, as a declared `yaw`, reflected with `y` like the positions.
    It is read from either export when the run included it.
  - [`read_bonsai()`](https://animovement.dev/aniread/reference/read_bonsai.md)
    keeps the blob’s `Orientation` as `orientation_axis`: the angle of
    its long axis, axial rather than a heading, so it is not declared as
    orientation. It is turned with `y` when y is reflected.
  - [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
    documents that its `orientation` is scikit-image’s axial angle in
    image coordinates.

- [`read_structure()`](https://animovement.dev/aniread/reference/read_structure.md)
  reads a pose-estimation project’s skeleton as an
  [`anicore::anistructure()`](https://animovement.dev/anicore/reference/anistructure.html),
  detecting the tool from the file, alongside
  [`read_structure_deeplabcut()`](https://animovement.dev/aniread/reference/read_structure.md)
  (a project’s `config.yaml`, including multi-animal projects) and
  [`read_structure_sleap()`](https://animovement.dev/aniread/reference/read_structure.md)
  (a `.slp` file or an analysis `.h5`; body edges only, since symmetry
  edges are not segments). Attach it with
  [`anicore::set_structure()`](https://animovement.dev/anicore/reference/structures.html).
  A frame reader attaches a skeleton itself only when its data file
  carries one, as a SLEAP analysis `.h5` does; DeepLabCut keeps its
  skeleton in the project config, so a DeepLabCut frame still needs
  [`read_structure()`](https://animovement.dev/aniread/reference/read_structure.md).

- [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md),
  and so
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  keeps what a SLEAP analysis `.h5` records besides the tracks
  ([\#143](https://github.com/animovement/aniread/issues/143)). The
  skeleton is attached as the frame’s `keypoint` structure, parsed as
  [`read_structure_sleap()`](https://animovement.dev/aniread/reference/read_structure.md)
  parses it, and the SLEAP version from the file’s `provenance` record
  becomes `source_version`. The CSV export carries neither, so a frame
  read from it is unchanged.

- [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  reads AnimalTA’s detailed data files,
  `Results/Detailed_data/<video>/Arena_<a><target>.csv`, which “Run
  analyses” writes one per target. A file keeps its time and positions
  (`X` and `Y`, or `X_Smoothed` and `Y_Smoothed`) and drops the measures
  derived from them; its `arena` and `individual` are read from the file
  name, and several files can be read together as one recording. Its
  positions are in the unit of the scale set in AnimalTA, which the file
  does not record, so `unit_space` should be declared when a scale was
  set.
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  recognise these files too.

- [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  reads coordinates files tracked with AnimalTA’s “Separate head from
  tail” option. A target alone in its arena then has
  `X_Arena<a>_Ind<i>_Head` and `_Tail` columns instead of a single pair,
  which broke the reader’s pivot; they become the keypoints `head` and
  `tail` of that individual, while other targets keep `centroid`. Once
  corrected, AnimalTA saves the head and tail as two targets,
  `Ind<i>_part0` and `Ind<i>_part1`, in the coordinates file and in the
  names of the detailed data files; these read as the same `head` and
  `tail`. AnimalTA writes no centroid for such a target. A target
  renamed in AnimalTA keeps its name, with its case, as its
  `individual`.

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  (CSV export),
  [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  and
  [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  (CSV export) set `sampling_rate` from the frame rate their time column
  states ([\#149](https://github.com/animovement/aniread/issues/149)).
  None of these files records the rate, but each times its rows by
  frame: TRex and AnimalTA write a frame number beside the time, and
  idtracker.ai writes one row per frame. When every time is the frame
  number divided by one rate, to within the rounding of the time column,
  that rate is set, as a whole number when one fits; otherwise
  `sampling_rate` stays `NA`. All three sample files give their recorded
  rate: 30, 30 and 28 Hz.

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  names the individuals of an idtracker.ai `.h5` by its
  `identities_labels` attribute, the identity names set in
  idtracker.ai’s validator, rather than by position, and records its
  `width` attribute, written by newer releases, as the x extent in
  `axis_extents`
  ([\#149](https://github.com/animovement/aniread/issues/149)). A file
  whose identities were never renamed reads as before, since
  idtracker.ai then writes `"1"`, `"2"`, ….

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md),
  and so
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  keeps what an idtracker.ai `.h5` records about the recording
  ([\#146](https://github.com/animovement/aniread/issues/146)). The
  `version` attribute becomes `source_version` and `frames_per_second`
  becomes `sampling_rate`, each left `NA` when the file does not record
  it. `time` stays the frame number, so `unit_time` is still `"frame"`.
  The frame height is now read from the `height` attribute, where
  idtracker.ai writes it, so y is reflected around the frame rather than
  around the furthest tracked point. The CSV export keeps these in a
  separate `attributes.json`, so a frame read from it is unchanged.

- [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  reads SLEAP’s analysis CSV export
  ([\#87](https://github.com/animovement/aniread/issues/87)).
  [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
  advertised `csv` for SLEAP while the reader aborted with “We hope to
  support SLEAP CSV import soon!”, so the registry had been narrowed to
  `h5` as a stopgap; it advertises both again.

  The columns are `track`, `frame_idx`, `instance.score` and a
  `.x`/`.y`/`.score` triple per node, which is how sleap-io defines the
  format. Node names are read from the columns rather than assumed,
  since a recording has whatever skeleton it was tracked with, and
  `instance.score` is dropped rather than becoming a keypoint called
  `instance` — it scores the whole instance, where the h5 reader takes
  confidence from the per-node scores.

  One recording reads the same from either export, checked against the
  h5 it was generated from. Two things make that true: `time` is
  `frame_idx`, counted from 0 as the h5 counts frames; and a frame in
  which an instance was not detected comes back as an all-`NA` row
  rather than being absent, since the CSV holds a row per *instance* and
  omits those entirely — the same reinstatement
  [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  does.

- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  recognises a SLEAP analysis CSV, by the `frame_idx` and
  `instance.score` columns sleap-io uses to identify one. It previously
  inspected only HDF5 names, so a SLEAP CSV was not detected at all and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  could not route it.

- [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  records which export it read in the `source_format` metadata field.

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

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  reads the 9-column tidy export
  ([\#117](https://github.com/animovement/aniread/issues/117)).
  FreeMoCap added a `reprojection_error` column at v1.7.4; the reader
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

- [`read_c3d()`](https://animovement.dev/aniread/reference/read_c3d.md),
  [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md),
  [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  and
  [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  have examples that run
  ([\#103](https://github.com/animovement/aniread/issues/103)). They
  read new files in `inst/extdata`, each a few frames of a public
  recording: `c3d.c3d`, a Vicon Nexus static trial from pyCGM (MIT);
  `movement.nc`, movement’s two-mice sample (CC BY 4.0);
  `sleap.analysis.csv` and `sleap.analysis.h5`, two flies written by
  sleap-io from its own test data (BSD-3-Clause); and `trackmate.xml`, a
  dividing cell from TrackMate’s C. elegans example (CC BY 4.0), which
  shows the `parent` column. `inst/extdata/README.md` records where each
  came from, how it was cut, and the licence notices.

### Changed

- [`get_sample_data()`](https://animovement.dev/aniread/reference/get_sample_data.md)
  names sources as
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  does, and serves a sample for every source that has a public one
  ([\#169](https://github.com/animovement/aniread/issues/169)).
  `"idtracker"` is now `"idtrackerai"` and `"trackball"` is now
  `"trackball_bonsai"`; the old names still work but are deprecated. New
  datasets: `"octron"`, `"trackmate"` (three recordings), `"fasttrack"`,
  idtracker.ai’s CSV export (`"trajectories_csv"`), a second C3D file
  (`"sample-static"`), DeepLabCut’s wasp as CSV (`"single-wasp_csv"`),
  and SLEAP’s three Aeon mice, with named tracks (`"three-mice_Aeon"`).
  `get_sample_data("lightningpose")` now downloads the 172 kB
  `"IBL-paw_EKS-left"` by default rather than the 24 MB `"mouse-face"`,
  which is still available by name.

- [`write_intracktive()`](https://animovement.dev/aniread/reference/write_intracktive.md)
  numbers tracks by the frame’s identity keys
  ([`anicore::get_keys()`](https://animovement.dev/anicore/reference/get_keys.html))
  rather than by a fixed list of `session`, `trial`, `model`,
  `individual` and `keypoint`. A frame read by
  [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md),
  whose tracks are told apart by `track`, was written with all its
  tracks under one `track_id`; each track now gets its own. Since the
  keys are read from the aniframe’s metadata, `data` must now be an
  aniframe: a plain data frame errors, where it was written by whichever
  of those columns it had.

- The FreeMoCap v1 example files, `freemocap.csv`,
  `freemocap_by_trajectory.csv` and `freemocap_wide.csv` in
  `inst/extdata`, are now written by FreeMoCap’s own code (v1.8.2’s
  `split_and_save()`, `DataLoader` and `DataSaver`) from one synthetic
  recording, and so are distributed under aniread’s licence. They were
  excerpts of FreeMoCap’s v1.8.0 test-data release, whose licence is
  unknown.
  [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)’s
  examples therefore show other values, and the three layouts now hold
  the same points, so they can be compared row for row.
  `tests/testthat/data/freemocap/README.md` records how they were made.

- `time` is the time elapsed since the first frame of the video, so the
  first frame of the video is at `time = 0`, whatever the unit
  ([\#150](https://github.com/animovement/aniread/issues/150)). In
  frames, `time` is the frame number counted from 0, and converting it
  to seconds is a division by the frame rate with no offset; a file that
  starts later in the video keeps its offset. Sources that count frames
  from 0 (most of them) are read as they are, and sources that count
  from 1 are shifted by one. This shifts `time` for anyone indexing by
  frame number in:
  [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  (`.h5` and CSV, one frame earlier),
  [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  (`.h5`, and the CSV export and tidy CSV and Parquet exports when they
  have no frame rate, one frame earlier),
  [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  with `unit_time = "frame"` for an observation of images (one image
  earlier; a video’s frames are unchanged), and
  [`read_c3d()`](https://animovement.dev/aniread/reference/read_c3d.md),
  which now keeps the frame of the recording the file starts at from its
  header, so a trimmed file no longer starts at 0 s. Every other reader
  already started at 0. Code that picks rows by frame number from the
  SLEAP, idtracker.ai and BORIS readers needs the number one lower
  (frame `n` is now `time == n - 1`), and code that subtracted 1 to line
  them up with other sources no longer should. The “Time” section of
  [`?read_dataset`](https://animovement.dev/aniread/reference/read_dataset.md)
  lists each source’s own convention and what its reader does.

- `get_sample_data("freemocap")` downloads a real recording with a clear
  licence: movement’s FreeMoCap star-jump session (CC BY 4.0, shared by
  Max Staras), written by FreeMoCap’s own saver without the face mesh
  (animovement/movement-data#10). The default dataset, `"star-jump"`, is
  the 9-column `by_frame.csv` FreeMoCap writes from v1.7.4, with
  `reprojection_error`; `"star-jump_v1.7"` is the same recording in the
  8-column layout of earlier versions, and `"star-jump_by_trajectory"`
  and `"star-jump_wide"` are its `by_trajectory.csv` and
  `mediapipe_body_3d_xyz.csv`. The 10.7 MB 8-column file it used to
  download, `"test-data"`, whose origin and licence are unclear, is no
  longer offered. The files are cached under new names, so a cache from
  before holds no stale copy.

- `get_sample_data("movement")` downloads
  `MOVE_two-mice_octagon.analysis.nc` from SWC GIN, saved by movement
  0.17.0 or later with the singular dimension names
  ([\#167](https://github.com/animovement/aniread/issues/167)). The file
  it used to download, the same recording saved with the plural names of
  earlier versions, is the dataset `"legacy-plural"`. Both are cached
  under new file names, so a cache from before holds no stale copy.

- [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  takes the layout as
  `format = c("auto", "fixed", "variable", "detailed")`, following
  [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  and
  [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  ([\#118](https://github.com/animovement/aniread/issues/118)), and
  records it in the `source_format` metadata field. The layout
  `detailed = TRUE` named, `Frame;Time;Arena;Ind;X;Y`, is not AnimalTA’s
  detailed data but its coordinates file for a variable number of
  targets, so it is now `format = "variable"`, the one-pair-per-target
  coordinates file is `format = "fixed"`, and `format = "detailed"`
  names the detailed data files. `detailed` is deprecated:
  `detailed = TRUE` and `detailed = FALSE` still read as `"variable"`
  and `"fixed"`, with a warning.

- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  labels tracks by the name TrackMate gave them rather than by the
  numeric `TRACK_ID`
  ([\#149](https://github.com/animovement/aniread/issues/149)).
  TrackMate’s default names `Track_0`, `Track_1`, … are read as their
  numbers, `0`, `1`, …, since the column already says they are tracks,
  and a name you gave a track in TrackMate is kept as written, so a file
  with some tracks renamed reads as, say, `0`, `2` and `Cell A`. It
  falls back to `TRACK_ID` when a track has no name, or with a warning
  when two tracks would get the same id. The levels of `track` are now
  in numeric order, `2` before `10`, rather than sorted as text, with
  any names after the numbers.

- Functions carry a lifecycle badge when they are not stable
  (animovement/.github#46).
  [`read_structure()`](https://animovement.dev/aniread/reference/read_structure.md),
  [`read_structure_deeplabcut()`](https://animovement.dev/aniread/reference/read_structure.md)
  and
  [`read_structure_sleap()`](https://animovement.dev/aniread/reference/read_structure.md),
  which are new in this release, and
  [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)’s
  new `format` argument are experimental: they may still change without
  a deprecation cycle while their design settles
  ([\#118](https://github.com/animovement/aniread/issues/118)). Every
  function without a badge is stable, and changes only through a
  deprecation cycle.

- [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  names individuals by the track SLEAP recorded, rather than by position
  ([\#125](https://github.com/animovement/aniread/issues/125)). The h5
  reader read `track_names` only to count them and then labelled
  individuals `individual1`, `individual2`, …, discarding names the file
  already held — so `SLEAP_three-mice_Aeon_mixed-labels.analysis.h5`
  came back as `individual1/2/3` instead of `AEON3B_NTP/TP1/TP2`. A
  recording with no tracks, such as a single untracked instance, still
  falls back to the positional names, because there is nothing else to
  use.

  This changes the `individual` values returned for any h5 with named
  tracks. Code matching on `"individual1"` will need the real name
  instead; `levels(data$individual)` shows them.

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
  and leaving it unset meant `anicore::set_sampling_rate()` treated the
  column as frames and divided it by the frame rate.

- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)’s
  error names the layout it found rather than only the one it wanted.
  Told a `by_trajectory.csv` or a per-model `mediapipe_body_3d_xyz.csv`,
  it said to look for a file ending in `by_frame.csv` — unhelpful when
  the recording never produced one. Neither layout is read yet; both are
  now recognised well enough to say so.

### Fixed

- [`get_sample_data()`](https://animovement.dev/aniread/reference/get_sample_data.md)
  downloads every file in binary mode. It chose text mode for any suffix
  not on a list, which left out `.c3d`, `.xml` and `.npz`; on Windows,
  text mode rewrites line endings, which corrupts a binary file such as
  a C3D.

- [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  records that a trackball sensor has no fixed rate
  ([\#195](https://github.com/animovement/aniread/issues/195)). The
  sensor reports motion only as it happens, so the `sampling_rate` a
  frame is given is the rate of the windows its readings are integrated
  into, and anicore (from 0.8.0.9008) took that first declared rate for
  the device’s own as `source_sampling_rate`. `source_sampling_rate` is
  now `NaN`, anicore’s marker for a device with no fixed rate, and
  `sampling_rate` is still the window rate.

- [`write_intracktive()`](https://animovement.dev/aniread/reference/write_intracktive.md)
  writes inTRACKtive’s `t` as frame numbers counted from 0, as
  inTRACKtive reads it
  ([\#191](https://github.com/animovement/aniread/issues/191)). It wrote
  `time` unchanged, and inTRACKtive casts `t` to a whole number, so
  times in seconds collapsed several rows onto one `t` and times in
  minutes left empty frames between them. A frame whose time is already
  in frames is written as before, and the writer now stops if any of
  those times is not whole. A frame in another unit is converted with
  `anicore::convert_unit_time(data, "frame")`: by its recorded frame
  numbers when it has a `frame` column, and otherwise by its
  `sampling_rate`, so at 30 Hz times of 0, 1/30 and 2/30 seconds become
  0, 1 and 2, and TrackMate’s C. elegans sample, imaged every 2 minutes,
  becomes 0, 1, 2, …. Rather than invent frame numbers, the writer
  stops, saying how to declare the rate, when no `sampling_rate` is
  declared or the times are not regularly spaced at it. aniread now
  requires anicore 0.8.0.9008.

- [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  reads the analysis exports that sleap-io writes, as SLEAP does from
  1.6.3 on ([\#170](https://github.com/animovement/aniread/issues/170)).

  - An `.h5` written with sleap-io’s `"standard"` preset or custom axes
    failed or came back scrambled, since the reader assumed SLEAP’s
    original axis order. The order is now read from each dataset’s
    `dims` attribute, and SLEAP’s layout is assumed only where there is
    none, so files SLEAP wrote itself read as before.
  - A very old `.h5` without `point_scores` failed; it now reads with
    `NA` confidence.
  - When the `provenance` record names no SLEAP version,
    `source_version` is the sleap-io version that wrote the file, as
    `"sleap-io 0.9.2"` for example, rather than `NA`.
  - A sleap-io `.h5` spans the whole video, so frames after the last
    detection come back as `NA` rows, as undetected frames always have.
  - In the CSV, a row with an empty `track` is an untracked instance. It
    had `individual` `NA`, and an untracked recording with several
    instances in a frame failed; such rows are now named `individual1`,
    `individual2`, … by their place in the frame, as the `.h5` reader
    names the instances of a file without track names. sleap-io’s own
    `.h5` of an untracked recording names them `track_0`, `track_1`, …,
    and those names are kept. Where a track has two rows in one frame, a
    user-labelled and a predicted instance, the first, user-labelled,
    one is kept, as sleap-io’s `.h5` export keeps it. A CSV without
    score columns reads with `NA` confidence.
  - sleap-io sorts the CSV’s node columns by name, with `.score` before
    `.x` and `.y`. The reader matches them by name, so this needed no
    change, and is now tested.

- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  splits a track that divides, as a cell lineage does, into its
  branches, and records the lineage in a new `parent` column. From its
  first division such a track holds more than one spot in a frame, which
  a frame keyed by `track` and `time` cannot hold, and the reader warned
  about duplicate track-frame combinations and returned them. Each
  branch is now a track of its own, starting at its first spot after the
  division, so nothing is measured across one. The branch before the
  first division keeps the track’s id, and the others are numbered on
  from the largest track number in the file, track by track and, within
  a track, by the frame they start in, then the track they divided from,
  then x. `parent` holds the id of the track each track divided from, as
  the `P` of the Cell Tracking Challenge’s `res_track.txt` does, and is
  `NA` for a track that did not divide from another, so for every track
  of a file without divisions. It is a plain column with the levels of
  `track`, not an identity key. A track whose branches also merge is
  left whole, with the warning as before.

- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  reads the blank spatial unit (`spatialunits=" "`) that TrackMate
  writes for an image whose length unit is a space, as in files from
  TrackMate 7.13, as pixels when the pixel size is 1, as ImageJ treats
  an image with no length unit. It warned that `" "` had no equivalent
  in anicore and set `unit_space` to `"none"`, as it still does when the
  pixels are scaled.

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  no longer replaces factors with their codes when it turns the NaN
  idtracker.ai writes for a lost position into `NA`
  ([\#165](https://github.com/animovement/aniread/issues/165)). An `.h5`
  read with the keypoint `"1"` rather than `"centroid"`, and a CSV
  export of ten or more individuals mixed them up: their names sort as
  text (`"1"`, `"10"`, `"11"`, `"2"`, …), so individual 10 was named
  `"2"`. The individuals of a CSV export are now also ordered by number.

- [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md),
  and so
  [`read_lightningpose()`](https://animovement.dev/aniread/reference/read_lightningpose.md)
  and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  reads every DeepLabCut-layout file it rejected or misread
  ([\#168](https://github.com/animovement/aniread/issues/168)):

  - An `.h5` in pandas’ “fixed” format, which is what pandas writes by
    default and so what movement’s `to_dlc_file()` and any other re-save
    produce. Only DeepLabCut’s own “table” format was read, so
    movement’s DBTravelator sample files aborted.
  - Stitched multi-animal tracklets (`*_el.h5`), which DeepLabCut keeps
    under the HDF key `tracks` rather than `df_with_missing`.
    [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
    recognises them too; a SLEAP analysis file, which has a `tracks`
    dataset rather than a group, is not taken for one.
  - 3D files, from DeepLabCut’s triangulation or movement, whose coords
    are `x`, `y` and `z` with no likelihood. `confidence` is `NA`, the
    aniframe is 3D, and y is not reflected, since triangulated positions
    are not in image pixels; `video_height` is not used.
  - Multi-animal `.h5` files. The check for an `individuals` level read
    the attributes of the wrong node, so it never found one, and a
    multi-animal file was parsed as single-animal: there was no
    `individual` column, the individuals came back as keypoints, and the
    values did not belong to the keypoints they were on.
  - Multi-animal `.csv` files whose bodyparts or individuals have an
    underscore in their name, such as `left_ear`. The names were split
    at the underscore and the reader aborted.
  - `.h5` files with a bodypart or individual name outside ASCII, which
    aborted.
  - Lightning Pose’s Ensemble Kalman Smoother output, which has nine
    coords per keypoint. The ensemble medians and the ensemble and
    posterior variances became extra keypoints such as `nose_x_ens` and
    stray `median` and `var` columns; now `x`, `y` and `likelihood` are
    read and the rest is not. Its multi-camera 3D output,
    `multicam_3d_results.csv`, aborted and now reads as 3D.

  A multi-animal project tracks the bodyparts it does not assign to an
  animal, its unique bodyparts, under the pseudo-individual `single`;
  these are kept as the keypoints of an individual called `"single"`.
  The header is read from the file’s own levels in every case, so the
  `.csv` and `.h5` of the same data read the same, and the `time` read
  from an `.h5` is a plain vector rather than a one-dimensional array. A
  missing value from an `.h5` is `NA` rather than `NaN`, as it is from a
  `.csv`.

- [`get_sample_data()`](https://animovement.dev/aniread/reference/get_sample_data.md)
  downloads the movement sample datasets from their new home, [SWC
  GIN](https://gin.swc.ucl.ac.uk/neuroinformatics/movement-sample-data).
  They moved from G-Node GIN, which was often unreachable and made these
  downloads time out (neuroinformatics-unit/movement#1080). The file
  paths are unchanged.

- [`read_fictrac()`](https://animovement.dev/aniread/reference/read_fictrac.md)
  reads `.dat` files from every FicTrac 2 release
  ([\#172](https://github.com/animovement/aniread/issues/172)). It named
  25 columns whatever the file held, so the 23 columns written by
  FicTrac 2.0 to 2.02, and the 24 written by untagged versions from July
  2019 until 2.03, failed to read. The column count now decides the
  names, and `time` comes from the time since midnight where the file
  has one (column 25 from FicTrac 2.03 on, column 22 in a 24-column
  file) and from the timestamp in column 22 of a 23-column file. A file
  with any other number of columns gets an error saying so.

- [`read_fictrac()`](https://animovement.dev/aniread/reference/read_fictrac.md)
  keeps `time` running forward when a recording crosses midnight
  ([\#149](https://github.com/animovement/aniread/issues/149),
  [\#172](https://github.com/animovement/aniread/issues/172)). The time
  since midnight that it reads starts again from zero at midnight, so
  `time` jumped back by a day there. A drop of more than twelve hours
  between two rows now adds a day from that row on.

- [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  sets `sampling_rate` for an observation of several media files
  ([\#173](https://github.com/animovement/aniread/issues/173)). BORIS
  lists one FPS per file in a single cell, such as `25.000;25.000`,
  which did not parse as a number, so the rate was left out. It is now
  set when the files agree.

- [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  puts a behaviour without a category in the `"behavior"` channel when
  reading an aggregated export from current BORIS
  ([\#173](https://github.com/animovement/aniread/issues/173)). That
  export writes `"Not defined"` in the `Behavioral category` column
  where older exports and the tabular export leave it empty, so such
  behaviours landed in a channel called `"Not defined"`.

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  reads an idtracker.ai CSV export that has no time column
  ([\#149](https://github.com/animovement/aniread/issues/149)).
  idtracker.ai writes none when it could not read the video’s frame
  rate, and the reader aborted with “Column `time` doesn’t exist”.
  `time` is now the frame number, the row counted from 0 as the `.h5`
  reader counts frames, with `unit_time` `"frame"` and `sampling_rate`
  `NA`.

- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md),
  and so
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  recognises idtracker.ai’s `trajectories.csv` whatever its time column:
  `seconds`, the `time` that newer releases write, or none. It
  recognised only `seconds`, although
  [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  has read `time` since
  [\#60](https://github.com/animovement/aniread/issues/60).

- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  (CSV export),
  [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  and
  [`read_bonsai()`](https://animovement.dev/aniread/reference/read_bonsai.md)
  declare `unit_time` as `"s"`
  ([\#148](https://github.com/animovement/aniread/issues/148),
  [\#149](https://github.com/animovement/aniread/issues/149)). Their
  `time` is in seconds, but the metadata said frames, so anything that
  reads the unit misread it:
  [`anicore::convert_unit_time()`](https://animovement.dev/anicore/reference/convert_unit_time.html)
  divided the seconds by the frame rate, and speeds came out per frame
  rather than per second. The `time` values are unchanged, but results
  that depend on the unit will differ.
  [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  keeps `"frame"` for the `.h5`, whose `time` is the frame number.

- [`read_bonsai()`](https://animovement.dev/aniread/reference/read_bonsai.md)
  reflects y around the frame height the file records
  ([\#149](https://github.com/animovement/aniread/issues/149)). A
  workflow that writes the image alongside the centroid writes its
  `Size.Width` and `Size.Height` on every row, but the reader reflected
  y around the largest tracked y, so every y was off by the difference:
  254 px on the 1080 px frame of the test file. When every image in the
  file has the same size, that size is now used, and recorded as the
  `axis_extents` of x and y. `video_height` still takes precedence.

- [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  keeps individuals in different arenas apart with an `arena` identity
  key ([\#149](https://github.com/animovement/aniread/issues/149)).
  AnimalTA numbers individuals from 0 within each arena, and the reader
  dropped the `Arena` column of the layout for a variable number of
  targets, formerly called detailed, so in a file with several arenas
  the first individual of every arena became one individual with several
  rows per time. The aniframe now has an `arena` column, AnimalTA’s
  arena number, and its keys are `arena`, `individual` and `keypoint`,
  so functions that work per individual keep arenas apart. `individual`
  is AnimalTA’s name for the target, `Ind<i>`, in every layout: it was
  `0`, `1`, … in the variable layout and `arena0_ind0`, … in the fixed
  one. A corrected file, where AnimalTA writes `Ind` as `Ind0`, `Ind1`,
  …, gives the same names. Every layout has the `arena` column, also for
  a file with a single arena.

- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  declares `unit_space` as `"cm"`
  ([\#149](https://github.com/animovement/aniread/issues/149)). TRex
  gives positions in centimetres in both exports, but the metadata said
  pixels, so anything that reads the unit misread them. The positions
  are unchanged. TRex converts with its `cm_per_pixel`, which assumes an
  image 30 cm wide unless the real width was set, so the centimetres are
  only as real as that setting. The `.npz` export’s frame width is now
  recorded too, as the x extent in `axis_extents`.

- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  reflects y around the height of the image in the unit of the
  positions, `height * pixelheight` from `Settings/ImageData`, rather
  than around `height` in pixels
  ([\#149](https://github.com/animovement/aniread/issues/149)). In a
  file calibrated in microns or any other unit than pixels, every y was
  off by the difference.

- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  reads files in any time or space unit
  ([\#149](https://github.com/animovement/aniread/issues/149)). It
  recognised only `"sec"`, `"pixel"` and `"micron"`, and aborted on
  anything else, such as `"frame"`, `"min"`, `"msec"` or `"µm"`.
  TrackMate’s units are now mapped onto anicore’s, and one with no
  equivalent, such as days or inches, becomes `"unknown"` or `"none"`
  with a warning.

- [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  keeps the `confidence` of each point
  ([\#149](https://github.com/animovement/aniread/issues/149)). It was
  read from the file and never joined, so every frame came back without
  one.

- [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  reads 3D files
  ([\#149](https://github.com/animovement/aniread/issues/149)). The axes
  were fixed at `x` and `y`, so a dataset whose `space` coordinate holds
  `x`, `y` and `z` aborted; they are now read from `space`.

- [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  and
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  read files saved by movement 0.17.0 and later
  ([\#167](https://github.com/animovement/aniread/issues/167)). movement
  renamed the dimensions `individuals` and `keypoints` to `individual`
  and `keypoint`, so these files were not detected and
  [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  aborted with “Object ‘individuals’ does not exist”. Both names are now
  read, so files saved by earlier versions keep reading. Along with the
  rename:

  - A `confidence` scored per individual, with dimensions (`time`,
    `individual`), which movement accepts since 0.17.0, is repeated for
    every keypoint of that individual.
  - A file without a `source_file` attribute, such as a dataset movement
    built from arrays, takes the name of the file read as its `filename`
    rather than aborting.
  - A movement bounding boxes dataset or a multi-view dataset now aborts
    with a message saying it is not a single-view poses dataset, rather
    than with an error from deep inside the reader.

- [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  reads files that movement saved without a frame rate
  ([\#149](https://github.com/animovement/aniread/issues/149)). movement
  then writes `time_unit = "frames"` and no `fps`, and the reader
  aborted because `"frames"` is not one of anicore’s units. It now
  becomes `"frame"`, and `sampling_rate` stays `NA` rather than becoming
  an empty number.

- [`write_aniframe()`](https://animovement.dev/aniread/reference/write_aniframe.md)
  writes `.csv` files comma-separated
  ([\#136](https://github.com/animovement/aniread/issues/136)). It
  passed the call to
  [`vroom::vroom_write()`](https://vroom.tidyverse.org/reference/vroom_write.html),
  whose default delimiter is a tab, so `.csv` and `.tsv` both came out
  tab-separated. The delimiter now follows the extension — a comma for
  `.csv`, a tab for `.tsv` — and an explicit `delim` still wins.

- `detect_freemocap_format()` no longer mistakes a `by_trajectory` file
  for a wide one. It told them apart by a `frame` column that FreeMoCap
  does not write in either; they are distinguished by the timestamps,
  which only `by_trajectory` carries.

- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  recognises FreeMoCap files written by v1.7.4 and later
  ([\#117](https://github.com/animovement/aniread/issues/117)). It
  compared the header for exact equality with the eight columns of the
  older export, so a file with `reprojection_error` was not identified
  as FreeMoCap at all and
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  failed on it. The header is now matched by inclusion, which also
  survives the next column FreeMoCap appends.

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
