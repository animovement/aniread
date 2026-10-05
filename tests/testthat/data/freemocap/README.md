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

## `inst/extdata/freemocap*.csv` (v1) and `v1.7/recording_by_frame.csv`

One synthetic recording, written by FreeMoCap v1's own code with
`make_v1.py`:

- `inst/extdata/freemocap.csv` is `recording_by_frame.csv` from v1.8.2, the
  9-column tidy export (with `reprojection_error`, which FreeMoCap added at
  v1.7.4).
- `inst/extdata/freemocap_by_trajectory.csv` is `recording_by_trajectory.csv`
  from v1.8.2.
- `inst/extdata/freemocap_wide.csv` is `output_data/mediapipe_body_3d_xyz.csv`,
  the per-model wide file, from v1.8.2.
- `v1.7/recording_by_frame.csv` is `recording_by_frame.csv` from v1.7.3, the
  8-column tidy export, of the same recording. v1.7.3 writes the same
  `by_trajectory` and wide files as v1.8.2, byte for byte.

`make_v1.py` takes these modules unchanged from a FreeMoCap clone at the given
tag and runs them as FreeMoCap does after processing a recording:
`core_processes/post_process_skeleton_data/split_and_save.py` writes the
per-model wide files and `.npy` files from a skeleton array,
`data_layer/data_saver/data_loader.py` reads them back with the centre-of-mass
and reprojection-error `.npy` files, and `data_layer/data_saver/data_saver.py`'s
`DataSaver.save_all()` writes the `by_frame` and `by_trajectory` files. Only
skellytracker's model info is replaced, by a stub with MediaPipe's first 13
body landmarks, one point for each hand and the face, and two centre-of-mass
segments, to keep the files small; and of `path_getters.py` only the three
folder lookups the loader calls are taken, since the rest needs the GUI. The
positions, centres of mass and reprojection errors are seeded random numbers,
three frames. There is no timestamps folder, so the timestamps are empty, as
FreeMoCap writes them for a recording without one.

Regenerate with numpy, pandas and pydantic (FreeMoCap v1.8.2's lock pins numpy
1.26.2, pandas 2.1.4 and pydantic 2.11.9, which were used):

```sh
git clone https://github.com/freemocap/freemocap
python make_v1.py freemocap v1.8.2 out/v1.8.2
python make_v1.py freemocap v1.7.3 out/v1.7.3
```

These replace excerpts of FreeMoCap's v1.8.0 test-data release asset, whose
licence is unknown, and `freemocap_test_data_by_frame.csv`, an 8-column file of
unclear origin.

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

Every file here and every `inst/extdata/freemocap*.csv` holds synthetic data
generated for aniread, so they are distributed under aniread's licence.
FreeMoCap and skellyforge (AGPL-3.0) only formatted them; no upstream recording
is included. The Parquet file's metadata carries skellyforge's RTMPose model
description (keypoint names and segment definitions), as every Parquet file
skellyforge writes does.
