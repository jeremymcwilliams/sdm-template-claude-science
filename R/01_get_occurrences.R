# =====================================================================
# 01_get_occurrences.R  —  Download & clean species occurrences (GBIF)
# =====================================================================
# Inputs : cfg (from config.R)
# Output : data/processed/<species>_occ_clean.csv  (lon, lat)
#          outputs/figures/01_occurrences_raw_vs_clean.png
# ---------------------------------------------------------------------
# Uses the GBIF REST API directly (httr + jsonlite) so the template has
# no heavy package dependencies. Coordinate cleaning uses explicit,
# inspectable rules rather than a black-box package — better for teaching.
# ---------------------------------------------------------------------
suppressPackageStartupMessages({
  library(terra); library(httr); library(jsonlite)
})
set.seed(cfg$seed)

gbif <- function(path, query = list()) {
  r <- httr::GET(paste0("https://api.gbif.org/v1/", path), query = query,
                 httr::timeout(60))
  httr::stop_for_status(r)
  jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8"),
                     flatten = TRUE)
}

message("01 | Resolving '", cfg$species_name, "' against GBIF backbone ...")
m <- gbif("species/match", list(name = cfg$species_name))
key <- m$usageKey
stopifnot(!is.null(key))
message("01 | usageKey = ", key, "  (", m$scientificName, ")")

# ---- Build optional WKT polygon from the study extent ----------------
ext <- cfg$extent
wkt <- if (!is.null(ext)) {
  sprintf("POLYGON((%f %f,%f %f,%f %f,%f %f,%f %f))",
          ext["xmin"], ext["ymin"], ext["xmax"], ext["ymin"],
          ext["xmax"], ext["ymax"], ext["xmin"], ext["ymax"],
          ext["xmin"], ext["ymin"])
} else NULL

# ---- Page through the occurrence/search endpoint ---------------------
message("01 | Downloading GBIF occurrences (up to ", cfg$occ_limit, ") ...")
page_size <- 300
records <- list()
offset <- 0
repeat {
  q <- list(taxonKey = key, hasCoordinate = "true",
            hasGeospatialIssue = "false",
            limit = page_size, offset = offset)
  if (!is.null(wkt)) q$geometry <- wkt
  res <- gbif("occurrence/search", q)
  if (length(res$results) == 0 || is.null(nrow(res$results))) break
  records[[length(records) + 1]] <- res$results
  offset <- offset + page_size
  if (res$endOfRecords || offset >= cfg$occ_limit) break
}
cols <- c("decimalLongitude", "decimalLatitude", "countryCode",
          "year", "basisOfRecord", "coordinateUncertaintyInMeters")
occ <- do.call(rbind, lapply(records, function(d) {
  for (cc in setdiff(cols, names(d))) d[[cc]] <- NA
  d[, cols]
}))
names(occ)[1:2] <- c("lon", "lat")
stopifnot(nrow(occ) > 0)
message("01 | Retrieved ", nrow(occ), " raw records")
occ_raw <- occ

# ---- Clean with explicit rules ---------------------------------------
message("01 | Cleaning coordinates ...")
n0 <- nrow(occ)
occ <- occ[is.finite(occ$lon) & is.finite(occ$lat), ]          # finite
occ <- occ[abs(occ$lon) <= 180 & abs(occ$lat) <= 90, ]         # in range
occ <- occ[!(occ$lon == 0 & occ$lat == 0), ]                   # null island
occ <- occ[!(occ$lon == round(occ$lon) & occ$lat == round(occ$lat)), ]  # integer-degree (often imprecise)
# Drop records whose recorded uncertainty exceeds 10 km
if ("coordinateUncertaintyInMeters" %in% names(occ)) {
  bad <- !is.na(occ$coordinateUncertaintyInMeters) &
          occ$coordinateUncertaintyInMeters > 10000
  occ <- occ[!bad, ]
}
# Fossil / unknown basis records are unreliable for current-climate SDMs
if ("basisOfRecord" %in% names(occ)) {
  occ <- occ[!occ$basisOfRecord %in% c("FOSSIL_SPECIMEN", "UNKNOWN"), ]
}
message("01 | After rule-based cleaning: ", nrow(occ), " records (removed ", n0 - nrow(occ), ")")

# ---- Spatial thinning: one point per ~thin_dist_km grid cell ----------
# Cheap, deterministic thinning by snapping to a grid at the thinning
# distance, then keeping one record per cell. Reduces sampling bias.
deg <- cfg$thin_dist_km / 111.32
occ$cellx <- floor(occ$lon / deg)
occ$celly <- floor(occ$lat / deg)
occ <- occ[!duplicated(occ[, c("cellx", "celly")]), ]
occ$cellx <- occ$celly <- NULL
message("01 | After ", cfg$thin_dist_km, " km thinning: ", nrow(occ), " records")

# ---- Save -------------------------------------------------------------
out_csv <- file.path(cfg$dir_proc,
                     paste0(cfg$species_short, "_occ_clean.csv"))
write.csv(occ[, c("lon", "lat")], out_csv, row.names = FALSE)
message("01 | Wrote ", out_csv)

# ---- Diagnostic figure: raw vs clean ----------------------------------
png(file.path(cfg$dir_fig, paste0(cfg$species_short, "_01_occurrences_raw_vs_clean.png")),
    width = 1600, height = 800, res = 150)
op <- par(mfrow = c(1, 2), mar = c(3, 3, 3, 1))
plot(occ_raw$lon, occ_raw$lat, pch = 16, cex = 0.3, col = "grey50",
     xlab = "lon", ylab = "lat", main = paste0("Raw GBIF (n=", nrow(occ_raw), ")"))
plot(occ$lon, occ$lat, pch = 16, cex = 0.3, col = "forestgreen",
     xlab = "lon", ylab = "lat", main = paste0("Cleaned + thinned (n=", nrow(occ), ")"))
par(op); dev.off()

occ_clean <- occ   # leave in env for interactive use
