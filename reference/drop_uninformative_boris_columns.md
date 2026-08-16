# Drop columns that carry no per-row information

Trims a handful of BORIS-administrative columns when they're trivially
uniform across the export - keeps the resulting anievent compact for the
common single-observation case while still preserving these columns when
they actually vary (e.g. across observations stacked into a single
file).

## Usage

``` r
drop_uninformative_boris_columns(data)
```
