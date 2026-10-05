# FreeMoCap fixtures

## `v2/` and `inst/extdata/freemocap_v2.csv`

FreeMoCap v2 output, written by skellyforge's own writers (skellyforge main
`b96272b`, `skellyforge/skellymodels/managers/actor.py`), called the way
FreeMoCap main `75c8acc` (v2.0.0-alpha.25) calls them in
`freemocap/core/tasks/mocap/mocap_helpers/skeleton_from_mediapipe_observations.py`:
`Human.from_tracked_points_numpy_array()`, `fix_hands_to_wrist()`, `calculate()`,
then `save_out_csv_data()`, `save_out_all_data_csv()` and
`save_out_all_data_parquet()`.

- `inst/extdata/freemocap_v2.csv` is `freemocap_data_by_frame.csv`.
- `v2/freemocap_data_by_frame.parquet` is the Parquet file beside it.
- `v2/rtmpose_<aspect>_<trajectory>.csv` are the per-trajectory files.

The input positions are synthetic (seeded random numbers, three frames). The
RTMPose model is used with its aspect order cut to body and left hand, to keep
the files small. FreeMoCap's main pipeline attaches no reprojection error to the
skeleton, so `reprojection_error` is empty, as in real v2 output.

Regenerate with `make_v2.py`, in an environment with skellyforge installed:

```sh
git clone https://github.com/freemocap/skellyforge && git -C skellyforge checkout b96272b
uv venv && uv pip install ./skellyforge pydantic
.venv/bin/python make_v2.py out
```

## `v1.8/recording_by_frame.csv`

A 9-column `by_frame.csv` as FreeMoCap v1.8 writes it, from v1.8.2's own
`DataSaver.save_to_tidy_csv()` (`freemocap/data_layer/data_saver/data_saver.py`
at tag `v1.8.2`). `make_v18.py` runs that method on a per-frame dictionary of
synthetic positions and reprojection errors, in the shape
`DataLoader.load_frame_data().to_dict()` returns, with no timestamps directory
(so the timestamps are empty). Regenerate with
`python make_v18.py <freemocap clone> v1.8/recording_by_frame.csv`, needing only
numpy and pandas.

## Licence

The data in `v2/`, `v1.8/` and `inst/extdata/freemocap_v2.csv` are synthetic and
were generated for aniread, so they are distributed under aniread's licence.
FreeMoCap and skellyforge (AGPL-3.0) only formatted them; no upstream recording
is included. The Parquet file's metadata carries skellyforge's RTMPose model
description (keypoint names and segment definitions), as every Parquet file
skellyforge writes does.
