load_data <- function(package, resource, use_experiment_hub = TRUE) {
  # First, try using data() to load the resource
  # This works even during covr::package_coverage()
  tryCatch({
    # Suppress data() output
    invisible(utils::data(list = resource, package = package, envir = environment()))
    if (exists(resource, inherits = FALSE)) {
      return(get(resource, inherits = FALSE))
    }
  }, error = function(e) {
    # Silently continue to next method
  })

  # Second, check if the resource exists in the package namespace (lazy loaded)
  if (exists(resource, envir = asNamespace(package), inherits = FALSE)) {
    return(get(resource, envir = asNamespace(package), inherits = FALSE))
  }

  # Third, try to load from data file directly
  data_file <- paste0(resource, ".rda")
  data_path <- system.file("data", data_file, package = package, mustWork = FALSE)
  if (file.exists(data_path)) {
    env <- new.env()
    load(data_path, envir = env)
    if (exists(resource, envir = env)) {
      return(get(resource, envir = env))
    }
  }

  # Fourth, try ExperimentHub if enabled
  if (use_experiment_hub) {
    if (!requireNamespace("ExperimentHub", quietly = TRUE)) {
      warning("ExperimentHub package not available. Install with: BiocManager::install('ExperimentHub')")
    } else {
      tryCatch({
        cache <- ExperimentHub::getExperimentHubOption("CACHE")
        dir.create(cache, showWarnings = FALSE, recursive = TRUE)
        eh <- ExperimentHub::ExperimentHub()
        resources <- ExperimentHub::query(eh, package)
        # Find the specific resource
        resource_match <- resources[grepl(resource, resources$title, ignore.case = TRUE)]
        if (length(resource_match) > 0) {
          return(resource_match[[1]])
        }
      }, error = function(e) {
        warning("Failed to query ExperimentHub: ", e$message)
      })
    }
  }
  # If we get here, the resource was not found
  stop(
    "Resource '", resource, "' not found in package or ExperimentHub"
  )
}
