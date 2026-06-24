# Check whether a file is readable.

Check whether a file is readable.
[`file.access()`](https://rdrr.io/r/base/file.access.html) reports false
negatives on network (UNC) paths on Windows, so when it claims the file
is unreadable we fall back to a non-destructive attempt to open and read
a single byte.

## Usage

``` r
is_file_readable(path)
```

## Arguments

- path:

  Path(s) to the file.
