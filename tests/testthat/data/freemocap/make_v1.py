# Generate FreeMoCap v1 output with FreeMoCap's own code, at a given tag.
#
#   python make_v1.py <freemocap clone> <tag> <out dir>
#
# Runs the modules FreeMoCap v1 uses to write its output, taken unchanged from
# the clone at <tag>:
#
# * core_processes/post_process_skeleton_data/split_and_save.py writes the
#   per-model wide files (output_data/mediapipe_body_3d_xyz.csv, ...) and the
#   .npy files beside them, from a skeleton array;
# * data_layer/data_saver/data_loader.py reads them back, with the centre of
#   mass and (from v1.7.4) reprojection error .npy files, as FreeMoCap does
#   after processing a recording;
# * data_layer/data_saver/data_saver.py's DataSaver.save_all() writes
#   <recording>_by_frame.csv and <recording>_by_trajectory.csv from that.
#
# Only what lies outside those modules is replaced: skellytracker's model info
# (a stub naming MediaPipe's first 13 body landmarks, one point for each hand
# and the face, and two centre-of-mass segments, to keep the files small),
# and the package's __init__ files. path_getters.py's three folder lookups are
# taken from the same tag, without the rest of that module (which needs the
# GUI). The positions, centres of mass and reprojection errors are synthetic,
# seeded random numbers; there is no timestamps folder, so the timestamps are
# empty. Needs numpy, pandas and pydantic (FreeMoCap v1.8.2's lock: numpy
# 1.26.2, pandas 2.1.4, pydantic 2.11.9).
import ast
import subprocess
import sys
import tempfile
import types
from pathlib import Path

import numpy as np

clone, tag, out = sys.argv[1], sys.argv[2], Path(sys.argv[3])
out.mkdir(parents=True, exist_ok=True)


def show(path):
    return subprocess.run(
        ["git", "-C", clone, "show", f"{tag}:{path}"],
        capture_output=True, text=True, check=True,
    ).stdout


# A package of FreeMoCap's own modules at <tag>
pkg = Path(tempfile.mkdtemp())
modules = [
    "freemocap/data_layer/data_saver/data_loader.py",
    "freemocap/data_layer/data_saver/data_saver.py",
    "freemocap/data_layer/data_saver/data_models.py",
    "freemocap/system/paths_and_filenames/file_and_folder_names.py",
    "freemocap/core_processes/post_process_skeleton_data/split_and_save.py",
]
for m in modules:
    (pkg / m).parent.mkdir(parents=True, exist_ok=True)
    (pkg / m).write_text(show(m))

# path_getters.py: only the folder lookups the DataLoader calls
getters = ast.parse(show("freemocap/system/paths_and_filenames/path_getters.py"))
wanted = {
    "get_output_data_folder_path",
    "get_synchronized_videos_folder_path",
    "get_timestamps_directory",
}
functions = [n for n in getters.body if isinstance(n, ast.FunctionDef) and n.name in wanted]
assert {f.name for f in functions} == wanted
(pkg / "freemocap/system/paths_and_filenames/path_getters.py").write_text(
    "import logging\nfrom pathlib import Path\nfrom typing import Optional, Union\n"
    "from freemocap.system.paths_and_filenames.file_and_folder_names import (\n"
    "    OUTPUT_DATA_FOLDER_NAME, SYNCHRONIZED_VIDEOS_FOLDER_NAME)\n"
    "logger = logging.getLogger(__name__)\n\n"
    + "\n\n".join(ast.unparse(f) for f in functions)
)
for d in pkg.rglob("*"):
    if d.is_dir():
        (d / "__init__.py").touch()
sys.path.insert(0, str(pkg))


# skellytracker's model info, cut to a few points
def stub(name, **attrs):
    mod = types.ModuleType(name)
    mod.__dict__.update(attrs)
    sys.modules[name] = mod


body = [
    "nose", "left_eye_inner", "left_eye", "left_eye_outer", "right_eye_inner",
    "right_eye", "right_eye_outer", "left_ear", "right_ear", "mouth_left",
    "mouth_right", "left_shoulder", "right_shoulder",
]
model_info = types.SimpleNamespace(
    name="mediapipe",
    body_landmark_names=body,
    num_tracked_points_body=len(body),
    num_tracked_points_right_hand=1,
    num_tracked_points_left_hand=1,
    num_tracked_points_face=1,
    num_tracked_points=len(body) + 3,
    center_of_mass_definitions={"head": {}, "trunk": {}},
    segment_connections={},
)
stub("skellytracker")
stub("skellytracker.trackers")
stub("skellytracker.trackers.base_tracker")
stub("skellytracker.trackers.base_tracker.model_info", ModelInfo=object)
stub("skellytracker.trackers.mediapipe_tracker")
stub(
    "skellytracker.trackers.mediapipe_tracker.mediapipe_model_info",
    MediapipeModelInfo=lambda: model_info,
)

from freemocap.core_processes.post_process_skeleton_data.split_and_save import split_and_save
from freemocap.data_layer.data_saver.data_saver import DataSaver
from freemocap.system.paths_and_filenames import file_and_folder_names as names

# A recording folder, as FreeMoCap leaves it after processing
recording = Path(tempfile.mkdtemp()) / "recording"
output = recording / names.OUTPUT_DATA_FOLDER_NAME
for folder in (output / names.CENTER_OF_MASS_FOLDER_NAME, output / names.RAW_DATA_FOLDER_NAME,
               recording / names.SYNCHRONIZED_VIDEOS_FOLDER_NAME):
    folder.mkdir(parents=True)

rng = np.random.default_rng(42)
n_frames = 3
skeleton = rng.normal([-200, -600, 1600], 50, (n_frames, model_info.num_tracked_points, 3)).round(3)
split_and_save(skeleton_3d_data=skeleton, model_info=model_info, output_data_folder_path=str(output))
prefix = model_info.name + "_"
np.save(output / (prefix + names.DATA_3D_NPY_FILE_NAME), skeleton)
com = output / names.CENTER_OF_MASS_FOLDER_NAME
np.save(com / (prefix + names.TOTAL_BODY_CENTER_OF_MASS_NPY_FILE_NAME), skeleton[:, : len(body)].mean(axis=1))
np.save(com / (prefix + names.SEGMENT_CENTER_OF_MASS_NPY_FILE_NAME),
        np.stack([skeleton[:, :11].mean(axis=1), skeleton[:, 11:13].mean(axis=1)], axis=1))
# DataLoader looks the errors up by MediaPipe's full point list: the body,
# 21 points per hand and 478 face points.
n_error = len(body) + 21 + 21 + 478
raw = output / names.RAW_DATA_FOLDER_NAME
error = rng.gamma(2, 5, (n_frames, n_error)).round(3)
np.save(raw / (prefix + names.REPROJECTION_ERROR_NPY_FILE_NAME), error)
np.save(raw / (prefix + names.FULL_REPROJECTION_ERROR_NPY_FILE_NAME), np.stack([error, error]))

DataSaver(recording_folder_path=recording, model_info=model_info).save_all()

for f in [recording / "recording_by_frame.csv", recording / "recording_by_trajectory.csv",
          output / (prefix + names.BODY_3D_DATAFRAME_CSV_FILE_NAME)]:
    (out / f.name).write_bytes(f.read_bytes())
    print(out / f.name)
