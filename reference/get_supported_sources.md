# List the source software formats aniread can read

Returns the tracking / event software that `aniread` supports, paired
with the reader function for each and the file suffix(es) it accepts.
This lets downstream packages discover the supported formats
programmatically instead of hard-coding the list - mirroring
`movement`'s `get_supported_source_software()`.

## Usage

``` r
get_supported_sources()
```

## Value

A [tibble](https://tibble.tidyverse.org/reference/tibble.html) with one
row per supported source and the columns:

- `source`:

  Character. The source software / format name.

- `reader`:

  Character. The `aniread` function that reads it.

- `suffix`:

  List column of character vectors - the file suffix(es) the reader
  accepts.

## Details

Suffixes are returned without a leading dot (e.g. `"csv"`, `"h5"`),
matching the convention used throughout `aniread` (see the
`expected_suffix` argument of the internal file validator). The generic
[`read_custom()`](https://animovement.dev/aniread/reference/read_custom.md)
reader is intentionally omitted because it has no fixed source software
or file suffix.

The `source` names listed here are exactly those accepted by the
`source` argument of
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
and returned by
[`detect_source()`](https://animovement.dev/aniread/reference/detect_source.md).

## Examples

``` r
get_supported_sources()
#> # A tibble: 18 × 3
#>    source           reader             suffix   
#>    <chr>            <chr>              <list>   
#>  1 aniframe         read_aniframe      <chr [1]>
#>  2 animalta         read_animalta      <chr [1]>
#>  3 anipose          read_anipose       <chr [1]>
#>  4 bonsai           read_bonsai        <chr [1]>
#>  5 boris            read_boris         <chr [2]>
#>  6 c3d              read_c3d           <chr [1]>
#>  7 deeplabcut       read_deeplabcut    <chr [2]>
#>  8 fasttrack        read_fasttrack     <chr [1]>
#>  9 fictrac          read_fictrac       <chr [1]>
#> 10 freemocap        read_freemocap     <chr [1]>
#> 11 idtrackerai      read_idtracker     <chr [2]>
#> 12 lightningpose    read_lightningpose <chr [1]>
#> 13 movement         read_movement      <chr [2]>
#> 14 octron           read_octron        <chr [1]>
#> 15 sleap            read_sleap         <chr [2]>
#> 16 trackball_bonsai read_trackball     <chr [1]>
#> 17 trackmate        read_trackmate     <chr [1]>
#> 18 trex             read_trex          <chr [2]>

# All source names:
get_supported_sources()$source
#>  [1] "aniframe"         "animalta"         "anipose"          "bonsai"          
#>  [5] "boris"            "c3d"              "deeplabcut"       "fasttrack"       
#>  [9] "fictrac"          "freemocap"        "idtrackerai"      "lightningpose"   
#> [13] "movement"         "octron"           "sleap"            "trackball_bonsai"
#> [17] "trackmate"        "trex"            

# Which sources read HDF5 (`.h5`) files?
supported <- get_supported_sources()
supported$source[vapply(supported$suffix, \(s) "h5" %in% s, logical(1))]
#> [1] "deeplabcut"  "idtrackerai" "movement"    "sleap"      
```
