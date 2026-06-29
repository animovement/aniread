# Reinstate frames with no detection as all-NA rows

Completes the full `track` × `frame` grid so that every analysed frame
appears for every track. Frames Octron dropped (because nothing was
detected) come back as rows that are NA in every measurement column. The
per-track class `label` is carried onto the reinstated rows so a track
keeps a consistent identity rather than gaining NA identity values.

## Usage

``` r
complete_octron_frames(data, frame_count)
```

## Details

The frame range runs from 0 to `frame_count - 1` (the analysed-frame
count from the CSV header). When the header lacks that field the
observed `time` range is used instead. Frames present in the data but
beyond `frame_count` are preserved.
