# Decode a protocol 0 pickle's unicode string

Python writes these as "raw-unicode-escape": characters below 256 as
their Latin-1 byte, the rest as `\uXXXX` or `\UXXXXXXXX`.

## Usage

``` r
decode_pickle_unicode(bytes)
```

## Arguments

- bytes:

  The string's bytes.

## Value

A UTF-8 string.
