# The key columns to split by

Expands the role names `"what"` and `"when"`, takes the keys named in
braces in `path` when `by` is `NULL`, and checks that the two agree.

## Usage

``` r
resolve_by(data, by, path)
```

## Arguments

- data:

  An aniframe: an
  [anipoint](https://animovement.dev/anicore/reference/anipoint.html),
  [anievent](https://animovement.dev/anicore/reference/anievent.html),
  or another frame built on them.

- by:

  Key columns to write one file per combination of, or `NULL` (the
  default) for a single file. Any of
  [`anicore::get_keys()`](https://animovement.dev/anicore/reference/get_keys.html);
  the role names `"what"` and `"when"` stand for all identity or all
  temporal keys, so `by = c("what", "when")` writes one file per track.
  See "Files per group".

- path:

  Path to write to.

## Value

A character vector of key columns, empty for a single file.
