# Recover frame numbers from timestamps when the image index is bad

Some BORIS exports emit a bogus image index on boundary frames — e.g. a
STOP recorded on the very last frame of the video carries
`Image index stop = 1` while its `Stop (s)` is the true end time. That
makes the frame-based `stop` smaller than `start`, which fails
aniframe's non-negative-interval invariant even though the second-based
timestamps are perfectly consistent.

## Usage

``` r
backcalculate_boris_frames(start, stop, start_s, stop_s, fps)
```

## Value

A list with `start` and `stop` numeric vectors.

## Details

BORIS derives `Time` from `frame / fps`, so when fps is known the true
frame number is `round(Time * fps)`. We only rewrite the rows whose
frame interval is negative *and* whose second interval is non-negative,
leaving every other row on the verbatim image-index values (which keeps
the documented frame-alignment guarantee intact).
