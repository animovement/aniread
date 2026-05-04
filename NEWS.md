# aniread 0.4.0

## Breaking changes

* Readers whose source data uses image (top-left) origin now reflect `y` so the returned aniframe is in the conventional `bottom_left` origin. This fixes plots being upside-down without manual reorientation. Affects `read_animalta()`, `read_bonsai()`, `read_deeplabcut()`, `read_fasttrack()`, `read_idtracker()`, `read_lightningpose()`, `read_movement()`, `read_octron()`, `read_sleap()`, `read_trackmate()`, and `read_trex()` (#61).
* `aniframe (>= 0.5.0)` is now required, since the reflection uses the new `set_origin()` / `set_y_height()` API.

## New features

* All affected readers gain an optional `video_height` argument for supplying the source frame height when the format does not record it (DeepLabCut, LightningPose, SLEAP, AnimalTA, Bonsai, FastTrack, TRex, idtracker.ai CSV, movement netCDF). When omitted, the reader falls back to source-extracted values where available, and finally to `max(y)`.
* `read_idtracker()` now reads `/height` from the trajectories h5 file by default.
* `read_trackmate()` now reads the frame height from `Settings/ImageData/@height` in the XML by default.
* `read_octron()` continues to read `video_height:` from the CSV header, but now also accepts a `video_height` override and stores the value in the aniframe metadata.

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
