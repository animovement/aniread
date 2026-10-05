# SLEAP analysis CSV reader

The CSV export carries one row per instance, with columns `track`,
`frame_idx`, `instance.score` and a `.x`/`.y`/`.score` triple per node.
Node names are taken from the columns rather than assumed, since a
recording has whatever skeleton it was tracked with. Columns are matched
by name, so their order does not matter: SLEAP wrote the nodes in
skeleton order with `.x`, `.y`, `.score`, where sleap-io sorts them by
name.

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

A row with an empty `track` is an instance in no track. It is named
`individual1`, `individual2`, ... by its place among the untracked rows
of its frame, as
[`read_sleap_h5()`](https://animovement.dev/aniread/reference/read_sleap_h5.md)
names the instances of a file without track names. sleap-io writes a
frame's user-labelled instances before its predicted ones, and where a
track has both in one frame, the user-labelled one is kept, as
sleap-io's `.h5` export keeps it.

`time` is `frame_idx`, which counts from 0, as
[`read_sleap_h5()`](https://animovement.dev/aniread/reference/read_sleap_h5.md)
counts frames, so one recording reads the same from either export. A
frame in which an instance was not detected comes back as an all-`NA`
row rather than being absent, as it does from the h5, since the CSV
holds a row per *instance* and omits those entirely.
