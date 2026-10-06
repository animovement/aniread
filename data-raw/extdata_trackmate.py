"""Write inst/extdata/trackmate.xml: one dividing cell over five frames.

    python3 data-raw/extdata_trackmate.py

Trims tests/testthat/data/trackmate/CelegansEarly_MIP_trimmed.xml, itself
CelegansEarly_MIP.xml from Zenodo record 10.5281/zenodo.5132918 (Jean-Yves
Tinevez, CC BY 4.0) without its spots' ROI contours (see the README there),
with Python's xml.etree.ElementTree, which keeps every element and attribute it
does not remove:

* the track Track_0 (of 2), which divides once, between frames 8 and 9;
* its spots in frames 6 to 10 (of 0 to 16), and the links between them: three
  spots before the division and two in each daughter. The other spots, and
  the frames left without spots, are removed, and nspots on AllSpots counts
  the spots kept;
* the log cut to its first two lines, the TrackMate version and when it ran.

The track, spot and link features are those TrackMate computed for the whole
file, so the track's NUMBER_SPOTS still counts all 25 of its spots.
"""

import xml.etree.ElementTree as ET

SOURCE = "tests/testthat/data/trackmate/CelegansEarly_MIP_trimmed.xml"
DEST = "inst/extdata/trackmate.xml"
TRACK_ID = "0"
FIRST_FRAME, LAST_FRAME = 6, 10

tree = ET.parse(SOURCE)
root = tree.getroot()
model = root.find("Model")
all_spots = model.find("AllSpots")
all_tracks = model.find("AllTracks")

track = next(t for t in all_tracks if t.get("TRACK_ID") == TRACK_ID)
frame_of = {s.get("ID"): int(s.get("FRAME")) for s in all_spots.iter("Spot")}
track_spots = {e.get(k) for e in track for k in ("SPOT_SOURCE_ID", "SPOT_TARGET_ID")}
keep = {s for s in track_spots if FIRST_FRAME <= frame_of[s] <= LAST_FRAME}

# Spots: those of the kept track in the kept frames.
for frame in list(all_spots):
    for spot in list(frame):
        if spot.get("ID") not in keep:
            frame.remove(spot)
    if len(frame) == 0:
        all_spots.remove(frame)
all_spots.set("nspots", str(len(keep)))

# Tracks: the kept track, with the links between kept spots.
for other in list(all_tracks):
    if other is not track:
        all_tracks.remove(other)
for edge in list(track):
    if not (
        edge.get("SPOT_SOURCE_ID") in keep and edge.get("SPOT_TARGET_ID") in keep
    ):
        track.remove(edge)
filtered = model.find("FilteredTracks")
for track_id in list(filtered):
    if track_id.get("TRACK_ID") != TRACK_ID:
        filtered.remove(track_id)

# The log's first two lines: the TrackMate version and when it ran.
log = root.find("Log")
log.text = "\n".join(log.text.splitlines()[:2])

ET.indent(tree, space="  ")
tree.write(DEST, encoding="UTF-8", xml_declaration=True)
