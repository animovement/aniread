# Validate file

The validator ensures that the file:

- is not a directory,

- exists if it is meant to be read,

- does not exist if it is meant to be written,

- has one of the expected suffix(es).

## Usage

``` r
validate_files(
  path,
  expected_permission = "r",
  expected_suffix = NULL,
  expected_headers = NULL
)
```

## Arguments

- path:

  Path(s) to the file.

- expected_permission:

  Expected access permission(s) for the file. If "r", the file is
  expected to be readable. If "w", the file is expected to be writable.
  If "rw", the file is expected to be both readable and writable.
  Default: "r".

- expected_suffix:

  Expected suffix(es) for the file. If NULL (default), this check is
  skipped.

- expected_headers:

  Expected column name(s) to be present among the header names. Default
  is c("x", "y", "time").
