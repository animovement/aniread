# Generates the synthetic DeepLabCut-layout fixtures in this directory.
#
# Each DataFrame is built the way the writer it imitates builds it, and saved
# with the same pandas call. The writers, as of DeepLabCut 3.0.2:
#
# - deeplabcut/pose_estimation_pytorch/apis/videos.py::create_df_from_prediction
#   (video predictions, multi-animal with unique bodyparts under `single`):
#   df.to_hdf(output_h5, key="df_with_missing", format="table", mode="w")
# - deeplabcut/refine_training_dataset/stitch.py::TrackletStitcher.format_df and
#   write_tracks (stitched `_el.h5` tracklets):
#   df.to_hdf(output_name, key="tracks", format="table", mode="w")
# - deeplabcut/pose_estimation_3d/triangulation.py (3D, coords x, y, z only):
#   df_3d.to_hdf(..., key="df_with_missing", mode="w", format="table")
# - movement's save_poses.to_dlc_file() (scorer "movement", 3D without
#   likelihood): df.to_hdf(filepath, key="df_with_missing"), pandas' default
#   "fixed" format.
#
# DeepLabCut 3.0.2 requires pandas >= 2.2, < 3, so its files are written with
# pandas 2.2; the movement files with pandas 3. Run from this directory:
#
#   uv run --no-project --python 3.12 --with "pandas==2.2.3" --with tables \
#     make_fixtures.py dlc
#   uv run --no-project --python 3.12 --with "pandas>=3" --with tables \
#     make_fixtures.py movement
#
# Every value encodes where it belongs, so a test can tell whether it was read
# into the right row: 1000 * frame + 100 * individual + 10 * bodypart + coord,
# with individual mouse1 = 1, mouse2 = 2, single = 3 (0 when there is no
# individuals level), bodypart snout = 1, left_ear = 2, tail_base = 3,
# food_dish = 4, øre = 5, and coord x = 1, y = 2, z = 3. The 3D files use the
# non-ASCII øre to check that names keep their encoding. A likelihood is
# (10 * individual + bodypart) / 100.

import sys

import numpy as np
import pandas as pd

INDIVIDUALS = {"mouse1": 1, "mouse2": 2, "single": 3}
BODYPARTS = {"snout": 1, "left_ear": 2, "tail_base": 3, "food_dish": 4, "øre": 5}
COORDS = {"x": 1, "y": 2, "z": 3}

DLC3_SCORER = "DLC_Resnet50_openfieldOct5shuffle1_snapshot_best-200"
DLC3_TOPDOWN_SCORER = (
    "DLC_TopDownResnet50_openfieldOct5shuffle1_detector_best-150_snapshot_best-200"
)


def value(frame, individual, bodypart, coord):
    ind = INDIVIDUALS.get(individual, 0)
    bpt = BODYPARTS[bodypart]
    if coord == "likelihood":
        return (10 * ind + bpt) / 100
    return 1000 * frame + 100 * ind + 10 * bpt + COORDS[coord]


def fill(columns, frames):
    names = list(columns.names)
    rows = []
    for frame in frames:
        row = []
        for col in columns:
            label = dict(zip(names, col))
            row.append(
                value(
                    frame,
                    label.get("individuals"),
                    label["bodyparts"],
                    label["coords"],
                )
            )
        rows.append(row)
    return np.array(rows, dtype=float)


def dlc_single(n_frames=4):
    # create_df_from_prediction(), single-animal project
    cols = [[DLC3_SCORER], ["snout", "left_ear", "tail_base"], ["x", "y", "likelihood"]]
    index = pd.MultiIndex.from_product(cols, names=["scorer", "bodyparts", "coords"])
    return pd.DataFrame(fill(index, range(n_frames)), columns=index, index=range(n_frames))


def dlc_multi_unique(n_frames=4):
    # create_df_from_prediction(), multi-animal project with a unique bodypart
    scorer = DLC3_TOPDOWN_SCORER
    coords = ["x", "y", "likelihood"]
    cols_names = ["scorer", "individuals", "bodyparts", "coords"]
    cols = [[scorer], ["mouse1", "mouse2"], ["snout", "left_ear", "tail_base"], coords]
    index = pd.MultiIndex.from_product(cols, names=cols_names)
    df = pd.DataFrame(fill(index, range(n_frames)), columns=index, index=range(n_frames))
    unique_columns = [scorer], ["single"], ["food_dish"], coords
    unique_index = pd.MultiIndex.from_product(unique_columns, names=cols_names)
    df_u = pd.DataFrame(
        fill(unique_index, range(n_frames)),
        columns=unique_index,
        index=range(n_frames),
    )
    return df.join(df_u, how="outer")


def dlc_tracks():
    # TrackletStitcher.format_df(): one block per track, NaN outside each
    # track's frames, reindexed from frame 0, unique bodyparts joined under
    # `single`. mouse1 spans frames 1 to 4 and mouse2 frames 2 to 4, so
    # frame 0 is all NaN; the unique bodypart spans frames 1 to 5.
    scorer = [DLC3_SCORER]
    coords = ["x", "y", "likelihood"]
    names = ["scorer", "individuals", "bodyparts", "coords"]
    bpts = ["snout", "left_ear", "tail_base"]
    first, last = 1, 4
    columns = pd.MultiIndex.from_product([scorer, ["mouse1", "mouse2"], bpts, coords], names=names)
    inds = range(first, last + 1)
    data = fill(columns, inds)
    data[0, len(bpts) * len(coords) :] = np.nan  # mouse2 starts at frame 2
    df = pd.DataFrame(data, columns=columns, index=inds)
    df = df.reindex(range(last + 1))
    single_columns = pd.MultiIndex.from_product(
        [scorer, ["single"], ["food_dish"], coords], names=names
    )
    single_inds = range(1, 6)
    df2 = pd.DataFrame(fill(single_columns, single_inds), columns=single_columns, index=single_inds)
    return df.join(df2, how="outer")


def dlc_3d(n_frames=4):
    # triangulation.py, single-animal project
    cols = [["DLC_3D"], ["snout", "left_ear", "øre"], ["x", "y", "z"]]
    columns = pd.MultiIndex.from_product(cols, names=["scorer", "bodyparts", "coords"])
    return pd.DataFrame(fill(columns, range(n_frames)), columns=columns, index=range(n_frames))


def movement_multi(n_frames=4):
    # to_dlc_style_df(split_individuals=False), 2D
    cols = [["movement"], ["mouse1", "mouse2"], ["snout", "left_ear"], ["x", "y", "likelihood"]]
    columns = pd.MultiIndex.from_product(
        cols, names=["scorer", "individuals", "bodyparts", "coords"]
    )
    return pd.DataFrame(
        fill(columns, range(n_frames)),
        index=np.arange(n_frames, dtype=int),
        columns=columns,
        dtype=float,
    )


def movement_3d(n_frames=4):
    # to_dlc_style_df(split_individuals=True) of a one-individual 3D dataset
    cols = [["movement"], ["snout", "øre"], ["x", "y", "z"]]
    columns = pd.MultiIndex.from_product(cols, names=["scorer", "bodyparts", "coords"])
    return pd.DataFrame(
        fill(columns, range(n_frames)),
        index=np.arange(n_frames, dtype=int),
        columns=columns,
        dtype=float,
    )


def main(which):
    if which == "dlc":
        assert pd.__version__.startswith("2."), pd.__version__
        df = dlc_single()
        df.to_hdf("dlc3_single.h5", key="df_with_missing", format="table", mode="w")
        df.to_csv("dlc3_single.csv")
        df = dlc_multi_unique()
        df.to_hdf("dlc3_multi_unique.h5", key="df_with_missing", format="table", mode="w")
        df.to_csv("dlc3_multi_unique.csv")
        df = dlc_tracks()
        df.to_hdf("dlc3_tracks_el.h5", key="tracks", format="table", mode="w")
        # The same tracklets re-saved with pandas' defaults
        df.to_hdf("dlc3_tracks_fixed_el.h5", key="tracks", mode="w")
        df = dlc_3d()
        df.to_hdf("dlc3_3d.h5", key="df_with_missing", mode="w", format="table")
        df.to_csv("dlc3_3d.csv")
    elif which == "movement":
        assert pd.__version__.startswith("3."), pd.__version__
        movement_multi().to_hdf("movement_multi.h5", key="df_with_missing")
        movement_3d().to_hdf("movement_3d.h5", key="df_with_missing")
    else:
        raise SystemExit(f"Unknown fixture set: {which}")


if __name__ == "__main__":
    main(sys.argv[1])
