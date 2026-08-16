# Read a movement or event dataset from any supported format

One entry point for every format `aniread` supports. By default the
source software is worked out from the file itself, so you do not have
to know which reader a file needs before opening it.

## Usage

``` r
read_dataset(paths, source = "auto", ...)
```

## Arguments

- paths:

  Path to the file to read. A few readers take more than one path -
  [`read_trackball()`](http://animovement.dev/aniread/reference/read_trackball.md)
  takes one per sensor - in which case pass them all; detection inspects
  the first.

- source:

  Which source software wrote the file. `"auto"` (the default) detects
  it with
  [`detect_source()`](http://animovement.dev/aniread/reference/detect_source.md).
  Otherwise one of the names in
  [`get_supported_sources()`](http://animovement.dev/aniread/reference/get_supported_sources.md).

- ...:

  Passed on to the reader for `source`. This is how arguments that only
  some readers take are supplied, e.g. `sampling_rate` for
  [`read_trackball()`](http://animovement.dev/aniread/reference/read_trackball.md)
  or `path_probabilities` for
  [`read_idtracker()`](http://animovement.dev/aniread/reference/read_idtracker.md).

## Value

An [aniframe](http://animovement.dev/aniframe/reference/aniframe.md) or
[anievent](http://animovement.dev/aniframe/reference/anievent.md),
depending on the reader.

## Details

`read_dataset()` is a dispatcher, not a new reader: it works out which
reader to call and calls it. The object you get back is exactly what the
underlying reader returns - an
[aniframe](http://animovement.dev/aniframe/reference/aniframe.md) for
tracking data, or an
[anievent](http://animovement.dev/aniframe/reference/anievent.md) for
behavioural events from
[`read_boris()`](http://animovement.dev/aniread/reference/read_boris.md).

DeepLabCut and LightningPose CSV exports are structurally identical, so
a file in that format cannot be attributed to one or the other. Such a
file is read with
[`read_deeplabcut()`](http://animovement.dev/aniread/reference/read_deeplabcut.md) -
the parse is the same either way - and its `source` metadata is set to
`"deeplabcut/lightningpose"` to record that the distinction is
undetermined. Pass `source` explicitly to override this.

## See also

[`detect_source()`](http://animovement.dev/aniread/reference/detect_source.md)
to detect the format without reading,
[`get_supported_sources()`](http://animovement.dev/aniread/reference/get_supported_sources.md)
for what is supported, and the individual `read_*()` functions for
format-specific arguments.

## Examples

``` r
if (FALSE) { # \dontrun{
# Let aniread work out the format
data <- read_dataset("mouse.h5")

# Name it explicitly
data <- read_dataset("mouse.h5", source = "sleap")

# Reader-specific arguments pass straight through
data <- read_dataset(
  c("sensor1.csv", "sensor2.csv"),
  sampling_rate = 60,
  col_time = 4,
  col_dx = 1,
  col_dy = 2
)
} # }
```
