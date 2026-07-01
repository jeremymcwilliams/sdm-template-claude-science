#!/usr/bin/env Rscript
# =====================================================================
# run_all.R  —  Run the full SDM template end to end
# =====================================================================
# Usage:   Rscript run_all.R
# Edit R/config.R first to set species, region, resolution, method.
# Each step writes its outputs to data/ and outputs/ and can also be
# sourced individually in an interactive session for teaching.
# ---------------------------------------------------------------------
t0 <- Sys.time()
source("R/config.R")
source("R/01_get_occurrences.R")
source("R/02_get_predictors.R")
source("R/03_prepare_data.R")
source("R/04_fit_model.R")
source("R/04b_spatial_cv.R")       # optional: spatially-blocked CV (cfg$run_spatial_cv)
source("R/05_predict_map.R")
source("R/06_project_future.R")   # future CMIP6 projection (comment out to skip)
message("\nDONE in ", round(difftime(Sys.time(), t0, units = "mins"), 1),
        " min. See outputs/ for rasters, figures, and evaluation.csv")
