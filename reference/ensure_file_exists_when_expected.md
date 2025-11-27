# Ensure that the file exists (or not) as needed.

Ensure that the file exists (or not) as needed. This depends on the
expected usage (read and/or write).

## Usage

``` r
ensure_file_exists_when_expected(path, expected_permission)
```

## Arguments

- path:

  Path(s) to the file.

- expected_permission:

  Expected access permission(s) for the file. If "r", the file is
  expected to be readable. If "w", the file is expected to be writable.
  If "rw", the file is expected to be both readable and writable.
  Default: "r".
