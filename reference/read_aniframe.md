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
if (FALSE) { # \dontrun{
data <- read_aniframe("movement_data.parquet")
} # }
```
