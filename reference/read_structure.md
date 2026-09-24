# Read a skeleton as an anistructure

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
if (FALSE) { # \dontrun{
skeleton <- read_structure("my-project/config.yaml")
af <- read_deeplabcut("my-project/videos/mouse1DLC.csv") |>
  anicore::set_structure(skeleton)
} # }
```
