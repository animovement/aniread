# Tests for get_supported_sources
#
# - Returns a tibble with the documented columns and types
# - `direction` is "read" or "write", one row per source and direction
# - `suffix` is a list column of character vectors
# - Every listed function is an exported aniread function of its direction
# - No leading dots on suffixes; values are lower-case
# - The generic read_custom reader is intentionally excluded
# - A source can be read only, written only, or both

test_that("get_supported_sources returns a tibble with the expected columns", {
  result <- get_supported_sources()

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("source", "direction", "fun", "suffix"))
  expect_type(result$source, "character")
  expect_type(result$direction, "character")
  expect_type(result$fun, "character")
  expect_type(result$suffix, "list")
  expect_gt(nrow(result), 0)
})

test_that("each row is one source in one direction", {
  result <- get_supported_sources()

  expect_true(all(result$direction %in% c("read", "write")))
  expect_false(any(duplicated(result[c("source", "direction")])))
  expect_false(any(duplicated(result$fun)))
})

test_that("each row's suffix is a non-empty character vector", {
  result <- get_supported_sources()
  for (s in result$suffix) {
    expect_type(s, "character")
    expect_gt(length(s), 0)
  }
})

test_that("every listed function is an exported aniread function", {
  result <- get_supported_sources()
  exported <- getNamespaceExports("aniread")

  expect_true(all(result$fun %in% exported))
  expect_true(all(startsWith(result$fun[result$direction == "read"], "read_")))
  expect_true(all(startsWith(
    result$fun[result$direction == "write"],
    "write_"
  )))
})

test_that("suffixes carry no leading dot and are lower-case", {
  result <- get_supported_sources()
  all_suffixes <- unlist(result$suffix)
  expect_false(any(startsWith(all_suffixes, ".")))
  expect_identical(all_suffixes, tolower(all_suffixes))
})

test_that("the generic read_custom reader is excluded", {
  result <- get_supported_sources()
  expect_false("read_custom" %in% result$fun)
})

test_that("known sources are present with their suffixes", {
  result <- get_supported_sources()
  octron <- result[result$source == "octron", ]
  expect_equal(nrow(octron), 1)
  expect_identical(octron$direction, "read")
  expect_identical(octron$fun, "read_octron")
  expect_identical(octron$suffix[[1]], "csv")

  deeplabcut <- result[result$source == "deeplabcut", ]
  expect_setequal(deeplabcut$suffix[[1]], c("csv", "h5"))
})

test_that("aniframe is read and written, with different suffixes", {
  result <- get_supported_sources()
  aniframe <- result[result$source == "aniframe", ]

  expect_identical(aniframe$direction, c("read", "write"))
  expect_identical(aniframe$fun, c("read_aniframe", "write_aniframe"))
  expect_identical(aniframe$suffix[[1]], "parquet")
  expect_setequal(aniframe$suffix[[2]], c("parquet", "csv", "tsv"))
})

test_that("inTRACKtive is written only", {
  result <- get_supported_sources()
  intracktive <- result[result$source == "intracktive", ]

  expect_identical(intracktive$direction, "write")
  expect_identical(intracktive$fun, "write_intracktive")
})
