# Ensure that the file has the expected access permission(s).

Ensure that the file has the expected access permission(s).

## Usage

``` r
ensure_file_has_access_permissions(path, expected_permission)
```

## Arguments

- path:

  Path(s) to the file.

- expected_permission:

  Expected access permission(s) for the file. If "r", the file is
  expected to be readable. If "w", the file is expected to be writable.
  If "rw", the file is expected to be both readable and writable.
  Default: "r".
