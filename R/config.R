# =====================================================================
# config.R  —  Single place to set every knob for the SDM template
# =====================================================================
# Edit ONLY this file to run the template for a different species,
# region, or resolution. Everything downstream reads from `cfg`.
# ---------------------------------------------------------------------

cfg <- list(

  # ---- Species -------------------------------------------------------
  # Accepted scientific name. The pipeline resolves it against the GBIF
  # backbone, so spelling must be close enough for a fuzzy match.
  species_name = "Pseudotsuga menziesii",   # Douglas-fir
  species_short = "douglas_fir",            # used in filenames (no spaces)

  # ---- Study region (lon/lat bounding box, WGS84) --------------------
  # Default: western North America. Set to NULL to use the full extent
  # of the cleaned occurrences (padded by `extent_pad_deg`).
  extent = c(xmin = -140, xmax = -100, ymin = 30, ymax = 62),
  extent_pad_deg = 2,

  # ---- Predictors (WorldClim 2.1 bioclim) ----------------------------
  # Resolution: one of "10", "5", "2.5", "0.5" (arc-minutes). Coarser =
  # faster + smaller download; use 10 for teaching, 2.5/0.5 for real work.
  worldclim_res = "5",
  # Which bioclim variables to consider (1-19). Collinear ones are
  # pruned automatically in 03 by the |r| threshold below.
  bioclim_vars = 1:19,
  cor_threshold = 0.7,            # drop predictors with |Pearson r| above this

  # ---- Sampling ------------------------------------------------------
  n_background = 10000,           # background / pseudo-absence points
  thin_dist_km = 5,               # spatial thinning distance for occurrences
  test_fraction = 0.25,           # held-out fraction for evaluation

  # ---- Model ---------------------------------------------------------
  # "rf" (random forest, down-sampled), "glm", or "maxent" (needs Java).
  method = "rf",
  rf_ntree = 1000,

  # ---- Future climate projection (CMIP6, step 06) --------------------
  # The model is fitted ONCE on current climate (01-04); step 06 simply
  # projects that fitted model onto future climate surfaces. See the
  # README section "Projecting to future climate" for what each choice
  # means and how to pick.
  #
  # gcm    : one or more CMIP6 global climate models (WorldClim 2.1 hosts
  #          ~24). Give a vector to build a multi-model ENSEMBLE (mean +
  #          agreement) instead of a single map — recommended.
  # ssp    : emissions scenario. One of "ssp126","ssp245","ssp370","ssp585".
  # periods: one or more 20-yr windows: "2021-2040","2041-2060",
  #          "2061-2080","2081-2100".
  future_gcm    = c("MPI-ESM1-2-HR", "MRI-ESM2-0", "EC-Earth3-Veg"),
  future_ssp    = "ssp245",
  future_periods = c("2041-2060", "2081-2100"),

  # ---- Reproducibility & paths --------------------------------------
  seed = 42,
  occ_limit = 8000,               # max GBIF records to pull (paged 300/req)
  dir_raw = "data/raw",
  dir_proc = "data/processed",
  dir_fig = "outputs/figures",
  dir_mod = "outputs/models"
)

# Create output dirs if missing (idempotent)
for (d in c(cfg$dir_raw, cfg$dir_proc, cfg$dir_fig, cfg$dir_mod)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}
