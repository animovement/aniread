# Detect the layout of an optical flow file

Bonsai writes headerless CSV, sometimes preceded by a line of
serial-port junk (a partial row, or a run of noise characters). Rather
than assuming a fixed number of leading lines, take the modal field
count over the start of the file as the true record width and skip
everything before the first line that matches it.

## Usage

``` r
detect_opticalflow_layout(path, n_peek = 20)
```

## Arguments

- path:

  Path to the file.

- n_peek:

  Number of leading lines to inspect.

## Value

A list with `skip` (lines to discard) and `has_header` (`TRUE` when the
first kept line names the columns, `FALSE` when it is already data).
