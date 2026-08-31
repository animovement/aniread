# SLEAP analysis CSV reader

The CSV export carries one row per instance, with columns `track`,
`frame_idx`, `instance.score` and a `.x`/`.y`/`.score` triple per node.
Node names are taken from the columns rather than assumed, since a
recording has whatever skeleton it was tracked with.

## Usage

``` r
read_sleap_csv(path)
```

## Arguments

- path:

  Path to a SLEAP analysis CSV.

## Value

A data frame with `time`, `individual`, `keypoint`, `x`, `y` and
`confidence`.

## Details

Two things are aligned with
[`read_sleap_h5()`](https://animovement.dev/aniread/reference/read_sleap_h5.md)
so that one recording reads the same from either export: `time` counts
from 1, where `frame_idx` counts from 0; and a frame in which an
instance was not detected comes back as an all-`NA` row rather than
being absent, since the CSV holds a row per *instance* and omits those
entirely.
