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
# The model's predict() method lives in its own package; load it so this
# step also works when run on its own (not only via run_all.R).
if (identical(mo$method, "rf")) suppressPackageStartupMessages(library(randomForest))
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

# ---- Map figure (ggplot; optional admin borders via config) ----------
source("R/helpers_map.R")
borders <- get_borders(suit, cfg)
sub <- if (isTRUE(cfg$borders_state) || isTRUE(cfg$borders_country))
         "with administrative borders" else NULL
p <- gg_suitability(suit, cfg, borders,
                    title = paste0(cfg$species_name, " - habitat suitability"),
                    subtitle = sub, occ = occ)
ggsave(file.path(cfg$dir_fig, "05_suitability_map.png"), p,
       width = 8, height = 8, dpi = 150)
message("05 | Wrote suitability map figure")
