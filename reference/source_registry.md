# Registry of supported source software

The single place where a supported source software is declared. Each
entry pairs a source name with the reader that opens it, the file
suffix(es) it accepts, the detector that recognises it from the file
itself, and any optional package that detector needs.

[`get_supported_sources()`](http://animovement.dev/aniread/reference/get_supported_sources.md)
is a public view over this registry, and
[`detect_source()`](http://animovement.dev/aniread/reference/detect_source.md)
and
[`read_dataset()`](http://animovement.dev/aniread/reference/read_dataset.md)
drive off it, so a new format is added here once rather than in three
places.

## Usage

``` r
source_registry()
```

## Value

A list of registry entries.

## Entry fields

- `source`:

  Source software name, as accepted by the `source` argument of
  [`read_dataset()`](http://animovement.dev/aniread/reference/read_dataset.md).

- `reader`:

  Name of the `aniread` function that reads it.

- `suffix`:

  File suffix(es) accepted, without a leading dot.

- `detector`:

  Function of a single path returning `TRUE` when the file is of this
  source. See
  [`detect_source()`](http://animovement.dev/aniread/reference/detect_source.md)
  for the contract.

- `requires`:

  Named character vector mapping a suffix to the optional package its
  detector needs, or `NULL` when the detector needs nothing beyond
  base R. Suffixes absent from the vector have no requirement.
