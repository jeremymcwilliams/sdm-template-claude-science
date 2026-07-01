# =====================================================================
# 03_prepare_data.R  —  Build the modelling table (presence + background)
# =====================================================================
# - Extracts predictor values at presence & background points
# - Prunes collinear predictors (|r| > cfg$cor_threshold)
# - Splits into train/test
# Output : data/processed/model_data.rds  (list: train, test, vars)
#          outputs/figures/03_predictor_correlation.png
# ---------------------------------------------------------------------
suppressPackageStartupMessages({ library(terra); library(predicts) })
set.seed(cfg$seed)

predictors <- rast(file.path(cfg$dir_proc, "predictors.tif"))
occ <- read.csv(file.path(cfg$dir_proc,
                          paste0(cfg$species_short, "_occ_clean.csv")))

# ---- Presence points: keep those with complete predictor data --------
pres_xy <- occ[, c("lon", "lat")]
pres_env <- terra::extract(predictors, pres_xy, ID = FALSE)
ok <- complete.cases(pres_env)
pres_xy <- pres_xy[ok, ]; pres_env <- pres_env[ok, ]
message("03 | Presence points with env data: ", nrow(pres_env))

# ---- Background points (random within predictor extent) --------------
bg_xy <- spatSample(predictors[[1]], size = cfg$n_background,
                    method = "random", as.points = TRUE, na.rm = TRUE,
                    values = FALSE)
bg_xy <- as.data.frame(geom(bg_xy)[, c("x", "y")])
names(bg_xy) <- c("lon", "lat")
bg_env <- terra::extract(predictors, bg_xy, ID = FALSE)
ok <- complete.cases(bg_env)
bg_xy <- bg_xy[ok, ]; bg_env <- bg_env[ok, ]
message("03 | Background points with env data: ", nrow(bg_env))

# ---- Collinearity pruning --------------------------------------------
cmat <- cor(rbind(pres_env, bg_env), use = "complete.obs")
# Greedy drop: iteratively remove the variable with the most |r| > thr
vars <- colnames(cmat)
repeat {
  cc <- abs(cmat[vars, vars]); diag(cc) <- 0
  if (max(cc) <= cfg$cor_threshold) break
  # variable involved in the most high correlations -> drop
  counts <- rowSums(cc > cfg$cor_threshold)
  drop <- names(which.max(counts))
  vars <- setdiff(vars, drop)
}
message("03 | Retained ", length(vars), " predictors: ", paste(vars, collapse = ", "))

# Correlation figure (full matrix, retained vars highlighted)
png(file.path(cfg$dir_fig, "03_predictor_correlation.png"),
    width = 1100, height = 1000, res = 150)
if (requireNamespace("corrplot", quietly = TRUE)) {
  corrplot::corrplot(cor(rbind(pres_env, bg_env)), method = "color",
                     type = "upper", tl.cex = 0.7, tl.col = "black",
                     title = "Bioclim predictor correlations", mar = c(0,0,2,0))
} else {
  image(cmat, main = "Predictor correlation matrix")
}
dev.off()

# ---- Assemble modelling table ----------------------------------------
dat <- rbind(
  data.frame(pa = 1, pres_env[, vars, drop = FALSE]),
  data.frame(pa = 0, bg_env[, vars, drop = FALSE])
)
dat$pa <- factor(dat$pa, levels = c(0, 1))
# Coordinates aligned row-for-row with `dat` (presences first, then
# background) so the spatial-CV step (04b) can block points by location.
coords <- rbind(as.matrix(pres_xy), as.matrix(bg_xy))
colnames(coords) <- c("lon", "lat")

# ---- Train / test split (stratified by presence/absence) -------------
idx_p <- which(dat$pa == 1); idx_a <- which(dat$pa == 0)
te_p <- sample(idx_p, round(cfg$test_fraction * length(idx_p)))
te_a <- sample(idx_a, round(cfg$test_fraction * length(idx_a)))
te_idx <- c(te_p, te_a)
test  <- dat[te_idx, ]
train <- dat[-te_idx, ]
message("03 | Train: ", nrow(train), "  Test: ", nrow(test))

saveRDS(list(train = train, test = test, vars = vars,
             pres_xy = pres_xy, bg_xy = bg_xy,
             dat = dat, coords = coords),
        file.path(cfg$dir_proc, "model_data.rds"))
message("03 | Wrote ", file.path(cfg$dir_proc, "model_data.rds"))
