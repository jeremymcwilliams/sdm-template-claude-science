# =====================================================================
# 02_get_predictors.R  —  Download & crop WorldClim bioclim predictors
# =====================================================================
# Inputs : cfg, cleaned occurrences (to set extent if cfg$extent NULL)
# Output : data/processed/predictors.tif   (multi-band SpatRaster)
# ---------------------------------------------------------------------
# Downloads the WorldClim 2.1 bioclim zip directly (no `geodata` dep) and
# caches it under data/raw. Re-runs reuse the cached download.
# ---------------------------------------------------------------------
suppressPackageStartupMessages({ library(terra) })

res <- cfg$worldclim_res
zip_name <- paste0("wc2.1_", res, "m_bio.zip")
zip_path <- file.path(cfg$dir_raw, zip_name)
unzip_dir <- file.path(cfg$dir_raw, paste0("wc2.1_", res, "m_bio"))

if (!dir.exists(unzip_dir) ||
    length(list.files(unzip_dir, pattern = "\\.tif$")) < 19) {
  if (!file.exists(zip_path)) {
    url <- paste0("https://geodata.ucdavis.edu/climate/worldclim/2_1/base/",
                  zip_name)
    message("02 | Downloading WorldClim 2.1 bioclim (res = ", res, "') ...")
    old <- options(timeout = 600); on.exit(options(old), add = TRUE)
    download.file(url, zip_path, mode = "wb", quiet = TRUE)
  }
  message("02 | Unzipping ", zip_name, " ...")
  dir.create(unzip_dir, showWarnings = FALSE)
  unzip(zip_path, exdir = unzip_dir)
}

# Load the 19 bioclim GeoTIFFs in numeric order (bio_1 .. bio_19)
tifs <- list.files(unzip_dir, pattern = "_bio_\\d+\\.tif$", full.names = TRUE)
ord  <- order(as.integer(sub(".*_bio_(\\d+)\\.tif$", "\\1", basename(tifs))))
bio  <- rast(tifs[ord])
names(bio) <- paste0("bio", 1:19)
bio <- bio[[cfg$bioclim_vars]]

# ---- Determine cropping extent ---------------------------------------
if (!is.null(cfg$extent)) {
  e <- ext(cfg$extent["xmin"], cfg$extent["xmax"],
           cfg$extent["ymin"], cfg$extent["ymax"])
} else {
  occ <- read.csv(file.path(cfg$dir_proc,
                            paste0(cfg$species_short, "_occ_clean.csv")))
  p <- cfg$extent_pad_deg
  e <- ext(min(occ$lon) - p, max(occ$lon) + p,
           min(occ$lat) - p, max(occ$lat) + p)
}
predictors <- crop(bio, e)
message("02 | Predictor stack: ", nlyr(predictors), " layers, ",
        paste(dim(predictors)[1:2], collapse = " x "), " cells")

out_tif <- file.path(cfg$dir_proc, "predictors.tif")
writeRaster(predictors, out_tif, overwrite = TRUE)
message("02 | Wrote ", out_tif)
