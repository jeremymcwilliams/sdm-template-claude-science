# =====================================================================
# helpers_map.R  —  shared mapping helpers (borders + ggplot maps)
# ---------------------------------------------------------------------
# Used by 05_predict_map.R and 06_project_future.R. Sourced automatically
# by those steps; you don't call it directly.
#
# Borders come from Natural Earth (public domain), fetched straight from
# the project's GitHub mirror and cached under data/raw/natural_earth.
# No wrapper package needed — same direct-download approach as the rest
# of this template. Toggle borders in R/config.R:
#     borders_state   = TRUE/FALSE   state / province lines
#     borders_country = TRUE/FALSE   country outlines
#     borders_scale   = "50m" (default) or "10m" (finer, larger download)
# =====================================================================
suppressPackageStartupMessages({ library(terra); library(sf); library(ggplot2) })

# ---- Fetch + cache one Natural Earth layer, return it cropped to ext --
.ne_layer <- function(layer, ext_vec, cache_dir) {
  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
  # layer looks like "ne_50m_admin_1_states_provinces" -> res = "50m",
  # and the GitHub folder is ".../master/50m_cultural".
  res  <- sub("_.*$", "", sub("^ne_", "", layer))          # "50m" / "10m"
  base <- paste0("https://raw.githubusercontent.com/nvkelso/",
                 "natural-earth-vector/master/", res, "_cultural")
  for (ext in c("shp", "shx", "dbf", "prj")) {
    f <- file.path(cache_dir, paste0(layer, ".", ext))
    if (!file.exists(f)) {
      url <- paste0(base, "/", layer, ".", ext)
      try(download.file(url, f, quiet = TRUE, mode = "wb"), silent = TRUE)
    }
  }
  shp <- file.path(cache_dir, paste0(layer, ".shp"))
  if (!file.exists(shp)) stop("Natural Earth download failed for ", layer)
  g  <- sf::st_read(shp, quiet = TRUE)
  bb <- sf::st_bbox(c(xmin = ext_vec[["xmin"]], ymin = ext_vec[["ymin"]],
                      xmax = ext_vec[["xmax"]], ymax = ext_vec[["ymax"]]),
                    crs = sf::st_crs(4326))
  old <- sf::sf_use_s2(FALSE)                 # planar crop; NE polys are global
  on.exit(sf::sf_use_s2(old), add = TRUE)
  suppressWarnings(sf::st_crop(sf::st_make_valid(g), bb))
}

# ---- Public: return list(state=sf|NULL, country=sf|NULL) per config ---
get_borders <- function(r, cfg) {
  scale <- if (is.null(cfg$borders_scale)) "50m" else cfg$borders_scale
  cache <- file.path(cfg$dir_raw, "natural_earth")
  ev <- as.vector(terra::ext(r))               # xmin xmax ymin ymax (named)
  want_state   <- isTRUE(cfg$borders_state)
  want_country <- isTRUE(cfg$borders_country)
  out <- list(state = NULL, country = NULL)
  if (want_state) {
    out$state <- tryCatch(
      .ne_layer(paste0("ne_", scale, "_admin_1_states_provinces"), ev, cache),
      error = function(e) { message("  borders: state layer unavailable (",
                                    conditionMessage(e), ")"); NULL })
  }
  if (want_country) {
    out$country <- tryCatch(
      .ne_layer(paste0("ne_", scale, "_admin_0_countries"), ev, cache),
      error = function(e) { message("  borders: country layer unavailable (",
                                    conditionMessage(e), ")"); NULL })
  }
  out
}

# ---- Public: append border geom_sf layers to a ggplot ----------------
add_borders <- function(p, borders) {
  if (!is.null(borders$state))
    p <- p + ggplot2::geom_sf(data = borders$state, fill = NA,
                              color = "grey35", linewidth = 0.25)
  if (!is.null(borders$country))
    p <- p + ggplot2::geom_sf(data = borders$country, fill = NA,
                              color = "black", linewidth = 0.55)
  p
}

# ---- Public: continuous suitability map (0-1) as a ggplot ------------
gg_suitability <- function(r, cfg, borders, title, subtitle = NULL,
                           occ = NULL) {
  df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "suitability"
  ev <- as.vector(terra::ext(r))
  p <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = df, ggplot2::aes(x, y, fill = suitability)) +
    ggplot2::scale_fill_viridis_c(name = "Suitability", limits = c(0, 1))
  if (!is.null(occ))
    p <- p + ggplot2::geom_point(data = occ,
               ggplot2::aes(lon, lat), shape = 16, size = 0.25,
               color = "white", alpha = 0.5)
  p <- add_borders(p, borders)
  p + ggplot2::coord_sf(xlim = ev[c("xmin","xmax")],
                        ylim = ev[c("ymin","ymax")], expand = FALSE) +
    ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid = ggplot2::element_line(color = "grey92",
                                                      linewidth = 0.2))
}

# ---- Public: categorical change map as a ggplot ----------------------
gg_change <- function(r, cfg, borders, title) {
  df <- as.data.frame(r, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "class"
  labs4 <- c("0" = "unsuitable", "1" = "loss", "2" = "stable", "3" = "gain")
  cols4 <- c("unsuitable" = "grey90", "loss" = "#d73027",
             "stable" = "#4575b4", "gain" = "#1a9850")
  df$class <- factor(labs4[as.character(df$class)],
                     levels = c("unsuitable","loss","stable","gain"))
  ev <- as.vector(terra::ext(r))
  p <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = df, ggplot2::aes(x, y, fill = class)) +
    ggplot2::scale_fill_manual(name = NULL, values = cols4, drop = FALSE)
  p <- add_borders(p, borders)
  p + ggplot2::coord_sf(xlim = ev[c("xmin","xmax")],
                        ylim = ev[c("ymin","ymax")], expand = FALSE) +
    ggplot2::labs(title = title, x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(panel.grid = ggplot2::element_line(color = "grey92",
                                                      linewidth = 0.2))
}
