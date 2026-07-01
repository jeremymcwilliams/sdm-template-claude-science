# =====================================================================
# 06_project_future.R  —  Project the fitted model onto FUTURE climate
# =====================================================================
# The niche is already fitted on CURRENT climate (steps 01-04). Here we
# only swap in future CMIP6 bioclim surfaces and re-predict. For each
# future period we build a multi-GCM ENSEMBLE:
#   - mean suitability across GCMs         (the projection)
#   - # of GCMs agreeing on presence       (the uncertainty)
# and a CHANGE map vs current (gain / loss / stable / unsuitable).
#
# Requires: outputs/models/<species>_model.rds  (from step 04)
#           outputs/<species>_suitability.tif    (from step 05, current)
# Config  : cfg$future_gcm (vector), cfg$future_ssp, cfg$future_periods
# Output  : outputs/future/<species>_<ssp>_<period>_suitability.tif
#           outputs/future/<species>_<ssp>_<period>_agreement.tif
#           outputs/future/<species>_<ssp>_<period>_change.tif
#           outputs/figures/06_future_<ssp>_<period>.png
# ---------------------------------------------------------------------
suppressPackageStartupMessages({ library(terra) })

dir_fut <- file.path("outputs", "future")
dir.create(dir_fut, recursive = TRUE, showWarnings = FALSE)

# ---- Load fitted model, its predictors, and current suitability ------
mo <- readRDS(file.path(cfg$dir_mod, paste0(cfg$species_short, "_model.rds")))
vars <- mo$vars                      # predictors the model actually uses
thr  <- mo$threshold                 # max-SSS presence threshold
cur_suit <- rast(file.path("outputs",
                           paste0(cfg$species_short, "_suitability.tif")))
cur_pres <- cur_suit >= thr

# Template geometry we must match (current predictor grid)
tmpl <- rast(file.path(cfg$dir_proc, "predictors.tif"))[[1]]
ext_v <- ext(tmpl)
res_m <- cfg$worldclim_res

# ---- Helper: fetch + load one future bioclim stack -------------------
get_future <- function(gcm, ssp, period) {
  fn  <- sprintf("wc2.1_%sm_bioc_%s_%s_%s.tif", res_m, gcm, ssp, period)
  dst <- file.path(cfg$dir_raw, fn)
  if (!file.exists(dst)) {
    url <- sprintf("https://geodata.ucdavis.edu/cmip6/%sm/%s/%s/%s",
                   res_m, gcm, ssp, fn)
    old <- options(timeout = 600); on.exit(options(old), add = TRUE)
    download.file(url, dst, mode = "wb", quiet = TRUE)
  }
  r <- rast(dst)
  names(r) <- paste0("bio", 1:19)    # CMIP6 files are 19 bands, bio1..bio19
  r <- r[[vars]]                     # keep only the model's predictors
  crop(r, ext_v)
}

predfun <- function(model, data, ...) mo$prob(model, data)

# ---- Loop over future periods; ensemble across GCMs ------------------
for (period in cfg$future_periods) {
  message("06 | Projecting ", cfg$future_ssp, " ", period,
          " across ", length(cfg$future_gcm), " GCM(s) ...")

  suit_stack <- rast()   # one suitability layer per GCM
  for (gcm in cfg$future_gcm) {
    fenv <- get_future(gcm, cfg$future_ssp, period)
    s <- terra::predict(fenv, mo$model, fun = predfun, na.rm = TRUE)
    names(s) <- gcm
    suit_stack <- c(suit_stack, s)
  }

  # Ensemble: mean suitability, and how many GCMs call it "present"
  ens_suit  <- mean(suit_stack)
  names(ens_suit) <- "suitability"
  agreement <- sum(suit_stack >= thr)          # 0..n GCMs
  names(agreement) <- "gcm_agreement"

  # Align current presence to this grid (defensive; same grid in practice)
  cur_p <- resample(cur_pres, ens_suit, method = "near")
  fut_p <- ens_suit >= thr

  # Change classes: 1 loss, 2 stable, 3 gain, 0 unsuitable-both
  change <- cur_p * 0
  change[cur_p == 1 & fut_p == 0] <- 1   # loss
  change[cur_p == 1 & fut_p == 1] <- 2   # stable
  change[cur_p == 0 & fut_p == 1] <- 3   # gain
  names(change) <- "change"

  tag <- paste0(cfg$species_short, "_", cfg$future_ssp, "_", period)
  writeRaster(ens_suit,  file.path(dir_fut, paste0(tag, "_suitability.tif")), overwrite = TRUE)
  writeRaster(agreement, file.path(dir_fut, paste0(tag, "_agreement.tif")),   overwrite = TRUE)
  writeRaster(change,    file.path(dir_fut, paste0(tag, "_change.tif")),      overwrite = TRUE)

  # ---- Figure: future suitability + change map -----------------------
  png(file.path(cfg$dir_fig, paste0("06_future_", cfg$future_ssp, "_", period, ".png")),
      width = 1700, height = 850, res = 150)
  op <- par(mfrow = c(1, 2), mar = c(3, 3, 3, 4))
  plot(ens_suit, col = hcl.colors(100, "Viridis"), range = c(0, 1),
       main = paste0(cfg$species_name, "\n", cfg$future_ssp, " ", period,
                     " (mean of ", length(cfg$future_gcm), " GCMs)"))
  cols <- c("grey90", "#d73027", "#4575b4", "#1a9850")  # unsuit, loss, stable, gain
  plot(change, col = cols, type = "classes",
       levels = c("unsuitable", "loss", "stable", "gain"),
       main = paste0("Range change vs current\n", cfg$future_ssp, " ", period))
  par(op); dev.off()

  # ---- Quick summary to console --------------------------------------
  fr <- freq(change)
  message("06 | ", tag, " cells -> ",
          paste(sprintf("%s:%d", c("unsuit","loss","stable","gain")[fr$value + 1], fr$count),
                collapse = "  "))
}
message("06 | Done. See outputs/future/ and outputs/figures/06_*.png")
