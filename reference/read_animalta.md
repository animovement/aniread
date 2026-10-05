# Read AnimalTA data

Read a data frame from AnimalTA. AnimalTA exports tracking data in image
(top-left) coordinates; the reader reflects y so the returned aniframe
is in the conventional `bottom_left` origin.

AnimalTA writes positions in three layouts, and the reader reads all
three. Which one it read is recorded in the `source_format` metadata
field.

- `"fixed"`: the coordinates file of a video tracked with a fixed number
  of targets (`coordinates/<video>_Coordinates.csv`, or
  `corrected_coordinates/<video>_Corrected.csv` once corrected). One row
  per frame, with a pair of columns per target, `X_Arena<a>_Ind<i>` and
  `Y_Arena<a>_Ind<i>`. When a target alone in its arena was tracked with
  AnimalTA's "Separate head from tail" option, its pair is replaced by
  `X_Arena<a>_Ind<i>_Head`, `Y_..._Head`, `X_..._Tail` and `Y_..._Tail`.
  Once the tracking is corrected, AnimalTA holds them as two targets and
  names the same columns `X_Arena<a>_Ind<i>_part0` and so on for the
  head and `..._part1` for the tail. Both become the keypoints `head`
  and `tail` of `Ind<i>`; AnimalTA writes no centroid for such a target.
  Every other target has the keypoint `centroid`, AnimalTA's name for
  the one position it tracks.

- `"variable"`: the coordinates file of a video tracked with a variable
  number of targets. One row per target and frame, in the columns
  `Frame`, `Time`, `Arena`, `Ind`, `X` and `Y`.

- `"detailed"`: a file from the "Detailed data" folder that AnimalTA's
  "Run analyses" writes,
  `Results/Detailed_data/<video>/Arena_<a><target>.csv`. It holds one
  target, one row per frame, and the columns ticked under "Detailed data
  columns": by default `Time`, `X`, `Y` (`X_Smoothed` and `Y_Smoothed`
  when a smoothing filter was applied) and measures derived from them,
  such as `Distance` and `Speed`. Only the time and positions are kept.
  The target is named from the file name. Several files, one per target,
  can be read at once by passing their paths together. A target tracked
  with "Separate head from tail" has two files,
  `Arena_<a>Ind<i>_part0.csv` for its head and
  `Arena_<a>Ind<i>_part1.csv` for its tail, which read together as the
  keypoints `head` and `tail` of one individual.

AnimalTA's head and tail are the two ends of the animal's skeleton, kept
apart from frame to frame by distance. AnimalTA does not work out which
end is the head, so check that `head` is the head before relying on it.

Positions in the coordinates files are in pixels. Positions in a
detailed file are in the unit of the scale set in AnimalTA, and in
pixels when none was set. The file does not record which, so
`unit_space` keeps its default of `"px"`; if a scale was set, declare
its unit with
[`anicore::set_metadata()`](https://animovement.dev/anicore/reference/set_metadata.html),
and give `video_height` in that unit too.

AnimalTA writes the time since the start of the video in seconds in its
`Time` column, rounded to 0.01 s in the coordinates files and to 0.001 s
in a detailed file. The reader keeps it as `time`, so `unit_time` is
`"s"`. A detailed file exported without the `Time` column but with
`Frame` is timed by its frame number instead, with `unit_time`
`"frame"`.

AnimalTA does not write the frame rate, but each row is a frame at the
rate it tracked at: the coordinates files give its number in `Frame`,
and a detailed file has a row for every frame. When every row agrees on
one rate, to within the rounding of `Time`, it becomes `sampling_rate`:
the frames between the first and last row over the seconds between them,
or the whole number nearest to it when that fits every row as well.
Otherwise it is left `NA`. In a short file the rounding leaves the rate
uncertain by about one rounding step over the file's duration.

AnimalTA numbers individuals from 0 within each arena, so an individual
is identified by its arena and its name together. The arena is its own
identity column, `arena`, holding AnimalTA's arena number (`"0"`, `"1"`,
...), and `individual` holds AnimalTA's name for the target: `Ind<i>`,
or the name it was given in AnimalTA, with its case kept. Every layout
gives the same values: the fixed layout's columns are named
`X_Arena<a>_Ind<i>`, the variable layout's `Arena` and `Ind` columns
hold the same arena and target, and so does a detailed file's name,
`Arena_<a>Ind<i>.csv`. A detailed file whose name is not in that form is
named after the file, with its arena `NA`. `arena`, `individual` and
`keypoint` are the aniframe's identity keys, so functions that work per
individual keep arenas apart. The `arena` column is there for every
file, also when it has a single arena.

## Usage

``` r
read_animalta(
  path,
  format = c("auto", "fixed", "variable", "detailed"),
  video_height = NULL,
  detailed = deprecated()
)
```

## Arguments

- path:

  Path to an AnimalTA file. Several detailed files, one per target, can
  be given together.

- format:

  **\[experimental\]** Which layout the file uses: `"auto"` (the
  default) reads it from the header; `"fixed"`, `"variable"` or
  `"detailed"` require that layout and error on anything else. The
  layout names may change while one convention for readers of a source
  with several export layouts is settled
  ([\#118](https://github.com/animovement/aniread/issues/118)).

- video_height:

  Optional numeric height of the source video frame, in pixels for the
  coordinates files. AnimalTA does not record this in the export, so
  when not supplied the maximum observed `y` is used as a fallback.

- detailed:

  **\[deprecated\]** Use `format` instead. `detailed = TRUE` named the
  layout of a variable number of targets, now `format = "variable"`, and
  `detailed = FALSE` the fixed one, now `format = "fixed"`.

## Value

a movement dataframe. `time` is AnimalTA's `Time` (or `Frame`), with the
first frame of the video at 0; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## References

- Chiara, V., & Kim, S.-Y. (2023). AnimalTA: A highly flexible and
  easy-to-use program for tracking and analysing animal movement in
  different environments. *Methods in Ecology and Evolution*, 14,
  1699–1707.
  [doi:0.1111/2041-210X.14115](https://doi.org/0.1111/2041-210X.14115) .

## Examples

``` r
path <- system.file("extdata", "animalta.csv", package = "aniread")
read_animalta(path)
#> # Arenas:        0, 1, 2, 3, 4, 5, 6, 7, 8
#> # Individuals:   Ind0
#> # Keypoints:     centroid
#> # Sampling rate: 30 Hz
#> # Time:          00:10:39.070 to 00:10:39.370
#>    arena individual keypoint  time     x     y confidence
#>    <fct> <fct>      <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 0     Ind0       centroid  639.  557.  640.         NA
#>  2 0     Ind0       centroid  639.  556.  643.         NA
#>  3 0     Ind0       centroid  639.  553.  647.         NA
#>  4 0     Ind0       centroid  639.  551.  650.         NA
#>  5 0     Ind0       centroid  639.  551.  652.         NA
#>  6 0     Ind0       centroid  639.  549.  657.         NA
#>  7 0     Ind0       centroid  639.  548.  661.         NA
#>  8 0     Ind0       centroid  639.  547   665.         NA
#>  9 0     Ind0       centroid  639.  547.  670.         NA
#> 10 0     Ind0       centroid  639.  548.  671.         NA
#> # ℹ 80 more rows
```
