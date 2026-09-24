write_config <- function(lines) {
  path <- withr::local_tempfile(
    fileext = ".yaml",
    .local_envir = parent.frame()
  )
  writeLines(lines, path)
  path
}

# A minimal .slp: the skeleton lives in the metadata group's `json` attribute.
write_slp <- function(labels) {
  path <- withr::local_tempfile(fileext = ".slp", .local_envir = parent.frame())
  rhdf5::h5createFile(path)
  rhdf5::h5createGroup(path, "metadata")
  fid <- rhdf5::H5Fopen(path)
  gid <- rhdf5::H5Gopen(fid, "metadata")
  rhdf5::h5writeAttribute(
    as.character(jsonlite::toJSON(labels, auto_unbox = TRUE)),
    gid,
    "json"
  )
  rhdf5::H5Gclose(gid)
  rhdf5::H5Fclose(fid)
  path
}

body <- list(
  "py/reduce" = list(
    list("py/type" = "sleap.skeleton.EdgeType"),
    list("py/tuple" = list(1))
  )
)
symmetry <- list(
  "py/reduce" = list(
    list("py/type" = "sleap.skeleton.EdgeType"),
    list("py/tuple" = list(2))
  )
)

sleap_labels <- function(skeletons) {
  list(
    nodes = list(
      list(name = "head"),
      list(name = "thorax"),
      list(name = "ear_l"),
      list(name = "ear_r")
    ),
    skeletons = skeletons
  )
}

fly <- list(
  graph = list(name = "fly"),
  nodes = list(
    list(id = 0L),
    list(id = list("py/id" = 2L)),
    list(id = 2L),
    list(id = 3L)
  ),
  links = list(
    list(source = 0L, target = 1L, type = body),
    list(source = 2L, target = 3L, type = symmetry),
    list(source = 0L, target = 2L, type = list("py/id" = 1L)),
    list(source = 0L, target = 3L, type = list("py/id" = 1L)),
    list(source = 3L, target = 2L, type = list("py/id" = 2L))
  )
)

test_that("a DeepLabCut config becomes points and directed segments", {
  path <- write_config(c(
    "Task: mouse",
    "bodyparts:",
    "- snout",
    "- neck",
    "- tail",
    "skeleton:",
    "- - snout",
    "  - neck",
    "- - neck",
    "  - tail"
  ))
  s <- read_structure_deeplabcut(path)
  expect_s3_class(s, "anistructure")
  expect_equal(s$points, c("snout", "neck", "tail"))
  expect_equal(s$segments$from, c("snout", "neck"))
  expect_equal(s$segments$to, c("neck", "tail"))
  expect_equal(s$source, "DeepLabCut project mouse")
})

test_that("a multi-animal config reads the animals' body parts, not the unique ones", {
  path <- write_config(c(
    "multianimalproject: true",
    "bodyparts: MULTI!",
    "multianimalbodyparts: [head, tail]",
    "uniquebodyparts: [food]",
    "skeleton:",
    "- [head, tail]",
    "- [head, tail]",
    "- [tail, tip]"
  ))
  s <- read_structure(path)
  expect_equal(s$points, c("head", "tail", "tip"))
  expect_equal(nrow(s$segments), 2L)
})

test_that("a config without a skeleton gives points alone, and one without parts errors", {
  s <- read_structure_deeplabcut(write_config(c("bodyparts: [a, b]")))
  expect_equal(s$points, c("a", "b"))
  expect_equal(nrow(s$segments), 0L)
  expect_error(
    read_structure_deeplabcut(write_config("Task: x")),
    "no body parts"
  )
})

test_that("a .slp skeleton keeps body edges and drops symmetry edges", {
  skip_if_not_installed("rhdf5")
  s <- read_structure(write_slp(sleap_labels(list(fly))))
  expect_equal(s$points, c("head", "thorax", "ear_l", "ear_r"))
  expect_equal(s$segments$from, c("head", "head", "head"))
  expect_equal(s$segments$to, c("thorax", "ear_l", "ear_r"))
  expect_equal(s$source, "SLEAP skeleton fly")
})

test_that("a .slp with several skeletons needs one chosen", {
  skip_if_not_installed("rhdf5")
  other <- fly
  other$graph$name <- "other"
  other$links <- other$links[1]
  path <- write_slp(sleap_labels(list(fly, other)))
  expect_error(read_structure_sleap(path), "several skeletons")
  expect_equal(
    nrow(read_structure_sleap(path, skeleton = "other")$segments),
    1L
  )
  expect_error(read_structure_sleap(path, skeleton = "nope"), "no skeleton")
  expect_error(
    read_structure_sleap(write_slp(sleap_labels(list()))),
    "no skeleton"
  )
})

test_that("an analysis .h5 gives its body edges, in either orientation", {
  skip_if_not_installed("rhdf5")
  # Three edges, so the two layouts (2 x E and E x 2) cannot be confused.
  pairs <- matrix(c(0L, 1L, 1L, 2L, 2L, 3L), nrow = 2)
  for (edges in list(pairs, t(pairs))) {
    path <- withr::local_tempfile(fileext = ".h5")
    rhdf5::h5createFile(path)
    rhdf5::h5write(c("a", "b", "c", "d"), path, "node_names")
    rhdf5::h5write(edges, path, "edge_inds")
    s <- read_structure(path)
    expect_equal(s$segments$from, c("a", "b", "c"))
    expect_equal(s$segments$to, c("b", "c", "d"))
  }
  bare <- withr::local_tempfile(fileext = ".h5")
  rhdf5::h5createFile(bare)
  rhdf5::h5write(c("a", "b"), bare, "node_names")
  expect_equal(nrow(read_structure_sleap(bare)$segments), 0L)
})

test_that("read_structure() says what it cannot read", {
  expect_error(read_structure("x.csv"), "Cannot tell")
  expect_error(read_structure("x.yaml", source = c("a", "b")), "single source")
  path <- write_config("bodyparts: [a]")
  expect_error(read_structure(path, source = "trex"), "Unsupported")
})

test_that("link types are resolved in the order they are defined, as sleap-io does", {
  skip_if_not_installed("rhdf5")
  # The first link is a symmetry edge, so py/id 1 refers to SYMMETRY here.
  mirrored <- list(
    graph = list(name = "mirrored"),
    nodes = list(list(id = 0L), list(id = 1L), list(id = 2L), list(id = 3L)),
    links = list(
      list(source = 2L, target = 3L, type = symmetry),
      list(source = 0L, target = 1L, type = body),
      list(source = 3L, target = 2L, type = list("py/id" = 1L)),
      list(source = 1L, target = 2L, type = list("py/id" = 2L))
    )
  )
  s <- read_structure_sleap(write_slp(sleap_labels(list(mirrored))))
  expect_equal(s$segments$from, c("head", "thorax"))
  expect_equal(s$segments$to, c("thorax", "ear_l"))
})

test_that("a reference to an undefined link type is read as the type itself", {
  skip_if_not_installed("rhdf5")
  bare <- list(
    graph = list(name = "bare"),
    nodes = list(list(id = 0L), list(id = 1L), list(id = 2L)),
    links = list(
      list(source = 0L, target = 1L, type = list("py/id" = 1L)),
      list(source = 1L, target = 2L, type = list("py/id" = 2L))
    )
  )
  s <- read_structure_sleap(write_slp(sleap_labels(list(bare))))
  expect_equal(s$segments$from, "head")
  expect_equal(s$segments$to, "thorax")
})
