# Read DeepLabCut data

Read csv files from DeepLabCut (DLC). The function recognises whether it
is a single- or multi-animal dataset.

## Usage

``` r
read_deeplabcut(path, multianimal = NULL)
```

## Arguments

- path:

  Path to a DeepLabCut data file

- multianimal:

  By default, whether a file is multi-animal is detected automatically.
  This gives an option to ensure it. logical TRUE/FALSE.

## Value

a movement dataframe
