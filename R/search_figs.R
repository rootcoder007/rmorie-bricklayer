# SPDX-License-Identifier: AGPL-3.0-or-later
# The figures of Frost (1996), "The Theory of Search: A Simplified Explanation", drawn from the
# search theory family of R/search.R with the book's parameters, and the optimal search square for
# a circular normal datum that chapter 6 computes by successive trials.

#' Unnormalised probability inside a centred square after earlier square searches.
#'
#' For a circular normal datum (standard deviation 1) every centred square search changes the
#' density only by the Chebyshev radius max(|x|, |y|), so the mass inside a square of half side `h`
#' is a sum over the shells between earlier half sides, each scaled by the chance of having been
#' missed by every earlier search that covered it.
#' @param h Half sides, in standard deviations.
#' @param a The half sides of the earlier searches.
#' @param pd Their PODs.
#' @return For each `h`, the probability that the object is inside the square and was not found before.
#' @noRd
.sr_sq_mass <- function(h, a, pd) {
  big <- function(r) (2 * stats::pnorm(r) - 1)^2
  lo <- sort(unique(c(0, a)))
  hi <- c(lo[-1L], Inf)
  miss <- vapply(hi, function(r) prod(1 - pd[a >= r]), 0)
  drop((big(outer(h, hi, pmin)) - big(outer(h, lo, pmin))) %*% miss)
}

#' The search factor that maximises a function, by a grid then optimize().
#' @param fun The function of the factor.
#' @return The maximising factor.
#' @noRd
.sr_argmax <- function(fun) {
  fs <- exp(seq(log(0.02), log(10), length.out = 241))
  i <- which.max(fun(fs))
  stats::optimize(fun, c(fs[max(1L, i - 1L)], fs[min(241L, i + 1L)]), maximum = TRUE, tol = 1e-10)$maximum
}

#' The optimal search square for a circular normal datum
#'
#' For a point datum with a circular normal distribution of position error,
#' the square centred on the datum that a given effort, spread evenly, should
#' cover to make the probability of success as large as possible (Frost 1996,
#' chapter 6). With several efforts, each search is optimised in turn against
#' the distribution as earlier unsuccessful searches left it.
#'
#' @details The search factor \code{f} is the half side of the square in units
#' of the total probable error of position \code{E} (the radius of the circle
#' holding half the distribution, \code{E = 1.1774 sigma}). For relative effort
#' \code{z = Z / E^2} the coverage is \code{C = z / (2 f)^2}, the containment
#' is the circular normal's mass in the square, \code{(2 Phi(f E / sigma) - 1)^2}
#' for a first search, and the probability of success \code{POC x POD(C)} with
#' the POD curve of \code{model} (\code{\link{srchpod}}). The factor is found
#' on a grid of 241 values from 0.02 to 10 and refined by \code{optimize()}.
#' After a search the density inside its square is multiplied by
#' \code{1 - POD}; every later search is optimised against what is left, and
#' its \code{poc} and \code{pos} are conditional on the earlier searches having
#' failed. Frost's figures 6-3 to 6-6 are drawn from it by \code{\link{srchfig}}.
#'
#' @param effort Positive numeric vector: the effort (sweep width times track
#'   length) of each search in turn, in the square of the units of \code{E}.
#' @param model \code{"invcube"} (the default; Frost's ideal search
#'   conditions), \code{"random"} (poor conditions), \code{"definite"} or
#'   \code{"mbeta"}.
#' @param m Number in (0, 1]: the M-Beta height. Default 1.
#' @param E Positive number: the total probable error of position. Default 1.
#' @return A data frame with one row per search: \code{search}, \code{effort},
#'   \code{releff} (effort over \code{E^2}), \code{cumeff} (cumulative relative
#'   effort), \code{factor}, \code{side} (\code{2 f E}), \code{poc},
#'   \code{coverage}, \code{pod}, \code{pos} and \code{cumpos} (the probability
#'   that one of the searches so far succeeded).
#' @references Frost, J. R. (1996). The Theory of Search: A Simplified
#'   Explanation. Soza and Company and U.S. Coast Guard Office of Search and
#'   Rescue. Chapter 6.
#'
#'   Koopman, B. O. (1957). The theory of search. III. The optimum
#'   distribution of searching effort. Operations Research 5(5), 613-626.
#'   \doi{10.1287/opre.5.5.613}
#' @srrstats {G1.0} Frost (1996, chapter 6) and Koopman (1957) are cited in @references.
#' @srrstats {G1.3} @details defines the search factor, relative effort, coverage and the containment of a square.
#' @srrstats {G2.0} `m` and `E` must be single numbers, `effort` a vector of at least one positive value.
#' @srrstats {G5.4a} test-search-figs.R checks Frost's stated optima: 4 E^2 gives a factor of 1.02 and POS
#'   0.4578, 2 E^2 gives 0.81 and 0.2875, 8 E^2 gives 1.29 and 0.6588.
#' @examples
#' # Frost's example: an effort of 4 E^2 on a point datum
#' optsqr(4)
#' # poor search conditions: the random search curve
#' optsqr(4, model = "random")
#' # three searches in a row, each optimal for what the last ones left
#' optsqr(c(4, 4, 8), E = 2)
#' try(optsqr(-1))
#' @export
optsqr <- function(effort, model = c("invcube", "random", "definite", "mbeta"), m = 1, E = 1) {
  model <- .rmbl_arg(model)
  effort <- as.vector(.sr_num(effort, "effort", scalar = FALSE, positive = TRUE))
  m <- .sr_num(m, "m", positive = TRUE, min = 0, max = 1)
  E <- .sr_num(E, "E", positive = TRUE)
  z <- effort / E^2
  e0 <- sqrt(2 * log(2))
  a <- pd <- numeric()
  left <- 1
  rows <- vector("list", length(z))
  for (k in seq_along(z)) {
    fn <- function(f) .sr_sq_mass(f * e0, a, pd) * .sr_pod(z[k] / (4 * f^2), model, m)
    f <- .sr_argmax(fn)
    mass <- .sr_sq_mass(f * e0, a, pd)
    cv <- z[k] / (4 * f^2)
    pod <- .sr_pod(cv, model, m)
    rows[[k]] <- data.frame(search = k, effort = effort[k], releff = z[k], cumeff = sum(z[seq_len(k)]),
                            factor = f, side = 2 * f * E, poc = mass / left, coverage = cv, pod = pod,
                            pos = mass * pod / left, cumpos = 1 - (left - mass * pod))
    left <- left - mass * pod
    a <- c(a, f * e0)
    pd <- c(pd, pod)
  }
  do.call(rbind, rows)
}

# ---- the figures ---------------------------------------------------------------------------------

#' The book's figures: id, caption, how each is drawn, and the drawing function's name.
#' @return A data frame.
#' @noRd
.sr_fig_table <- function() {
  f <- function(fig, caption, how) data.frame(fig = fig, caption = caption, how = how)
  rbind(
    f("3-1", "Probability density distribution for a point datum with top view", "model"),
    f("3-2", "Circle of radius one standard deviation and its circumscribed square", "model"),
    f("3-3", "Circle of radius E and its circumscribed square", "model"),
    f("3-4", "Probability map for a point datum", "model"),
    f("3-5", "Circle of radius 1.1 E and its circumscribed square", "model"),
    f("3-6", "Line datum: circles at the end points boxed in", "schematic"),
    f("3-7", "Probability density distribution for a line datum connecting two point datums", "approximation"),
    f("3-8", "Probability density distribution for a line datum with top view", "model"),
    f("3-9", "Strip of width 2 E centred on the datum line", "model"),
    f("3-10", "Example of a completed probability map for a line datum", "model"),
    f("3-11", "Uniform probability density distribution with top view", "model"),
    f("3-12", "Probability map for an area datum", "model"),
    f("3-13", "Generalized probability density distribution with top view", "approximation"),
    f("3-14", "Probability map for a generalized datum", "model"),
    f("4-1", "Lateral range curves: definite range, M-Beta, inverse cube and another sensor", "model"),
    f("4-2", "Definite range lateral range curve", "model"),
    f("4-3", "The area swept by a definite range sensor", "schematic"),
    f("4-4", "M-Beta lateral range curve, M = 0.5", "model"),
    f("4-5", "M-Beta lateral range curve, M = 0.25", "model"),
    f("4-6", "The geometry of the inverse cube law", "schematic"),
    f("4-7", "Inverse cube lateral range curve and its sweep width", "model"),
    f("5-1", "Random search", "model"),
    f("5-2", "Parallel sweep search", "schematic"),
    f("5-3", "Definite range curves of two tracks 2 W apart", "model"),
    f("5-4", "Definite range curves of two tracks W apart", "model"),
    f("5-5", "Definite range and random search", "model"),
    f("5-6", "M-Beta (M = 0.5) curves of two tracks 2 W apart", "model"),
    f("5-7", "M-Beta (M = 0.25 and M = 0.5)", "model"),
    f("5-8", "Inverse cube", "model"),
    f("5-9", "Inverse cube curve under a smaller sweep width and navigation error", "approximation"),
    f("6-1", "A simple non-uniform distribution", "model"),
    f("6-2", "The trial search square of half the area", "model"),
    f("6-3", "Optimal search factors for point datums (effort to 18)", "model"),
    f("6-4", "Optimal search factors for point datums (effort to 100)", "model"),
    f("6-5", "Cumulative probability of success for optimal searches", "model"),
    f("6-6", "Optimal search factors for 1-5 sequential searches with random relative efforts", "approximation")
  )
}

#' The figures of The Theory of Search
#'
#' Draws any figure of Frost (1996), "The Theory of Search: A Simplified
#' Explanation", from the package's search theory functions with the book's
#' parameters, and returns the numbers it drew.
#'
#' @details \code{srchfig()} with no argument lists the book's 36 figures
#' (3-1 to 3-14, 4-1 to 4-7, 5-1 to 5-9 and 6-1 to 6-6) with how each is
#' drawn: \code{"model"} figures are computed from the functions with the
#' book's parameters and reproduce the values the text states (for example
#' 57.91, 9.08 and 1.42 percent in figure 3-4,
#' 0.75 and 0.6836 in figure 5-7, 0.7899 at coverage 1 in figure 5-8, the
#' optimal factor 1.02 at an effort of 4 E^2 in figure 6-3);
#' \code{"schematic"} figures are diagrams with no data (3-6, 4-3, 4-6, 5-2);
#' \code{"approximation"} figures are drawn from the model where the book's
#' plate cannot be recovered exactly: 3-7 (the density implied by boxing in two
#' circles is drawn as the \code{"line"} datum, a circular normal spread along
#' the segment), 3-13 (the book's surface is illustrative; it is drawn from the
#' cells of figure 3-14), 5-9 (the plate is blank in the published file; it is
#' drawn from the text, an inverse cube curve with a smaller sweep width and
#' flattened by navigation error), 6-6 (the book's random efforts are not
#' given; 250 groups of 5 are drawn here with \code{seed}).
#'
#' Distances are in standard deviations of position error (\code{E = 1.1774}),
#' or in sweep widths (\code{W = 1}) for the lateral range figures. The
#' general methods draw the same figures with other parameters:
#' \code{plot(ltrlrng(...), equiv = , spacing = )},
#' \code{plot(srchpod(...), models = , m = )},
#' \code{plot(datumpmap(...), view = )}.
#' @param fig A figure number as text, \code{"5-7"}, or the chapter as a
#'   number with \code{num}; \code{NULL} (the default) lists the figures.
#' @param num The figure's number within chapter \code{fig}, or \code{NULL}.
#' @param seed Number: the seed of figure 6-6's random efforts. Default 1;
#'   the session's random number stream is left as it was.
#' @param main The title, or \code{NULL} for the book's caption.
#' @return Without \code{fig}, a data frame of \code{fig}, \code{caption} and
#'   \code{how}. With one, the figure's data, invisibly: a data frame (or a
#'   list of them) of what was drawn.
#' @references Frost, J. R. (1996). The Theory of Search: A Simplified
#'   Explanation. Soza and Company and U.S. Coast Guard Office of Search and
#'   Rescue. Chapters 3-6.
#' @srrstats {G1.0} Frost (1996) is cited in @references with the chapters the figures come from.
#' @srrstats {G2.3a} `fig` is matched against the book's figure numbers, which the refusal lists.
#' @srrstats {EA5.0} The figures use the package's plot style (.bl_par, .bl_grid, .bl_title) and palettes.
#' @srrstats {EA6.1} test-search-figs.R draws every figure to pdf(NULL) and checks the data each returns.
#' @examples
#' head(srchfig())
#' srchfig("3-4")
#' srchfig(5, 8)
#' d <- srchfig("6-3")
#' head(d)
#' try(srchfig("9-9"))
#' @export
srchfig <- function(fig = NULL, num = NULL, seed = 1, main = NULL) {
  tab <- .sr_fig_table()
  if (is.null(fig)) return(tab)
  if (!is.null(num)) fig <- paste0(.sr_num(fig, "fig", whole = TRUE), "-", .sr_num(num, "num", whole = TRUE))
  fig <- .rmbl_string1(fig, "fig")
  if (!fig %in% tab$fig) {
    .sr_stop("`fig` must be one of the book's figures, %s; got \"%s\"", paste(tab$fig, collapse = ", "), fig)
  }
  seed <- .sr_num(seed, "seed", whole = TRUE)
  ttl <- .bl_main(main, sprintf("Figure %s. %s", fig, tab$caption[tab$fig == fig]))
  ch <- substr(fig, 1L, 1L)
  if (ch == "3") return(invisible(.sr_fig3(fig, ttl)))
  if (ch == "4") return(invisible(.sr_fig4(fig, ttl)))
  if (ch == "5") return(invisible(.sr_fig5(fig, ttl)))
  invisible(.sr_fig6(fig, ttl, seed))
}

#' The total probable error of position in standard deviations.
#' @return sqrt(2 log 2).
#' @noRd
.sr_E <- function() sqrt(2 * log(2))

#' Draws a circle of radius R (standard deviations) and its circumscribed square, with their POCs.
#' @param R The radius.
#' @param lab The radius as the book writes it.
#' @param ttl The title.
#' @return A data frame: shape and poc.
#' @noRd
.sr_fig_circsq <- function(R, lab, ttl) {
  op <- .bl_par()
  on.exit(graphics::par(op), add = TRUE)
  poc <- c(circle = 1 - exp(-R^2 / 2), square = (2 * stats::pnorm(R) - 1)^2)
  graphics::plot(c(-R, 2.6 * R), c(-R, R), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = "")
  graphics::rect(-R, -R, R, R, border = "#1F2430", lwd = 1.5)
  a <- seq(0, 2 * pi, length.out = 241)
  graphics::lines(R * cos(a), R * sin(a), col = "#1F2430", lwd = 1.5)
  graphics::points(0, 0, pch = 13, cex = 1.6)
  graphics::arrows(0, 0, R * cos(pi / 4), -R * sin(pi / 4), length = 0.08)
  graphics::text(R * 0.45, -R * 0.2, lab, cex = 0.9)
  graphics::text(c(-R, R), -R, c(paste0("-", lab), paste0("+", lab)), pos = 1, cex = 0.8, xpd = NA)
  graphics::text(1.25 * R, c(0.6, 0.25) * R, sprintf("%s POC = %.0f%%", c("Square:", "Circle:"),
                                                     100 * poc[c("square", "circle")]), pos = 4, cex = 0.9)
  .bl_title(ttl)
  data.frame(shape = names(poc), poc = unname(poc))
}

#' Chapter 3: datums and probability maps.
#' @param fig The figure.
#' @param ttl The title.
#' @return The figure's data.
#' @noRd
.sr_fig3 <- function(fig, ttl) {
  E <- .sr_E()
  g <- seq(-3.5, 3.5, length.out = 57)
  w314 <- rbind(c(4, 3, 4, 2, 1), c(5, 10, 6, 5, 2), c(2, 8, 15, 10, 3), c(3, 4, 5, 6, 2))
  both <- function(m) plot(m, view = "both", main = ttl)
  switch(fig,
    "3-1" = both(datumpmap(g, g)),
    "3-2" = .sr_fig_circsq(1, "\u03c3", ttl),
    "3-3" = .sr_fig_circsq(E, "E", ttl),
    "3-5" = .sr_fig_circsq(1.1 * E, "1.1E", ttl),
    "3-4" = {
      m <- datumpmap(c(-3, -1, 1, 3) * E, c(-3, -1, 1, 3) * E)
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      .sr_draw_cells(m, 2, shade = c(2, 3), circle = c(0, 0, E))
      .bl_title(ttl)
      m
    },
    "3-6" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      r <- 1.1 * E
      graphics::plot(c(-r, 6 + r), c(-r, r), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = "")
      a <- seq(0, 2 * pi, length.out = 241)
      for (cx in c(0, 6)) graphics::lines(cx + r * cos(a), r * sin(a))
      graphics::segments(c(0, 0), c(-r, r), c(6, 6), c(-r, r), lwd = 1.5)
      graphics::segments(0, 0, 6, 0, lty = 2)
      graphics::text(c(0, 6), 0.45 * r, c("E1", "E2"), cex = 0.9)
      .bl_title(ttl)
      data.frame(x = c(0, 6), y = 0, radius = r)
    },
    "3-7" = both(datumpmap(g, seq(-5, 5, length.out = 57), "line", c(0, -2), end = c(0, 2))),
    "3-8" = both(datumpmap(g, seq(-5, 5, length.out = 57), "corridor", c(0, -2), end = c(0, 2))),
    "3-9" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      poc <- 2 * stats::pnorm(E) - 1
      graphics::plot(c(-4, 4), c(-2.5, 2.5), type = "n", axes = FALSE, xlab = "", ylab = "", main = "")
      graphics::rect(-3, -E, 3, E, col = grDevices::adjustcolor("#56B4E9", 0.3), border = "#1F2430")
      graphics::segments(-3.5, 0, 3.5, 0, lwd = 2, col = "#D55E00")
      graphics::arrows(-3.3, 0, -3.3, c(E, -E), length = 0.06)
      graphics::text(-3.3, c(E, -E) / 2, "E", pos = 2)
      graphics::text(0, E + 0.4, sprintf("POC = %.1f%%", 100 * poc))
      .bl_title(ttl)
      data.frame(halfwidth = E, poc = poc)
    },
    "3-10" = {
      m <- datumpmap(0:10, c(-2.5, -1.5, -0.5, 0.5, 1.5, 2.5) * 1.2 * E, "corridor", c(0, 0), end = c(10, 0))
      plot(m, view = "cells", digits = 1, main = ttl)
      m
    },
    "3-11" = both(datumpmap(g, g, "area", c(-2, -1.5), end = c(2, 1.5))),
    "3-12" = {
      m <- datumpmap(0:5, 0:4, "area", c(0, 0), end = c(5, 4))
      plot(m, view = "cells", digits = 0, main = ttl)
      m
    },
    "3-13" = {
      fine <- w314[rep(1:4, each = 10), rep(1:5, each = 10)]
      both(datumpmap(seq(0, 5, length.out = 51), seq(0, 4, length.out = 41), "general", wts = fine))
    },
    "3-14" = {
      m <- datumpmap(0:5, 0:4, "general", wts = w314)
      plot(m, view = "cells", digits = 0, main = ttl)
      m
    }
  )
}

#' Chapter 4: lateral range curves and sweep width.
#' @param fig The figure.
#' @param ttl The title.
#' @return The figure's data.
#' @noRd
.sr_fig4 <- function(fig, ttl) {
  lr <- function(model, m = 1, equiv = FALSE) plot(ltrlrng(0, 1, model, m), equiv = equiv, main = ttl)
  switch(fig,
    "4-2" = lr("definite"),
    "4-4" = lr("mbeta", 0.5, TRUE),
    "4-5" = lr("mbeta", 0.25, TRUE),
    "4-7" = lr("invcube", equiv = TRUE),
    "4-1" = {
      op <- .bl_panels_begin(4L)
      on.exit(graphics::par(op), add = TRUE)
      on.exit(.bl_panels_abort(), add = TRUE)
      xs <- seq(-2, 2, length.out = 401)
      cols <- .bl_cols(3)
      # D: a sensor that sees poorly straight below (illustrative), scaled to sweep width 1
      dd <- function(x) {
        pmin(1, pmax(0, 0.85 * (exp(-((x - 0.45) / 0.35)^2) + exp(-((x + 0.45) / 0.35)^2)) - 0.25 * exp(-(x / 0.2)^2)))
      }
      sc <- 1 / sum(diff(xs) * (dd(xs[-1]) + dd(xs[-401])) / 2)
      out <- list()
      for (k in 1:4) {
        graphics::par(mar = .bl_safe_mar(c(3.2, 3.6, 2.4, 0.8)))
        graphics::plot(c(-2, 2), c(0, 1.05), type = "n", xlab = "", ylab = "", main = "")
        .bl_grid(NULL)
        if (k < 4L) {
          md <- c("definite", "mbeta", "invcube")[k]
          out[[k]] <- .sr_draw_lr(xs, 1, md, 0.5, 0, cols, equiv = FALSE)
          graphics::rect(-0.5, 0, 0.5, 1, border = "#3D4350", lty = 2)
          .bl_title(c("A: definite range", "B: M-Beta", "C: inverse cube")[k])
        } else {
          p <- pmin(1, dd(xs) * sc)
          .bl_line(xs, p, cols[1L], label = FALSE, points = FALSE)
          graphics::rect(-0.5, 0, 0.5, 1, border = "#3D4350", lty = 2)
          .bl_title("D: another sensor")
          out[[k]] <- data.frame(x = xs, p = p)
        }
      }
      .bl_panels_end()
      out
    },
    "4-3" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      graphics::plot(c(0, 10), c(-2, 2), type = "n", axes = FALSE, xlab = "", ylab = "", main = "")
      graphics::rect(0.5, -0.5, 9.5, 0.5, col = grDevices::adjustcolor("#56B4E9", 0.3), border = "#1F2430")
      graphics::arrows(0.5, 0, 9.8, 0, length = 0.1, lwd = 2, col = "#D55E00")
      graphics::arrows(0.2, -0.5, 0.2, 0.5, length = 0.06, code = 3)
      graphics::text(0.2, 0, "W", pos = 2)
      .bl_title(ttl)
      data.frame(width = 1)
    },
    "4-6" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      graphics::plot(c(-0.5, 11), c(-0.5, 4.5), type = "n", axes = FALSE, xlab = "", ylab = "", main = "")
      h <- 4
      r <- 8
      a <- 2
      graphics::segments(0, 0, r + a, 0)
      graphics::segments(0, 0, 0, h)
      graphics::segments(0, h, c(r, r + a), 0)
      graphics::text(c(0, -0.3, r / 2, r / 2, r + a / 2), c(h + 0.3, h / 2, -0.35, h / 2 + 0.4, -0.35),
                     c("O", "h", "r", "s", "a"), font = 2)
      graphics::text(r - 0.6, 0.45, "\u03b1")
      .bl_title(ttl)
      data.frame(h = h, r = r, a = a, solid = a * h / (h^2 + r^2)^1.5)
    }
  )
}

#' Chapter 5: effort, coverage and POD.
#' @param fig The figure.
#' @param ttl The title.
#' @return The figure's data.
#' @noRd
.sr_fig5 <- function(fig, ttl) {
  pod <- function(models, m = NULL) {
    plot(srchpod(1, models[1L], m = (m %||% 1)[1L]), models = models, m = m, cmax = 2, main = ttl)
  }
  sp <- function(model, m, S) plot(ltrlrng(0, 1, model, m), spacing = S, main = ttl)
  switch(fig,
    "5-1" = pod("random"),
    "5-5" = pod(c("definite", "random")),
    "5-7" = pod(c("mbeta", "definite", "random"), c(0.5, 0.25)),
    "5-8" = pod(c("invcube", "definite", "random")),
    "5-3" = sp("definite", 1, 2),
    "5-4" = sp("definite", 1, 1),
    "5-6" = sp("mbeta", 0.5, 2),
    "5-2" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      graphics::plot(c(0, 10), c(0, 6), type = "n", axes = FALSE, xlab = "", ylab = "", main = "", asp = 1)
      graphics::rect(0, 0, 10, 6, lty = 2)
      ys <- seq(0.5, 5.5, by = 1)
      xx <- c(rbind(ifelse(seq_along(ys) %% 2 == 1, 0.5, 9.5), ifelse(seq_along(ys) %% 2 == 1, 9.5, 0.5)))
      graphics::lines(xx, rep(ys, each = 2), lwd = 2, col = "#0072B2")
      graphics::arrows(xx[length(xx) - 1L], ys[length(ys)], xx[length(xx)], ys[length(ys)], length = 0.1, lwd = 2,
                       col = "#0072B2")
      graphics::arrows(10.3, ys[1], 10.3, ys[2], length = 0.05, code = 3)
      graphics::text(10.3, mean(ys[1:2]), "S", pos = 4, xpd = NA)
      .bl_title(ttl)
      data.frame(x = xx, y = rep(ys, each = 2))
    },
    "5-9" = {
      cols <- .bl_cols(4)
      xs <- seq(-2.5, 2.5, length.out = 501)
      cur <- list(c(1, 0), c(0.6, 0), c(0.6, 0.3), c(0.6, 0.6))
      d <- do.call(rbind, lapply(cur, function(v) {
        data.frame(W = v[1], navsd = v[2], x = xs, p = .sr_lr_nav(xs, v[1], "invcube", 1, v[2]))
      }))
      op <- .bl_par(c(0, 1))
      on.exit(graphics::par(op), add = TRUE)
      graphics::plot(range(xs), c(0, 1.05), type = "n", xlab = "", ylab = "", main = "")
      .bl_grid(NULL)
      for (k in seq_along(cur)) {
        s <- d[d$W == cur[[k]][1] & d$navsd == cur[[k]][2], ]
        graphics::lines(s$x, s$p, col = cols[k], lwd = 2.2, lty = k)
      }
      graphics::legend("topright", legend = c("ideal, W = 1", "poorer conditions, W = 0.6",
                                              "W = 0.6, navigation error 0.3", "W = 0.6, navigation error 0.6"),
                       col = cols, lty = 1:4, lwd = 2.2, bty = "n", cex = 0.75)
      .bl_ylab("Probability of detection")
      .bl_xlab("Lateral range (in ideal sweep widths)")
      .bl_title(ttl)
      d
    }
  )
}

#' Chapter 6: optimal search.
#' @param fig The figure.
#' @param ttl The title.
#' @param seed The seed of figure 6-6.
#' @return The figure's data.
#' @noRd
.sr_fig6 <- function(fig, ttl, seed) {
  op <- .bl_par()
  on.exit(graphics::par(op), add = TRUE)
  cols <- .bl_cols(2)
  curve <- function(zs, model) {
    do.call(rbind, lapply(zs, function(z) cbind(model = model, optsqr(z, model))))
  }
  if (fig %in% c("6-1", "6-2")) {
    side <- sqrt(12.5)
    trials <- data.frame(side = c(5, side, sqrt(25 / 3)), area = c(25, 12.5, 25 / 3))
    trials$poc <- with(trials, pmin(area, 9) * 0.5 / 9 + pmax(area - 9, 0) * 0.5 / 16)
    graphics::plot(c(-2.6, 2.6), c(-2.6, 2.6), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = "")
    if (fig == "6-2") {
      graphics::rect(-side / 2, -side / 2, side / 2, side / 2, col = "#D9D9D9", border = "#1F2430", lty = 2)
      graphics::text(-1.6, 2.1, sprintf("%.2f%%", 100 * (trials$poc[2] - 0.5)), font = 2)
    }
    graphics::rect(-2.5, -2.5, 2.5, 2.5)
    graphics::rect(-1.5, -1.5, 1.5, 1.5, col = "white")
    graphics::text(0, 0, "50%", font = 2)
    if (fig == "6-1") graphics::text(0, 2, "50%", font = 2)
    .bl_title(ttl)
    return(trials)
  }
  if (fig %in% c("6-3", "6-4", "6-5")) {
    top <- c("6-3" = 18, "6-4" = 100, "6-5" = 25)[[fig]]
    zs <- seq(0.05, top, length.out = 80)
    d <- rbind(curve(zs, "invcube"), curve(zs, "random"))
    yv <- if (fig == "6-5") 100 * d$cumpos else d$cumeff
    xv <- if (fig == "6-5") d$cumeff else d$factor
    graphics::plot(range(xv), c(0, max(yv)), type = "n", xlab = "", ylab = "", main = "")
    .bl_grid(NULL)
    for (k in 1:2) {
      s <- d$model == c("invcube", "random")[k]
      .bl_line(xv[s], yv[s], cols[k], fill = FALSE, label = FALSE, points = FALSE)
    }
    graphics::legend(if (fig == "6-5") "bottomright" else "topleft",
                     legend = c("Ideal search conditions (inverse cube)", "Poor search conditions (random search)"),
                     col = cols, lwd = 2.4, bty = "n", cex = 0.8)
    .bl_xlab(if (fig == "6-5") "Cumulative relative effort" else "Optimal search factor")
    .bl_ylab(if (fig == "6-5") "Cumulative POS (%)" else "Cumulative relative effort")
    .bl_title(ttl)
    return(d)
  }
  .rmbl_local_seed(seed)
  efforts <- matrix(stats::runif(250 * 5, 0.1, 50), ncol = 5)
  d <- do.call(rbind, lapply(seq_len(nrow(efforts)), function(i) cbind(group = i, optsqr(efforts[i, ]))))
  d <- d[d$cumeff <= 100, ]
  ref <- curve(seq(0.05, 100, length.out = 80), "invcube")
  graphics::plot(c(0, 3), c(0, 100), type = "n", xlab = "", ylab = "", main = "")
  .bl_grid(NULL)
  graphics::points(d$factor, d$cumeff, pch = 16, cex = 0.5, col = grDevices::adjustcolor(cols[1L], 0.7))
  graphics::lines(ref$factor, ref$cumeff, col = cols[2L], lwd = 2)
  .bl_xlab("Optimal search factor")
  .bl_ylab("Cumulative relative effort")
  .bl_title(ttl)
  d
}
