# Read a skeleton as an anistructure

**\[experimental\]**

Reads the skeleton a pose-estimation project defines — its keypoints and
the edges between them — as an
[`anicore::anistructure()`](https://animovement.dev/anicore/reference/anistructure.html)
with points and segments. Attach it to a frame with
[`anicore::set_structure()`](https://animovement.dev/anicore/reference/structures.html).

- `read_structure_deeplabcut()` reads a DeepLabCut project's
  `config.yaml`: `bodyparts`, or `multianimalbodyparts` in a
  multi-animal project, and `skeleton`. A multi-animal project's
  `uniquebodyparts` are left out: DeepLabCut assigns them to a separate
  `"single"` individual, not to each animal's body.

- `read_structure_sleap()` reads a SLEAP `.slp` file (project or
  predictions) or an analysis `.h5` export. Only body edges become
  segments; SLEAP's symmetry edges pair left and right keypoints and are
  not segments.

- `read_structure()` detects which from the file, as
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  does for frames.

Edges keep the direction the file lists them in, which is what
[`anicore::as_anisegment()`](https://animovement.dev/anicore/reference/as_anisegment.html)
measures along.

A frame reader attaches whatever its data file itself contains, so
whether you need these depends on where the tool keeps its skeleton:

- A SLEAP analysis `.h5` carries its skeleton, and
  [`read_sleap()`](https://animovement.dev/aniread/reference/read_sleap.md)
  attaches it as it reads the tracks.

- DeepLabCut keeps its skeleton in the project's `config.yaml`, not in
  the data file, so
  [`read_deeplabcut()`](https://animovement.dev/aniread/reference/read_deeplabcut.md)
  attaches none. Read the config with `read_structure()` and attach it
  with
  [`anicore::set_structure()`](https://animovement.dev/anicore/reference/structures.html).

- SLEAP's analysis CSV carries no skeleton either. Read it from the
  `.slp` or `.h5` of the same recording.

## Usage

``` r
read_structure(path, source = "auto")

read_structure_deeplabcut(path)

read_structure_sleap(path, skeleton = NULL)
```

## Arguments

- path:

  Path to the file.

- source:

  `"auto"` to detect it from the file, or `"deeplabcut"` or `"sleap"`.

- skeleton:

  For a `.slp` holding several skeletons, the name of the one to read.

## Value

An
[`anicore::anistructure()`](https://animovement.dev/anicore/reference/anistructure.html).

## Examples

``` r
# A DeepLabCut project keeps its skeleton in config.yaml
config <- tempfile(fileext = ".yaml")
writeLines(
  c(
    "bodyparts:",
    "- head",
    "- stinger",
    "skeleton:",
    "- - head",
    "  - stinger"
  ),
  config
)
skeleton <- read_structure(config)
skeleton
#> <anistructure> 2 points, 1 segment, 0 joints
#> Points: head, stinger
#> Segments: head - stinger

# Attach it to a frame with the same body parts
path <- system.file("extdata", "deeplabcut.csv", package = "aniread")
read_deeplabcut(path) |>
  anicore::set_structure(skeleton)
#> # Keypoints: head, stinger
#>    keypoint  time     x     y confidence
#>    <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 head         0 1086.  7.05     0.0531
#>  2 head         1 1086.  7.00     0.0353
#>  3 head         2 1086.  6.74     0.0171
#>  4 head         3 1085.  5.96     0.238 
#>  5 head         4 1085.  6.06     0.502 
#>  6 head         5 1085.  6.01     0.510 
#>  7 head         6 1085.  5.77     0.835 
#>  8 head         7 1084.  4.83     0.662 
#>  9 head         8 1084.  4.90     0.461 
#> 10 head         9 1084.  3.85     0.934 
#> 11 stinger      0 1084.  7.24     0.0737
#> 12 stinger      1 1083.  7.09     0.0329
#> 13 stinger      2 1083.  6.94     0.0102
#> 14 stinger      3 1082.  2.87     0.173 
#> 15 stinger      4 1079.  1.34     0.269 
#> 16 stinger      5 1078.  1.65     0.284 
#> 17 stinger      6 1077.  1.25     0.802 
#> 18 stinger      7 1076.  1.75     0.621 
#> 19 stinger      8 1076.  2.13     0.351 
#> 20 stinger      9 1076.  0        0.942 
# A SLEAP analysis .h5 carries the skeleton of its tracks
path <- system.file("extdata", "sleap.analysis.h5", package = "aniread")
skeleton <- read_structure(path)
skeleton
#> <anistructure> 13 points, 12 segments, 0 joints
#> Points: head, thorax, abdomen, wingL, wingR, forelegL4, forelegR4, midlegL4,
#>   midlegR4, hindlegL4, hindlegR4, eyeL, eyeR
#> Segments: head - eyeL, head - eyeR, thorax - head, thorax - abdomen,
#>   thorax - wingL, thorax - wingR, thorax - forelegL4, thorax - forelegR4,
#>   thorax - midlegL4, thorax - midlegR4, thorax - hindlegL4, thorax - hindlegR4
```
