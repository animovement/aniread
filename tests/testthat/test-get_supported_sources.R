# Tests for get_supported_sources
#
# - Returns a tibble with the documented columns and types
# - `suffix` is a list column of character vectors
# - Every listed reader is an exported aniread function
# - No leading dots on suffixes; values are lower-case
# - The generic read_custom reader is intentionally excluded

test_that("get_supported_sources returns a tibble with the expected columns", {
  result <- get_supported_sources()

  expect_s3_class(result, "tbl_df")
  expect_named(result, c("source", "reader", "suffix"))
  expect_type(result$source, "character")
  expect_type(result$reader, "character")
  expect_type(result$suffix, "list")
  expect_gt(nrow(result), 0)
})

test_that("each row's suffix is a non-empty character vector", {
  result <- get_supported_sources()
  for (s in result$suffix) {
    expect_type(s, "character")
    expect_gt(length(s), 0)
  }
})

test_that("every listed reader is an exported aniread function", {
  result <- get_supported_sources()
  exported <- getNamespaceExports("aniread")
  expect_true(all(result$reader %in% exported))
})

test_that("source and reader entries are unique", {
  result <- get_supported_sources()
  expect_false(any(duplicated(result$source)))
  expect_false(any(duplicated(result$reader)))
})

test_that("suffixes carry no leading dot and are lower-case", {
  result <- get_supported_sources()
  all_suffixes <- unlist(result$suffix)
  expect_false(any(startsWith(all_suffixes, ".")))
  expect_identical(all_suffixes, tolower(all_suffixes))
})

test_that("the generic read_custom reader is excluded", {
  result <- get_supported_sources()
  expect_false("read_custom" %in% result$reader)
})

test_that("known sources are present with their suffixes", {
  result <- get_supported_sources()
  octron <- result[result$source == "octron", ]
  expect_equal(nrow(octron), 1)
  expect_identical(octron$reader, "read_octron")
  expect_identical(octron$suffix[[1]], "csv")

  deeplabcut <- result[result$source == "deeplabcut", ]
  expect_setequal(deeplabcut$suffix[[1]], c("csv", "h5"))
})
