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
