# FicTrac fixtures

Both files are synthetic, written for these tests to the column layouts
FicTrac's `Trackball::logData()` (`src/Trackball.cpp`,
<https://github.com/rjdmoore/fictrac>) writes: comma-and-space separated, no
header, numbers at 14 significant digits. No FicTrac output was copied
(FicTrac is CC BY-NC-SA 3.0, and the public 23-column files we found carry no
licence). They may be used under the aniread package licence.

- `fictrac_23col.dat`: the layout of FicTrac 2.0 to 2.02. Columns 22 and 23
  are the timestamp (here the capture time in ms since the epoch, at about
  100 Hz) and the sequence counter.
- `fictrac_24col.dat`: the layout of commit 41ab862 (July 2019). Column 22 is
  the capture time in ms since midnight, 23 the sequence counter and 24 the
  time since the last frame. The recording crosses midnight after its sixth
  row, so column 22 drops from 86399994.5 to 4.5.

The 25-column layout of FicTrac 2.03 onward is covered by the rows written in
`test-read_fictrac.R` and by the FicTrac sample data.
