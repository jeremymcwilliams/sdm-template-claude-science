# Reproducible Species Distribution Model (SDM) Template

A small, config-driven pipeline for fitting a correlative species
distribution model from open data. Built for teaching and for getting a
defensible first model quickly — every step is a separate, readable R
script that can be run on its own or as part of the whole pipeline.

**Worked example:** Douglas-fir (*Pseudotsuga menziesii*) across western
North America. Swap the species in one line (`R/config.R`).

---

## Example output

The template ships with the outputs of a verified Douglas-fir run (10
arc-minute resolution, random forest) under [`examples/`](examples/).

![Douglas-fir habitat suitability](examples/05_suitability_map.png)

Predicted suitability tracks the species' actual range — the Coast
Ranges, Cascades, Sierra Nevada, and northern Rockies. Held-out
performance for this run:

| Metric | Value |
|--------|-------|
| Test AUC | 0.959 |
| Test correlation | 0.758 |
| Max-SSS threshold | 0.469 |
| Predictors retained | 8 of 19 (|r| > 0.7 pruned) |

> These are presence-vs-background metrics on a random split — read the
> [caveats](#method-notes--caveats) before quoting them.

---

## What it does

1. **Occurrences** — downloads georeferenced records from **GBIF** (REST
   API, no heavy packages) and cleans them with explicit, inspectable
   rules (range checks, null-island, integer-degree, uncertainty,
   fossil/unknown basis, spatial thinning).
2. **Predictors** — downloads **WorldClim 2.1** bioclimatic variables
   (19 layers) by direct download and crops them to the study region.
3. **Prepare** — extracts predictor values at presence + background
   points, prunes collinear predictors (|r| > threshold), and makes a
   stratified train/test split.
4. **Fit & evaluate** — fits a down-sampled random forest (or logistic
   GLM), evaluates on held-out data (AUC, correlation, max-SSS
   threshold), and plots ROC + variable importance.
5. **Project** — predicts habitat suitability across the region, writes
   a continuous suitability raster and a binary presence raster, and
   draws the map.

---

## Quick start

```bash
# From the sdm_template/ directory, in the `sdm` R environment:
Rscript run_all.R
```

Or, interactively (good for teaching — inspect objects between steps):

```r
source("R/config.R")
source("R/01_get_occurrences.R")
source("R/02_get_predictors.R")
source("R/03_prepare_data.R")
source("R/04_fit_model.R")
source("R/05_predict_map.R")
```

---

## Configure it (`R/config.R`)

Everything is set in one file. The most common edits:

| Knob | What it controls |
|------|------------------|
| `species_name` / `species_short` | Which species (must match GBIF backbone) |
| `extent` | Study-region bounding box (lon/lat); `NULL` = use occurrence extent |
| `worldclim_res` | Climate resolution in arc-minutes: `"10"` (fast/teaching) → `"0.5"` (fine) |
| `bioclim_vars` | Which of bio1–bio19 to consider |
| `cor_threshold` | Collinearity cutoff for predictor pruning |
| `n_background` | Number of background / pseudo-absence points |
| `thin_dist_km` | Spatial thinning distance |
| `method` | `"rf"` (random forest) or `"glm"` |
| `seed` | Reproducibility |

To model a different species, change only `species_name`, `species_short`,
and (optionally) `extent`, then re-run.

---

## Outputs

```
data/processed/
  <species>_occ_clean.csv     cleaned presence coordinates
  predictors.tif              cropped bioclim stack
  model_data.rds              train/test tables + retained predictors
outputs/
  <species>_suitability.tif   continuous habitat suitability (0–1)
  <species>_presence.tif      binary presence at max-SSS threshold
  models/
    <species>_model.rds       fitted model object
    evaluation.csv            AUC, correlation, threshold
  figures/
    01_occurrences_raw_vs_clean.png
    03_predictor_correlation.png
    04_roc.png
    04_variable_importance.png
    05_suitability_map.png
```

---

## Method notes & caveats

- **Background, not true absence.** GBIF gives presence-only data; we
  draw random background points. AUC is therefore presence-vs-background
  discrimination, not presence-vs-absence — interpret accordingly.
- **Sampling bias.** GBIF records are spatially biased toward roads,
  cities, and well-surveyed regions. Spatial thinning mitigates but does
  not remove this. For publication, consider a target-group background
  or bias layer.
- **No spatial cross-validation.** The train/test split is random. Because
  occurrences are spatially autocorrelated, a random split inflates AUC
  relative to spatially blocked CV (`blockCV`). Treat the AUC here as
  optimistic.
- **Collinearity pruning is greedy** and based on Pearson |r| only;
  consider VIF for a more principled selection.
- **Current climate only.** To project to future climates, download a
  future WorldClim/CMIP6 scenario with the same variables and re-run
  step 05 against it.

---

## Dependencies

R packages (conda env `sdm`): `terra`, `predicts`, `randomForest`, `sf`,
`corrplot`, `httr`, `jsonlite`. GBIF and WorldClim are accessed by direct
download, so no API wrapper packages are required.

Data sources: [GBIF](https://www.gbif.org) (occurrences),
[WorldClim 2.1](https://www.worldclim.org) (climate).
