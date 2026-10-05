# Generates the synthetic Ensemble Kalman Smoother (EKS) fixtures in this
# directory, laid out as EKS 4.6.2 (paninski-lab/eks, MIT) writes them:
#
# - eks/singlecam_smoother.py: the labels below, a MultiIndex from
#   eks/utils.py::make_dlc_pandas_index() (scorer "ensemble-kalman_tracker"),
#   saved with df_smoothed.to_csv(save_file).
# - eks/multicam_smoother.py: the per-camera files have the same labels; with a
#   calibration, the 3D latents go to multicam_3d_results.csv with labels x, y,
#   z and their posterior variances, saved with df_3d.to_csv(...).
#
# Run from this directory:
#
#   uv run --no-project --python 3.12 --with pandas make_fixtures.py
#
# Each value encodes where it belongs: 1000 * frame + 10 * bodypart + label,
# with bodypart nose = 1, paw_l = 2, and label the 1-based position of the
# coord in its list. A likelihood is bodypart / 100.

import numpy as np
import pandas as pd

BODYPARTS = {"nose": 1, "paw_l": 2}


def make_dlc_pandas_index(keypoint_names, labels):
    # eks/utils.py
    return pd.MultiIndex.from_product(
        [["ensemble-kalman_tracker"], keypoint_names, labels],
        names=["scorer", "bodyparts", "coords"],
    )


def fill(labels, n_frames):
    rows = []
    for frame in range(n_frames):
        row = []
        for bodypart, b in BODYPARTS.items():
            for i, label in enumerate(labels, start=1):
                if label == "likelihood":
                    row.append(b / 100)
                else:
                    row.append(1000 * frame + 10 * b + i)
        rows.append(row)
    return np.array(rows, dtype=float)


def main(n_frames=3):
    labels = [
        "x", "y", "likelihood", "x_ens_median", "y_ens_median",
        "x_ens_var", "y_ens_var", "x_posterior_var", "y_posterior_var",
    ]
    pdindex = make_dlc_pandas_index(list(BODYPARTS), labels=labels)
    markers_df = pd.DataFrame(fill(labels, n_frames), columns=pdindex)
    markers_df.to_csv("eks_singlecam.csv")

    labels_3d = ["x", "y", "z", "x_posterior_var", "y_posterior_var", "z_posterior_var"]
    pdindex_3d = make_dlc_pandas_index(list(BODYPARTS), labels=labels_3d)
    df_3d = pd.DataFrame(fill(labels_3d, n_frames), columns=pdindex_3d)
    df_3d.to_csv("eks_multicam_3d_results.csv")


if __name__ == "__main__":
    main()
