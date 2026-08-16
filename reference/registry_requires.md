# Optional package a source's detector needs for a given suffix

Optional package a source's detector needs for a given suffix

## Usage

``` r
registry_requires(entry, suffix)
```

## Arguments

- entry:

  A registry entry.

- suffix:

  File suffix, without a leading dot.

## Value

The package name, or `NA_character_` when nothing is required.
