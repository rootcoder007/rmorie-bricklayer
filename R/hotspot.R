# Hot spots over time: incidents counted in square grid cells for each period, how concentrated
# they are (the law of crime concentration: a small share of places holds half the incidents),
# which cells are hot (the busiest `top` share of the cells that ever had an incident), and how
# much the hot set of one period overlaps the next (Jaccard): a hot spot that persists is a place
# problem, one that moves is not.

#' Hot spots and how long they last
#'
#' Counts incidents (break-ins, shootings, calls for service) in square
#' grid cells for each period, measures how concentrated they are, picks out
#' the hot cells of each period and says how much the hot set of one period
#' overlaps the next. A hot spot that persists is a place problem; one that
#' moves from period to period is not, and the two call for different
#' responses.
#'
#' @details
#' Counts incidents in square cells of side \code{cell} (kilometres
#' for longitude and latitude, map units otherwise) for each
#' period and reports, per period: the incidents, the cells with
#' any, the share of the ever-active cells that holds half the
#' incidents (the law of crime concentration: a small share of places
#' holds half the incidents), the hot cells (the \code{top} share of the
#' ever-active cells with the most incidents, with the cells tied at the cut
#' included unless the tie would more than double the hot set) and
#' their share of the incidents, and the Jaccard
#' overlap of the hot set with the previous period's (shared hot
#' cells over cells hot in either). Per cell: the incidents in
#' all, and in how many periods it was hot.
#'
#' The ever-active cells (a cell with at least one incident in
#' some period) are the base for the shares, so the empty land
#' and water inside a city's bounding box do not dilute the
#' concentration. The number of hot cells per period is
#' \eqn{k = \max(1, \lceil top \times n_{cells} \rceil)}.
#'
#' Longitude and latitude are projected onto a flat map through the median
#' point (equirectangular, Earth radius 6371.0088 km), which is accurate for
#' a city or region; a warning is given when the incidents span more than
#' 2000 km. The grid starts at the smallest projected coordinate. Points at
#' (0, 0), the raw exports' "no location", are dropped with a message, as
#' are incidents with a non-finite coordinate or a missing period; longitudes
#' across the antimeridian are taken on one side of it. When a tie empties a
#' period's hot set, its overlap with the neighbouring periods is \code{NA},
#' not 0. The plot method draws the concentration, the overlap and a map of
#' the cells.
#'
#' Errors: \code{lon}, \code{lat} and \code{period} of different lengths;
#' \code{cell} not one positive number; \code{top} not in (0, 1];
#' coordinates outside the degree ranges with \code{coords = "lonlat"}; fewer
#' than two usable incidents.
#'
#' @param lon,lat Incident coordinates: longitude and latitude
#'   in degrees, or planar coordinates with \code{coords = "planar"}.
#' @param period The period of each incident (a year, a month, a
#'   date, a label such as \code{"Q1"}); periods are taken in sorted order.
#' @param cell Side of a grid cell: kilometres for longitude and
#'   latitude, map units otherwise; one positive number, default 0.25.
#' @param top Share of the ever-active cells counted as hot in
#'   each period, in (0, 1]; default 0.05 (the busiest 5%).
#' @param coords \code{"lonlat"} (the default, degrees) or \code{"planar"}
#'   (projected coordinates, such as metres in a UTM zone).
#' @return An object of class \code{rmbl_hotspot}, a list:
#'   \describe{
#'     \item{\code{periods}}{data frame, one row per period: \code{period}
#'       (character), \code{incidents}, \code{active_cells}, \code{cells_for_half}
#'       (fewest cells holding half the incidents), \code{share_for_half}
#'       (that number over the ever-active cells), \code{hot_cells},
#'       \code{tied_in} (the cells made hot only by a tie with the k-th busiest),
#'       \code{tied_out} (the tied cells left out when the tie would have made
#'       more than twice \code{k} cells hot, which printing says),
#'       \code{hot_share} (share of the incidents in hot cells) and
#'       \code{jaccard_previous} (\code{NA} for the first period). Shares are
#'       proportions in \eqn{[0, 1]}.}
#'     \item{\code{cells}}{data frame, one row per ever-active cell: \code{x}, \code{y}
#'       (its centre in the input's units), \code{incidents} and
#'       \code{periods_hot}.}
#'     \item{\code{cell}, \code{top}, \code{coords}}{the settings.}
#'     \item{\code{n_cells}, \code{hot_k}}{the number of ever-active cells and
#'       \eqn{k}.}
#'   }
#' @examples
#' b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
#'                           package = "rmoriebricklayer"))
#' b <- b[!is.na(b$lon), ]
#' q <- quarters(as.Date(b$occ_date))
#' h <- hotspot_persistence(b$lon, b$lat, q, cell = 0.3)
#' h$periods
#' plot(h)
#'
#' # the cells hot in every quarter
#' subset(h$cells, periods_hot == 4)
#'
#' # larger cells and a wider hot set
#' h2 <- hotspot_persistence(b$lon, b$lat, q, cell = 0.5, top = 0.1)
#' h2$periods[, c("period", "hot_cells", "hot_share", "jaccard_previous")]
#'
#' # planar coordinates, here in kilometres
#' set.seed(3)
#' hotspot_persistence(stats::runif(200, 0, 10), stats::runif(200, 0, 10),
#'                     rep(2023:2024, 100), cell = 2, top = 0.2, coords = "planar")
#'
#' # a share of zero hot cells is refused
#' try(hotspot_persistence(b$lon, b$lat, q, top = 0))
#' @export
hotspot_persistence <- function(lon, lat, period, cell = 0.25, top = 0.05, coords = c("lonlat", "planar")) {
  coords <- .rmbl_arg(coords)
  lon <- .rmbl_num_input(lon, "lon", allow_null = FALSE)
  lat <- .rmbl_num_input(lat, "lat", allow_null = FALSE)
  if (length(lon) != length(lat) || length(period) != length(lon)) {
    stop("`lon`, `lat` and `period` must have the same length", call. = FALSE)
  }
  if (!is.numeric(cell) || length(cell) != 1L || !is.finite(cell) || cell <= 0) {
    stop("`cell` must be a positive number", call. = FALSE)
  }
  if (!is.numeric(top) || length(top) != 1L || !is.finite(top) || top <= 0 || top > 1) {
    stop("`top` must be a share in (0, 1]", call. = FALSE)
  }
  keep <- is.finite(lon) & is.finite(lat) & !is.na(period)
  if (!all(keep)) {
    message(sprintf("hotspot_persistence(): %d incident%s without a usable location or period dropped", sum(!keep),
                    if (sum(!keep) == 1L) "" else "s"))
  }
  if (coords == "lonlat") {
    bad <- keep & (abs(lat) > 90 | abs(lon) > 180)
    if (any(bad)) {
      stop(sprintf("coordinate %d is not a longitude and latitude in degrees; planar data take coords = \"planar\"",
                   which(bad)[1L]), call. = FALSE)
    }
    nowhere <- keep & .jx_null_island(lon, lat)
    if (any(nowhere)) {
      message(sprintf("hotspot_persistence(): %d incident%s at (0, 0), the raw exports' \"no location\", dropped",
                      sum(nowhere), if (sum(nowhere) == 1L) "" else "s"))
    }
    keep <- keep & !nowhere
  }
  lon <- lon[keep]
  lat <- lat[keep]
  period <- period[keep]
  if (length(lon) < 2L) stop("need at least two located incidents with a period", call. = FALSE)
  if (coords == "lonlat") {
    p <- .jx_lonlat_plane(lon, lat, "hotspot_persistence")
    lon0 <- p$lon0
    lat0 <- p$lat0
  } else {
    p <- list(x = lon, y = lat)
  }
  # the origin of the points near the rest (.jx_origin): one at -1e300 put every other in one cell
  x0 <- .jx_origin(p$x, cell)
  y0 <- .jx_origin(p$y, cell)
  ix <- floor((p$x - x0) / cell)
  iy <- floor((p$y - y0) / cell)
  key <- paste(ix, iy)
  ukey <- unique(key)
  cid <- match(key, ukey)
  nc <- length(ukey)
  pf <- factor(period, levels = sort(unique(period)))
  np <- nlevels(pf)
  counts <- matrix(0L, nc, np)
  tab <- table(cid, as.integer(pf))
  counts[as.integer(rownames(tab)), as.integer(colnames(tab))] <- unclass(tab)
  k <- max(1L, ceiling(top * nc))
  hot <- matrix(FALSE, nc, np)
  emptied <- logical(np)
  rows <- vector("list", np)
  for (j in seq_len(np)) {
    cnt <- counts[, j]
    tot <- sum(cnt)
    srt <- sort(cnt, decreasing = TRUE)
    cut <- srt[k]
    # the busiest k cells and every cell tied with the k-th, never a cell with no incident. When the
    # tie would make more than twice k cells hot, the counts do not single those cells out: the
    # tied group is left out (cell = 0.1 had made 100 of 100 cells "hot"; review of e57fed5 and
    # 46de6a9), and tied_out says how many
    above <- cnt > cut
    tied <- cnt == cut & cnt > 0
    tied_out <- 0L
    if (sum(above) + sum(tied) > 2L * k) {
      tied_out <- sum(tied)
      tied <- rep(FALSE, nc)
    }
    h <- above | tied
    hot[, j] <- h
    # a period whose hot set the tie emptied has no hot set to compare: its overlap with the period
    # before and after is unknown, not 0 (statistics stress test of 5e1dce5)
    emptied[j] <- tied_out > 0L && !any(h)
    half <- if (tot > 0) which(cumsum(srt) >= tot / 2)[1L] else NA_integer_
    jac <- NA_real_
    if (j > 1L && !emptied[j] && !emptied[j - 1L]) {
      u <- sum(h | hot[, j - 1L])
      if (u > 0) jac <- sum(h & hot[, j - 1L]) / u
    }
    rows[[j]] <- data.frame(period = levels(pf)[j], incidents = tot, active_cells = sum(cnt > 0),
                            cells_for_half = half, share_for_half = half / nc, hot_cells = sum(h),
                            tied_in = max(0L, sum(h) - k), tied_out = tied_out,
                            hot_share = if (tot > 0) sum(cnt[h]) / tot else NA_real_, jaccard_previous = jac,
                            stringsAsFactors = FALSE)
  }
  centre_x <- x0 + (as.numeric(sub(" .*", "", ukey)) + 0.5) * cell
  centre_y <- y0 + (as.numeric(sub(".* ", "", ukey)) + 0.5) * cell
  if (coords == "lonlat") {
    centre_lon <- lon0 + centre_x / (.jx_earth_km * pi / 180 * cos(lat0 * pi / 180))
    centre_lon <- ((centre_lon + 180) %% 360) - 180
    centre_lat <- lat0 + centre_y / (.jx_earth_km * pi / 180)
  } else {
    centre_lon <- centre_x
    centre_lat <- centre_y
  }
  cells <- data.frame(x = centre_lon, y = centre_lat, incidents = rowSums(counts), periods_hot = rowSums(hot))
  structure(list(periods = do.call(rbind, rows), cells = cells, cell = cell, top = top, coords = coords,
                 n_cells = nc, hot_k = k),
            class = "rmbl_hotspot")
}

#' @export
print.rmbl_hotspot <- function(x, ...) {
  cat(sprintf("Hot spots: %d active cells of side %g %s over %d periods; hot = busiest %d (%g%%)\n", x$n_cells,
              x$cell, if (x$coords == "lonlat") "km" else "units", nrow(x$periods), x$hot_k, 100 * x$top))
  d <- x$periods
  d$share_for_half <- sprintf("%.1f%%", 100 * d$share_for_half)
  d$hot_share <- sprintf("%.1f%%", 100 * d$hot_share)
  d$jaccard_previous <- ifelse(is.na(d$jaccard_previous), "", sprintf("%.2f", d$jaccard_previous))
  print(d, row.names = FALSE)
  chronic <- sum(x$cells$periods_hot >= nrow(x$periods) / 2)
  cat(sprintf("Cells hot in at least half the periods: %d\n", chronic))
  # a tie with the k-th busiest cell that would have made more than twice k cells hot is left out:
  # the counts are too even (or the cells too small) to single out hot spots
  tied <- !is.na(d$tied_out) & d$tied_out > 0
  if (any(tied)) {
    # one "period p: n cells tied" per period: pasting the periods and the counts as two lists read
    # as one list ("in 1, 2, 100, 100 cells tied")
    cat(sprintf(paste("Note: cells tied with the busiest %d were left out of the hot set (%s); the counts",
                      "are too even (or the cells too small) to single out hot spots\n"),
                x$hot_k, paste(sprintf("period %s: %d cells tied", d$period[tied], d$tied_out[tied]),
                               collapse = "; ")))
  }
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_hotspot <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_hotspot")
  d <- x$periods
  op <- .bl_panels_begin(3L)
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  pal <- .bl_cols(2, col, palette)
  xs <- seq_len(nrow(d))
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, 100)), 3, 1)))
  top_y <- max(100 * d$share_for_half, 1, na.rm = TRUE) * 1.15
  graphics::plot(xs, 100 * d$share_for_half, type = "n", ylim = c(0, top_y),
                 xaxt = "n", xlab = "", ylab = "", main = "", ...)
  .bl_grid(NULL)
  .bl_line(xs, 100 * d$share_for_half, pal[1L])
  graphics::axis(1, at = xs, labels = d$period)
  .bl_title("Share of places holding half the incidents")
  .bl_ylab("Percent of active cells")
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, 1)), 3, 1)))
  graphics::plot(xs, d$jaccard_previous, type = "n", ylim = c(0, 1), xaxt = "n", xlab = "", ylab = "", main = "", ...)
  .bl_grid(NULL)
  .bl_line(xs[-1L], d$jaccard_previous[-1L], pal[2L])
  graphics::axis(1, at = xs, labels = d$period)
  .bl_title("Hot spots kept from the period before")
  .bl_ylab("Jaccard overlap")
  cl <- x$cells
  ramp <- grDevices::colorRampPalette(c("#FFF3D6", "#F6B26B", "#D6604D", "#7F1D1D"))(max(1L, max(cl$periods_hot)))
  graphics::par(mar = .bl_safe_mar(c(4.2, 4.5, 3, 1)))
  graphics::plot(cl$x, cl$y, type = "n", asp = if (x$coords == "lonlat") 1 / cos(mean(cl$y) * pi / 180) else 1,
                 xlab = if (x$coords == "lonlat") "Longitude" else "x", ylab = "", main = "", ...)
  .bl_grid(NULL)
  cool <- cl$periods_hot == 0
  graphics::points(cl$x[cool], cl$y[cool], pch = 15, cex = 0.5, col = "#C9CFD8")
  o <- order(cl$periods_hot)
  o <- o[!cool[o]]
  graphics::points(cl$x[o], cl$y[o], pch = 22, cex = 1.3, bg = ramp[cl$periods_hot[o]], col = "white", lwd = 0.6)
  .bl_title(.bl_main(main, "Where the hot spots were"))
  .bl_ylab(if (x$coords == "lonlat") "Latitude" else "y")
  graphics::mtext(sprintf("darker: hot in more of the %d periods", nrow(d)), side = 3, line = 0.15,
                  cex = 0.7 * graphics::par("cex"), col = "#555555")
  .bl_panels_end()
  invisible(d)
}
