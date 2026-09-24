#' Read a skeleton as an anistructure
#'
#' @description
#' Reads the skeleton a pose-estimation project defines — its keypoints and
#' the edges between them — as an [anicore::anistructure()] with points and
#' segments. Attach it to a frame with [anicore::set_structure()].
#'
#' * `read_structure_deeplabcut()` reads a DeepLabCut project's
#'   `config.yaml`: `bodyparts`, or `multianimalbodyparts` in a multi-animal
#'   project, and `skeleton`. A multi-animal project's `uniquebodyparts` are
#'   left out: DeepLabCut assigns them to a separate `"single"` individual,
#'   not to each animal's body.
#' * `read_structure_sleap()` reads a SLEAP `.slp` file (project or
#'   predictions) or an analysis `.h5` export. Only body edges become
#'   segments; SLEAP's symmetry edges pair left and right keypoints and are
#'   not segments.
#' * `read_structure()` detects which from the file, as [read_dataset()] does
#'   for frames.
#'
#' Edges keep the direction the file lists them in, which is what
#' [anicore::as_anisegment()] measures along.
#'
#' @param path Path to the file.
#' @param source `"auto"` to detect it from the file, or `"deeplabcut"` or
#'   `"sleap"`.
#' @param skeleton For a `.slp` holding several skeletons, the name of the
#'   one to read.
#'
#' @return An [anicore::anistructure()].
#'
#' @examples
#' \dontrun{
#' skeleton <- read_structure("my-project/config.yaml")
#' af <- read_deeplabcut("my-project/videos/mouse1DLC.csv") |>
#'   anicore::set_structure(skeleton)
#' }
#' @export
read_structure <- function(path, source = "auto") {
  if (!rlang::is_string(source)) {
    cli::cli_abort(
      "{.arg source} must be a single source name or {.val auto}, not {.obj_type_friendly {source}}."
    )
  }
  if (identical(source, "auto")) {
    source <- detect_structure_source(path)
  }
  switch(
    source,
    deeplabcut = read_structure_deeplabcut(path),
    sleap = read_structure_sleap(path),
    cli::cli_abort(c(
      "Unsupported {.arg source}: {.val {source}}.",
      "i" = "Skeletons can be read from {.val {c('deeplabcut', 'sleap')}}."
    ))
  )
}


#' @rdname read_structure
#' @export
read_structure_deeplabcut <- function(path) {
  validate_files(path, expected_suffix = c("yaml", "yml"))
  rlang::check_installed("yaml", reason = "to read a DeepLabCut config.")
  config <- yaml::read_yaml(path)

  # As DeepLabCut's own `bodyparts_list`: a multi-animal project lists the
  # animals' parts in `multianimalbodyparts`, with `bodyparts: MULTI!`.
  points <- if (isTRUE(config$multianimalproject)) {
    config$multianimalbodyparts
  } else {
    config$bodyparts
  }
  points <- setdiff(as.character(unlist(points)), "MULTI!")
  pairs <- lapply(config$skeleton %||% list(), function(p) {
    as.character(unlist(p))
  })
  if (length(points) == 0L) {
    cli::cli_abort("{.file {path}} lists no body parts.")
  }

  structure_from_edges(
    points,
    pairs,
    source = paste("DeepLabCut project", config$Task %||% basename(path))
  )
}


#' @rdname read_structure
#' @export
read_structure_sleap <- function(path, skeleton = NULL) {
  validate_files(path, expected_suffix = c("slp", "h5"))
  rlang::check_installed("rhdf5", reason = "to read SLEAP files.")
  if (identical(tolower(tools::file_ext(path)), "h5")) {
    return(read_sleap_analysis_skeleton(path))
  }

  rlang::check_installed("jsonlite", reason = "to read a SLEAP .slp file.")
  metadata <- rhdf5::h5readAttributes(path, "metadata")
  labels <- jsonlite::fromJSON(metadata$json, simplifyVector = FALSE)
  skeletons <- labels$skeletons
  names(skeletons) <- vapply(
    skeletons,
    function(s) s$graph$name %||% NA_character_,
    character(1)
  )
  if (length(skeletons) == 0L) {
    cli::cli_abort("{.file {path}} holds no skeleton.")
  }
  if (is.null(skeleton)) {
    if (length(skeletons) > 1L) {
      cli::cli_abort(c(
        "{.file {path}} holds several skeletons: {.val {names(skeletons)}}.",
        "i" = "Choose one with {.arg skeleton}."
      ))
    }
    chosen <- skeletons[[1]]
  } else {
    if (!skeleton %in% names(skeletons)) {
      cli::cli_abort(
        "{.file {path}} has no skeleton {.val {skeleton}}; it has {.val {names(skeletons)}}."
      )
    }
    chosen <- skeletons[[skeleton]]
  }

  # As sleap-io's SkeletonSLPDecoder: a skeleton's nodes index the file's
  # node list, and a link's type is an EdgeType (1 = body, 2 = symmetry),
  # written in full ("py/reduce") the first time and then referenced by a
  # "py/id" numbering those definitions from 1, per skeleton.
  node_names <- vapply(labels$nodes, function(n) n$name, character(1))
  points <- vapply(
    chosen$nodes,
    function(n) {
      id <- n$id
      if (is.list(id)) node_names[[id[["py/id"]]]] else node_names[[id + 1L]]
    },
    character(1)
  )
  defined <- integer()
  types <- vapply(
    chosen$links,
    function(link) {
      type <- link$type
      if (!is.null(type[["py/reduce"]])) {
        value <- as.integer(type[["py/reduce"]][[2]][["py/tuple"]][[1]])
        defined <<- c(defined, value)
        return(value)
      }
      id <- as.integer(type[["py/id"]])
      if (id <= length(defined)) defined[[id]] else id
    },
    integer(1)
  )
  body <- chosen$links[types == 1L]
  pairs <- lapply(body, function(link) points[c(link$source, link$target) + 1L])

  structure_from_edges(
    points,
    pairs,
    source = paste("SLEAP skeleton", chosen$graph$name %||% basename(path))
  )
}


#' The skeleton a SLEAP analysis .h5 export carries
#'
#' `edge_inds` holds the body edges as 0-based node indices; files written
#' without a skeleton have no edges.
#'
#' @noRd
read_sleap_analysis_skeleton <- function(path) {
  datasets <- rhdf5::h5ls(path)$name
  points <- as.character(rhdf5::h5read(path, "node_names"))
  pairs <- list()
  if ("edge_inds" %in% datasets) {
    edges <- rhdf5::h5read(path, "edge_inds")
    if (nrow(edges) != 2L) {
      edges <- t(edges)
    }
    pairs <- lapply(seq_len(ncol(edges)), function(i) points[edges[, i] + 1L])
  }
  structure_from_edges(points, pairs, source = "SLEAP analysis export")
}


#' Build an anistructure from points and edge pairs
#'
#' Repeated edges are read once, and endpoints missing from the point list
#' are added to it.
#'
#' @noRd
structure_from_edges <- function(points, pairs, source) {
  pairs <- unique(Filter(function(p) length(p) == 2L, pairs))
  endpoints <- unlist(pairs)
  anicore::anistructure(
    points = unique(c(points, endpoints)),
    segments = if (length(pairs) > 0L) pairs,
    source = source
  )
}


#' Which tool a skeleton file comes from
#'
#' @noRd
detect_structure_source <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("yaml", "yml")) {
    return("deeplabcut")
  }
  if (ext %in% c("slp", "h5")) {
    return("sleap")
  }
  cli::cli_abort(c(
    "Cannot tell which tool {.file {path}} comes from.",
    "i" = "Skeletons are read from a DeepLabCut {.file config.yaml}, or a SLEAP {.file .slp} or analysis {.file .h5}.",
    "i" = "Name the tool with {.arg source}."
  ))
}
