# Tests for read_trackmate
#
# - File validation errors (non-existent, wrong suffix)
# - Errors when no tracks found
# - Errors when no filtered tracks found
# - Correct spot attribute extraction (slim and non-slim)
# - Correct spot-to-track mapping
# - Duplicate track-frame detection and warning
# - Unit conversion (pixel -> px, sec -> s)
# - Output is an aniframe with correct structure
# - Metadata is set correctly
# - Reflects to bottom_left and records `y_height` from the XML
# - `video_height` argument overrides ImageData/@height
# - Falls back to max(y) when ImageData is missing
# - Keeps z and sets cartesian_3d when z varies
# - Drops z when only one unique value (sets cartesian_2d)
# - Frame column removed when time stamps exist
# - Every TrackMate time and space unit maps onto anicore's, falling back to
#   "unknown" and "none" with a warning
# - sampling_rate from ImageData/@timeinterval, in Hz, only for a positive
#   interval in a unit of time
# - source_version from the root version attribute
# - Reflects around height * pixelheight, the height in the spatial unit
# - Labels tracks by Track/@name, falling back to TRACK_ID
# - Reads files written by TrackMate 6, 7.0 and 7.13 (data/trackmate)
# - Reads a blank spatial unit as pixels when the pixel size is 1
# - Splits a track that divides into its branches

test_that("read_trackmate errors on non-existent file", {
  expect_error(
    read_trackmate("nonexistent.xml"),
    class = "rlang_error"
  )
})

test_that("read_trackmate errors on wrong file suffix", {
  tmp <- tempfile(fileext = ".csv")
  file.create(tmp)
  on.exit(unlink(tmp))

  expect_error(
    read_trackmate(tmp),
    class = "rlang_error"
  )
})

test_that("read_trackmate errors when no tracks in XML", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="pixel" timeunits="sec"/>
			<AllSpots/>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  expect_error(
    read_trackmate(tmp),
    "No tracks found"
  )
})

test_that("read_trackmate errors when no filtered tracks in XML", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="pixel" timeunits="sec"/>
			<AllSpots/>
			<AllTracks>
				<Track TRACK_ID="0"/>
			</AllTracks>
			<FilteredTracks/>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  expect_error(
    read_trackmate(tmp),
    "No filtered tracks"
  )
})

test_that("read_trackmate parses valid XML correctly", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<Settings>
				<ImageData width="200" height="100"/>
			</Settings>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0" RADIUS="2.5" QUALITY="100"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="0.5" FRAME="1" RADIUS="2.5" QUALITY="100"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)

  expect_s3_class(result, "anipoint")
  expect_equal(nrow(result), 2)
  expect_true(all(c("time", "x", "y") %in% names(result)))
  expect_equal(result$x, c(10.0, 15.0))
  # Source y was c(20, 25); ImageData/@height is 100, so reflection
  # gives c(100 - 20, 100 - 25) = c(80, 75) in bottom_left.
  expect_equal(result$y, c(80.0, 75.0))
})

test_that("read_trackmate turns the data the right way up and records the extent", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="pixel" timeunits="sec"/>
			<Settings>
				<ImageData width="500" height="400"/>
			</Settings>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="50.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="100.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)
  meta <- anicore::get_metadata(result)

  expect_equal(anicore::get_axis_directions(result)[["y"]], "up")
  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = 400))
  expect_equal(result$y, c(400 - 50, 400 - 100))
})

test_that("read_trackmate `video_height` overrides ImageData height", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="pixel" timeunits="sec"/>
			<Settings>
				<ImageData width="500" height="400"/>
			</Settings>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="50.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="100.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp, video_height = 1080)
  meta <- anicore::get_metadata(result)

  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = 1080))
  expect_equal(result$y, c(1080 - 50, 1080 - 100))
})

test_that("read_trackmate falls back to max(y) when ImageData missing", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="pixel" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)
  meta <- anicore::get_metadata(result)

  # max(y_source) = 25; the maximum should map to 0 in bottom_left.
  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = 25))
  expect_equal(result$y, c(25 - 20, 25 - 25))
})

test_that("read_trackmate converts units correctly", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="pixel" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)
  meta <- anicore::get_metadata(result)
  default_meta <- anicore::list_default_metadata()

  expect_equal(
    meta$unit_space,
    factor("px", levels = levels(default_meta$unit_space))
  )
  expect_equal(
    meta$unit_time,
    factor("s", levels = levels(default_meta$unit_time))
  )
  expect_equal(meta$source, "trackmate")
})

test_that("read_trackmate only includes filtered tracks", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
					<Spot ID="3" POSITION_X="100.0" POSITION_Y="200.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="4" POSITION_X="105.0" POSITION_Y="205.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
				<Track TRACK_ID="1">
					<Edge SPOT_SOURCE_ID="3" SPOT_TARGET_ID="4"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)

  expect_equal(nrow(result), 2)
  expect_equal(nlevels(result$track), 1)
  expect_equal(as.character(unique(result$track)), "0")
  expect_false(any(result$x > 50))
})

test_that("read_trackmate assigns keypoint column as centroid", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)
  default_meta <- anicore::list_default_metadata()

  expect_true("keypoint" %in% names(result))
  expect_equal(
    unique(result$keypoint),
    factor("centroid")
  )
})

test_that("read_trackmate warns on duplicate track-frame combinations", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  expect_warning(
    read_trackmate(tmp),
    "duplicate"
  )
})

test_that("read_trackmate keeps z and sets cartesian_3d when z varies", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<Settings>
				<ImageData width="500" height="400"/>
			</Settings>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="3.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="7.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)

  expect_true("z" %in% names(result))
  expect_equal(sort(unique(result$z)), c(3, 7))
  expect_equal(
    as.character(anicore::get_metadata(result, "coordinate_system")),
    "cartesian_3d"
  )
})

test_that("read_trackmate drops z when only one unique value", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)

  # When all spots share the same z, the reader drops the column and sets
  # `coordinate_system = "cartesian_2d"`.
  expect_false("z" %in% names(result))
  expect_equal(
    as.character(anicore::get_metadata(result, "coordinate_system")),
    "cartesian_2d"
  )
})

test_that("read_trackmate removes frame column when time stamps exist", {
  xml_content <- '<?xml version="1.0" encoding="UTF-8"?>
		<TrackMate>
			<Model spatialunits="micron" timeunits="sec"/>
			<AllSpots>
				<SpotsInFrame frame="0">
					<Spot ID="1" POSITION_X="10.0" POSITION_Y="20.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>
					<Spot ID="2" POSITION_X="15.0" POSITION_Y="25.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>
				</SpotsInFrame>
			</AllSpots>
			<AllTracks>
				<Track TRACK_ID="0">
					<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>
				</Track>
			</AllTracks>
			<FilteredTracks>
				<TrackID TRACK_ID="0"/>
			</FilteredTracks>
		</TrackMate>'

  tmp <- tempfile(fileext = ".xml")
  writeLines(xml_content, tmp)
  on.exit(unlink(tmp))

  result <- read_trackmate(tmp)

  expect_false("frame" %in% names(result))
})

# Write a minimal TrackMate XML with the calibration given, and return its path.
# `NULL` leaves an attribute out; `image_data = FALSE` leaves out ImageData.
write_trackmate_fixture <- function(
  timeunits = "sec",
  spatialunits = "pixel",
  timeinterval = "1.0",
  version = "7.11.1",
  image_data = TRUE,
  pixel_size = NULL,
  env = parent.frame()
) {
  attr <- function(name, value) {
    if (is.null(value)) "" else sprintf(' %s="%s"', name, value)
  }
  settings <- if (image_data) {
    sprintf(
      '<Settings><ImageData width="500" height="400"%s%s%s/></Settings>',
      attr("timeinterval", timeinterval),
      attr("pixelwidth", pixel_size),
      attr("pixelheight", pixel_size)
    )
  } else {
    ""
  }
  xml_content <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    "<TrackMate",
    attr("version", version),
    ">",
    "<Model",
    attr("spatialunits", spatialunits),
    attr("timeunits", timeunits),
    ">",
    "<AllSpots><SpotsInFrame frame=\"0\">",
    '<Spot ID="1" POSITION_X="10.0" POSITION_Y="50.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>',
    '<Spot ID="2" POSITION_X="15.0" POSITION_Y="100.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>',
    "</SpotsInFrame></AllSpots>",
    '<AllTracks><Track TRACK_ID="0">',
    '<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>',
    "</Track></AllTracks>",
    '<FilteredTracks><TrackID TRACK_ID="0"/></FilteredTracks>',
    "</Model>",
    settings,
    "</TrackMate>"
  )
  tmp <- withr::local_tempfile(fileext = ".xml", .local_envir = env)
  writeLines(xml_content, tmp, useBytes = TRUE)
  tmp
}

read_trackmate_quietly <- function(path) {
  suppressMessages(read_trackmate(path))
}

test_that("read_trackmate maps every TrackMate time unit onto anicore's", {
  cases <- c(
    sec = "s",
    s = "s",
    seconds = "s",
    msec = "ms",
    ms = "ms",
    "\u00b5s" = "us",
    usec = "us",
    ns = "ns",
    min = "m",
    hour = "h",
    h = "h",
    frame = "frame",
    Frames = "frame"
  )
  for (unit in names(cases)) {
    path <- write_trackmate_fixture(timeunits = unit)
    result <- read_trackmate_quietly(path)
    expect_equal(
      as.character(anicore::get_metadata(result, "unit_time")),
      cases[[unit]],
      label = unit
    )
  }
})

test_that("read_trackmate maps every TrackMate space unit onto anicore's", {
  cases <- c(
    pixel = "px",
    pixels = "px",
    micron = "um",
    microns = "um",
    um = "um",
    "\u00b5m" = "um",
    "\u03bcm" = "um",
    nm = "nm",
    mm = "mm",
    cm = "cm",
    m = "m",
    km = "km"
  )
  for (unit in names(cases)) {
    path <- write_trackmate_fixture(spatialunits = unit)
    result <- read_trackmate_quietly(path)
    expect_equal(
      as.character(anicore::get_metadata(result, "unit_space")),
      cases[[unit]],
      label = unit
    )
  }
})

test_that("read_trackmate falls back to unknown units with a warning", {
  path <- write_trackmate_fixture(timeunits = "day")
  expect_warning(
    result <- read_trackmate_quietly(path),
    "has no equivalent in anicore"
  )
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_time")),
    "unknown"
  )
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))

  path <- write_trackmate_fixture(spatialunits = "inch")
  expect_warning(
    result <- read_trackmate_quietly(path),
    "has no equivalent in anicore"
  )
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_space")),
    "none"
  )
})

test_that("read_trackmate reads a file that records no units", {
  path <- write_trackmate_fixture(timeunits = NULL, spatialunits = NULL)
  expect_no_warning(result <- read_trackmate_quietly(path))
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_time")),
    "unknown"
  )
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_space")),
    "none"
  )
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))
})

test_that("read_trackmate sets sampling_rate from the frame interval, in Hz", {
  cases <- list(
    list(unit = "sec", interval = "0.5", rate = 2),
    list(unit = "sec", interval = "1.0", rate = 1),
    list(unit = "msec", interval = "40", rate = 25),
    list(unit = "\u00b5s", interval = "1000", rate = 1000),
    list(unit = "ns", interval = "1e6", rate = 1000),
    list(unit = "min", interval = "0.5", rate = 1 / 30),
    list(unit = "h", interval = "2", rate = 1 / 7200)
  )
  for (case in cases) {
    path <- write_trackmate_fixture(
      timeunits = case$unit,
      timeinterval = case$interval
    )
    result <- read_trackmate_quietly(path)
    expect_equal(
      anicore::get_metadata(result, "sampling_rate"),
      case$rate,
      label = paste(case$interval, case$unit)
    )
  }
})

test_that("read_trackmate leaves sampling_rate NA without a usable interval", {
  # Frames are not a unit of time, so an interval in frames gives no rate
  path <- write_trackmate_fixture(timeunits = "frame", timeinterval = "1.0")
  result <- read_trackmate_quietly(path)
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))

  for (interval in list("0.0", "-1", "NaN", "Infinity", "abc", NULL)) {
    path <- write_trackmate_fixture(timeinterval = interval)
    result <- read_trackmate_quietly(path)
    expect_true(
      is.na(anicore::get_metadata(result, "sampling_rate")),
      label = format(interval)
    )
  }

  path <- write_trackmate_fixture(image_data = FALSE)
  result <- read_trackmate_quietly(path)
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))
})

test_that("read_trackmate sets source_version from the root version", {
  path <- write_trackmate_fixture(version = "7.11.1")
  result <- read_trackmate_quietly(path)
  expect_equal(anicore::get_metadata(result, "source_version"), "7.11.1")

  for (version in list(NULL, "")) {
    path <- write_trackmate_fixture(version = version)
    result <- read_trackmate_quietly(path)
    expect_true(is.na(anicore::get_metadata(result, "source_version")))
  }
})

# Write a TrackMate XML with two filtered tracks and the given ImageData and
# Track attributes, and return its path.
write_trackmate_tracks <- function(
  image_data = 'width="500" height="400"',
  track_attrs = c('name="Track_0"', 'name="Track_1"'),
  extra_track = "",
  env = parent.frame()
) {
  xml_content <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<TrackMate version="7.11.1">',
    '<Model spatialunits="micron" timeunits="sec">',
    '<AllSpots><SpotsInFrame frame="0">',
    '<Spot ID="1" POSITION_X="10.0" POSITION_Y="50.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>',
    '<Spot ID="2" POSITION_X="15.0" POSITION_Y="60.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>',
    '<Spot ID="3" POSITION_X="20.0" POSITION_Y="70.0" POSITION_Z="0.0" POSITION_T="0.0" FRAME="0"/>',
    '<Spot ID="4" POSITION_X="25.0" POSITION_Y="80.0" POSITION_Z="0.0" POSITION_T="1.0" FRAME="1"/>',
    "</SpotsInFrame></AllSpots>",
    "<AllTracks>",
    sprintf('<Track TRACK_ID="0" %s>', track_attrs[[1]]),
    '<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/></Track>',
    sprintf('<Track TRACK_ID="1" %s>', track_attrs[[2]]),
    '<Edge SPOT_SOURCE_ID="3" SPOT_TARGET_ID="4"/></Track>',
    extra_track,
    "</AllTracks>",
    '<FilteredTracks><TrackID TRACK_ID="0"/><TrackID TRACK_ID="1"/></FilteredTracks>',
    "</Model>",
    sprintf("<Settings><ImageData %s/></Settings>", image_data),
    "</TrackMate>"
  )
  tmp <- withr::local_tempfile(fileext = ".xml", .local_envir = env)
  writeLines(xml_content, tmp)
  tmp
}

test_that("read_trackmate reflects around the height in the spatial unit", {
  # 400 pixels at 0.5 micron per pixel: the image is 200 microns high, and
  # the positions are in microns
  path <- write_trackmate_tracks(
    'width="500" height="400" pixelwidth="0.5" pixelheight="0.5"'
  )
  result <- read_trackmate_quietly(path)

  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = 200))
  expect_equal(sort(result$y), sort(200 - c(50, 60, 70, 80)))
})

test_that("read_trackmate uses height alone without a usable pixelheight", {
  for (image_data in c(
    'width="500" height="400"',
    'width="500" height="400" pixelheight="0.0"',
    'width="500" height="400" pixelheight="NaN"'
  )) {
    path <- write_trackmate_tracks(image_data)
    result <- read_trackmate_quietly(path)
    expect_equal(
      anicore::get_metadata(result, "axis_extents"),
      c(y = 400),
      label = image_data
    )
  }
})

test_that("read_trackmate `video_height` overrides the calibrated height", {
  path <- write_trackmate_tracks('width="500" height="400" pixelheight="0.5"')
  result <- suppressMessages(read_trackmate(path, video_height = 300))
  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = 300))
})

test_that("read_trackmate labels tracks by their names", {
  path <- write_trackmate_tracks(
    track_attrs = c('name="Cell A"', 'name="Cell B"')
  )
  result <- read_trackmate_quietly(path)
  expect_setequal(as.character(unique(result$track)), c("Cell A", "Cell B"))

  # TrackMate's default names
  path <- write_trackmate_tracks()
  result <- read_trackmate_quietly(path)
  expect_setequal(as.character(unique(result$track)), c("Track_0", "Track_1"))
})

test_that("read_trackmate only needs the names of the filtered tracks to differ", {
  path <- write_trackmate_tracks(
    track_attrs = c('name="Cell A"', 'name="Cell B"'),
    extra_track = '<Track TRACK_ID="2" name="Cell A"/>'
  )
  expect_no_warning(result <- read_trackmate_quietly(path))
  expect_setequal(as.character(unique(result$track)), c("Cell A", "Cell B"))
})

test_that("read_trackmate labels tracks by ID when names cannot identify them", {
  # A track without a name, or with an empty one
  for (attrs in list(c('name="Cell A"', ""), c('name="Cell A"', 'name=""'))) {
    path <- write_trackmate_tracks(track_attrs = attrs)
    expect_no_warning(result <- read_trackmate_quietly(path))
    expect_setequal(as.character(unique(result$track)), c("0", "1"))
  }

  # Two tracks sharing a name
  path <- write_trackmate_tracks(
    track_attrs = c('name="Cell A"', 'name="Cell A"')
  )
  expect_warning(
    result <- read_trackmate_quietly(path),
    "track names are not unique"
  )
  expect_setequal(as.character(unique(result$track)), c("0", "1"))
})

# Files written by TrackMate ------------------------------------------------

# Trimmed from CC BY 4.0 files on Zenodo; data/trackmate/README.md records
# their sources, creators and how they were trimmed.
trackmate_file <- function(name) test_path("data/trackmate", name)

test_that("read_trackmate reads a file written before TrackMate 7", {
  path <- trackmate_file("crop_1_60_ManualCuration_trimmed.xml")
  expect_no_warning(result <- read_trackmate_quietly(path))

  expect_equal(levels(result$track), c("Track_0", "Track_1"))
  expect_equal(as.vector(table(result$track)), c(20, 20))
  expect_equal(
    head(result$time[result$track == "Track_1"], 3),
    c(0, 300.014, 600.028)
  )
  expect_equal(anicore::get_metadata(result, "source_version"), "6.0.1")
  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "s")
  expect_equal(as.character(anicore::get_metadata(result, "unit_space")), "um")
  expect_equal(anicore::get_metadata(result, "sampling_rate"), 1 / 300.014)
  # 774 pixels of 0.633 micron
  expect_equal(
    anicore::get_metadata(result, "axis_extents"),
    c(y = 774 * 0.633)
  )
})

test_that("read_trackmate reads a blank spatial unit as pixels", {
  # TrackMate 7.13.2 wrote spatialunits=" ", with a pixel size of 1.
  path <- trackmate_file("trpL_150310-11_trimmed.xml")
  expect_no_warning(result <- read_trackmate_quietly(path))
  expect_equal(as.character(anicore::get_metadata(result, "unit_space")), "px")
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_time")),
    "frame"
  )
  expect_true(is.na(anicore::get_metadata(result, "sampling_rate")))
  expect_equal(anicore::get_metadata(result, "source_version"), "7.13.2")
  expect_equal(anicore::get_metadata(result, "axis_extents"), c(y = 727))

  for (pixel_size in list(NULL, "1.0")) {
    path <- write_trackmate_fixture(spatialunits = " ", pixel_size = pixel_size)
    expect_no_warning(result <- read_trackmate_quietly(path))
    expect_equal(
      as.character(anicore::get_metadata(result, "unit_space")),
      "px"
    )
  }

  # Scaled pixels in a unit nobody named.
  path <- write_trackmate_fixture(spatialunits = " ", pixel_size = "0.5")
  expect_warning(
    result <- read_trackmate_quietly(path),
    "has no equivalent in anicore"
  )
  expect_equal(
    as.character(anicore::get_metadata(result, "unit_space")),
    "none"
  )
})

test_that("read_trackmate splits a dividing track into its branches", {
  path <- trackmate_file("CelegansEarly_MIP_trimmed.xml")
  expect_no_warning(result <- read_trackmate_quietly(path))

  expect_equal(
    levels(result$track),
    c("Track_0", "Track_0.a", "Track_0.b", "Track_2", "Track_2.a", "Track_2.b")
  )
  # Every spot is kept, once.
  expect_equal(nrow(result), 51)
  expect_false(anyDuplicated(as.data.frame(result)[c("track", "time")]) > 0)

  # The daughters start at the frame after the mother's last spot, and are
  # lettered by x.
  times <- function(track) result$time[result$track == track]
  expect_equal(max(times("Track_0")), 16)
  expect_equal(min(times("Track_0.a")), 18)
  expect_equal(min(times("Track_0.b")), 18)
  first_x <- function(track) result$x[result$track == track][[1]]
  expect_lt(first_x("Track_0.a"), first_x("Track_0.b"))

  expect_equal(as.character(anicore::get_metadata(result, "unit_time")), "m")
  expect_equal(as.character(anicore::get_metadata(result, "unit_space")), "um")
  expect_equal(anicore::get_metadata(result, "sampling_rate"), 1 / 120)
})

test_that("read_trackmate names the branches of a lineage as TrackMate does", {
  # One cell dividing at frames 7 and 11: 1, 2, then 4 cells.
  result <- read_trackmate_quietly(trackmate_file("trpL_150310-11_trimmed.xml"))

  expect_equal(
    levels(result$track),
    paste0("Track_0", c("", ".a", ".aa", ".ab", ".b", ".ba", ".bb"))
  )
  ranges <- tapply(result$time, as.character(result$track), range)
  expect_equal(ranges[["Track_0"]], c(0, 7))
  expect_equal(ranges[["Track_0.b"]], c(8, 11))
  expect_equal(ranges[["Track_0.ba"]], c(12, 13))
})

test_that("read_trackmate keeps whole a track that splits and merges in time", {
  # Track_1 links frame 16 to both 17 and 18, and 17 to 18, so it never
  # holds two spots in a frame.
  result <- read_trackmate_quietly(
    trackmate_file("crop_1_60_ManualCuration_trimmed.xml")
  )
  expect_equal(sum(result$track == "Track_1"), 20)
})

test_that("read_trackmate keeps whole a track whose branches merge", {
  # Spots 1 and 2 share frame 0 and both link to spot 3.
  xml_content <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<TrackMate><Model spatialunits="pixel" timeunits="sec"><AllSpots>',
    '<SpotsInFrame frame="0">',
    '<Spot ID="1" POSITION_X="10" POSITION_Y="20" POSITION_Z="0" POSITION_T="0" FRAME="0"/>',
    '<Spot ID="2" POSITION_X="30" POSITION_Y="20" POSITION_Z="0" POSITION_T="0" FRAME="0"/>',
    '</SpotsInFrame><SpotsInFrame frame="1">',
    '<Spot ID="3" POSITION_X="20" POSITION_Y="20" POSITION_Z="0" POSITION_T="1" FRAME="1"/>',
    "</SpotsInFrame></AllSpots>",
    '<AllTracks><Track TRACK_ID="0" name="Track_0">',
    '<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="3"/>',
    '<Edge SPOT_SOURCE_ID="2" SPOT_TARGET_ID="3"/>',
    "</Track></AllTracks>",
    '<FilteredTracks><TrackID TRACK_ID="0"/></FilteredTracks>',
    "</Model></TrackMate>"
  )
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(xml_content, path)

  expect_warning(result <- read_trackmate_quietly(path), "duplicate")
  expect_equal(as.character(unique(result$track)), "Track_0")
})

test_that("read_trackmate follows a link written backwards in time", {
  # TrackMate links a spot to a later one; a link from the later spot reads
  # the same.
  xml_content <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<TrackMate><Model spatialunits="pixel" timeunits="sec"><AllSpots>',
    '<SpotsInFrame frame="0">',
    '<Spot ID="1" POSITION_X="20" POSITION_Y="20" POSITION_Z="0" POSITION_T="0" FRAME="0"/>',
    '</SpotsInFrame><SpotsInFrame frame="1">',
    '<Spot ID="2" POSITION_X="30" POSITION_Y="20" POSITION_Z="0" POSITION_T="1" FRAME="1"/>',
    '<Spot ID="3" POSITION_X="10" POSITION_Y="20" POSITION_Z="0" POSITION_T="1" FRAME="1"/>',
    "</SpotsInFrame></AllSpots>",
    '<AllTracks><Track TRACK_ID="0" name="Track_0">',
    '<Edge SPOT_SOURCE_ID="1" SPOT_TARGET_ID="2"/>',
    '<Edge SPOT_SOURCE_ID="3" SPOT_TARGET_ID="1"/>',
    "</Track></AllTracks>",
    '<FilteredTracks><TrackID TRACK_ID="0"/></FilteredTracks>',
    "</Model></TrackMate>"
  )
  path <- withr::local_tempfile(fileext = ".xml")
  writeLines(xml_content, path)

  expect_no_warning(result <- read_trackmate_quietly(path))
  expect_equal(result$x[result$track == "Track_0.a"], 10)
  expect_equal(result$x[result$track == "Track_0.b"], 30)
})
