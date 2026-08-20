# Detect which source software wrote a file

Works out which of the supported source software formats a file is in,
by looking at the file itself rather than trusting its name. This is
what
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
uses when `source = "auto"`.

Candidates are first narrowed to the sources registered for the file's
suffix, then each candidate's detector inspects the file's contents.
Exactly one match is required.

## Usage

``` r
detect_source(paths)
```

## Arguments

- paths:

  Path to the file. If several paths are given (as
  [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
  takes), only the first is inspected.

## Value

The source name, as it appears in
[`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md),
or the combined `"deeplabcut/lightningpose"`.

## Details

DeepLabCut and LightningPose export structurally identical CSV files, so
a file in that format matches both. Rather than guess, `detect_source()`
returns the combined name `"deeplabcut/lightningpose"`;
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
reads it with
[`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md) -
the parse is the same either way - and records the combined name as the
source, so the ambiguity is preserved rather than silently resolved.

Detectors for HDF5, Parquet, XML and C3D files need an optional package
(`rhdf5`, `arrow`, `xml2`, `c3dr`). When one is not installed its
sources are skipped, and if nothing is detected the error names both the
skipped sources and the packages that would have been consulted.

## Writing a detector

A detector is a function of a single path returning `TRUE` when the file
is of that source. It must be cheap - read a handful of lines, or an
HDF5 index, never the whole file - and it need not be defensive:
`detect_source()` runs each one with messages and warnings suppressed
and treats an error as "did not match".

## See also

[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
to read the file,
[`get_supported_sources()`](https://animovement.dev/aniread/reference/get_supported_sources.md)
for the supported formats.

## Examples

``` r
if (FALSE) { # \dontrun{
detect_source("mouse.csv")
#> [1] "deeplabcut/lightningpose"
} # }
```
