# tests/testthat/test-write_aniframe.R
#
# What we are testing ---------------------------------------------------------
# 1. Input‑type validation – `write_aniframe()` aborts when the object is not
#    an aniframe.
# 2. Extension validation – unsupported file extensions raise an error.
# 3. CSV/TSV dispatch – the CSV helper (`write_aniframe_csv`) is called for
#    both ".csv" and ".tsv".
# 4. Parquet dispatch – the Parquet helper (`write_aniframe_parquet`) is called
#    for ".parquet" and the CSV helper is *not* called.
# 5. Return value – the original aniframe is returned invisibly.

# Helper ----------------------------------------------------------------------
create_tmp_file <- function(ext) {
  tempfile(pattern = "test_write_aniframe_", fileext = paste0(".", ext))
}

# ---------------------------------------------------------------------------
# 1️⃣  Input‑type validation
# ---------------------------------------------------------------------------
test_that("write_aniframe() aborts when data is not an aniframe", {
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
  anif <- anicore::example_aniframe()

  expect_error(
    write_aniframe(anif, "mydata.xlsx"),
    regexp = "File extension needs to be one of"
  )
})

# -------------------------------------------------------------------------
# 3️⃣  CSV / TSV dispatch
# -------------------------------------------------------------------------
test_that("CSV and TSV paths call write_aniframe_csv()", {
  anif <- anicore::example_aniframe()

  # -----------------------------------------------------------------------
  # Spy flag – toggled by the stubbed CSV helper
  # -----------------------------------------------------------------------
  csv_called <- FALSE

  csv_stub <- function(data, filename, ...) {
    csv_called <<- TRUE # flip the spy flag
    vroom::vroom_write(data, filename, ...) # write a real CSV/TSV file
  }

  # -----------------------------------------------------------------------
  # Use `with_mocked_bindings()` so the mocks disappear as soon as the
  # expression finishes.
  # -----------------------------------------------------------------------
  with_mocked_bindings(
    # We reach the internal helpers via `:::` because they are not exported.
    write_aniframe_csv = csv_stub,
    write_aniframe_parquet = function(...) {
      stop("Parquet helper should not be invoked for CSV/TSV")
    },
    {
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
    }
  )
})

# -------------------------------------------------------------------------
# 4️⃣  Parquet dispatch
# -------------------------------------------------------------------------
test_that("Parquet path calls write_aniframe_parquet()", {
  anif <- anicore::example_aniframe()

  parquet_called <- FALSE

  parquet_stub <- function(data, filename, ...) {
    parquet_called <<- TRUE
    arrow::write_parquet(data, filename, ...)
  }

  with_mocked_bindings(
    write_aniframe_parquet = parquet_stub,
    write_aniframe_csv = function(...) {
      stop("CSV helper should not be invoked for Parquet")
    },
    {
      ## ----------- Parquet case --------------------------------------------
      p_file <- create_tmp_file("parquet")
      expect_silent(suppressWarnings(write_aniframe(anif, p_file)))
      expect_true(
        parquet_called,
        info = "Parquet helper should have been called"
      )
      expect_true(file.exists(p_file))
    }
  )
})

# ---------------------------------------------------------------------------
# 5️⃣  Return value is invisible original object
# ---------------------------------------------------------------------------
test_that("write_aniframe() returns the original aniframe invisibly", {
  anif <- anicore::example_aniframe()
  out <- write_aniframe(anif, create_tmp_file("csv")) |> suppressWarnings()

  # The returned object should be identical (by reference) to the input
  expect_identical(out, anif)

  # And it should be invisible – `invisible()` makes the printed output empty,
  # which we can test with `capture.output()`.
  expect_warning(write_aniframe(anif, create_tmp_file("csv")))
  expect_silent(write_aniframe(anif, create_tmp_file("parquet")))
})
