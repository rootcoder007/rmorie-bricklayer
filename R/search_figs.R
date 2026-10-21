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
#' chapter 6). With several efforts, each search is optimized in turn against
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
#' \code{1 - POD}; every later search is optimized against what is left, and
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
    f("5-9", "Lateral range curves under ideal and poor search conditions", "model"),
    f("6-1", "A simple non-uniform distribution", "model"),
    f("6-2", "The trial search square of half the area", "model"),
    f("6-3", "Optimal search factors for point datums (effort to 18)", "model"),
    f("6-4", "Optimal search factors for point datums (effort to 100)", "model"),
    f("6-5", "Cumulative probability of success for optimal searches", "model"),
    f("6-6", "Optimal search factors for 1-5 sequential searches with random relative efforts", "approximation")
  )
}

#' One line of R per figure that draws a version of it from your own numbers: the function behind
#' the figure, with example inputs to replace (the schematics give the computation they picture).
#' @return A named character vector, one call per figure.
#' @noRd
.sr_fig_yours <- function() {
  c(
    "3-1" = paste0("plot(datumpmap(seq(-4, 4, by = 0.25), seq(-4, 4, by = 0.25), ",
                   "center = c(0, 0), sigma = 1.5), view = \"both\")"),
    "3-2" = "sum(datumpmap(c(-1.5, 1.5), c(-1.5, 1.5), sigma = 1.5)$poc)",
    "3-3" = "sum(datumpmap(c(-1, 1) * 1.177 * 1.5, c(-1, 1) * 1.177 * 1.5, sigma = 1.5)$poc)",
    "3-4" = "plot(datumpmap(c(-3, -1, 1, 3) * 1.77, c(-3, -1, 1, 3) * 1.77, sigma = 1.5), view = \"cells\")",
    "3-5" = "sum(datumpmap(c(-1, 1) * 1.295 * 1.5, c(-1, 1) * 1.295 * 1.5, sigma = 1.5)$poc)",
    "3-6" = paste0("plot(datumpmap(seq(-4, 4, by = 0.25), seq(-4, 4, by = 0.25), ",
                   "\"line\", center = c(0, -2), end = c(0, 2), sigma = 1), view = \"both\")"),
    "3-7" = paste0("plot(datumpmap(seq(-4, 4, by = 0.25), seq(-4, 4, by = 0.25), ",
                   "\"line\", center = c(0, -2), end = c(0, 2), sigma = 1), view = \"both\")"),
    "3-8" = paste0("plot(datumpmap(seq(-4, 4, by = 0.25), seq(-4, 4, by = 0.25), ",
                   "\"corridor\", center = c(0, -2), end = c(0, 2), sigma = 1), view = \"both\")"),
    "3-9" = paste0("plot(datumpmap(c(-5, 5), c(-1.18, 1.18), \"corridor\", center = c(-4, ",
                   "0), end = c(4, 0), sigma = 1), view = \"cells\")"),
    "3-10" = paste0("plot(datumpmap(0:10, c(-3, -1.8, -0.6, 0.6, 1.8, 3), \"corridor\", ",
                    "center = c(0, 0), end = c(10, 0), sigma = 1), view = \"cells\")"),
    "3-11" = paste0("plot(datumpmap(seq(-4, 4, by = 0.25), seq(-4, 4, by = 0.25), ",
                    "\"area\", center = c(-2, -1.5), end = c(2, 1.5)), view = \"both\")"),
    "3-12" = "plot(datumpmap(0:5, 0:4, \"area\", center = c(0, 0), end = c(5, 4)), view = \"cells\")",
    "3-13" = "plot(datumpmap(0:5, 0:4, \"general\", wts = matrix(c(1:10, 10:1), 4, 5)), view = \"both\")",
    "3-14" = "plot(datumpmap(0:5, 0:4, \"general\", wts = matrix(c(1:10, 10:1), 4, 5)), view = \"cells\")",
    "4-1" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"mbeta\", m = 0.5))",
    "4-2" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"definite\"))",
    "4-3" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"definite\"), equiv = TRUE)",
    "4-4" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"mbeta\", m = 0.5), equiv = TRUE)",
    "4-5" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"mbeta\", m = 0.25), equiv = TRUE)",
    "4-6" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"invcube\"))",
    "4-7" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"invcube\"), equiv = TRUE)",
    "5-1" = "plot(srchpod(seq(0, 3, by = 0.1), model = \"random\"))",
    "5-2" = "pswppod(W = 0.8, S = 1, model = \"invcube\")",
    "5-3" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"definite\"), spacing = 1.6)",
    "5-4" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"definite\"), spacing = 0.8)",
    "5-5" = "plot(srchpod(seq(0, 3, by = 0.1), \"definite\"), models = c(\"definite\", \"random\"))",
    "5-6" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"mbeta\", m = 0.5), spacing = 1.6)",
    "5-7" = paste0("plot(srchpod(seq(0, 3, by = 0.1), \"mbeta\", m = 0.5), ",
                   "models = c(\"mbeta\", \"definite\", \"random\"), m = c(0.5, 0.25))"),
    "5-8" = "plot(srchpod(seq(0, 3, by = 0.1), \"invcube\"), models = c(\"invcube\", \"definite\", \"random\"))",
    "5-9" = "plot(ltrlrng(seq(-3, 3, by = 0.05), W = 0.8, model = \"invcube\", navsd = 0.3), spacing = 1)",
    "6-1" = "optsqr(effort = 2)",
    "6-2" = "optsqr(effort = 2)$side",
    "6-3" = "with(do.call(rbind, lapply(seq(0.5, 18, by = 0.5), optsqr)), plot(factor, cumeff, type = \"l\"))",
    "6-4" = "with(do.call(rbind, lapply(seq(2, 100, by = 2), optsqr)), plot(factor, cumeff, type = \"l\"))",
    "6-5" = "with(do.call(rbind, lapply(seq(0.5, 25, by = 0.5), optsqr)), plot(cumeff, 100 * cumpos, type = \"l\"))",
    "6-6" = "optsqr(c(1, 0.5, 2, 1.5))"
  )
}

#' The figures of The Theory of Search
#'
#' Draws any figure of Frost (1996), \dQuote{The Theory of Search: A Simplified
#' Explanation}, from the package's search theory functions with the book's
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
#' @return Without \code{fig}, a data frame of \code{fig}, \code{caption}, \code{how}
#'   and \code{yours}: one line of R that draws the figure from your own numbers (the
#'   function behind it, with example inputs to replace; for a schematic, the computation it
#'   pictures). With one, the figure's data, invisibly: a data frame (or a
#'   list of them) of what was drawn.
#' @references Frost, J. R. (1996). The Theory of Search: A Simplified
#'   Explanation. Soza and Company and U.S. Coast Guard Office of Search and
#'   Rescue. Chapters 3-6.
#' @srrstats {G1.0} Frost (1996) is cited in @references with the chapters the figures come from.
#' @srrstats {G2.3a} `fig` is matched against the book's figure numbers, which the refusal lists.
#' @srrstats {EA5.0} The figures use the package's plot style (.bl_par, .bl_grid, .bl_title) and palettes.
#' @srrstats {EA6.1} test-search-figs.R draws every figure to pdf(NULL) and checks the data each returns.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' head(srchfig())
#' srchfig("3-4")
#' srchfig(5, 8)
#' d <- srchfig("6-3")
#' head(d)
#' try(srchfig("9-9"))
#' @export
srchfig <- function(fig = NULL, num = NULL, seed = 1, main = NULL) {
  tab <- .sr_fig_table()
  if (is.null(fig)) {
    tab$yours <- unname(.sr_fig_yours()[tab$fig])
    return(tab)
  }
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
  # `lab` is plotmath ("sigma", "E", "1.1*E"): Greek letters as text do not survive a C-locale device
  graphics::text(R * 0.45, -R * 0.2, str2expression(lab), cex = 0.9)
  graphics::text(c(-R, R), -R, str2expression(c(paste0("-", lab), paste0("+", lab))), pos = 1, cex = 0.8,
                 xpd = NA)
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
    "3-2" = .sr_fig_circsq(1, "sigma", ttl),
    "3-3" = .sr_fig_circsq(E, "E", ttl),
    "3-5" = .sr_fig_circsq(1.1 * E, "1.1*E", ttl),
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
      L <- 6
      graphics::plot(c(-r, L + r), c(-r, r), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = "")
      a <- seq(0, 2 * pi, length.out = 241)
      for (cx in c(0, L)) graphics::lines(cx + r * cos(a), r * sin(a), lwd = 2)
      graphics::rect(-r, -r, L + r, r, lwd = 2)
      graphics::segments(0, 0, L, 0, lwd = 2)
      graphics::arrows(c(0, L), 0, c(0, L) + r * cos(c(3, 1) * pi / 4), r * sin(c(3, 1) * pi / 4), length = 0.1,
                       lwd = 2)
      graphics::text(c(0.15, L - 0.15) * c(1, 1), 0.72 * r, c("E1", "E2"), font = 3)
      .bl_title(ttl)
      data.frame(x = c(0, L), y = 0, radius = r)
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
      # an illustrative generalized density: a plateau over the possibility area, raised where the
      # cells of figure 3-14 are high, with scattered peaks (fixed draws)
      gx <- seq(-0.5, 5.5, length.out = 61)
      gy <- seq(-0.5, 4.5, length.out = 51)
      xc <- .sr_mid(gx)
      yc <- .sr_mid(gy)
      soft <- function(v, a, b) stats::plogis((v - a) / 0.08) * stats::plogis((b - v) / 0.08)
      plateau <- outer(soft(yc, 0, 4), soft(xc, 0, 5))
      cellv <- w314[pmin(4L, pmax(1L, ceiling(yc))), pmin(5L, pmax(1L, ceiling(xc)))]
      pk <- cbind(c(2.5, 1.6, 3.4, 2.1, 3.9, 1.2, 2.9, 4.4), c(2.4, 1.6, 2.8, 3.3, 1.4, 2.6, 1.1, 3.1),
                  c(6, 3, 2.5, 2, 1.5, 1.5, 1.2, 1))
      bumps <- Reduce(`+`, lapply(seq_len(nrow(pk)), function(i) {
        pk[i, 3] * outer(stats::dnorm(yc, pk[i, 2], 0.12), stats::dnorm(xc, pk[i, 1], 0.12))
      }))
      both(datumpmap(gx, gy, "general", wts = plateau * (1 + cellv / 5) + 0.15 * bumps))
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
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      lay <- graphics::par(mfrow = c(2L, 2L), mar = c(3.4, 0.5, 1.2, 0.5), oma = c(0, 0, 2, 0))
      on.exit(graphics::par(lay), add = TRUE, after = FALSE)  # the panel layout must not outlive the figure
      xs <- seq(-2, 2, length.out = 401)
      # D: a sensor that sees poorly straight below (illustrative), scaled to sweep width 1
      dd <- function(x) {
        pmin(1, pmax(0, 0.85 * (exp(-((x - 0.45) / 0.35)^2) + exp(-((x + 0.45) / 0.35)^2)) - 0.25 * exp(-(x / 0.2)^2)))
      }
      sc <- 1 / sum(diff(xs) * (dd(xs[-1]) + dd(xs[-401])) / 2)
      curves <- list(.sr_lr(xs, 1, "definite", 1), .sr_lr(xs, 1, "mbeta", 0.5), .sr_lr(xs, 1, "invcube", 1),
                     pmin(1, dd(xs) * sc))
      xs4 <- sort(unique(c(xs, -0.5 - 1e-9, 0.5 + 1e-9, -1 - 1e-9, 1 + 1e-9)))
      out <- list()
      for (k in 1:4) {
        xx <- if (k < 3L) xs4 else xs
        p <- if (k < 3L) .sr_lr(xx, 1, c("definite", "mbeta")[k], 0.5) else curves[[k]]
        graphics::plot(c(-2.1, 2.1), c(-0.55, 1.15), type = "n", axes = FALSE, xlab = "", ylab = "", main = "")
        graphics::segments(-2, 0, 2, 0, lwd = 1.5)
        graphics::segments(0, 0, 0, 1.1, lwd = 1.5)
        graphics::text(0, 1.12, "p(x)", pos = 4, cex = 0.8)
        graphics::text(0, 1, "1", pos = 2, cex = 0.8)
        graphics::text(2, 0, "x", pos = 3, cex = 0.8)
        graphics::lines(xx, p, lwd = 2.2)
        if (k > 1L) graphics::rect(-0.5, 0, 0.5, 1, lty = 2, border = "#555555")
        graphics::arrows(-0.5, -0.22, 0.5, -0.22, length = 0.05, code = 3)
        graphics::text(0, -0.22, "W", pos = 1, cex = 0.8, offset = 0.3)
        if (k == 1L) graphics::text(c(-0.5, 0.5), -0.05, c("-rdef", "+rdef"), pos = 1, cex = 0.7, offset = 0.2)
        if (k == 2L) {
          graphics::text(c(-1, 1), -0.05, c("-rmax", "+rmax"), pos = 1, cex = 0.7, offset = 0.2)
          graphics::arrows(-1, -0.45, 1, -0.45, length = 0.05, code = 3)
          graphics::text(0, -0.45, expression(beta), pos = 1, cex = 0.8, offset = 0.3)
          graphics::text(0, 0.5, "M 0.5", pos = 3, cex = 0.7)
        }
        graphics::mtext(LETTERS[k], side = 1, line = 2, font = 2, cex = 1.1)
        out[[k]] <- data.frame(x = xx, p = p)
      }
      graphics::mtext(ttl, side = 3, outer = TRUE, font = 2, line = 0.5)
      out
    },
    "4-3" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      graphics::plot(c(0, 10), c(-2, 2), type = "n", axes = FALSE, xlab = "", ylab = "", main = "")
      graphics::rect(0.5, -0.5, 9.5, 0.5, lwd = 2)
      graphics::segments(0.5, 0, 9.5, 0, lwd = 2)
      graphics::arrows(0.2, -0.5, 0.2, 0.5, length = 0.06, code = 3)
      graphics::text(0.2, 0, "W", pos = 2, font = 2)
      .bl_title(ttl)
      data.frame(width = 1)
    },
    "4-6" = {
      op <- .bl_par()
      on.exit(graphics::par(op), add = TRUE)
      lay <- graphics::par(mfrow = c(2L, 1L), mar = c(0.5, 0.5, 1, 0.5), oma = c(0, 0, 2, 0))
      on.exit(graphics::par(lay), add = TRUE, after = FALSE)  # the panel layout must not outlive the figure
      h <- 4
      r <- 8
      a <- 2
      graphics::plot(c(-0.8, 11), c(-1, 4.6), type = "n", axes = FALSE, xlab = "", ylab = "", main = "")
      graphics::segments(0, 0, r + a, 0, lwd = 2)
      graphics::segments(0, 0, 0, h)
      graphics::segments(0, h, r + a, 0, lwd = 2)
      graphics::segments(0, h, r, 0)
      cx <- r + 0.35
      graphics::segments(r, 0, cx, h * (1 - cx / (r + a)) + 0.02, lty = 2)
      graphics::text(c(-0.3, -0.5, 4, 0, r - 0.9, cx - 0.2, 4.5), c(h + 0.3, h / 2, 2.4, -0.5, 0.9, 0.55, -0.5),
                     expression(bold(O), bold(h), bold(s), bold(A), bold(alpha), bold(c), bold(r)))
      graphics::arrows(r + 0.6, -0.5, c(r, r + a), -0.5, length = 0.06)
      graphics::text(r + a / 2 + 0.3, -0.75, "a", font = 2)
      # the same in perspective: the observer, the wake a by b and the solid angle it subtends
      pm <- graphics::persp(c(0, 1), c(0, 1), matrix(0, 2, 2), zlim = c(0, 1), theta = 35, phi = 22, box = FALSE,
                            border = NA, col = NA)
      tp <- function(x, y, z) grDevices::trans3d(x, y, z, pm)
      pl <- tp(c(0, 1, 1, 0, 0), c(0, 0, 1, 1, 0), 0)
      graphics::lines(pl$x, pl$y)
      wk <- tp(c(0.6, 0.85, 0.85, 0.6, 0.6), c(0.35, 0.35, 0.6, 0.6, 0.35), 0)
      graphics::lines(wk$x, wk$y, lwd = 2)
      o <- tp(0.15, 0.2, 0.9)
      f <- tp(0.15, 0.2, 0)
      graphics::segments(o$x, o$y, f$x, f$y)
      graphics::segments(o$x, o$y, wk$x[1:4], wk$y[1:4], lwd = 1.2)
      graphics::text(o$x, o$y, "O", pos = 3, font = 2)
      graphics::text((o$x + f$x) / 2, (o$y + f$y) / 2, "h", pos = 2, font = 2)
      graphics::text((o$x + wk$x[1]) / 2, (o$y + wk$y[1]) / 2, "s", pos = 2, font = 2)
      graphics::text(mean(wk$x[1:2]), mean(wk$y[1:2]), "a", pos = 1, font = 2)
      graphics::text(mean(wk$x[2:3]), mean(wk$y[2:3]), "b", pos = 4, font = 2)
      graphics::text(mean(c(o$x, wk$x[1:2])), mean(c(o$y, wk$y[1:2])), expression(bold(alpha)))
      graphics::text(mean(c(o$x, wk$x[2:3])), mean(c(o$y, wk$y[2:3])), expression(bold(beta)))
      graphics::mtext(ttl, side = 3, outer = TRUE, font = 2, line = 0.5)
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
      graphics::par(mar = c(3, 3.5, 2.5, 6))
      S <- 1
      ys <- 4.5 - (0:4) * S
      graphics::plot(c(0, 10), c(-0.2, 5.2), type = "n", axes = FALSE, xlab = "", ylab = "", main = "", asp = 1)
      graphics::rect(0, 0, 10, 5, lty = 2, lwd = 1.5)
      xx <- c(rbind(ifelse(seq_along(ys) %% 2 == 1, 0.5, 9.5), ifelse(seq_along(ys) %% 2 == 1, 9.5, 0.5)))
      graphics::lines(xx, rep(ys, each = 2), lwd = 2)
      for (k in seq_along(ys)) {
        d <- if (k %% 2 == 1) 1 else -1
        graphics::arrows(5 - 0.3 * d, ys[k], 5 + 0.3 * d, ys[k], length = 0.09, lwd = 2)
      }
      graphics::points(0.5, ys[1], pch = 19)
      graphics::points(5, 2.5, pch = 19)
      graphics::arrows(5, 2.5, 6, 2.5, length = 0.07)
      lab <- function(x, y, t, ...) graphics::text(x, y, t, cex = 0.7, xpd = NA, ...)
      lab(3, 5.45, "Commence Search Point (CSP)")
      lab(6.2, 5.45, "Search Leg")
      lab(8.7, 5.45, "Turn Point (Way Point)")
      lab(10.2, 5.2, "Corner Point", pos = 4)
      lab(10.2, 4, "Cross Leg", pos = 4)
      lab(10.2, 3, "Track Space (S)", pos = 4)
      lab(4.9, 2.75, "Centre Point", pos = 2)
      lab(5.9, 2.75, "Orientation", pos = 2)
      lab(1.6, 0.9, "Direction\nof Creep")
      graphics::arrows(1.6, 0.55, 1.6, 0.15, length = 0.05)
      graphics::arrows(8, ys[2], 8, ys[3], length = 0.05, code = 3)
      lab(8, mean(ys[2:3]), "S", pos = 2)
      graphics::arrows(-0.6, 0, -0.6, 5, length = 0.06, code = 3, xpd = NA)
      lab(-0.6, 2.5, "Width", pos = 2)
      graphics::arrows(0, -0.4, 10, -0.4, length = 0.06, code = 3, xpd = NA)
      lab(5, -0.4, "Length", pos = 1)
      lab(0.25, 5.15, "1/2 S")
      .bl_title(ttl)
      data.frame(x = xx, y = rep(ys, each = 2))
    },
    "5-9" = {
      # Frost's figure 5-9: ideal conditions (sweep width 5.0 nm, probable position error 0.25 nm) and poor
      # conditions (2.0 nm and 2.0 nm), the inverse cube curve averaged over the position error
      xs <- seq(-10, 10, length.out = 801)
      cur <- data.frame(cond = c("ideal", "poor"), W = c(5, 2), navsd = c(0.25, 2))
      d <- do.call(rbind, lapply(seq_len(nrow(cur)), function(k) {
        data.frame(cond = cur$cond[k], W = cur$W[k], navsd = cur$navsd[k], x = xs,
                   p = .sr_lr_nav(xs, cur$W[k], "invcube", 1, cur$navsd[k]))
      }))
      op <- .bl_par(c(0, 1))
      on.exit(graphics::par(op), add = TRUE)
      graphics::plot(c(-10, 10), c(0, 1.02), type = "n", xlab = "", ylab = "", main = "", axes = FALSE)
      graphics::axis(1, at = -10:10, labels = abs(-10:10))
      graphics::axis(2, at = seq(0, 1, 0.1), labels = paste0(seq(0, 100, 10), "%"))
      cols <- c("#000080", "#E0301E")
      for (k in 1:2) graphics::lines(xs, d$p[d$cond == cur$cond[k]], col = cols[k], lwd = 2.4)
      box <- function(x, y, head, body, to) {
        txt <- c(head, body)
        w <- max(graphics::strwidth(txt, cex = 0.7))
        hgt <- length(txt) * 1.25 * graphics::strheight("M", cex = 0.7)
        graphics::rect(x, y - hgt, x + w * 1.08, y, border = "#1F2430", lwd = 1.5, col = "white")
        graphics::text(x + w * 0.04, y - (seq_along(txt) - 0.5) * hgt / length(txt), txt, pos = 4, offset = 0,
                       cex = 0.7, font = c(2, rep(1, length(body))))
        graphics::arrows(x + w * 0.9, y - 0.6 * hgt, to[1], to[2], length = 0.07, lwd = 1.5)
      }
      pi1 <- .sr_lr_nav(-1.6, 5, "invcube", 1, 0.25)
      pp <- .sr_lr_nav(0.8, 2, "invcube", 1, 2)
      box(-9.5, 0.92, "Ideal search conditions:",
          c("Visibility > 20 nm, winds calm", "Fixed wing aircraft at 300 m", "Corrected sweep width 5.0 nm",
            "Probable position error 0.25 nm"), c(-1.6, pi1))
      box(2.4, 0.62, "Poor search conditions:",
          c("Visibility 3 nm, winds 15 kts", "Fixed wing aircraft at 300 m", "Corrected sweep width 2.0 nm",
            "Probable position error 2.0 nm"), c(0.8, pp))
      .bl_ylab("POD")
      .bl_xlab("Lateral range in nautical miles")
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
    # the book's axes: optimal factor 0-1.5 against effort 0-18, 0-3 against 0-100, and POS against effort 0-25
    lim <- list("6-3" = c(1.5, 18, 0.2, 2), "6-4" = c(3, 100, 0.5, 10), "6-5" = c(25, 100, 1, 10))[[fig]]
    zs <- seq(0.05, if (fig == "6-5") 25 else lim[2], length.out = 90)
    d <- rbind(curve(zs, "invcube"), curve(zs, "random"))
    yv <- if (fig == "6-5") 100 * d$cumpos else d$cumeff
    xv <- if (fig == "6-5") d$cumeff else d$factor
    cols <- c("#000080", "#E0301E")
    graphics::plot(c(0, lim[1]), c(0, lim[2]), type = "n", xlab = "", ylab = "", main = "", axes = FALSE,
                   xaxs = "i", yaxs = "i")
    graphics::abline(v = seq(0, lim[1], lim[3]), h = seq(0, lim[2], lim[4]), col = "#1F2430", lwd = 0.6)
    graphics::axis(1, at = seq(0, lim[1], lim[3]))
    graphics::axis(2, at = seq(0, lim[2], lim[4]), labels = if (fig == "6-5") paste0(seq(0, 100, 10), "%") else TRUE)
    graphics::box()
    lab <- c("Ideal Search Conditions", "Poor Search Conditions")
    # each curve named beside a point of it: ideal below-right and poor above-left on the factor charts,
    # ideal above and poor below on the POS chart
    off <- if (fig == "6-5") rbind(c(0.35, 0.45), c(0.1, -0.15)) else rbind(c(0.02, -0.22), c(-0.3, 0.12))
    for (k in 1:2) {
      s <- d$model == c("invcube", "random")[k]
      graphics::lines(xv[s], yv[s], col = cols[k], lwd = 2.2)
      at <- which(s)[which.min(abs(yv[s] - 0.45 * lim[2]))]
      tx <- xv[at] + off[k, 1] * lim[1]
      ty <- yv[at] + off[k, 2] * lim[2]
      graphics::text(tx, ty, lab[k], cex = 0.75, font = 2, col = cols[k])
      graphics::arrows(tx, ty + 0.03 * lim[2] * sign(-off[k, 2]), xv[at], yv[at], length = 0.07, lwd = 1.4,
                       col = cols[k])
    }
    .bl_xlab(if (fig == "6-5") "Cumulative relative effort" else "Optimal search factor")
    .bl_ylab(if (fig == "6-5") "Cumulative POS" else "Cumulative relative effort")
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
