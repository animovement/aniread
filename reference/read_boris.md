# Read events from a BORIS export

Read behavioural events from a [BORIS](https://www.boris.unito.it/)
export into an
[`aniframe::anievent()`](http://animovement.dev/aniframe/reference/anievent.md).
Two flat-text BORIS exports are supported: **aggregated events** (one
row per bout, the default export shape) and **tabular events** (one row
per START / STOP / POINT transition; paired into bouts by the reader).

Time units come from the columns BORIS provides. The default
`unit_time = "s"` uses `Start (s)` / `Stop (s)` and works on any BORIS
export. With `unit_time = "frame"` the reader uses the
`Image index start` / `Image index stop` columns instead; frames stay
aligned with rows of a host
[`aniframe::aniframe()`](http://animovement.dev/aniframe/reference/aniframe.md),
which keeps event timing robust against effective-FPS drift when the
export is paired with movement data. If `"frame"` is requested but the
export carries no image-index columns, the reader falls back to `"s"`
with an informational message. FPS is recorded as `sampling_rate`
metadata without rescaling the timestamps; call
[`aniframe::set_sampling_rate()`](http://animovement.dev/aniframe/reference/set_sampling_rate.md)
later if you need to convert between frames and seconds.

Channels: each row's `channel` is the value of BORIS's
`Behavioral category` column when populated, falling back to the literal
`"behavior"` otherwise; `label` is the behaviour name, and `type` is
`"state"` or `"point"` mapped from BORIS's `Behavior type` column.
Overlap between bouts of the same channel is permitted on the `anievent`
side;
[`aniframe::validate_anievent()`](http://animovement.dev/aniframe/reference/validate_anievent.md)
flags overlapping state bouts with a warning rather than rejecting them.
Modifiers travel via the optional `modifiers` list-column; the
multi-column (`Modifier #1`, `Modifier #2`, ...) layout, the legacy
pipe-separated single-column (`a|b|None`) layout, and comma-separated
values within a single slot are all accepted.

## Usage

``` r
read_boris(
  path,
  format = c("auto", "aggregated", "tabular"),
  unit_time = c("s", "frame")
)
```

## Arguments

- path:

  Path to a BORIS export (`.tsv` or `.csv`).

- format:

  One of `"auto"`, `"aggregated"`, `"tabular"`. The default `"auto"`
  sniffs the format from the first row of the file.

- unit_time:

  One of `"s"`, `"frame"`. Default `"s"`. `"frame"` uses the BORIS
  image-index columns; pass it when pairing the anievent with an
  aniframe to keep frame-aligned semantics.

## Value

An
[`aniframe::anievent()`](http://animovement.dev/aniframe/reference/anievent.md)
with metadata fields `source`, `filename`, `unit_time`, and
`sampling_rate` (when FPS is a single numeric in the export) populated.

## References

- Friard, O., & Gamba, M. (2016). BORIS: a free, versatile open-source
  event-logging software for video/audio coding and live observations.
  *Methods in Ecology and Evolution*, 7(11), 1325-1330.
  [doi:10.1111/2041-210X.12584](https://doi.org/10.1111/2041-210X.12584)
  .
