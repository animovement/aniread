# Read LightningPose data

Read csv files from LightningPose (LP). Like DeepLabCut, the source is
in image (top-left) coordinates and the reader reflects y to
`bottom_left`.

## Usage

``` r
read_lightningpose(path, video_height = NULL)
```

## Arguments

- path:

  Path to a LightningPose data file

- video_height:

  Optional numeric height of the source video frame in pixels. Falls
  back to `max(y)` when not supplied.

## Value

an aniframe. `time` is Lightning Pose's frame index, with the first
frame of the video at 0; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

Lightning Pose writes DeepLabCut's csv layout, so the file is read by
[`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md).
That includes the output of its Ensemble Kalman Smoother (EKS, scorer
`ensemble-kalman_tracker`), which has nine coords per keypoint: `x`, `y`
and `likelihood` are read, and the ensemble medians and variances and
the posterior variances (`x_ens_median`, `y_ens_median`, `x_ens_var`,
`y_ens_var`, `x_posterior_var`, `y_posterior_var`) are not. Its
multi-camera 3D output, `multicam_3d_results.csv`, reads as 3D with `x`,
`y` and `z`, without confidence and without reflecting y; see
[`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md).

## Examples

``` r
path <- system.file("extdata", "lightningpose.csv", package = "aniread")
read_lightningpose(path)
#> # Keypoints: ear_base_l, ear_tip_l, eye_bottom_l, eye_top_l, nose_tip,
#> #   nostril_l, nostril_r, paw_forward_l, paw_forward_lh, tongue_tip,
#> #   whisker_pad_l_side, whisker_pad_l_top
#>    keypoint    time     x        y confidence
#>    <fct>      <dbl> <dbl>    <dbl>      <dbl>
#>  1 ear_base_l     0  652.   0.0470  1.000    
#>  2 ear_base_l     1  331. 219.      0.0000106
#>  3 ear_base_l     2  394. 281.      0.900    
#>  4 ear_base_l     3  396. 280.      0.992    
#>  5 ear_base_l     4  394. 281.      0.987    
#>  6 ear_base_l     5  393. 282.      0.998    
#>  7 ear_base_l     6  393. 282.      0.998    
#>  8 ear_base_l     7  394. 281.      0.993    
#>  9 ear_base_l     8  392. 283.      0.989    
#> 10 ear_base_l     9  394. 283.      1.000    
#> # ℹ 110 more rows
```
