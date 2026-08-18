# Read AnimalTA data

Read a data frame from AnimalTA. AnimalTA exports tracking data in image
(top-left) coordinates; the reader reflects y so the returned aniframe
is in the conventional `bottom_left` origin.

## Usage

``` r
read_animalta(path, detailed = "auto", video_height = NULL)
```

## Arguments

- path:

  An AnimalTA data frame

- detailed:

  Which export layout the file uses. `"auto"` (the default) reads it
  from the header: the raw layout continues into `X_Arena<n>_Ind<n>`
  columns, the detailed one into `Arena;Ind;X;Y`. Pass `TRUE` or `FALSE`
  to state it explicitly. We only have limited support for detailed
  data.

- video_height:

  Optional numeric height of the source video frame in pixels. AnimalTA
  does not record this in the export, so when not supplied the maximum
  observed `y` is used as a fallback.

## Value

a movement dataframe

## References

- Chiara, V., & Kim, S.-Y. (2023). AnimalTA: A highly flexible and
  easy-to-use program for tracking and analysing animal movement in
  different environments. *Methods in Ecology and Evolution*, 14,
  1699–1707.
  [doi:0.1111/2041-210X.14115](https://doi.org/0.1111/2041-210X.14115) .
