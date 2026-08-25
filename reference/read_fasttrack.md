# Read FastTrack tracking data

Reads a FastTrack tracking result file (.txt format) and returns an
aniframe with keypoints for head, body, and tail positions. FastTrack
stores positions in image (top-left) coordinates; the reader reflects y
so the returned aniframe is in the conventional `bottom_left` origin.
The tracking file does not record the source video resolution, so pass
`video_height` to get an accurate flip — otherwise `max(y)` is used as a
fallback.

## Usage

``` r
read_fasttrack(path, video_height = NULL)
```

## Arguments

- path:

  Path to a FastTrack tracking.txt file.

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

An aniframe

## Examples

``` r
path <- system.file("extdata", "fasttrack.txt", package = "aniread")
read_fasttrack(path)
#> # Individuals: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9
#> # Keypoints:   centroid, head, tail
#>    individual keypoint  time     x      y  area
#>         <int> <fct>    <dbl> <dbl>  <dbl> <dbl>
#>  1          0 centroid     0 508.    2.24  78.5
#>  2          0 head         0 514.    0     NA  
#>  3          0 tail         0 500.    5.39  NA  
#>  4          1 centroid     0 458.    4.77  73  
#>  5          1 head         0 464.    6.07  NA  
#>  6          1 tail         0 450.    2.80  NA  
#>  7          2 centroid     0  29.2  49.6   78  
#>  8          2 head         0  24.0  45.4   NA  
#>  9          2 tail         0  35.0  54.3   NA  
#> 10          3 centroid     0 365.  102.   148. 
#> # ℹ 20 more rows
```
