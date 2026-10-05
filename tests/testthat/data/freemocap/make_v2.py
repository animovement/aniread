# Generate FreeMoCap v2 output with skellyforge's own writers
# (skellyforge main b96272b, as called by freemocap main 75c8acc in
# freemocap/core/tasks/mocap/mocap_helpers/skeleton_from_mediapipe_observations.py).
# Only the input positions are synthetic: three frames, RTMPose, body and
# left hand aspects (face and right hand dropped from the aspect order to keep
# the files small).
import sys
from pathlib import Path
import numpy as np
from skellyforge.skellymodels.models.tracking_model_info import RTMPoseModelInfo
from skellyforge.skellymodels.managers.human import Human

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)

model_info = RTMPoseModelInfo()
model_info.order = ["body", "left_hand"]
model_info.aspects = {k: model_info.aspects[k] for k in model_info.order}

rng = np.random.default_rng(171)
n_frames = 3
n_points = sum(model_info.aspects[a].num_tracked_points for a in model_info.order)
base = rng.normal(loc=[0, 0, 1000], scale=[150, 150, 400], size=(n_points, 3))
data = np.stack([base + rng.normal(scale=2, size=base.shape) for _ in range(n_frames)])
data = np.round(data, 3)

skeleton = Human.from_tracked_points_numpy_array(
    name="human", model_info=model_info, tracked_points_numpy_array=data
)
try:
    skeleton.fix_hands_to_wrist()
except Exception as e:
    print("fix_hands_to_wrist:", e)
skeleton.calculate()
print(skeleton)

skeleton.save_out_csv_data(out)
skeleton.save_out_all_data_csv(out)
skeleton.save_out_all_data_parquet(out)
