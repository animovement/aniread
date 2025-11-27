# Read FreeMoCap motion capture data

Imports FreeMoCap motion capture data from a CSV file and converts it to
an aniframe format. The function expects data in tidy format (typically
files ending in 'by_frame.csv') and will error if other formats are
detected.

## Usage

``` r
read_freemocap(path)
```

## Arguments

- path:

  Character string specifying the path to the FreeMoCap CSV file. Should
  be a file ending in 'by_frame.csv'.

## Value

An aniframe object with the following characteristics:

- Metadata indicating source as "freemocap"

- Spatial units in millimeters (mm)

- 3D Cartesian coordinate system

- Time units in seconds (if timestamps available) or frames (if not)

- Start datetime in metadata (if timestamps available)

## Examples

``` r
if (FALSE) { # \dontrun{
# Read FreeMoCap data
mocap_data <- read_freemocap("path/to/data_by_frame.csv")

# Check metadata
aniframe::get_metadata(mocap_data)
} # }
```
