# =====================================================================
# 04_fit_model.R  —  Fit the SDM and evaluate on held-out data
# =====================================================================
# Methods: "rf" (down-sampled random forest), "glm" (logistic).
# Output : outputs/models/<species>_model.rds
#          outputs/figures/04_roc.png, 04_variable_importance.png
#          outputs/models/evaluation.csv
# ---------------------------------------------------------------------
suppressPackageStartupMessages({ library(terra); library(predicts) })
set.seed(cfg$seed)

md <- readRDS(file.path(cfg$dir_proc, paste0(cfg$species_short, "_model_data.rds")))
train <- md$train; test <- md$test; vars <- md$vars
form <- as.formula(paste("pa ~", paste(vars, collapse = " + ")))

message("04 | Fitting method = ", cfg$method)
if (cfg$method == "rf") {
  library(randomForest)
  # Down-sample the majority (background) class to the # of presences so
  # the forest is not swamped by background -> better calibrated.
  npres <- sum(train$pa == 1)
  model <- randomForest(form, data = train, ntree = cfg$rf_ntree,
                        sampsize = c("0" = npres, "1" = npres),
                        importance = TRUE)
  prob <- function(m, nd) predict(m, nd, type = "prob")[, "1"]

} else if (cfg$method == "glm") {
  model <- glm(form, data = train, family = binomial())
  prob <- function(m, nd) predict(m, nd, type = "response")

} else {
  stop("Unsupported method: ", cfg$method)
}

# ---- Evaluate on held-out test set -----------------------------------
p_test <- prob(model, test[test$pa == 1, ])
a_test <- prob(model, test[test$pa == 0, ])
ev <- pa_evaluate(p = p_test, a = a_test)

auc <- ev@stats$auc
# Max-SSS threshold (maximises sensitivity + specificity) — common SDM choice
thr <- ev@thresholds$max_spec_sens
cor_stat <- ev@stats$cor
message(sprintf("04 | AUC = %.3f | max-SSS threshold = %.3f", auc, thr))

eval_df <- data.frame(
  species = cfg$species_name, method = cfg$method,
  n_train = nrow(train), n_test = nrow(test),
  auc = auc, cor = cor_stat, threshold_maxSSS = thr
)
write.csv(eval_df, file.path(cfg$dir_mod, paste0(cfg$species_short, "_evaluation.csv")), row.names = FALSE)

# ---- ROC curve (predicts' built-in plot) ------------------------------
png(file.path(cfg$dir_fig, paste0(cfg$species_short, "_04_roc.png")), width = 900, height = 900, res = 150)
plot(ev, "ROC")
dev.off()

# ---- Variable importance (rf only) -----------------------------------
if (cfg$method == "rf") {
  png(file.path(cfg$dir_fig, paste0(cfg$species_short, "_04_variable_importance.png")),
      width = 1000, height = 800, res = 150)
  varImpPlot(model, main = "Random forest variable importance")
  dev.off()
}

saveRDS(list(model = model, prob = prob, eval = ev, threshold = thr,
             auc = auc, vars = vars, method = cfg$method),
        file.path(cfg$dir_mod, paste0(cfg$species_short, "_model.rds")))
message("04 | Wrote model + evaluation")
