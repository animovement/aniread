# List the formats aniread can read and write

Returns the tracking / event software and file formats that `aniread`
supports, with the function that reads or writes each and the file
suffix(es) it handles. This lets downstream packages discover the
supported formats programmatically instead of hard-coding the list -
mirroring `movement`'s `get_supported_source_software()`.

## Usage

``` r
get_supported_sources()
```

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per supported source and direction, and the columns:

- `source`:

  Character. The source software / format name.

- `direction`:

  Character. `"read"` or `"write"`.

- `fun`:

  Character. The `aniread` function that reads or writes it.

- `suffix`:

  List column of character vectors - the file suffix(es) the function
  reads or writes.

## Details

Suffixes are returned without a leading dot (e.g. `"csv"`, `"h5"`),
matching the convention used throughout `aniread` (see the
`expected_suffix` argument of the internal file validator). The generic
[`read_custom()`](https://animovement.dev/aniread/reference/read_custom.md)
reader is intentionally omitted because it has no fixed source software
or file suffix.

The `source` names of the `"read"` rows are exactly those accepted by
the `source` argument of
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
and returned by
[`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md).
Those of the `"write"` rows are accepted by the `format` argument of
[`write_dataset()`](https://animovement.dev/aniread/reference/write_dataset.md).

## Examples

``` r
get_supported_sources()
#> # A tibble: 20 × 4
#>    source           direction fun                suffix   
#>    <chr>            <chr>     <chr>              <list>   
#>  1 aniframe         read      read_aniframe      <chr [1]>
#>  2 aniframe         write     write_aniframe     <chr [3]>
#>  3 animalta         read      read_animalta      <chr [1]>
#>  4 anipose          read      read_anipose       <chr [1]>
#>  5 bonsai           read      read_bonsai        <chr [1]>
#>  6 boris            read      read_boris         <chr [2]>
#>  7 c3d              read      read_c3d           <chr [1]>
#>  8 deeplabcut       read      read_deeplabcut    <chr [2]>
#>  9 fasttrack        read      read_fasttrack     <chr [1]>
#> 10 fictrac          read      read_fictrac       <chr [1]>
#> 11 freemocap        read      read_freemocap     <chr [1]>
#> 12 idtrackerai      read      read_idtracker     <chr [3]>
#> 13 intracktive      write     write_intracktive  <chr [1]>
#> 14 lightningpose    read      read_lightningpose <chr [1]>
#> 15 movement         read      read_movement      <chr [2]>
#> 16 octron           read      read_octron        <chr [1]>
#> 17 sleap            read      read_sleap         <chr [2]>
#> 18 trackball_bonsai read      read_trackball     <chr [1]>
#> 19 trackmate        read      read_trackmate     <chr [1]>
#> 20 trex             read      read_trex          <chr [2]>

# The formats aniread can write:
supported <- get_supported_sources()
supported[supported$direction == "write", ]
#> # A tibble: 2 × 4
#>   source      direction fun               suffix   
#>   <chr>       <chr>     <chr>             <list>   
#> 1 aniframe    write     write_aniframe    <chr [3]>
#> 2 intracktive write     write_intracktive <chr [1]>

# Which sources read HDF5 (`.h5`) files?
readers <- supported[supported$direction == "read", ]
readers$source[vapply(readers$suffix, \(s) "h5" %in% s, logical(1))]
#> [1] "deeplabcut"  "idtrackerai" "movement"    "sleap"      
```
