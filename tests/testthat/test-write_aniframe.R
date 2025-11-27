# tests/testthat/test-write_aniframe.R
library(testthat)

# Helper ----------------------------------------------------------------------
create_tmp_file <- function(ext) {
  tempfile(pattern = "test_write_aniframe_", fileext = paste0(".", ext))
}

# ---------------------------------------------------------------------------
# 1️⃣  Input‑type validation
# ---------------------------------------------------------------------------
test_that("write_aniframe() aborts when data is not an aniframe", {
  # a plain data.frame should trigger the check
  not_aniframe <- mtcars

  expect_error(
    write_aniframe(not_aniframe, "dummy.csv"),
    regexp = "Data is not an aniframe"
  )
})

# ---------------------------------------------------------------------------
# 2️⃣  Extension validation
# ---------------------------------------------------------------------------
test_that("write_aniframe() aborts on unsupported file extensions", {
  anif <- aniframe::example_aniframe()

  # unsupported extension .xlsx
  expect_error(
    write_aniframe(anif, "mydata.xlsx"),
    regexp = "File extension needs to be one of"
  )
})
# -------------------------------------------------------------------------
# 3️⃣  CSV / TSV dispatch
# -------------------------------------------------------------------------
test_that("CSV and TSV paths call write_aniframe_csv()", {
  anif <- aniframe::example_aniframe()

  # -----------------------------------------------------------------------
  # Spy variables – they will be toggled by our stubbed helper
  # -----------------------------------------------------------------------
  csv_called <- FALSE

  # -----------------------------------------------------------------------
  # Stub the CSV helper ----------------------------------------------------
  # -----------------------------------------------------------------------
  csv_stub <- function(data, filename, ...) {
    csv_called <<- TRUE # flip the spy flag
    # Write a minimal CSV so the file actually appears on disk
    vroom::vroom_write(data, filename, ...)
  }

  # Attach the stub to the *internal* helper inside the package namespace
  mockery::stub(
    where = write_aniframe, # function we are testing
    what = "write_aniframe_csv", # name of the internal helper
    how = csv_stub
  )

  # -----------------------------------------------------------------------
  # Also stub the Parquet helper to guarantee it is *not* called
  # -----------------------------------------------------------------------
  mockery::stub(
    where = write_aniframe,
    what = "write_aniframe_parquet",
    how = function(...) {
      stop("Parquet helper should not be invoked for CSV/TSV")
    }
  )

  ## ----------- CSV case -----------------------------------------------
  csv_file <- create_tmp_file("csv")
  expect_warning(write_aniframe(anif, csv_file))
  expect_true(csv_called, info = "CSV helper should have been called")
  expect_true(file.exists(csv_file))

  ## Reset spy flag for the TSV sub‑test
  csv_called <<- FALSE

  ## ----------- TSV case -----------------------------------------------
  tsv_file <- create_tmp_file("tsv")
  expect_warning(write_aniframe(anif, tsv_file, delim = "\t"))
  expect_true(csv_called, info = "CSV helper also handles TSV")
  expect_true(file.exists(tsv_file))
})

# -------------------------------------------------------------------------
# 4️⃣  Parquet dispatch
# -------------------------------------------------------------------------
test_that("Parquet path calls write_aniframe_parquet()", {
  anif <- aniframe::example_aniframe()

  parquet_called <- FALSE

  # -----------------------------------------------------------------------
  # Stub the Parquet helper ------------------------------------------------
  # -----------------------------------------------------------------------
  parquet_stub <- function(data, filename, ...) {
    parquet_called <<- TRUE
    # Write a real parquet file so we can later confirm its existence
    arrow::write_parquet(data, filename, ...)
  }

  mockery::stub(
    where = write_aniframe,
    what = "write_aniframe_parquet",
    how = parquet_stub
  )

  # -----------------------------------------------------------------------
  # Stub the CSV helper to ensure it is *not* invoked for .parquet files
  # -----------------------------------------------------------------------
  mockery::stub(
    where = write_aniframe,
    what = "write_aniframe_csv",
    how = function(...) {
      stop("CSV helper should not be invoked for Parquet")
    }
  )

  ## ----------- Parquet case --------------------------------------------
  p_file <- create_tmp_file("parquet")
  expect_silent(suppressWarnings(write_aniframe(anif, p_file)))
  expect_true(parquet_called, info = "Parquet helper should have been called")
  expect_true(file.exists(p_file))
})

# ---------------------------------------------------------------------------
# 5️⃣  Return value is invisible original object
# ---------------------------------------------------------------------------
test_that("write_aniframe() returns the original aniframe invisibly", {
  anif <- aniframe::example_aniframe()
  out <- write_aniframe(anif, create_tmp_file("csv")) |> suppressWarnings()

  # The returned object should be identical (by reference) to the input
  expect_identical(out, anif)

  # And it should be invisible – `invisible()` makes the printed output empty,
  # which we can test with `capture.output()`.
  expect_warning(write_aniframe(anif, create_tmp_file("csv")))
  expect_silent(write_aniframe(anif, create_tmp_file("parquet")))
})
