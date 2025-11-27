# Write an *aniframe* to disk

This high‑level wrapper writes an **aniframe** object to a file in one
of the supported formats (`parquet`, `csv`, or `tsv`). We highly
recommend using `parquet` as neither `csv` or `tsv` can preserve the
metadata.

## Usage

``` r
write_aniframe(data, filename, ...)
```

## Arguments

- data:

  An **aniframe** object (see
  [`aniframe::is_aniframe()`](http://animovement.dev/aniframe/reference/is_aniframe.md)).

- filename:

  Character string specifying the output file name. The file extension
  determines which writer is used.

- ...:

  Additional arguments passed to the format‑specific writer
  (`write_aniframe_csv()` or `write_aniframe_parquet()`). Typical
  arguments include `delim`, `col_names`, `compression`, etc., depending
  on the backend.

## Value

The original `data` object (invisibly), enabling pipe‑friendly usage.

## Details

- **Supported extensions** are `"parquet"`, `"csv"` and `"tsv"`. We
  highly recommend using `parquet` as neither `csv` or `tsv` can
  preserve the metadata.

- CSV/TSV files are written with the *vroom* for fast I/O.

- Parquet files are written with the *arrow* package is installed
  (install‑on‑demand if missing).

## Examples

``` r
if (FALSE) { # \dontrun{
## Create a small aniframe for demonstration
df <- aniframe::example_aniframe()

## Write the aniframe as CSV
write_aniframe(df, "demo.csv")

## Write the same aniframe as Parquet
write_aniframe(df, "demo.parquet")
} # }
```
