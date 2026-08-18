# Work out which AnimalTA export layout a file uses

The two layouts are separable from their first line — the raw export
continues into `X_Arena<n>_Ind<n>` columns, the detailed one into
`Arena;Ind;X;Y` — and
[`read_animalta()`](http://animovement.dev/aniread/reference/read_animalta.md)
already encodes both header sets. It just used to consult its argument
instead of looking, so a detailed file read with the default gave a
header error naming columns the user had never heard of rather than
pointing at `detailed` (#88).

## Usage

``` r
resolve_animalta_layout(path, detailed)
```

## Arguments

- path:

  Path to the file.

- detailed:

  `"auto"`, or a logical stating the layout outright.

## Value

`TRUE` for the detailed layout, `FALSE` for the raw one.
