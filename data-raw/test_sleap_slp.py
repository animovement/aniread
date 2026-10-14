"""Write tests/testthat/data/sleap/SLEAP_synthetic.predictions.slp.

    python3 data-raw/test_sleap_slp.py

A synthetic SLEAP labels file, made up rather than copied from any recording:
one video, a two-node skeleton (head -> tail) and one predicted instance in
each of three frames. It follows the layout SLEAP 1.3 writes (format_id 1.2):
the labels' JSON in the `metadata` group's `json` attribute, and the frames,
instances and points as compound datasets.

The detector sweep in test-detect_source.R only needs a .slp in the fixture
tree, so the file is kept as small as the layout allows.
"""

import json
from pathlib import Path

import h5py
import numpy as np

path = Path("tests/testthat/data/sleap/SLEAP_synthetic.predictions.slp")

labels = {
    "version": "2.0.0",
    "skeletons": [
        {
            "directed": True,
            "graph": {"name": "mouse", "num_edges_inserted": 1},
            "links": [
                {
                    "edge_insert_idx": 0,
                    "key": 0,
                    "source": 0,
                    "target": 1,
                    "type": {
                        "py/reduce": [
                            {"py/type": "sleap.skeleton.EdgeType"},
                            {"py/tuple": [1]},
                        ]
                    },
                }
            ],
            "multigraph": True,
            "nodes": [{"id": 0}, {"id": 1}],
        }
    ],
    "nodes": [{"name": "head", "weight": 1.0}, {"name": "tail", "weight": 1.0}],
    "videos": [{"filename": "mouse.mp4", "backend": {"filename": "mouse.mp4"}}],
    "tracks": [],
    "suggestions": [],
    "negative_anchors": {},
    "provenance": {"sleap_version": "1.3.1"},
}

frames = np.array(
    [(i, 0, i, i, i + 1) for i in range(3)],
    dtype=[
        ("frame_id", "u8"),
        ("video", "u4"),
        ("frame_idx", "u8"),
        ("instance_id_start", "u8"),
        ("instance_id_end", "u8"),
    ],
)
instances = np.array(
    [(i, 1, i, 0, -1, 0, 0.9, 2 * i, 2 * i + 2, 0.0) for i in range(3)],
    dtype=[
        ("instance_id", "i8"),
        ("instance_type", "u1"),
        ("frame_id", "u8"),
        ("skeleton", "u4"),
        ("track", "i4"),
        ("from_predicted", "i8"),
        ("score", "f4"),
        ("point_id_start", "u8"),
        ("point_id_end", "u8"),
        ("tracking_score", "f4"),
    ],
)
point_dtype = [("x", "f8"), ("y", "f8"), ("visible", "?"), ("complete", "?")]
pred_points = np.array(
    [
        (10.0 + i, 20.0, True, True, 0.95) if node == 0 else
        (10.0 + i, 30.0, True, True, 0.85)
        for i in range(3)
        for node in range(2)
    ],
    dtype=point_dtype + [("score", "f8")],
)

with h5py.File(path, "w") as f:
    meta = f.create_group("metadata")
    meta.attrs["format_id"] = 1.2
    meta.attrs["json"] = np.bytes_(json.dumps(labels, separators=(",", ":")))
    f.create_dataset("frames", data=frames)
    f.create_dataset("instances", data=instances)
    f.create_dataset("points", data=np.zeros(0, dtype=point_dtype))
    f.create_dataset("pred_points", data=pred_points)
    f.create_dataset(
        "videos_json", data=[json.dumps(labels["videos"][0]).encode()]
    )
    f.create_dataset("tracks_json", data=np.zeros(0))
    f.create_dataset("suggestions_json", data=np.zeros(0))
