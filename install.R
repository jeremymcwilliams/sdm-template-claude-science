# =====================================================================
# install.R  —  Native-R package installer for the SDM template.
#
# Use this when you DON'T have conda: Posit Cloud, RStudio Desktop, an
# HPC R module, or any plain R install. It installs the same packages
# that environment.yml pins, using R's own install.packages().
#
#   Rscript install.R          # from the project root
#   # or, in the RStudio console:  source("install.R")
#
# Then run the pipeline:
#   Rscript run_all.R
#
# The conda route (environment.yml) still works and is unchanged — this
# is just an alternative that needs no conda.
# =====================================================================

## ---- 1. Packages this template needs --------------------------------
pkgs <- c(
  "terra",        # rasters, spatial predict
  "predicts",     # SDM helpers, pa_evaluate, background sampling
  "randomForest", # the default model
  "sf",           # vector geometry / thinning
  "corrplot",     # predictor-correlation figure
  "httr",         # GBIF + WorldClim downloads
  "jsonlite"      # GBIF JSON parsing
)

## ---- 2. Use a binary CRAN mirror when one is available --------------
# Posit Cloud already defaults to the Posit Public Package Manager (P3M),
# which serves precompiled Linux BINARIES — installs are fast and need no
# compiler. If no mirror is set (e.g. a bare Rscript session), point at
# P3M's binary endpoint for current Ubuntu; fall back to cloud CRAN.
repo <- getOption("repos")[["CRAN"]]
if (is.null(repo) || is.na(repo) || repo == "@CRAN@") {
  # P3M "latest" binary channel. Works on Linux; on Mac/Windows R will
  # transparently ignore the Linux binary path and use CRAN binaries.
  sysname <- Sys.info()[["sysname"]]
  if (sysname == "Linux") {
    codename <- tryCatch(
      system("lsb_release -cs", intern = TRUE), error = function(e) "")
    if (length(codename) && nzchar(codename)) {
      repo <- sprintf(
        "https://packagemanager.posit.co/cran/__linux__/%s/latest",
        codename)
    } else {
      repo <- "https://packagemanager.posit.co/cran/latest"
    }
  } else {
    repo <- "https://cloud.r-project.org"
  }
  options(repos = c(CRAN = repo))
}
message("Installing from: ", getOption("repos")[["CRAN"]])

## ---- 3. Install only what's missing ---------------------------------
have    <- rownames(installed.packages())
missing <- setdiff(pkgs, have)

if (length(missing)) {
  message("Installing ", length(missing), " package(s): ",
          paste(missing, collapse = ", "))
  install.packages(missing)
} else {
  message("All required packages already installed.")
}

## ---- 4. Verify everything loads -------------------------------------
ok <- vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)
if (all(ok)) {
  message("\nSuccess — all ", length(pkgs), " packages load. ",
          "Run:  Rscript run_all.R")
} else {
  failed <- pkgs[!ok]
  message("\nThese packages did NOT install cleanly: ",
          paste(failed, collapse = ", "))
  message(
    "terra and sf need system libraries GDAL, GEOS and PROJ.\n",
    "  - Posit Cloud / most RStudio Server images: already present.\n",
    "  - Ubuntu/Debian you control:  sudo apt-get install -y \\\n",
    "        libgdal-dev libgeos-dev libproj-dev libudunits2-dev\n",
    "  - macOS (Homebrew):           brew install gdal geos proj udunits\n",
    "  - HPC: load a geospatial / GDAL module before Rscript install.R")
  quit(status = 1)
}
