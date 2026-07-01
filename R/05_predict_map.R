# =====================================================================
# 05_predict_map.R  —  Project the model across the study region
# =====================================================================
# Output : outputs/<species>_suitability.tif   (continuous 0-1)
#          outputs/<species>_presence.tif       (binary, max-SSS thr)
#          outputs/figures/05_suitability_map.png
# ---------------------------------------------------------------------
suppressPackageStartupMessages({ library(terra) })

predictors <- rast(file.path(cfg$dir_proc, "predictors.tif"))
mo <- readRDS(file.path(cfg$dir_mod, paste0(cfg$species_short, "_model.rds")))
occ <- read.csv(file.path(cfg$dir_proc,
                          paste0(cfg$species_short, "_occ_clean.csv")))

message("05 | Projecting suitability across ", ncell(predictors), " cells ...")
# terra::predict handles the model; wrap rf prob extraction in a function
predfun <- function(model, data, ...) mo$prob(model, data)
suit <- terra::predict(predictors, mo$model, fun = predfun, na.rm = TRUE)
names(suit) <- "suitability"

suit_tif <- file.path("outputs", paste0(cfg$species_short, "_suitability.tif"))
writeRaster(suit, suit_tif, overwrite = TRUE)

# Binary presence/absence at max-SSS threshold
pres <- suit >= mo$threshold
names(pres) <- "presence"
writeRaster(pres,
            file.path("outputs", paste0(cfg$species_short, "_presence.tif")),
            overwrite = TRUE)
message("05 | Wrote suitability + binary rasters")

# ---- Map figure -------------------------------------------------------
png(file.path(cfg$dir_fig, "05_suitability_map.png"),
    width = 1100, height = 1100, res = 150)
plot(suit, col = hcl.colors(100, "Viridis"),
     main = paste0(cfg$species_name, " - habitat suitability"))
points(occ$lon, occ$lat, pch = 16, cex = 0.2, col = adjustcolor("white", 0.5))
dev.off()
message("05 | Wrote suitability map figure")
