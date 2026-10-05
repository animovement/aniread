# Read FreeMoCap motion capture data

Reads the layouts FreeMoCap v1 and v2 write, dispatching on the column
names rather than the file name:

- `<recording>_by_frame.csv`: the v1 tidy export. FreeMoCap added a
  `reprojection_error` column at v1.7.4, so this exists in an 8- and a
  9-column form; both are read.

- `<recording>_by_trajectory.csv`: v1's one column triple per tracked
  point, with the camera timestamps alongside.

- `output_data/mediapipe_*_3d_xyz.csv`: v1's per-model wide files, one
  model each and no timestamps.

- `output_data/freemocap_data_by_frame.csv`, and the `.parquet` beside
  it: the v2 tidy export, one row per keypoint per trajectory per frame
  (see `trajectory`). Reading the Parquet file needs the arrow package.

- `output_data/<tracker>_<aspect>_<trajectory>.csv`: v2's per-trajectory
  files, such as `mediapipe_body_3d_xyz.csv`. They keep v1's names but
  are long (`frame`, `keypoint`, `x`, `y`, `z`), so they are told from
  v1's wide files by their columns. Their model is read from the file
  name.

Which layout was read is recorded in the `source_format` metadata field.
Point names are parsed the way FreeMoCap's own data saver parses them,
so the same recording gives the same `model` and `keypoint` values
whichever layout it is read from.

## Usage

``` r
read_freemocap(
  path,
  format = c("auto", "by_frame", "by_trajectory", "wide", "v2_by_frame", "v2_trajectory"),
  trajectory = c("3d_xyz", "rigid_3d_xyz")
)
```

## Arguments

- path:

  Path to a FreeMoCap CSV, or a v2 Parquet file.

- format:

  **\[experimental\]** Export layout. `"auto"` (default) reads it from
  the column names; naming one requires that layout and errors on
  anything else. The layout names may change while one convention for
  readers of a source with several export layouts is settled
  ([\#118](https://github.com/animovement/aniread/issues/118)).

- trajectory:

  Which positions to read from the v2 tidy export: `"3d_xyz"` (default),
  the triangulated, filtered keypoints, or `"rigid_3d_xyz"`, the same
  keypoints with bone lengths held constant. FreeMoCap only computes
  `rigid_3d_xyz` for aspects with a joint hierarchy (the body), so other
  aspects keep `3d_xyz` and a message says which. Ignored, with a
  warning, for every other layout.

## Value

An aniframe with `time`, `model`, `keypoint`, `confidence` and
`x`/`y`/`z` in millimetres on a 3D cartesian coordinate system. `time`
is seconds elapsed from `start_datetime` where the layout carries
timestamps, and frames where it does not. Either way the first frame is
at 0; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

`confidence` comes from `reprojection_error`, which the 9-column
`by_frame` export and the v2 tidy export carry; every other layout gives
all-`NA` confidence. The two run in opposite directions: a reprojection
error is a distance in pixels, so zero is perfect and larger is worse,
whereas every other reader in aniread fills `confidence` from a
likelihood or a probability where larger is better. Storing the error
unchanged would make `aniprocess::mask_na_across(method = "confidence")`
mask the best points, so it is mapped through

\$\$confidence = 1 / (1 + error)\$\$

which is monotone decreasing onto \\(0, 1\]\\: a zero error gives 1. The
mapping is invertible, so the original error is recoverable as
`1 / confidence - 1`.

### FreeMoCap v2

v2 writes its output through skellyforge. Its tidy export names each
model `<tracker>.<aspect>` (`mediapipe.body`, `rtmpose.left_hand`);
these are read as `<tracker>_<aspect>` (`mediapipe_body`,
`rtmpose_left_hand`), the naming of v1's `model` column and of v2's own
per-trajectory file names. The hands keep separate models, since v2's
hand keypoint names do not say which hand they belong to.

Each keypoint appears once per trajectory type, so only one set of
positions is read, chosen by `trajectory`. The centres of mass
(`total_body_center_of_mass` and `segment_center_of_mass`) are added as
keypoints of a `<tracker>_com` model, as v1 kept them in
`mediapipe_com`, with the keypoint names v2 gives them. (Only the body
has centres of mass in FreeMoCap's models; another aspect's would go to
`<tracker>_<aspect>_com`, so that segment names cannot collide.) Any
other trajectory type is not read.

v2 writes no timestamps, so `time` is the frame number and
`sampling_rate` is left unset. FreeMoCap's main pipeline does not attach
reprojection errors to the skeleton it saves, so `confidence` is usually
all `NA` too.

[`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
recognises the v2 tidy CSV. It does not claim the per-trajectory files,
whose five columns any tidy export could have, or the Parquet file; read
those with `read_freemocap()` directly.

## Examples

``` r
path <- system.file("extdata", "freemocap.csv", package = "aniread")
read_freemocap(path)
#> # Models:    mediapipe_body, mediapipe_com, mediapipe_face, mediapipe_hand
#> # Keypoints: left_ear, left_eye, left_eye_inner, left_eye_outer, left_shoulder,
#> #   mouth_left, mouth_right, nose, right_ear, right_eye, right_eye_inner,
#> #   right_eye_outer, right_shoulder, full_body, head, trunk, 0000, left_0000,
#> #   right_0000
#>    model          keypoint        time     x     y     z confidence
#>    <fct>          <fct>          <dbl> <dbl> <dbl> <dbl>      <dbl>
#>  1 mediapipe_body left_ear           0 -234. -539. 1592.     0.154 
#>  2 mediapipe_body left_ear           1 -210. -664. 1543.     0.0482
#>  3 mediapipe_body left_ear           2 -199. -520. 1588.     0.0771
#>  4 mediapipe_body left_eye           0 -194. -616. 1599.     0.0547
#>  5 mediapipe_body left_eye           1 -224. -632. 1586.     0.152 
#>  6 mediapipe_body left_eye           2 -218. -563. 1553.     0.0837
#>  7 mediapipe_body left_eye_inner     0 -153. -698. 1535.     0.167 
#>  8 mediapipe_body left_eye_inner     1 -168. -673. 1584.     0.0877
#>  9 mediapipe_body left_eye_inner     2 -245. -619. 1665.     0.153 
#> 10 mediapipe_body left_eye_outer     0 -243. -556. 1639.     0.120 
#> # ℹ 47 more rows

# The same recording in its by_trajectory form
path <- system.file(
  "extdata",
  "freemocap_by_trajectory.csv",
  package = "aniread"
)
read_freemocap(path)
#> # Models:    mediapipe_body, mediapipe_com, mediapipe_face, mediapipe_hand
#> # Keypoints: left_ear, left_eye, left_eye_inner, left_eye_outer, left_shoulder,
#> #   mouth_left, mouth_right, nose, right_ear, right_eye, right_eye_inner,
#> #   right_eye_outer, right_shoulder, full_body, head, trunk, 0000, left_0000,
#> #   right_0000
#>    model          keypoint        time     x     y     z confidence
#>    <fct>          <fct>          <int> <dbl> <dbl> <dbl>      <dbl>
#>  1 mediapipe_body left_ear           0 -234. -539. 1592.         NA
#>  2 mediapipe_body left_ear           1 -210. -664. 1543.         NA
#>  3 mediapipe_body left_ear           2 -199. -520. 1588.         NA
#>  4 mediapipe_body left_eye           0 -194. -616. 1599.         NA
#>  5 mediapipe_body left_eye           1 -224. -632. 1586.         NA
#>  6 mediapipe_body left_eye           2 -218. -563. 1553.         NA
#>  7 mediapipe_body left_eye_inner     0 -153. -698. 1535.         NA
#>  8 mediapipe_body left_eye_inner     1 -168. -673. 1584.         NA
#>  9 mediapipe_body left_eye_inner     2 -245. -619. 1665.         NA
#> 10 mediapipe_body left_eye_outer     0 -243. -556. 1639.         NA
#> # ℹ 47 more rows

# FreeMoCap v2's tidy export, reading the rigid-body positions
path <- system.file("extdata", "freemocap_v2.csv", package = "aniread")
read_freemocap(path, trajectory = "rigid_3d_xyz")
#> ℹ No "rigid_3d_xyz" for "rtmpose_left_hand"; read "3d_xyz" for it instead.
#> # Models:    rtmpose_body, rtmpose_com, rtmpose_left_hand
#> # Keypoints: head_center, hips_center, left_ankle, left_big_toe, left_ear,
#> #   left_elbow, left_eye, left_heel, left_hip, left_knee, left_shoulder,
#> #   left_small_toe, left_wrist, neck_center, nose, right_ankle, right_big_toe,
#> #   right_ear, right_elbow, right_eye, right_heel, right_hip, right_knee,
#> #   right_shoulder, right_small_toe, right_wrist, trunk_center, head,
#> #   left_foot, left_forearm, left_shank, left_thigh, left_upper_arm,
#> #   right_foot, right_forearm, right_shank, right_thigh, right_upper_arm,
#> #   spine, total_body_center_of_mass, forefinger1, forefinger2, forefinger3,
#> #   forefinger4, hand_root, middle_finger1, middle_finger2, middle_finger3,
#> #   middle_finger4, pinky_finger1, pinky_finger2, pinky_finger3, pinky_finger4,
#> #   ring_finger1, ring_finger2, ring_finger3, ring_finger4, thumb1, thumb2,
#> #   thumb3, thumb4
#>    model        keypoint      time     x     y     z confidence
#>    <fct>        <fct>        <dbl> <dbl> <dbl> <dbl>      <dbl>
#>  1 rtmpose_body head_center      0 -158. -46.4 1178.         NA
#>  2 rtmpose_body head_center      1 -158. -44.3 1177.         NA
#>  3 rtmpose_body head_center      2 -159. -45.2 1176.         NA
#>  4 rtmpose_body hips_center      0 -101. 156.  1287.         NA
#>  5 rtmpose_body hips_center      1 -101. 155.  1286.         NA
#>  6 rtmpose_body hips_center      2 -101. 153.  1286.         NA
#>  7 rtmpose_body left_ankle       0 -197.  50.2  625.         NA
#>  8 rtmpose_body left_ankle       1 -196.  48.5  624.         NA
#>  9 rtmpose_body left_ankle       2 -196.  46.7  626.         NA
#> 10 rtmpose_body left_big_toe     0  195. 124.  1673.         NA
#> # ℹ 173 more rows
```
