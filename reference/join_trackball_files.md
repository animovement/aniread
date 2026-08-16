# Join data files with non-matching time stamps

Bin both sensors onto a shared time grid. Expects time on the absolute
scale returned by
[`read_opticalflow()`](http://animovement.dev/aniread/reference/read_opticalflow.md) -
the offset between the two files is what the shared window is derived
from, so pre-zeroed input would collapse every recording onto the same
origin.

## Usage

``` r
join_trackball_files(data_list, sampling_rate)
```

## Arguments

- data_list:

  List of 2 dataframes

- sampling_rate:

  Sampling rate
