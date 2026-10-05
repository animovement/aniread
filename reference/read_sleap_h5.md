# SLEAP HDF5 Reader

Reads `tracks` and `point_scores` into one layout whatever order the
file stores their axes in, following the `dims` attribute sleap-io
writes. `time` is the position on the frame axis, counting from 1.

## Usage

``` r
read_sleap_h5(path)
```
