# Package index

## Reading any file

One entry point for every supported format.
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
works out which source software wrote a file and reads it, so you do not
need to know which reader it needs beforehand.

- [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  : Read a movement or event dataset from any supported format
- [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  : Detect which source software wrote a file

## Reader functions

The format-specific readers
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
dispatches to. Call them directly when you already know the source, or
for their format-specific arguments.

- [`read_aniframe()`](https://animovement.dev/aniread/reference/read_aniframe.md)
  : Read an aniframe from a Parquet file
- [`read_animalta()`](https://animovement.dev/aniread/reference/read_animalta.md)
  : Read AnimalTA data
- [`read_anipose()`](https://animovement.dev/aniread/reference/read_anipose.md)
  : Read Anipose 3D pose estimation data
- [`read_bonsai()`](https://animovement.dev/aniread/reference/read_bonsai.md)
  : Read centroid tracking data from Bonsai
- [`read_c3d()`](https://animovement.dev/aniread/reference/read_c3d.md)
  : Read a C3D motion capture file
- [`read_custom()`](https://animovement.dev/aniread/reference/read_custom.md)
  : Read a custom file format
- [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md)
  : Read DeepLabCut data
- [`read_fasttrack()`](https://animovement.dev/aniread/reference/read_fasttrack.md)
  : Read FastTrack tracking data
- [`read_fictrac()`](https://animovement.dev/aniread/reference/read_fictrac.md)
  : Read projected FicTrac data
- [`read_freemocap()`](https://animovement.dev/aniread/reference/read_freemocap.md)
  : Read FreeMoCap motion capture data
- [`read_idtracker()`](https://animovement.dev/aniread/reference/read_idtracker.md)
  : Read idtracker.ai data
- [`read_lightningpose()`](https://animovement.dev/aniread/reference/read_lightningpose.md)
  : Read LightningPose data
- [`read_movement()`](https://animovement.dev/aniread/reference/read_movement.md)
  : Read data exported from the movement Python package
- [`read_octron()`](https://animovement.dev/aniread/reference/read_octron.md)
  : Read Octron Segmentation Data
- [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  : Read SLEAP data
- [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  : Read trackball data
- [`read_trackmate()`](https://animovement.dev/aniread/reference/read_trackmate.md)
  : Read TrackMate XML into an aniframe
- [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
  : Read TRex Movement Tracking Data

## Event-data readers

Readers for behavioural-event data — these import into an
[`anicore::anievent()`](https://animovement.dev/anicore/reference/anievent.html).

- [`read_boris()`](https://animovement.dev/aniread/reference/read_boris.md)
  : Read events from a BORIS export

## Writer functions

These functions are allow you to save your data.

- [`write_aniframe()`](https://animovement.dev/aniread/reference/write_aniframe.md)
  :

  Write an *aniframe* to disk

- [`write_intracktive()`](https://animovement.dev/aniread/reference/write_intracktive.md)
  : Write aniframe data to inTRACKtive CSV format

## Miscellaneous

- [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
  : List the source software formats aniread can read
- [`get_sample_data()`](https://animovement.dev/aniread/reference/get_sample_data.md)
  : Download sample tracking data
- [`calibrate_trackball()`](https://animovement.dev/aniread/reference/calibrate_trackball.md)
  : Get calibration values for trackball data
