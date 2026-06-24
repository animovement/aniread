# Read a tabular BORIS export

Dispatches between the two flavours BORIS produces:

## Usage

``` r
read_boris_tabular(path)
```

## Details

- **Flat header** (newer): row 1 is a full data header containing
  `Subject` / `Behavior` plus all observation-level metadata broadcast
  as repeating per-row columns. The transition status (`START` / `STOP`
  / `POINT`) lives in the `Behavior type` column.

- **Header-block** (older): rows 1..N are a 2-column key/value block of
  observation metadata, a blank-ish separator follows, then a
  `Time<delim>...<delim>Status` data header.
