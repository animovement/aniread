# Changelog

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
