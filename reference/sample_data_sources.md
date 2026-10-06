# Sample datasets, by source

Keys are the source names of
[`source_registry()`](https://animovement.dev/aniread/reference/source_registry.md),
so a source is named the same here as in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).
The first dataset of a source is its default; keep defaults small.

## Usage

``` r
sample_data_sources()
```

## Value

A named list of sources, each a named list of datasets with `url` and
`filename`.
