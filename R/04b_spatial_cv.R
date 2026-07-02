# =====================================================================
# 04b_spatial_cv.R  —  Spatially blocked cross-validation (optional)
# =====================================================================
# WHY: step 04 reports an AUC from a RANDOM train/test split. Because
# occurrence records cluster in space (people report otters near cities),
# random test points sit next to training points and the model can
# "peek" at neighbours — the AUC comes out optimistically high. This
# step lays a grid of square blocks over the study area, deals whole
# blocks into k folds, and holds out one fold (whole regions) at a time.
# The resulting AUC is a more honest estimate of how well the model
# transfers to places it has NOT seen. It is usually LOWER; the gap
# between the two numbers is the lesson.
#
# No extra packages: the blocking is a few lines of base R, so students
# can read exactly how folds are built.
#
# Runs only when cfg$run_spatial_cv is TRUE.
# Output : outputs/models/spatial_cv.csv   (per-fold + summary rows)
#          outputs/figures/04b_spatial_cv.png (fold map + AUC comparison)
# ---------------------------------------------------------------------
if (!isTRUE(cfg$run_spatial_cv)) {
  message("04b | run_spatial_cv = FALSE -> skipping spatial CV")
} else {
suppressPackageStartupMessages({ library(terra); library(predicts) })
set.seed(cfg$seed)

md <- readRDS(file.path(cfg$dir_proc, paste0(cfg$species_short, "_model_data.rds")))
if (is.null(md$coords) || is.null(md$dat)) {
  stop("04b | model_data.rds lacks coords/dat. Re-run 03_prepare_data.R ",
       "so the coordinates needed for spatial blocking are saved.")
}
dat <- md$dat; coords <- md$coords; vars <- md$vars
form <- as.formula(paste("pa ~", paste(vars, collapse = " + ")))

# ---- Fit + predict helpers (mirror step 04's method choice) ----------
fit_predict <- function(tr, te) {
  if (cfg$method == "rf") {
    suppressPackageStartupMessages(library(randomForest))
    npres <- sum(tr$pa == 1)
    m <- randomForest(form, data = tr, ntree = cfg$rf_ntree,
                      sampsize = c("0" = npres, "1" = npres))
    predict(m, te, type = "prob")[, "1"]
  } else if (cfg$method == "glm") {
    m <- glm(form, data = tr, family = binomial())
    predict(m, te, type = "response")
  } else {
    stop("04b | Unsupported method for spatial CV: ", cfg$method)
  }
}

# ---- Build spatial blocks and deal them into k folds -----------------
# Snap each point to a block index (row, col) on a grid of size
# spatial_block_deg. Each occupied block is one indivisible unit.
bs  <- cfg$spatial_block_deg
col <- floor((coords[, "lon"] - min(coords[, "lon"])) / bs)
row <- floor((coords[, "lat"] - min(coords[, "lat"])) / bs)
block_id <- paste(row, col, sep = "_")
blocks   <- unique(block_id)
# Randomly assign whole blocks to folds: make a balanced set of fold
# labels (one per block), then shuffle it so which block lands in which
# fold is random.
k <- cfg$spatial_cv_k
fold_of_block <- setNames(
  sample(rep(seq_len(k), length.out = length(blocks))), blocks)
point_fold <- fold_of_block[block_id]
message("04b | ", length(blocks), " occupied ", bs, "-deg blocks -> ",
        k, " folds (", nrow(dat), " points)")

# ---- k-fold loop: hold out one fold (whole regions) at a time --------
fold_rows <- lapply(seq_len(k), function(f) {
  hold <- which(point_fold == f)
  tr <- dat[-hold, ]; te <- dat[hold, ]
  # A fold must contain BOTH presences and background to score an AUC
  if (sum(te$pa == 1) < 1 || sum(te$pa == 0) < 1 ||
      sum(tr$pa == 1) < 1 || sum(tr$pa == 0) < 1) {
    return(data.frame(fold = f, n_test = nrow(te),
                      n_test_pres = sum(te$pa == 1), auc = NA_real_))
  }
  pr <- fit_predict(tr, te)
  ev <- pa_evaluate(p = pr[te$pa == 1], a = pr[te$pa == 0])
  data.frame(fold = f, n_test = nrow(te),
             n_test_pres = sum(te$pa == 1), auc = ev@stats$auc)
})
cv <- do.call(rbind, fold_rows)
mean_auc <- mean(cv$auc, na.rm = TRUE)
sd_auc   <- sd(cv$auc,   na.rm = TRUE)
message(sprintf("04b | spatial AUC = %.3f +/- %.3f  (mean +/- sd over %d folds)",
                mean_auc, sd_auc, sum(!is.na(cv$auc))))

# ---- Pull the random-split AUC from step 04 for comparison -----------
random_auc <- NA_real_
ev_path <- file.path(cfg$dir_mod, paste0(cfg$species_short, "_evaluation.csv"))
if (file.exists(ev_path)) random_auc <- read.csv(ev_path)$auc[1]

# ---- Write the results table -----------------------------------------
out <- rbind(
  cv,
  data.frame(fold = "spatial_mean", n_test = sum(cv$n_test),
             n_test_pres = sum(cv$n_test_pres), auc = mean_auc),
  data.frame(fold = "spatial_sd", n_test = NA, n_test_pres = NA, auc = sd_auc),
  data.frame(fold = "random_split", n_test = NA, n_test_pres = NA,
             auc = random_auc)
)
write.csv(out, file.path(cfg$dir_mod, paste0(cfg$species_short, "_spatial_cv.csv")), row.names = FALSE)

# ---- Figure: fold map (left) + AUC comparison (right) ----------------
png(file.path(cfg$dir_fig, paste0(cfg$species_short, "_04b_spatial_cv.png")),
    width = 1600, height = 750, res = 150)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
# (a) where the folds are on the map
pal <- hcl.colors(k, "Dark 3")
plot(coords[, "lon"], coords[, "lat"], col = pal[point_fold], pch = 19,
     cex = 0.35, xlab = "Longitude", ylab = "Latitude",
     main = sprintf("Spatial blocks -> %d folds (%g-deg)", k, bs), asp = 1)
legend("topright", legend = paste("fold", seq_len(k)), col = pal,
       pch = 19, bty = "n", cex = 0.8)
# (b) random vs spatial AUC
bars <- c(Random = random_auc, Spatial = mean_auc)
bp <- barplot(bars, ylim = c(0, 1), col = c("grey70", "#2c7fb8"),
              ylab = "Test AUC", main = "Random split vs spatial CV")
arrows(bp[2], mean_auc - sd_auc, bp[2], mean_auc + sd_auc,
       angle = 90, code = 3, length = 0.05, col = "grey20")
abline(h = 0.5, lty = 3, col = "grey40")   # 0.5 = no better than chance
text(bp, pmax(bars - 0.06, 0.04), sprintf("%.3f", bars), col = "white", font = 2)
par(op); dev.off()
message("04b | Wrote ", cfg$species_short, "_spatial_cv.csv + ",
        cfg$species_short, "_04b_spatial_cv.png")
}
