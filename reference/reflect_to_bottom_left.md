# Reflect image-plane data from a top-left to a bottom-left origin

Marks the data's `origin` as `"top_left"` (so the reflection is well
defined), applies a user-supplied `video_height` to the `y_height`
metadata when given, then calls
[`aniframe::set_origin()`](http://animovement.dev/aniframe/reference/set_origin.md)
to reflect y around `y_height`. Used by all readers whose source data is
in an image / video coordinate system. When `video_height` is `NULL`,
the `y_height` value already on the aniframe (set to `max(y)` by
[`aniframe::as_aniframe()`](http://animovement.dev/aniframe/reference/as_aniframe.md)
when not otherwise populated) is used.

## Usage

``` r
reflect_to_bottom_left(data, video_height = NULL)
```

## Arguments

- data:

  An aniframe with image-plane (top-left) coordinates.

- video_height:

  Optional numeric height of the source video frame in y-axis units.
  When supplied, takes precedence over the existing `y_height` metadata.

## Value

An aniframe with reflected y coordinates and `origin` set to
`"bottom_left"`.
