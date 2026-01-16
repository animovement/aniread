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

An aniframe object.

## Examples

``` r
if (FALSE) { # \dontrun{
data <- read_aniframe("movement_data.parquet")
} # }
```
