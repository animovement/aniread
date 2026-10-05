# Work out which AnimalTA export layout a file uses

AnimalTA's layouts are separable from their first line, so `"auto"`
reads the layout from the header rather than asking for it. Before it
looked, a file read with the wrong default gave a header error naming
columns the user had never heard of rather than pointing at the argument
(#88).

## Usage

``` r
resolve_animalta_layout(path, format)
```

## Arguments

- path:

  Path to the file, or several detailed files.

- format:

  `"auto"`, or the layout to require.

## Value

`"fixed"`, `"variable"` or `"detailed"`.
