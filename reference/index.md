# Package index

## Reader functions

These functions are the links between R and your movement data.

- [`read_aniframe()`](http://animovement.dev/aniread/reference/read_aniframe.md)
  : Read an aniframe from a Parquet file
- [`read_animalta()`](http://animovement.dev/aniread/reference/read_animalta.md)
  : Read AnimalTA data
- [`read_anipose()`](http://animovement.dev/aniread/reference/read_anipose.md)
  : Read Anipose 3D pose estimation data
- [`read_bonsai()`](http://animovement.dev/aniread/reference/read_bonsai.md)
  : Read centroid tracking data from Bonsai
- [`read_c3d()`](http://animovement.dev/aniread/reference/read_c3d.md) :
  Read a C3D motion capture file
- [`read_custom()`](http://animovement.dev/aniread/reference/read_custom.md)
  : Read a custom file format
- [`read_deeplabcut()`](http://animovement.dev/aniread/reference/read_deeplabcut.md)
  : Read DeepLabCut data
- [`read_fasttrack()`](http://animovement.dev/aniread/reference/read_fasttrack.md)
  : Read FastTrack tracking data
- [`read_fictrac()`](http://animovement.dev/aniread/reference/read_fictrac.md)
  : Read projected FicTrac data
- [`read_freemocap()`](http://animovement.dev/aniread/reference/read_freemocap.md)
  : Read FreeMoCap motion capture data
- [`read_idtracker()`](http://animovement.dev/aniread/reference/read_idtracker.md)
  : Read idtracker.ai data
- [`read_lightningpose()`](http://animovement.dev/aniread/reference/read_lightningpose.md)
  : Read LightningPose data
- [`read_movement()`](http://animovement.dev/aniread/reference/read_movement.md)
  : Read data exported from the movement Python package
- [`read_octron()`](http://animovement.dev/aniread/reference/read_octron.md)
  : Read Octron Segmentation Data
- [`read_sleap()`](http://animovement.dev/aniread/reference/read_sleap.md)
  : Read SLEAP data
- [`read_trackball()`](http://animovement.dev/aniread/reference/read_trackball.md)
  : Read trackball data
- [`read_trackmate()`](http://animovement.dev/aniread/reference/read_trackmate.md)
  : Read TrackMate XML into an aniframe
- [`read_trex()`](http://animovement.dev/aniread/reference/read_trex.md)
  : Read TRex Movement Tracking Data

## Event-data readers

Readers for behavioural-event data — these import into an
[`aniframe::anievent()`](http://animovement.dev/aniframe/reference/anievent.md).

- [`read_boris()`](http://animovement.dev/aniread/reference/read_boris.md)
  : Read events from a BORIS export

## Writer functions

These functions are allow you to save your data.

- [`write_aniframe()`](http://animovement.dev/aniread/reference/write_aniframe.md)
  :

  Write an *aniframe* to disk

- [`write_intracktive()`](http://animovement.dev/aniread/reference/write_intracktive.md)
  : Write aniframe data to inTRACKtive CSV format

## Miscellaneous

- [`get_sample_data()`](http://animovement.dev/aniread/reference/get_sample_data.md)
  : Download sample tracking data
- [`calibrate_trackball()`](http://animovement.dev/aniread/reference/calibrate_trackball.md)
  : Get calibration values for trackball data
