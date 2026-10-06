# Registry of supported source software

The single place where a supported source software is declared. Each
entry pairs a source name with the reader that opens it, the file
suffix(es) it accepts, the detector that recognises it from the file
itself, and any optional package that detector needs; and, where
`aniread` can write the format, the writer and the suffix(es) it writes.

[`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
is a public view over this registry, and
[`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md),
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
and
[`write_dataset()`](https://animovement.dev/aniread/reference/write_dataset.md)
drive off it, so a new format is added here once rather than in several
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
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  and the `format` argument of
  [`write_dataset()`](https://animovement.dev/aniread/reference/write_dataset.md).

- `reader`:

  Name of the `aniread` function that reads it. Absent for a format that
  is only written.

- `suffix`:

  File suffix(es) the reader accepts, without a leading dot.

- `detector`:

  Function of a single path returning `TRUE` when the file is of this
  source. See
  [`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md)
  for the contract.

- `requires`:

  Named character vector mapping a suffix to the optional package its
  detector needs, or `NULL` when the detector needs nothing beyond
  base R. Suffixes absent from the vector have no requirement.

- `writer`:

  Name of the `aniread` function that writes it. Absent for a format
  that is only read.

- `write_suffix`:

  File suffix(es) the writer writes. When several formats write the same
  suffix,
  [`write_dataset()`](https://animovement.dev/aniread/reference/write_dataset.md)
  infers the first one listed here.
