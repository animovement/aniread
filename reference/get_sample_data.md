# Download sample tracking data

Downloads sample data for different animal tracking software and returns
the path to the downloaded file. The function caches the data to avoid
repeated downloads.

## Usage

``` r
get_sample_data(
  source,
  dataset = NULL,
  cache_dir = tempdir(),
  quiet = FALSE,
  list_datasets = FALSE
)
```

## Arguments

- source:

  Character string specifying either a source name, as
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md)
  names it, or a URL. Currently supported source names:

  - "animalta": Data from AnimalTA

  - "anipose": Mouse paw tracking data

  - "bonsai": Tracking data from Bonsai

  - "c3d": Motion capture in C3D (2 datasets): "example", a walking
    trial, and "sample-static", a static calibration trial

  - "deeplabcut": Mouse/animal tracking from DeepLabCut (4 datasets)

  - "fasttrack": Tracking from FastTrack

  - "fictrac": Fictrac sample data

  - "freemocap": FreeMoCap motion capture of a person doing star jumps
    (4 datasets), from movement's sample data, written by FreeMoCap's
    own saver. The default, "star-jump", is the 9-column `by_frame.csv`
    of v1.7.4 and later; "star-jump_v1.7" is the 8-column one of earlier
    versions; "star-jump_by_trajectory" and "star-jump_wide" are the
    recording's `by_trajectory.csv` and `mediapipe_body_3d_xyz.csv`

  - "idtrackerai": Trajectories from idtracker.ai (2 datasets): the
    `.h5` export, and "trajectories_csv", the CSV export

  - "lightningpose": Mouse tracking from LightningPose (3 datasets). The
    default, "IBL-paw_EKS-left", is the Ensemble Kalman Smoother's
    output for one camera

  - "movement": netCDF files saved by the movement Python package (2
    datasets). The default, "two-mice_octagon", has the dimension names
    movement uses since 0.17.0; "legacy-plural" is the same recording
    with the plural names of earlier versions

  - "octron": Segmentation tracking from OCTRON

  - "sleap": Animal tracking from SLEAP (4 datasets)

  - "trackball_bonsai": Two optical-flow sensors under a trackball,
    logged with Bonsai. Unpacks to one file per sensor and returns both
    paths, which
    [`read_trackball()`](https://animovement.dev/aniread/reference/read_trackball.md)
    reads as one recording

  - "trackmate": Cell tracking from TrackMate (3 datasets)

  - "trex": Multi-animal tracking from TRex (2 datasets). The default,
    "five-locusts", unpacks to one `.npz` per individual and returns a
    vector of paths, which
    [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
    reads as one recording

  `"idtracker"` and `"trackball"`, the names before these matched
  [`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md),
  still work but are deprecated.

  Alternatively, provide a URL string (starting with "http://" or
  "https://") to download a file from a custom location.

- dataset:

  Character string specifying which dataset to download for sources that
  have multiple options. If NULL (default), the first listed dataset is
  used. Call `get_sample_data(list_datasets = TRUE)` to see all
  available options.

- cache_dir:

  Character string specifying the directory where to cache the
  downloaded files. Defaults to a temporary directory using
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html). Set to a
  permanent location to persist data across R sessions.

- quiet:

  TRUE/FALSE. TRUE suppresses inform messages.

- list_datasets:

  TRUE/FALSE. If TRUE, prints available sources and datasets. Can be
  called with or without specifying a source.

## Value

Character string (or vector) with the path(s) to the downloaded file(s).
For a dataset distributed as a zip file (the TRex "five-locusts" and
trackball datasets), returns a character vector of paths to the files it
unpacks to. For all others, returns a single file path. Returns NULL
invisibly if `list_datasets = TRUE`.

## Details

The function downloads sample data and caches it locally. If the file
already exists in the cache directory, it will use the cached version
instead of downloading again.

Some sources have multiple datasets available. The first dataset listed
for each source is used by default when `dataset = NULL`.

Special handling for TRex datasets: TRex datasets are distributed as zip
files containing multiple individual tracking files (one per animal).
The function automatically extracts these and returns a vector of paths
to the individual files.

The predefined data sources are hosted at:

- https://gin.swc.ucl.ac.uk/neuroinformatics/movement-sample-data

- https://github.com/animovement/movement-data

## Examples

``` r
if (FALSE) { # \dontrun{
# See all available sources and datasets
get_sample_data(list_datasets = TRUE)

# See datasets for a specific source
get_sample_data("sleap", list_datasets = TRUE)

# Get default dataset for SLEAP
path <- get_sample_data("sleap")

# Get a specific SLEAP dataset
path <- get_sample_data("sleap", dataset = "zebras_drone")

# Get TRex data (returns vector of paths to individual files)
paths <- get_sample_data("trex")

# Download from a custom URL
path <- get_sample_data("https://example.com/data/tracking.csv")
} # }
```
