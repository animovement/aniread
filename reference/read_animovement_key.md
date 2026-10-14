# Parse animovement's Parquet metadata key

Parse animovement's Parquet metadata key

## Usage

``` r
read_animovement_key(json)
```

## Arguments

- json:

  The key's value, or `NULL` when the file has none.

## Value

A list, empty when there is no key, parsed without simplifying so
[`anicore::set_metadata_json()`](https://animovement.dev/anicore/reference/metadata_json.html)
can tell an empty array from an empty object.
