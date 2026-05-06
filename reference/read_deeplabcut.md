# Read DeepLabCut data

Read files from DeepLabCut (DLC) in either csv or h5 format. DeepLabCut
stores predictions in image (top-left) coordinates; the reader reflects
y so the returned aniframe is in the conventional `bottom_left` origin.
DLC's csv/h5 exports do not contain the source video resolution (it
lives in the project's `config.yaml`), so pass `video_height` to get an
accurate flip — otherwise `max(y)` is used as a fallback.

## Usage

``` r
read_deeplabcut(path, video_height = NULL)
```

## Arguments

- path:

  Path to a DeepLabCut data file

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

an aniframe
