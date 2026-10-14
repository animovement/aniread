# Read an aniframe from a Parquet file

Reads movement data from a Parquet file and returns an aniframe object.
Parquet files are required as they preserve the metadata necessary for
aniframe objects.

## Usage

``` r
read_aniframe(path)
```

## Arguments

- path:

  Path to a Parquet file.

## Value

The aniframe that was written, with its class: an anipoint, an anievent,
or another frame built on them, such as an anijoint. `time` is as it was
written; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Examples

``` r
path <- tempfile(fileext = ".parquet")
write_aniframe(anicore::example_anipoint(), path)
read_aniframe(path)
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
```
