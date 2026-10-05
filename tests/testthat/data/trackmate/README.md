# TrackMate fixtures

Each file is trimmed from a TrackMate XML published on Zenodo under the
[Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/)
licence (CC BY 4.0), which permits redistributing modified copies with
attribution. The trimmed files are distributed under the same licence.

| Fixture | Source file | Record | Creators | TrackMate | Units |
|---|---|---|---|---|---|
| `crop_1_60_ManualCuration_trimmed.xml` | `crop_1_60_ManualCuration.xml` | Fiji/CellProfiler cell migration timelapse data set and code, [10.5281/zenodo.4317505](https://doi.org/10.5281/zenodo.4317505) | Anna Klemm, Carolina Wählby | 6.0.1 | micron, sec |
| `CelegansEarly_MIP_trimmed.xml` | `CelegansEarly_MIP.xml` | C.elegans embryo early development tracked with TrackMate, [10.5281/zenodo.5132918](https://doi.org/10.5281/zenodo.5132918) | Jean-Yves Tinevez | 7.0.4-SNAPSHOT | µm, min |
| `trpL_150310-11_trimmed.xml` | `trpL_150310-11.xml` | Trackastra integration in TrackMate example, [10.5281/zenodo.12600359](https://doi.org/10.5281/zenodo.12600359) | Simon van Vliet, Annina Winkler | 7.13.2 | blank (`" "`), frame |

What each one covers:

* `crop_1_60_ManualCuration_trimmed.xml`, written before TrackMate 7.
  `Track_1` (read as track `1`) splits and merges again, through links that skip a frame, so it
  never holds two spots in one frame.
* `CelegansEarly_MIP_trimmed.xml`, two cells that each divide once.
* `trpL_150310-11_trimmed.xml`, a blank spatial unit with the time in
  frames, and a bacterial lineage that divides three times.

How they were trimmed, with Python's `xml.etree.ElementTree`, which keeps
every element and attribute it does not remove:

* `crop_1_60_ManualCuration_trimmed.xml`: the tracks `Track_0` and
  `Track_1` (of 25), and frames 0 to 19 (of 60): the other tracks, and the
  spots of later frames and the links to them, are removed.
* `CelegansEarly_MIP_trimmed.xml`: all tracks and spots, without each
  spot's ROI contour (the `ROI_N_POINTS` attribute and the coordinates it
  counts).
* `trpL_150310-11_trimmed.xml`: the track `Track_0` (of 2), frames 0 to 13
  (of 20), and no ROI contours.

`nspots` on `AllSpots` counts the spots kept. The track features (such as
`NUMBER_SPOTS` and `NUMBER_SPLITS`) are still those TrackMate computed for
the whole file.
