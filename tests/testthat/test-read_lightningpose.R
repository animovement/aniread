# Tests for read_lightningpose()
#
# Lightning Pose writes DeepLabCut's csv layout and is read by
# read_deeplabcut(). These cover the Ensemble Kalman Smoother (EKS) output,
# whose extra coords per keypoint used to be split into fake keypoints.
#
# Fixtures in data/lightningpose:
# - mouse_single.csv, mouse_twoview.csv: Lightning Pose predictions already
#   in the package.
# - eks_singlecam.csv, eks_multicam_3d_results.csv: synthetic, written by
#   make_fixtures.py in the same directory in the layout EKS 4.6.2
#   (paninski-lab/eks, MIT) writes. Each value encodes the frame, bodypart
#   and coord it belongs to; see make_fixtures.py.
# - eks_ibl-paw_multicam_left_head.csv: the header and first three frames of
#   EKS_IBL-paw_multicam_left.predictions.csv from movement's sample data on
#   SWC GIN (International Brain Laboratory data, CC BY 4.0), truncated.

lp_fixture <- function(filename) {
  test_path("data", "lightningpose", filename)
}

# The value make_fixtures.py wrote for each row of a reading.
eks_value <- function(result, label) {
  bodypart <- c(nose = 1, paw_l = 2)[as.character(result$keypoint)]
  unname(1000 * result$time + 10 * bodypart + label)
}

test_that("read_lightningpose records its source", {
  result <- read_lightningpose(lp_fixture("mouse_single.csv"))

  expect_s3_class(result, "anipoint")
  expect_equal(anicore::get_metadata(result)$source, "lightningpose")
})

test_that("EKS output keeps its keypoints, x, y and likelihood", {
  result <- read_lightningpose(lp_fixture("eks_singlecam.csv"))

  expect_setequal(levels(result$keypoint), c("nose", "paw_l"))
  expect_named(
    result,
    c("keypoint", "time", "x", "y", "confidence"),
    ignore.order = TRUE
  )
  expect_equal(result$x, eks_value(result, 1))
  expect_equal(
    result$confidence,
    unname(c(nose = 0.01, paw_l = 0.02)[as.character(result$keypoint)])
  )
})

test_that("EKS output from real data reads", {
  result <- read_lightningpose(lp_fixture("eks_ibl-paw_multicam_left_head.csv"))

  expect_setequal(levels(result$keypoint), c("paw_l", "paw_r"))
  expect_equal(nrow(result), 3 * 2)
  expect_equal(
    result$x[result$keypoint == "paw_l" & result$time == 0],
    37.449986
  )
})

test_that("EKS multi-camera 3D output reads as 3D", {
  result <- read_lightningpose(lp_fixture("eks_multicam_3d_results.csv"))

  expect_equal(anicore::get_coordinate_system(result), "cartesian_3d")
  expect_setequal(levels(result$keypoint), c("nose", "paw_l"))
  expect_true(all(is.na(result$confidence)))
  expect_equal(result$x, eks_value(result, 1))
  expect_equal(result$y, eks_value(result, 2))
  expect_equal(result$z, eks_value(result, 3))
})
