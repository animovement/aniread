# Read SLEAP data

Reads either of SLEAP's analysis exports: the HDF5 file, or the CSV with
columns `track`, `frame_idx`, `instance.score` and a `.x`/`.y`/`.score`
triple per node.

## Usage

``` r
read_sleap(path, video_height = NULL)
```

## Arguments

- path:

  A SLEAP analysis file, either HDF5 (`.h5`) or CSV.

- video_height:

  Optional numeric height of the source video frame in pixels.

## Value

a movement dataframe. `time` is SLEAP's frame index, so the first frame
of the video is at `time = 0`; see "Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

SLEAP stores predictions in image (top-left) coordinates; the reader
reflects y so the returned aniframe is in the conventional `bottom_left`
origin. Neither export includes the source video resolution, so pass
`video_height` to get an accurate flip — otherwise `max(y)` is used as a
fallback.

`individual` is the track name SLEAP recorded, from either export. A
recording with no tracks - a single unnamed instance, or predictions
that were never tracked - has no names to use, and falls back to
`individual1`, `individual2`, and so on. In the CSV, where such rows
have an empty `track`, they are numbered in the order they appear within
each frame. sleap-io (which writes SLEAP's exports from SLEAP 1.6.3 on)
gives the instances of an untracked recording the names `track_0`,
`track_1`, ... in the `.h5`, and those are kept like any other track
name.

Both the files SLEAP wrote itself and those written by sleap-io are
read. sleap-io can store the `.h5` arrays in another axis order (its
`"standard"` preset, or custom axes) and records the order in each
dataset's `dims` attribute, which the reader follows; a file without it
has SLEAP's original layout. The frame axis of a sleap-io `.h5` runs to
the end of the video, so frames after the last detection come back as
`NA` rows, as undetected frames always have. Very old `.h5` files have
no `point_scores`, and give `NA` confidence.

The `.h5` also carries the skeleton the recording was tracked with and a
record of the run, and both are kept:

- The skeleton is attached as the frame's `keypoint` structure, read as
  [`read_structure_sleap()`](https://animovement.dev/aniread/reference/read_structure.md)
  reads it: the nodes become points and the body edges segments. A file
  written without edges gives points alone.

- The SLEAP version that ran the tracking, from the file's `provenance`
  record, becomes the `source_version` metadata field. When the record
  names none, a file written by sleap-io gives the sleap-io version that
  wrote it instead, as `"sleap-io 0.9.2"` for example. It stays `NA`
  when the file records neither.

The CSV carries neither, so a frame read from it has no structure and no
`source_version`. Attach one with
[`read_structure()`](https://animovement.dev/aniread/reference/read_structure.md)
and
[`anicore::set_structure()`](https://animovement.dev/anicore/reference/structures.html).

## Examples

``` r
# Two flies tracked with SLEAP, in the analysis CSV
path <- system.file("extdata", "sleap.analysis.csv", package = "aniread")
read_sleap(path)
#> # Individuals: track_0, track_1
#> # Keypoints:   abdomen, eyeL, eyeR, forelegL4, forelegR4, head, hindlegL4,
#> #   hindlegR4, midlegL4, midlegR4, thorax, wingL, wingR
#>    individual keypoint  time     x     y confidence
#>    <fct>      <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 track_0    abdomen      0  240. 432.       0.489
#>  2 track_0    abdomen      1  403. 224.       0.955
#>  3 track_0    abdomen      2  584.  92.4      0.580
#>  4 track_0    abdomen      3  380.  99.8      0.741
#>  5 track_0    abdomen      4  265. 333.       0.636
#>  6 track_0    abdomen      5  268. 336.       0.736
#>  7 track_0    eyeL         0  213. 372.       0.851
#>  8 track_0    eyeL         1  440. 180.       1.07 
#>  9 track_0    eyeL         2  600.  28.4      1.00 
#> 10 track_0    eyeL         3  328. 128.       0.781
#> # ℹ 146 more rows

# The same predictions in the analysis .h5, whose frames run to the end of
# the video, and which also carries the skeleton and the SLEAP version
path <- system.file("extdata", "sleap.analysis.h5", package = "aniread")
flies <- read_sleap(path)
flies
#> # Individuals: track_0, track_1
#> # Keypoints:   abdomen, eyeL, eyeR, forelegL4, forelegR4, head, hindlegL4,
#> #   hindlegR4, midlegL4, midlegR4, thorax, wingL, wingR
#>    individual keypoint  time     x     y confidence
#>    <fct>      <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 track_0    abdomen      0  240. 432.       0.489
#>  2 track_0    abdomen      1  403. 224.       0.955
#>  3 track_0    abdomen      2  584.  92.4      0.580
#>  4 track_0    abdomen      3  380.  99.8      0.741
#>  5 track_0    abdomen      4  265. 333.       0.636
#>  6 track_0    abdomen      5  268. 336.       0.736
#>  7 track_0    abdomen      6   NA   NA       NA    
#>  8 track_0    abdomen      7   NA   NA       NA    
#>  9 track_0    abdomen      8   NA   NA       NA    
#> 10 track_0    eyeL         0  213. 372.       0.851
#> # ℹ 224 more rows
anicore::get_structure(flies)
#> $keypoint
#> <anistructure> 13 points, 12 segments, 0 joints
#> variable: keypoint
#> Points: head, thorax, abdomen, wingL, wingR, forelegL4, forelegR4, midlegL4,
#>   midlegR4, hindlegL4, hindlegR4, eyeL, eyeR
#> Segments: head - eyeL, head - eyeR, thorax - head, thorax - abdomen,
#>   thorax - wingL, thorax - wingR, thorax - forelegL4, thorax - forelegR4,
#>   thorax - midlegL4, thorax - midlegR4, thorax - hindlegL4, thorax - hindlegR4
#> 
anicore::get_metadata(flies, "source_version")
#> [1] "1.2.7"
```
