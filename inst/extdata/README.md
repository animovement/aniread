# Example files

The files the readers' examples read. This note records where the following
ones came from, who made them and under what licence they are distributed.

| File | Reader | Source | Creators | Licence |
|---|---|---|---|---|
| `c3d.c3d` | `read_c3d()` | `SampleData/ROM/Sample_Static.c3d` from [pyCGM](https://github.com/cadop/pyCGM) | Mathew Schwartz (cadop) | MIT |
| `movement.nc` | `read_movement()` | `poses/MOVE_two-mice_octagon.analysis.nc` from [movement's sample data](https://gin.swc.ucl.ac.uk/neuroinformatics/movement-sample-data) | Mehul Rastogi and Chunyu Ann Duan (SLEAP tracking), Niko Sirmpilatze (movement file), Sainsbury Wellcome Centre, UCL | CC BY 4.0 |
| `sleap.analysis.csv`, `sleap.analysis.h5` | `read_sleap()` | `tests/data/slp/predictions_1.2.7_provenance_and_tracking.slp` from [sleap-io](https://github.com/talmolab/sleap-io) at tag v0.9.2 | Talmo Lab | BSD-3-Clause |
| `trackmate.xml` | `read_trackmate()` | `CelegansEarly_MIP.xml` from *C.elegans embryo early development tracked with TrackMate*, [10.5281/zenodo.5132918](https://doi.org/10.5281/zenodo.5132918) | Jean-Yves Tinevez | CC BY 4.0 |

The CC BY 4.0 files are modified copies, distributed under the same licence,
<https://creativecommons.org/licenses/by/4.0/>. The MIT and BSD-3-Clause
notices are reproduced below.

## How each file was made

* `c3d.c3d`: the first 5 of the 275 frames of `Sample_Static.c3d`, a static
  trial written by Vicon Nexus 1.8.5 at 100 Hz, with all 141 points (Plug-in
  Gait markers and model outputs, in mm), all 10 analog channels and every
  parameter. Written by c3dr 0.2.1's own writer (ezc3d), which adds an `EZC3D`
  parameter group naming itself; the frame count and `TRIAL:ACTUAL_END_FIELD`
  are updated to 5 frames. The source file (sha256 `16cc70ae...4ffe300a8b`) is
  also distributed unchanged by animovement/movement-data, as
  `data/c3d/Sample_Static.c3d`. `data-raw/extdata_c3d.R` in the source
  repository writes it. pyCGM does not say who recorded the trial; cite
  Schwartz and Dixon (2018), doi:10.1371/journal.pone.0189984.
* `movement.nc`: the first 4 frames of `MOVE_two-mice_octagon.analysis.nc`,
  two mice competing for rewards in an octagonal arena
  (doi:10.1101/2025.02.14.638359), tracked with SLEAP and converted to netCDF
  with movement. Written by movement 0.17.0 (`load_poses.from_numpy()`, then
  xarray's `to_netcdf()`) with `fps = 50`, and `source_file` cut to its file
  name. It is `tests/testthat/data/movement/two-mice_seconds_singular.nc`.
* `sleap.analysis.csv` and `sleap.analysis.h5`: two tracked flies, 13 nodes,
  in frames 0 to 5 of a video declared 9 frames long, with `track_1` removed
  from frame 3, and a provenance record of SLEAP 1.2.7. Written by sleap-io
  0.9.2's `save_csv()` and `save_analysis_h5()` (preset `"matlab"`, SLEAP's
  own layout). They are `tests/testthat/data/sleap/SLEAP_two-flies_sleap-io.analysis.csv`
  and `SLEAP_two-flies_sleap-io.matlab.analysis.h5`.
* `trackmate.xml`: one cell, `Track_0`, in frames 6 to 10 of 17 (2 min apart,
  positions in µm), dividing between frames 8 and 9: three spots before the
  division and two in each daughter. The source file was written by TrackMate
  7.0.4-SNAPSHOT. Trimmed from
  `tests/testthat/data/trackmate/CelegansEarly_MIP_trimmed.xml` (the whole file
  without the spots' ROI contours) with Python's `xml.etree.ElementTree`, which
  keeps every element and attribute it does not remove: the other track and
  the other spots and their links are removed, and the log is cut to its first
  two lines. The track features, such as `NUMBER_SPOTS`, are still those
  TrackMate computed for the whole track. `data-raw/extdata_trackmate.py` in
  the source repository writes it.

## pyCGM (MIT)

```
The MIT License (MIT)

Copyright (c) 2015 cadop

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## sleap-io (BSD-3-Clause)

```
BSD 3-Clause License

Copyright (c) 2022, Talmo Lab
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
