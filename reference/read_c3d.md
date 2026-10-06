# Read a C3D motion capture file

Reads a C3D file and returns the data as an aniframe with associated
metadata including source software, units, and sampling rate.

## Usage

``` r
read_c3d(path)
```

## Arguments

- path:

  Path to a `.c3d` file.

## Value

An aniframe with columns `time`, `keypoint`, `x`, `y`, and `z`. Metadata
includes source software, filename, time/space units, and sampling rate.
`time` is in seconds, with the first frame of the recording at 0; see
"Time" in
[`read_dataset()`](https://animovement.dev/aniread/reference/read_dataset.md).

## Details

C3D numbers frames from 1, and a file's header records the frame of the
recording its first frame is, which is not frame 1 when the recording
was trimmed. `time` is in seconds from the first frame of the recording,
so a file that starts at frame 1 starts at `time = 0`, and one trimmed
to start at frame 705 of a 200 Hz recording starts at 3.52 s. A
recording longer than 65535 frames records its first frame in the
`TRIAL` group's `ACTUAL_START_FIELD` parameter instead, which is used
when it is there.

## See also

[`c3dr::c3d_read()`](https://docs.ropensci.org/c3dr/reference/c3d_read.html)
for lower-level C3D access.

## Examples

``` r
# Five frames of a static trial from Vicon Nexus, at 100 Hz
path <- system.file("extdata", "c3d.c3d", package = "aniread")
read_c3d(path)
#> # Keypoints:     *111, *112, *113, *114, C7, CLAV, HEDA, HEDL, HEDO, HEDP,
#> #   LANK, LASI, LAbsAnkleAngle, LAnkleAngles, LBHD, LCLA, LCLL, LCLO, LCLP,
#> #   LELB, LElbowAngles, LFEA, LFEL, LFEO, LFEP, LFHD, LFIN, LFOA, LFOL, LFOO,
#> #   LFOP, LFootProgressAngles, LHEE, LHNA, LHNL, LHNO, LHNP, LHUA, LHUL, LHUO,
#> #   LHUP, LHeadAngles, LHipAngles, LKNE, LKneeAngles, LNeckAngles, LPSI,
#> #   LPelvisAngles, LRAA, LRAL, LRAO, LRAP, LSHO, LShoulderAngles, LSpineAngles,
#> #   LTHI, LTIA, LTIB, LTIL, LTIO, LTIP, LTOA, LTOE, LTOL, LTOO, LTOP,
#> #   LThoraxAngles, LWRA, LWRB, LWristAngles, PELA, PELL, PELO, PELP, RANK,
#> #   RASI, RAbsAnkleAngle, RAnkleAngles, RBAK, RBHD, RCLA, RCLL, RCLO, RCLP,
#> #   RELB, RElbowAngles, RFEA, RFEL, RFEO, RFEP, RFHD, RFIN, RFOA, RFOL, RFOO,
#> #   RFOP, RFootProgressAngles, RHEE, RHNA, RHNL, RHNO, RHNP, RHUA, RHUL, RHUO,
#> #   RHUP, RHeadAngles, RHipAngles, RKNE, RKneeAngles, RNeckAngles, RPSI,
#> #   RPelvisAngles, RRAA, RRAL, RRAO, RRAP, RSHO, RShoulderAngles, RSpineAngles,
#> #   RTHI, RTIA, RTIB, RTIL, RTIO, RTIP, RTOA, RTOE, RTOL, RTOO, RTOP,
#> #   RThoraxAngles, RWRA, RWRB, RWristAngles, STRN, T10, TRXA, TRXL, TRXO, TRXP
#> # Sampling rate: 100 Hz
#> # Time:          00:00:00.000 to 00:00:00.040
#>    keypoint  time     x     y     z
#>    <fct>    <dbl> <dbl> <dbl> <dbl>
#>  1 *111      0     693.  424. 1240.
#>  2 *111      0.01  693.  424. 1240.
#>  3 *111      0.02  693.  424. 1240.
#>  4 *111      0.03  693.  424. 1240.
#>  5 *111      0.04  693.  424. 1240.
#>  6 *112      0    -226.  406. 1214.
#>  7 *112      0.01 -226.  405. 1214.
#>  8 *112      0.02 -226.  405. 1214.
#>  9 *112      0.03 -226.  405. 1214.
#> 10 *112      0.04 -226.  405. 1214.
#> # ℹ 695 more rows
```
