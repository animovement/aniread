# Write a movement or event dataset to any supported format

One entry point for every format `aniread` writes, the counterpart of
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).
By default the format is worked out from the file suffix.

## Usage

``` r
write_dataset(data, path, format = NULL, by = NULL, ...)
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

- by:

  Key columns to write one file per combination of, or `NULL` (the
  default) for a single file. Any of
  [`anicore::get_keys()`](https://animovement.dev/anicore/reference/get_keys.html);
  the role names `"what"` and `"when"` stand for all identity or all
  temporal keys, so `by = c("what", "when")` writes one file per track.
  See "Files per group".

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

## Files per group

With `by`, each file is named from `path` with the key values appended
before the suffix: `"mice.csv"` with `by = "individual"` gives
`mice_individual-mouse1.csv`, `mice_individual-mouse2.csv`, and so on,
and several keys give `mice_individual-mouse1_session-2.csv`.

For other names, put the keys in `path` in braces:
`"{session}/mice_{individual}.csv"`. The braces then set `by`, so it can
be left out, and directories in `path` are created. Characters other
than letters, digits, `.`, `_` and `-` in a value become `-`.

Each file holds an aniframe with the same class and metadata as `data`.

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
#> ✔ Wrote inTRACKtive CSV to /tmp/RtmpZBT9fG/file1a5735e25353.csv

# One file per individual, or per track
dir <- tempfile()
dir.create(dir)
write_dataset(data, file.path(dir, "mice.parquet"), by = "individual")
#> Wrote 3 files, one per individual, to /tmp/RtmpZBT9fG/file1a575b86fe54.
write_dataset(data, file.path(dir, "{individual}/{keypoint}.parquet"))
#> Wrote 33 files, one per individual and keypoint, to
#> /tmp/RtmpZBT9fG/file1a575b86fe54.
list.files(dir, recursive = TRUE)
#>  [1] "1/abdomen.parquet"         "1/foot_left.parquet"      
#>  [3] "1/foot_right.parquet"      "1/head.parquet"           
#>  [5] "1/hip_left.parquet"        "1/hip_right.parquet"      
#>  [7] "1/knee_left.parquet"       "1/knee_right.parquet"     
#>  [9] "1/neck.parquet"            "1/shoulder_left.parquet"  
#> [11] "1/shoulder_right.parquet"  "2/abdomen.parquet"        
#> [13] "2/foot_left.parquet"       "2/foot_right.parquet"     
#> [15] "2/head.parquet"            "2/hip_left.parquet"       
#> [17] "2/hip_right.parquet"       "2/knee_left.parquet"      
#> [19] "2/knee_right.parquet"      "2/neck.parquet"           
#> [21] "2/shoulder_left.parquet"   "2/shoulder_right.parquet" 
#> [23] "3/abdomen.parquet"         "3/foot_left.parquet"      
#> [25] "3/foot_right.parquet"      "3/head.parquet"           
#> [27] "3/hip_left.parquet"        "3/hip_right.parquet"      
#> [29] "3/knee_left.parquet"       "3/knee_right.parquet"     
#> [31] "3/neck.parquet"            "3/shoulder_left.parquet"  
#> [33] "3/shoulder_right.parquet"  "mice_individual-1.parquet"
#> [35] "mice_individual-2.parquet" "mice_individual-3.parquet"
```
