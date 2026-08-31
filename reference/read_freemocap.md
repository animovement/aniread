# Read FreeMoCap motion capture data

Reads all three layouts FreeMoCap writes, dispatching on the column
names:

- `<recording>_by_frame.csv` — the tidy export. FreeMoCap added a
  `reprojection_error` column at v1.8.0, so this exists in an 8- and a
  9-column form; both are read.

- `<recording>_by_trajectory.csv` — one column triple per tracked point,
  with the camera timestamps alongside.

- `output_data/mediapipe_*_3d_xyz.csv` — the per-model wide files, one
  model each and no timestamps.

Which layout was read is recorded in the `source_format` metadata field.
Point names are parsed the way FreeMoCap's own data saver parses them,
so the same recording gives the same `model` and `keypoint` values
whichever layout it is read from.

## Usage

``` r
read_freemocap(path, format = c("auto", "by_frame", "by_trajectory", "wide"))
```

## Arguments

- path:

  Path to a FreeMoCap CSV.

- format:

  Export layout. `"auto"` reads it from the column names; naming one
  requires that layout and errors on anything else.

## Value

An aniframe with `time`, `model`, `keypoint`, `confidence` and
`x`/`y`/`z` in millimetres on a 3D cartesian coordinate system. `time`
is seconds elapsed from `start_datetime` where the layout carries
timestamps, and frames where it does not.

## Details

`confidence` comes from `reprojection_error`, which only the 9-column
`by_frame` export carries; every other layout gives all-`NA` confidence.
The two run in opposite directions — a reprojection error is a distance
in pixels, so zero is perfect and larger is worse, whereas every other
reader in aniread fills `confidence` from a likelihood or a probability
where larger is better. Storing the error unchanged would make
`aniprocess::filter_na_across(method = "confidence")` drop the best
points, so it is mapped through

\$\$confidence = 1 / (1 + error)\$\$

which is monotone decreasing onto \\(0, 1\]\\: a zero error gives 1. The
mapping is invertible, so the original error is recoverable as
`1 / confidence - 1`.

## Examples

``` r
path <- system.file("extdata", "freemocap.csv", package = "aniread")
read_freemocap(path)
#> # Models:    mediapipe_body
#> # Keypoints: left_eye, left_shoulder, nose, right_eye, right_shoulder
#>    model          keypoint        time     x     y     z confidence
#>    <fct>          <fct>          <dbl> <dbl> <dbl> <dbl>      <dbl>
#>  1 mediapipe_body left_eye           0 -182. -687. 1617.     0.0669
#>  2 mediapipe_body left_eye           1 -191. -713. 1731.     0.114 
#>  3 mediapipe_body left_eye           2 -202. -749. 1845.     0.110 
#>  4 mediapipe_body left_shoulder      0 -322. -536. 1928.     0.135 
#>  5 mediapipe_body left_shoulder      1 -270. -567. 2070.     0.300 
#>  6 mediapipe_body left_shoulder      2 -235. -591. 2181.     0.186 
#>  7 mediapipe_body nose               0 -201. -648. 1594.     0.0613
#>  8 mediapipe_body nose               1 -208. -678. 1704.     0.0964
#>  9 mediapipe_body nose               2 -219. -717. 1816.     0.0896
#> 10 mediapipe_body right_eye          0 -225. -688. 1570.     0.0629
#> 11 mediapipe_body right_eye          1 -242. -724. 1711.     0.113 
#> 12 mediapipe_body right_eye          2 -259. -765. 1841.     0.137 
#> 13 mediapipe_body right_shoulder     0 -321. -419. 1591.     0.0933
#> 14 mediapipe_body right_shoulder     1 -367. -472. 1736.     0.174 
#> 15 mediapipe_body right_shoulder     2 -408. -525. 1863.     0.223 

# The same recording in its by_trajectory form
path <- system.file(
  "extdata",
  "freemocap_by_trajectory.csv",
  package = "aniread"
)
read_freemocap(path)
#> # Models:    mediapipe_body, mediapipe_com, mediapipe_face, mediapipe_hand
#> # Keypoints: left_eye, left_eye_inner, left_eye_outer, nose, full_body, 0000,
#> #   left_0000, right_0000
#>    model          keypoint        time     x     y     z confidence
#>    <fct>          <fct>          <int> <dbl> <dbl> <dbl>      <dbl>
#>  1 mediapipe_body left_eye           0 -182. -687. 1617.         NA
#>  2 mediapipe_body left_eye           1 -191. -713. 1731.         NA
#>  3 mediapipe_body left_eye           2 -202. -749. 1845.         NA
#>  4 mediapipe_body left_eye           3 -219. -786. 1934.         NA
#>  5 mediapipe_body left_eye_inner     0 -189. -687. 1602.         NA
#>  6 mediapipe_body left_eye_inner     1 -199. -714. 1720.         NA
#>  7 mediapipe_body left_eye_inner     2 -212. -751. 1837.         NA
#>  8 mediapipe_body left_eye_inner     3 -230. -789. 1927.         NA
#>  9 mediapipe_body left_eye_outer     0 -175. -686. 1631.         NA
#> 10 mediapipe_body left_eye_outer     1 -182. -712. 1744.         NA
#> # ℹ 22 more rows
```
