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

## Examples

``` r
path <- system.file("extdata", "animalta.csv", package = "aniread")
read_animalta(path)
#> # Individuals: arena0_ind0, arena1_ind0, arena2_ind0, arena3_ind0, arena4_ind0,
#> #   arena5_ind0, arena6_ind0, arena7_ind0, arena8_ind0
#> # Keypoints:   centroid
#>    individual  keypoint  time     x     y confidence
#>    <fct>       <fct>    <dbl> <dbl> <dbl>      <dbl>
#>  1 arena0_ind0 centroid  639.  557.  640.         NA
#>  2 arena0_ind0 centroid  639.  556.  643.         NA
#>  3 arena0_ind0 centroid  639.  553.  647.         NA
#>  4 arena0_ind0 centroid  639.  551.  650.         NA
#>  5 arena0_ind0 centroid  639.  551.  652.         NA
#>  6 arena0_ind0 centroid  639.  549.  657.         NA
#>  7 arena0_ind0 centroid  639.  548.  661.         NA
#>  8 arena0_ind0 centroid  639.  547   665.         NA
#>  9 arena0_ind0 centroid  639.  547.  670.         NA
#> 10 arena0_ind0 centroid  639.  548.  671.         NA
#> # ℹ 80 more rows
```
