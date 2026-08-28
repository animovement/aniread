# Turn image-plane data the right way up

Image and video tooling counts y downward from the top of the frame,
while plotting and maths count it upward. Every reader whose source is
an image plane declares the convention its data arrived in and then
turns the vertical axis over, so downstream sees one convention.

## Usage

``` r
reflect_to_bottom_left(data, video_height = NULL)
```

## Arguments

- data:

  An aniframe with image-plane coordinates.

- video_height:

  Optional numeric height of the source video frame in y-axis units.
  When supplied, takes precedence over the extent inferred from the
  data.

## Value

An aniframe with y counting upward.

## Details

The depth axis is declared too, as `back` — the camera on the near side
of the scene. That is the default for these formats rather than
something the file says, and it is what
[`anicore::get_handedness()`](https://animovement.dev/anicore/reference/get_handedness.html)
and
[`anicore::get_angle_direction()`](https://animovement.dev/anicore/reference/get_angle_direction.html)
are read from, so a recording made through a glass floor should say so
with `anicore::set_axis_directions(data, c(z = "forward"))`.

`anicore` no longer invents an extent to reflect around, so the reader
supplies one: the video height when the source gives it, and otherwise
the furthest tracked point, which is the guess `as_aniframe()` used to
make on everyone's behalf.
