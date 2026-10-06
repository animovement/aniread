# Write a movement or event dataset to any supported format

One entry point for every format `aniread` writes, the counterpart of
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).
By default the format is worked out from the file suffix.

## Usage

``` r
write_dataset(data, path, format = NULL, ...)
```

## Arguments

- data:

  An aniframe: an
  [anipoint](https://animovement.dev/anicore/reference/anipoint.html),
  [anievent](https://animovement.dev/anicore/reference/anievent.html),
  or another frame built on them.

- path:

  Path to write to.

- format:

  Which format to write. `NULL` (the default) infers it from the suffix
  of `path`. Otherwise one of the `"write"` sources in
  [`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md).

- ...:

  Passed on to the writer for `format`.

## Value

`data`, invisibly.

## Details

`write_dataset()` is a dispatcher, not a new writer: it works out which
writer to call and calls it.

When several formats write the same suffix, the first listed in
[`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
is inferred: a `.csv` is written as a plain table by
[`write_aniframe()`](https://animovement.dev/aniread/reference/write_aniframe.md),
and inTRACKtive's CSV needs `format = "intracktive"`.

Parquet keeps everything:
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
gives back the same class, grouping and metadata that were written.
Other formats keep what the format can hold.

## See also

[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
to read the file back,
[`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
for what can be written, and the individual `write_*()` functions for
format-specific arguments.

## Examples

``` r
data <- anicore::example_anipoint()
path <- tempfile(fileext = ".parquet")

write_dataset(data, path)
read_dataset(path)
#> # Individuals: 1, 2, 3
#> # Keypoints:   head, neck, shoulder_right, shoulder_left, abdomen, hip_right,
#> #   hip_left, knee_right, knee_left, foot_right, foot_left
#> # Sessions:    1
#> # Trials:      1
#>    individual keypoint session trial  time        x       y confidence
#>         <int> <fct>      <int> <int> <int>    <dbl>   <dbl>      <dbl>
#>  1          1 head           1     1     1 -1.40    -1.01        0.774
#>  2          1 head           1     1     2  0.255    0.932       0.802
#>  3          1 head           1     1     3 -2.44    -0.651       0.516
#>  4          1 head           1     1     4 -0.00557  0.436       0.725
#>  5          1 head           1     1     5  0.622   -0.164       0.484
#>  6          1 head           1     1     6  1.15     1.27        0.779
#>  7          1 head           1     1     7 -1.82     0.415       0.566
#>  8          1 head           1     1     8 -0.247   -0.0481      0.931
#>  9          1 head           1     1     9 -0.244    0.198       0.578
#> 10          1 head           1     1    10 -0.283   -0.389       0.806
#> # ℹ 1,640 more rows

# Name the format where the suffix is shared
write_dataset(data, tempfile(fileext = ".csv"), format = "intracktive")
#> ✔ Wrote inTRACKtive CSV to /tmp/RtmpwmXOge/file1a404e9ed252.csv
```
