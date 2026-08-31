#' Read a NumPy `.npy` array from a connection
#'
#' `.npy` is a short header followed by a raw buffer: a six-byte magic
#' string, a two-byte version, a two-byte little-endian header length, then
#' a Python dict literal giving `descr` (dtype), `fortran_order` and
#' `shape`. Parsing it takes a few lines, which is why this is here rather
#' than in a dependency - the alternative would be reticulate and a Python
#' install for the sake of one array format.
#'
#' Only the dtypes TRex writes are handled: little-endian floats and
#' unsigned integers. A dtype outside that set is an error rather than a
#' silent misread, because `readBin()` will happily return nonsense for a
#' size it does not support.
#'
#' @param con An open binary connection positioned at the start of the array.
#'
#' @return A list with `descr`, `shape` and `values`.
#' @noRd
read_npy <- function(con) {
  magic <- readBin(con, "raw", 6L)
  if (!identical(magic, as.raw(c(0x93, 0x4e, 0x55, 0x4d, 0x50, 0x59)))) {
    cli::cli_abort("Not a {.file .npy} array: the magic string is missing.")
  }

  readBin(con, "raw", 2L) # major/minor version
  header_length <- readBin(
    con,
    "integer",
    n = 1L,
    size = 2L,
    signed = FALSE,
    endian = "little"
  )
  header <- rawToChar(readBin(con, "raw", header_length))

  descr <- sub(".*'descr': *'([^']+)'.*", "\\1", header)
  shape <- suppressWarnings(as.numeric(strsplit(
    gsub(".*'shape': *\\(([^)]*)\\).*", "\\1", header),
    ","
  )[[1]]))
  shape <- shape[!is.na(shape)]
  n <- if (length(shape)) prod(shape) else 1L

  size <- as.integer(sub("^[<>|][a-z]", "", descr))
  kind <- substr(descr, 2L, 2L)

  values <- if (kind == "f") {
    readBin(con, "double", n = n, size = size, endian = "little")
  } else if (kind %in% c("u", "i")) {
    read_npy_integer(con, n = n, size = size, signed = kind == "i")
  } else {
    cli::cli_abort(c(
      "Cannot read the {.file .npy} dtype {.val {descr}}.",
      "i" = "Only little-endian floats and integers are supported."
    ))
  }

  list(descr = descr, shape = shape, values = values)
}

#' Read integers from a `.npy` buffer as doubles
#'
#' R has no 64-bit integer type, and `readBin()` will not read one. TRex
#' writes `id` as `<u8`, so eight-byte integers are assembled from their
#' bytes into a double, which is exact for the identity counts involved
#' (anything below 2^53).
#'
#' @param con An open binary connection.
#' @param n Number of values.
#' @param size Bytes per value.
#' @param signed Whether the values are signed.
#'
#' @return A numeric vector.
#' @noRd
read_npy_integer <- function(con, n, size, signed) {
  # `readBin()` only accepts `signed = FALSE` for sizes 1 and 2, and has no
  # 64-bit integer at all, so anything it cannot represent exactly is
  # assembled from its bytes instead.
  if (signed && size <= 4L) {
    return(as.numeric(readBin(
      con,
      "integer",
      n = n,
      size = size,
      endian = "little"
    )))
  }
  if (!signed && size <= 2L) {
    return(as.numeric(readBin(
      con,
      "integer",
      n = n,
      size = size,
      signed = FALSE,
      endian = "little"
    )))
  }

  raw_bytes <- readBin(con, "raw", n = n * size)
  vapply(
    seq_len(n),
    function(i) {
      bytes <- raw_bytes[((i - 1L) * size + 1L):(i * size)]
      sum(as.numeric(bytes) * 256^(seq_len(size) - 1L))
    },
    numeric(1)
  )
}

#' Read every array out of a NumPy `.npz` archive
#'
#' An `.npz` is a zip file of `.npy` members, so `unz()` reads them without
#' unpacking anything to disk.
#'
#' @param path Path to a `.npz` file.
#'
#' @return A named list of numeric vectors, one per array.
#' @noRd
read_npz <- function(path) {
  members <- utils::unzip(path, list = TRUE)$Name
  arrays <- members[grepl("\\.npy$", members)]

  values <- lapply(arrays, function(member) {
    con <- unz(path, member, open = "rb")
    on.exit(close(con), add = TRUE)
    read_npy(con)$values
  })

  stats::setNames(values, sub("\\.npy$", "", arrays))
}

#' Is this file a NumPy `.npz` archive?
#'
#' Checks for a zip magic string containing at least one `.npy` member,
#' rather than trusting the extension.
#'
#' @param path Path to check.
#'
#' @return `TRUE` or `FALSE`.
#' @noRd
is_npz_file <- function(path) {
  members <- tryCatch(
    utils::unzip(path, list = TRUE)$Name,
    error = function(e) {
      character()
    }
  )
  length(members) > 0 && any(grepl("\\.npy$", members))
}
