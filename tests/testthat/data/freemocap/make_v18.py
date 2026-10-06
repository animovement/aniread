# Generate a v1.8-style 9-column by_frame.csv with FreeMoCap v1.8.2's own
# DataSaver.save_to_tidy_csv() (freemocap/data_layer/data_saver/data_saver.py at
# tag v1.8.2). Its imports of skellytracker and the DataLoader are stubbed, since
# only the tidy writer runs; the per-frame dictionary it walks is built in the
# shape DataLoader.load_frame_data().to_dict() returns, with synthetic
# positions and no timestamps directory (so timestamps are empty, as in a
# recording without synchronized_videos/timestamps).
import subprocess, sys, types
from pathlib import Path
import numpy as np

src = subprocess.run(
    ["git", "-C", sys.argv[1], "show", "v1.8.2:freemocap/data_layer/data_saver/data_saver.py"],
    capture_output=True, text=True, check=True,
).stdout

def stub(name, **attrs):
    mod = types.ModuleType(name)
    mod.__dict__.update(attrs)
    sys.modules[name] = mod

stub("skellytracker"); stub("skellytracker.trackers"); stub("skellytracker.trackers.base_tracker")
stub("skellytracker.trackers.base_tracker.model_info", ModelInfo=object)
stub("skellytracker.trackers.mediapipe_tracker")
stub("skellytracker.trackers.mediapipe_tracker.mediapipe_model_info",
     MediapipeModelInfo=lambda: types.SimpleNamespace(name="mediapipe"))
stub("freemocap"); stub("freemocap.data_layer"); stub("freemocap.data_layer.data_saver")
stub("freemocap.data_layer.data_saver.data_loader", DataLoader=object)
stub("freemocap.data_layer.data_saver.data_models", InfoDict=object)

ns = {"__name__": "data_saver"}
exec(compile(src, "data_saver.py", "exec"), ns)
DataSaver = ns["DataSaver"]

points = ["body_nose", "body_left_eye", "body_right_eye", "com_full_body",
          "com_head", "right_hand_0000", "left_hand_0000", "face_0000"]
# DataLoader._set_reprojection_error_point_names(): body landmarks, then
# right_/left_ hand and bare face indices; centres of mass carry none.
error_names = ["nose", "left_eye", "right_eye", "right_0000", "left_0000", "0000"]

rng = np.random.default_rng(10)
frames = {}
for f in range(3):
    frames[f] = {
        "timestamps": {"mean": None, "by_camera": {}},
        "tracked_points": {
            p: {k: round(float(v), 3) for k, v in zip("xyz", rng.normal([0, -600, 1600], 50))}
            for p in points
        },
        "reprojection_error": {
            n: {"value": round(float(rng.gamma(2, 5)), 3)} for n in error_names
        },
    }

saver = DataSaver.__new__(DataSaver)
saver.model_info = types.SimpleNamespace(name="mediapipe")
saver.recording_data_by_frame = frames
saver.save_to_tidy_csv(save_path=Path(sys.argv[2]))
