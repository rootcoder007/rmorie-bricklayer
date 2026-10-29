# Hot spots over time: incidents counted in square grid cells for each period,
# how concentrated they are (the law of crime concentration: a small share of
# places holds half the incidents), which cells are hot (the busiest `top` share
# of the cells that ever had an incident), and how much the hot set of one
# period overlaps the next (Jaccard): a hot spot that persists is a place
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
#' (0, 0), the raw exports' \dQuote{no location}, are dropped with a message, as
#' are incidents with a non-finite coordinate or a missing period; longitudes
#' across the antimeridian are taken on one side of it. When a tie empties a
#' period's hot set, its overlap with the neighbouring periods is \code{NA},
#' not 0. The plot method draws the concentration, the overlap and a map of
#' the cells.
#'
#' Errors: \code{lon}, \code{lat} and \code{prd} of different lengths;
#' \code{cell} not one positive number; \code{top} not in (0, 1];
#' coordinates outside the degree ranges with \code{coords = "lonlat"}; fewer
#' than two usable incidents.
#'
#' @param lon,lat Incident coordinates: longitude and latitude
#'   in degrees, or planar coordinates with \code{coords = "planar"}.
#' @param prd The period of each incident (a year, a month, a
#'   date, a label such as \code{"Q1"}); periods are taken in sorted order.
#' @param cell Side of a grid cell: kilometres for longitude and
#'   latitude, map units otherwise; one positive number, default 0.25.
#' @param top Share of the ever-active cells counted as hot in
#'   each period, in (0, 1]; default 0.05 (the busiest 5%).
#' @param xy \code{"lonlat"} (the default, degrees) or \code{"planar"}
#'   (projected coordinates, such as metres in a UTM zone).
#' @return An object of class \code{rmbl_hotspot}, a list: \describe{
#'   \item{\code{periods}}{data frame, one row per period: \code{period}
#'   (character), \code{incidents}, \code{actcells}, \code{cellsforhalf} (fewest
#'   cells holding half the incidents), \code{shrforhalf} (that number over the
#'   ever-active cells), \code{hotcells}, \code{tiedin} (the cells made hot only
#'   by a tie with the k-th busiest), \code{tiedout} (the tied cells left out
#'   when the tie would have made more than twice \code{k} cells hot, which
#'   printing says), \code{hotshr} (share of the incidents in hot cells) and
#'   \code{jacpre} (\code{NA} for the first period). Shares are proportions in
#'   \eqn{[0, 1]}.} \item{\code{cells}}{data frame, one row per ever-active
#'   cell: \code{x}, \code{y} (its centre in the input's units),
#'   \code{incidents} and \code{perhot}.} \item{\code{cell}, \code{top},
#'   \code{coords}}{the settings.} \item{\code{ncells}, \code{hotk}}{the number
#'   of ever-active cells and \eqn{k}.} }
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
#'                           package = "rmoriebricklayer"))
#' b <- b[!is.na(b$lon), ]
#' q <- quarters(as.Date(b$occ_date))
#' h <- hotpers(b$lon, b$lat, q, cell = 0.3)
#' h$periods
#' plot(h)
#'
#' # the cells hot in every quarter
#' subset(h$cells, perhot == 4)
#'
#' # larger cells and a wider hot set
#' h2 <- hotpers(b$lon, b$lat, q, cell = 0.5, top = 0.1)
#' h2$periods[, c("period", "hotcells", "hotshr", "jacpre")]
#'
#' # planar coordinates, here in kilometres
#' set.seed(3)
#' hotpers(stats::runif(200, 0, 10), stats::runif(200, 0, 10),
#'                     rep(2023:2024, 100), cell = 2, top = 0.2, xy = "planar")
#'
#' # a share of zero hot cells is refused
#' try(hotpers(b$lon, b$lat, q, top = 0))
#' @export
#' @srrstats {G2.14b} Incidents without a usable location or period are dropped
#'   with a message giving the count.
hotpers <- function(
  lon,
  lat,
  prd,
  cell = 0.25,
  top = 0.05,
  xy = c("lonlat", "planar")
) {
  xy <- .rmbl_arg(xy)
  lon <- .rmbl_num_input(lon, "lon", allow_null = FALSE)
  lat <- .rmbl_num_input(lat, "lat", allow_null = FALSE)
  .hp_check_args(lon, lat, prd, cell, top)
  keep <- .hp_keep(lon, lat, prd, xy)
  lon <- lon[keep]
  lat <- lat[keep]
  prd <- prd[keep]
  if (length(lon) < 2L) {
    stop("need at least two located incidents with a period", call. = FALSE)
  }
  p <- if (xy == "lonlat") {
    .jx_lonlat_plane(lon, lat, "hotpers")
  } else {
    list(x = lon, y = lat)
  }
  g <- .hp_grid(p, prd, cell)
  nc <- g$nc
  counts <- g$counts
  k <- max(1L, ceiling(top * nc))
  ph <- .hp_periods(counts, g$pf, k, nc)
  cen <- .hp_centres(g$ukey, g$x0, g$y0, cell, xy, p)
  cells <- data.frame(
    x = cen$x,
    y = cen$y,
    incidents = rowSums(counts),
    perhot = rowSums(ph$hot)
  )
  structure(
    list(
      periods = do.call(rbind, ph$rows),
      cells = cells,
      cell = cell,
      top = top,
      coords = xy,
      ncells = nc,
      hotk = k
    ),
    class = "rmbl_hotspot"
  )
}

#' @export
format.rmbl_hotspot <- function(x, digits = 4L, ...) {
  d <- .rmbl_plain(x$periods)
  for (k in intersect(c("shrforhalf", "hotshr"), names(d))) {
    d[[k]] <- ifelse(is.na(d[[k]]), "", sprintf("%.1f%%", 100 * d[[k]]))
  }
  np <- nrow(d)
  chronic <- sum(x$cells$perhot >= np / 2)
  tied <- !is.na(d$tiedout) & d$tiedout > 0
  .rmbl_res_block(
    "Hot spots",
    facts = list(
      `Active cells` = x$ncells,
      `Cell side` = paste(x$cell, if (x$coords == "lonlat") "km" else "units"),
      Periods = np,
      `Hot cells` = sprintf("the busiest %d (%g%%)", x$hotk, 100 * x$top),
      `Hot in half the periods` = chronic
    ),
    tables = list(`By period` = d),
    reading = .hp_reading(x$periods, chronic, x$hotk),
    notes = c(
      paste(
        "shrforhalf is the share of active cells that hold half the",
        "incidents, hotshr the share of incidents in the hot cells, and",
        "jacpre the overlap of the hot cells with the period before (1 = the",
        "same cells)."
      ),
      if (any(tied)) {
        paste(
          sprintf("Cells tied with the busiest %d were left out", x$hotk),
          "of the hot set: the counts are too even (or the cells too small)",
          "to single out hot spots."
        )
      },
      if (any(tied)) {
        sprintf("period %s: %d cells tied", d$period[tied], d$tiedout[tied])
      }
    ),
    digits = digits,
    maxrows = 30L
  )
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
  .hp_plot_trends(d, xs, pal, ...)
  .hp_plot_map(x, d, main, ...)
  .bl_panels_end()
  invisible(d)
}

#' plot.rmbl_hotspot()'s first two panels: concentration and overlap by period.
#' @param d The periods table.
#' @param xs The periods' positions.
#' @param pal The two line colours.
#' @param ... Passed to plot() for the concentration and overlap panels.
#' @return NULL, invisibly.
#' @noRd
.hp_plot_trends <- function(d, xs, pal, ...) {
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, 100)), 3, 1)))
  top_y <- max(100 * d$shrforhalf, 1, na.rm = TRUE) * 1.15
  graphics::plot(
    xs,
    100 * d$shrforhalf,
    type = "n",
    ylim = c(0, top_y),
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  .bl_line(xs, 100 * d$shrforhalf, pal[1L])
  graphics::axis(1, at = xs, labels = d$period)
  .bl_title("Share of places holding half the incidents")
  .bl_ylab("Percent of active cells")
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, 1)), 3, 1)))
  graphics::plot(
    xs,
    d$jacpre,
    type = "n",
    ylim = c(0, 1),
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  .bl_line(xs[-1L], d$jacpre[-1L], pal[2L])
  graphics::axis(1, at = xs, labels = d$period)
  .bl_title("Hot spots kept from the period before")
  .bl_ylab("Jaccard overlap")
  invisible(NULL)
}

#' plot.rmbl_hotspot()'s map of the cells, darker where hot more often.
#' @param x The rmbl_hotspot.
#' @param d The periods table.
#' @param main As for plot.rmbl_hotspot().
#' @param ... Passed to plot() for the map of the cells.
#' @return NULL, invisibly.
#' @noRd
.hp_plot_map <- function(x, d, main, ...) {
  cl <- x$cells
  ramp <- grDevices::colorRampPalette(c(
    "#FFF3D6",
    "#F6B26B",
    "#D6604D",
    "#7F1D1D"
  ))(max(1L, max(cl$perhot)))
  graphics::par(mar = .bl_safe_mar(c(4.2, 4.5, 3, 1)))
  graphics::plot(
    cl$x,
    cl$y,
    type = "n",
    asp = if (x$coords == "lonlat") 1 / cos(mean(cl$y) * pi / 180) else 1,
    xlab = if (x$coords == "lonlat") "Longitude" else "x",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  cool <- cl$perhot == 0
  graphics::points(cl$x[cool], cl$y[cool], pch = 15, cex = 0.5, col = "#C9CFD8")
  o <- order(cl$perhot)
  o <- o[!cool[o]]
  graphics::points(
    cl$x[o],
    cl$y[o],
    pch = 22,
    cex = 1.3,
    bg = ramp[cl$perhot[o]],
    col = "white",
    lwd = 0.6
  )
  .bl_title(.bl_main(main, "Where the hot spots were"))
  .bl_ylab(if (x$coords == "lonlat") "Latitude" else "y")
  graphics::mtext(
    sprintf("darker: hot in more of the %d periods", nrow(d)),
    side = 3,
    line = 0.15,
    cex = 0.7 * graphics::par("cex"),
    col = "#555555"
  )
  invisible(NULL)
}

#' hotpers()'s incidents counted in grid cells by period.
#' @param p The incidents' planar coordinates (a list: x and y).
#' @param prd,cell As for hotpers().
#' @return A list: x0, y0, ukey, nc, pf and counts (cells x periods).
#' @noRd
.hp_grid <- function(p, prd, cell) {
  # the origin of the points near the rest (.jx_origin): one at -1e300 put every
  # other in one cell
  x0 <- .jx_origin(p$x, cell)
  y0 <- .jx_origin(p$y, cell)
  ix <- floor((p$x - x0) / cell)
  iy <- floor((p$y - y0) / cell)
  key <- paste(ix, iy)
  ukey <- unique(key)
  cid <- match(key, ukey)
  nc <- length(ukey)
  pf <- factor(prd, levels = sort(unique(prd)))
  np <- nlevels(pf)
  counts <- matrix(0L, nc, np)
  tab <- table(cid, as.integer(pf))
  counts[as.integer(rownames(tab)), as.integer(colnames(tab))] <- unclass(tab)
  list(x0 = x0, y0 = y0, ukey = ukey, nc = nc, pf = pf, counts = counts)
}

#' hotpers()'s hot cells and summary row for each period.
#' @param counts The cells x periods counts.
#' @param pf The periods as a factor.
#' @param k The number of hot cells.
#' @param nc The number of cells.
#' @return A list: hot (cells x periods) and rows (one data frame a period).
#' @noRd
.hp_periods <- function(counts, pf, k, nc) {
  np <- nlevels(pf)
  hot <- matrix(FALSE, nc, np)
  emptied <- logical(np)
  rows <- vector("list", np)
  for (j in seq_len(np)) {
    pj <- .hp_period(counts[, j], k, nc)
    hot[, j] <- pj$hot
    emptied[j] <- pj$emptied
    jac <- NA_real_
    if (j > 1L && !emptied[j] && !emptied[j - 1L]) {
      u <- sum(pj$hot | hot[, j - 1L])
      if (u > 0) jac <- sum(pj$hot & hot[, j - 1L]) / u
    }
    rows[[j]] <- data.frame(
      period = levels(pf)[j],
      pj$row,
      jacpre = jac,
      stringsAsFactors = FALSE
    )
  }
  list(hot = hot, rows = rows)
}

#' hotpers()'s lengths, cell size and share, checked.
#' @param lon,lat,prd,cell,top As for hotpers().
#' @noRd
.hp_check_args <- function(lon, lat, prd, cell, top) {
  if (length(lon) != length(lat) || length(prd) != length(lon)) {
    stop("`lon`, `lat` and `prd` must have the same length", call. = FALSE)
  }
  if (
    !is.numeric(cell) || length(cell) != 1L || !is.finite(cell) ||
      cell <= 0 || cell > 360
  ) {
    stop("`cell` must be a positive number", call. = FALSE)
  }
  if (
    !is.numeric(top) ||
      length(top) != 1L ||
      !is.finite(top) ||
      top <= 0 ||
      top > 1
  ) {
    stop("`top` must be a share in (0, 1]", call. = FALSE)
  }
  invisible(NULL)
}

#' The incidents hotpers() keeps: a location and a period, and for longitude
#' and latitude, degrees and not (0, 0).
#' @param lon,lat,prd,xy As for hotpers().
#' @return A logical vector.
#' @noRd
.hp_keep <- function(lon, lat, prd, xy) {
  keep <- is.finite(lon) & is.finite(lat) & !is.na(prd)
  if (!all(keep)) {
    message(sprintf(
      "hotpers(): %d incident%s without a usable location or period dropped",
      sum(!keep),
      if (sum(!keep) == 1L) "" else "s"
    ))
  }
  if (xy != "lonlat") {
    return(keep)
  }
  bad <- keep & (abs(lat) > 90 | abs(lon) > 180)
  if (any(bad)) {
    stop(
      sprintf(
        paste0(
          "coordinate %d is not a longitude and latitude in degrees; ",
          "planar data take coords = \"planar\""
        ),
        which(bad)[1L]
      ),
      call. = FALSE
    )
  }
  nowhere <- keep & .jx_null_island(lon, lat)
  if (any(nowhere)) {
    message(sprintf(
      paste0(
        "hotpers(): %d incident%s at (0, 0), the raw exports' \"no ",
        "location\", dropped"
      ),
      sum(nowhere),
      if (sum(nowhere) == 1L) "" else "s"
    ))
  }
  keep & !nowhere
}

#' One period's hot cells.
#'
#' The busiest k cells and every cell tied with the k-th, never a cell with no
#' incident. When the tie would make more than twice k cells hot, the counts do
#' not single those cells out: the tied group is left out (cell = 0.1 had made
#' 100 of 100 cells "hot"; review of e57fed5 and 46de6a9), and tiedout says how
#' many. A period whose hot set the tie emptied has no hot set to compare: its
#' overlap with the period before and after is unknown, not 0 (statistics
#' stress test of 5e1dce5).
#' @param cnt The period's count in each cell.
#' @param k The number of hot cells asked for.
#' @param nc The number of cells.
#' @return A list: hot (the cells), emptied, and row (the period's summary,
#'   without its name and overlap).
#' @noRd
.hp_period <- function(cnt, k, nc) {
  tot <- sum(cnt)
  srt <- sort(cnt, decreasing = TRUE)
  cut <- srt[k]
  above <- cnt > cut
  tied <- cnt == cut & cnt > 0
  tied_out <- 0L
  if (sum(above) + sum(tied) > 2L * k) {
    tied_out <- sum(tied)
    tied <- rep(FALSE, nc)
  }
  h <- above | tied
  half <- if (tot > 0) which(cumsum(srt) >= tot / 2)[1L] else NA_integer_
  list(
    hot = h,
    emptied = tied_out > 0L && !any(h),
    row = data.frame(
      incidents = tot,
      actcells = sum(cnt > 0),
      cellsforhalf = half,
      shrforhalf = half / nc,
      hotcells = sum(h),
      tiedin = max(0L, sum(h) - k),
      tiedout = tied_out,
      hotshr = if (tot > 0) sum(cnt[h]) / tot else NA_real_,
      stringsAsFactors = FALSE
    )
  )
}

#' The cells' centres, in longitude and latitude when the points were.
#' @param ukey The cells' keys ("ix iy").
#' @param x0,y0 The grid's origin.
#' @param cell The cell size.
#' @param xy As for hotpers().
#' @param p The projected points (with lon0 and lat0 for longitude and
#'   latitude).
#' @return A list: x and y.
#' @noRd
.hp_centres <- function(ukey, x0, y0, cell, xy, p) {
  centre_x <- x0 + (as.numeric(sub(" .*", "", ukey)) + 0.5) * cell
  centre_y <- y0 + (as.numeric(sub(".* ", "", ukey)) + 0.5) * cell
  if (xy != "lonlat") {
    return(list(x = centre_x, y = centre_y))
  }
  centre_lon <- p$lon0 +
    centre_x / (.jx_earth_km * pi / 180 * cos(p$lat0 * pi / 180))
  centre_lon <- ((centre_lon + 180) %% 360) - 180
  list(x = centre_lon, y = p$lat0 + centre_y / (.jx_earth_km * pi / 180))
}
