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

an aniframe

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
