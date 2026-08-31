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

  Character string specifying either a tracking software name or a URL.
  Currently supported software names:

  - "animalta": Data from AnimalTA

  - "anipose": Mouse paw tracking data

  - "bonsai": Tracking data from Bonsai

  - "deeplabcut": Mouse/animal tracking from DeepLabCut (3 datasets)

  - "fictrac": Fictrac sample data

  - "freemocap": FreeMoCap motion capture test data

  - "idtracker": Trajectories from idtracker.ai

  - "lightningpose": Mouse tracking from LightningPose (2 datasets)

  - "movement": Movement package native format (2 datasets)

  - "sleap": Animal tracking from SLEAP (3 datasets)

  - "trex": Multi-animal tracking from TRex (2 datasets). The default,
    "five-locusts", unpacks to one `.npz` per individual and returns a
    vector of paths, which
    [`read_trex()`](https://animovement.dev/aniread/reference/read_trex.md)
    reads as one recording

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
For TRex datasets, returns a character vector of paths to the individual
tracking files. For all other sources, returns a single file path.
Returns NULL invisibly if `list_datasets = TRUE`.

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

- https://gin.g-node.org/neuroinformatics/movement-test-data

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
