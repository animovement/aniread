# Read idtracker.ai data

Read idtracker.ai data

## Usage

``` r
read_idtracker(path, path_probabilities = NULL, version = 6)
```

## Arguments

- path:

  Path to an idtracker.ai data frame

- path_probabilities:

  Path to a csv file with probabilities. Only needed if you are reading
  csv files as they are included in h5 files.

- version:

  idtracker.ai version. Currently only v6 output is implemented

## Value

a movement dataframe
