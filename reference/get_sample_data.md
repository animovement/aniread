# Download sample tracking data

Downloads sample data for different animal tracking software and returns
the path to the downloaded file. The function caches the data to avoid
repeated downloads.

## Usage

``` r
get_sample_data(source, cache_dir = tempdir(), quiet = FALSE)
```

## Arguments

- source:

  Character string specifying the tracking software. Currently
  supported:

  - "animalta": Data from AnimalTA (single individual, multi-arena)

  - "anipose": Mouse paw tracking data

  - "bonsai": Tracking data from Bonsai

  - "deeplabcut": Mouse tracking from DeepLabCut

  - "fictrac": Fictrac sample data (.dat format)

  - "freemocap": FreeMoCap test data by frame

  - "idtrackerai": Trajectories from idtracker.ai (.h5 format)

  - "lightningpose": Mouse tracking from LightningPose

  - "sleap": Single mouse EPM tracking from SLEAP (.h5 format)

  - "trex": Beetle tracking from TRex

- cache_dir:

  Character string specifying the directory where to cache the
  downloaded files. Defaults to a temporary directory using
  [`tempdir()`](https://rdrr.io/r/base/tempfile.html). Set to a
  permanent location to persist data across R sessions.

- quiet:

  TRUE/FALSE. TRUE suppresses inform messages.

## Value

Character string with the path to the downloaded file.

## Details

The function downloads sample data from a GitHub repository and caches
it locally. If the file already exists in the cache directory, it will
use the cached version instead of downloading it again.

The data sources are hosted at:
https://github.com/animovement/movement-data

## Examples

``` r
if (FALSE) { # \dontrun{
# Get path to DeepLabCut sample data
path <- get_sample_data("deeplabcut")

# Read the data with the corresponding reader function
data <- read_deeplabcut(path)
} # }
```
