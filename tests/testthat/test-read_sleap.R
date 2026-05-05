# Tests for read_sleap

test_that("read_sleap aborts with a friendly message on CSV input", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("placeholder", tmp)
  on.exit(unlink(tmp), add = TRUE)
  expect_error(read_sleap(tmp), "SLEAP CSV import")
})

test_that("read_sleap rejects unsupported extensions", {
  expect_error(read_sleap("nonexistent.txt"))
})
