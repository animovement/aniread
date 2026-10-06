# Write inst/extdata/c3d.c3d: the first 5 frames of pyCGM's Sample_Static.c3d,
# written by c3dr's own writer (ezc3d).
#
#   Rscript data-raw/extdata_c3d.R <path to Sample_Static.c3d>
#
# Sample_Static.c3d is SampleData/ROM/Sample_Static.c3d from pyCGM
# (https://github.com/cadop/pyCGM, MIT, Copyright (c) 2015 cadop), also in
# animovement/movement-data as data/c3d/Sample_Static.c3d (sha256
# 16cc70aeb15a0eb0dcfea54fb6c08c5e408f027e5aba17f7b38ecd4ffe300a8b). Vicon
# Nexus 1.8.5 wrote it: 275 frames at 100 Hz of 141 points in mm, and 10 analog
# channels at one sample a frame.
#
# Every point and analog channel is kept, with every parameter; only the frames
# after the fifth are dropped. c3d_setdata() updates the frame count, and the
# last frame of the trial (TRIAL:ACTUAL_END_FIELD) is set to match. The file
# still starts at frame 1 of the recording, so its time starts at 0.
# Written with c3dr 0.2.1.

args <- commandArgs(trailingOnly = TRUE)
source_path <- if (length(args) > 0) args[[1]] else "Sample_Static.c3d"
n_frames <- 5

x <- c3dr::c3d_read(source_path)
trimmed <- c3dr::c3d_setdata(
  x,
  newdata = c3dr::c3d_data(x)[seq_len(n_frames), ],
  newanalog = c3dr::c3d_analog(x)[seq_len(n_frames * x$header$analogperframe), ]
)
trimmed$parameters$TRIAL$ACTUAL_END_FIELD <- c(n_frames, 0L)

c3dr::c3d_write(trimmed, file.path("inst", "extdata", "c3d.c3d"))
