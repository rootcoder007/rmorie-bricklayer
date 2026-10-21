# SPDX-License-Identifier: AGPL-3.0-or-later
#
# R bindings for the statistical kernels in the compiled core. Two
# groups live here:
#
#   * kernels vendored from morie (morie_core.h) that were already
#     compiled into this package but had no binding, so nothing could
#     reach them: the standard deviation, Euclidean distance, the normal
#     log-density, trimmed IPW weights, bootstrap replicate means, the
#     regularized incomplete gamma function, and the Hawkes likelihood;
#   * bricklayer's own robust and distributional summaries
#     (rmbl_stats.cpp), which morie does not carry.
#
# Every one is also published through `LinkingTo: rmoriebricklayer`, so
# rmorie and rmoriedata call the same compiled copy rather than their
# own.

#' Standard deviation and Euclidean distance (C backend)
#'
#' `csdev()` returns the standard deviation of a numeric vector and
#' `cdistm()` the straight-line (Euclidean) distance between two
#' vectors of the same length. Both run in the package's compiled core,
#' the same code that rmorie and rmoriedata reach through
#' `LinkingTo: rmoriebricklayer`, so a figure computed here is the figure
#' those packages compute. Use them when you want the shared core's
#' answer rather than base R's, for example when checking a capsule's
#' recorded summary statistics against a fresh computation.
#'
#' @details
#' `csdev()` computes
#' \deqn{s = \sqrt{\frac{1}{n - \mathrm{ddof}} \sum_{i=1}^n (x_i - \bar x)^2},}
#' so `ddof = 1` is the sample standard deviation of [stats::sd()]
#' and
#' `ddof = 0` the population figure. `cdistm()` computes
#' \eqn{\sqrt{\sum_i (a_i - b_i)^2}}.
#'
#' Missing values propagate: there is no `na.rm`, and one `NA` makes the
#' result `NA`. Remove them first (for example with
#' [stats::na.omit()]) when
#' that is what you want. A vector with no more than `ddof` values has no
#' defined spread and gives `NaN` (one value with the default `ddof = 1`,
#' or an empty vector). Two empty vectors are at distance 0.
#'
#' Refusals: a character, factor, list or data-frame `x`, `a` or `b`
#' (`"must be numeric"`), and for `cdistm()` vectors of different lengths
#' (`"must have the same length"`). Logical input is accepted and counted
#' as 0/1. Both run in one pass over the data and allocate nothing beyond
#' the coerced input.
#'
#' @param x,a,b Numeric (or logical) vectors; coerced with
#'   [as.numeric()].
#'   `a` and `b` must have the same length.
#' @param ddof Delta degrees of freedom, a single number;
#'   [as.integer()] truncates it to an integer.
#'   The divisor is `n - ddof`.
#'   The default `1` gives the sample standard
#'   deviation, matching [stats::sd()]; `0` gives the population
#'   figure.
#' @return `csdev()`: a length-1 numeric, the standard deviation in the
#'   units of `x` (`NA` when `x` holds a missing value, `NaN` when
#'   `length(x) <= ddof`). `cdistm()`: a length-1 non-negative numeric,
#'   the distance in the units of `a` and `b`.
#' @seealso
#' [cmom()] for the mean, variance, skewness and
#' kurtosis in a
#' single pass; [cmad()] for a spread that one wild value
#' cannot move.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' # Sample standard deviation, matching stats::sd().
#' csdev(c(2, 4, 4, 4, 5, 5, 7, 9))
#' all.equal(csdev(1:10), stats::sd(1:10))
#'
#' # ddof = 0 divides by n instead of n - 1.
#' csdev(1:10, ddof = 0)
#' all.equal(csdev(1:10, ddof = 0), sqrt(mean((1:10 - mean(1:10))^2)))
#'
#' # Missing values propagate; remove them first if they should be ignored.
#' csdev(c(3, NA, 5))
#' csdev(stats::na.omit(c(3, NA, 5)))
#'
#' # Euclidean distance between two points.
#' cdistm(c(0, 0), c(3, 4))     # 5
#' cdistm(1:5, 1:5)             # 0 -- a point is zero from itself
#'
#' # Vectors of different lengths are refused rather than recycled.
#' try(cdistm(1:3, 1:2))
#' @name cspread
#' @export
#' @srrstats {G2.4a} ddof goes through .rmbl_scalar(integer = TRUE): fractional, too-large and Inf values are
#'   refused, then as.integer() is applied.
csdev <- function(x, ddof = 1L) {
  .Call(C_rmbl_sd, .rmbl_num_input(x, "x"), as.integer(.rmbl_scalar(ddof, "ddof", 0, integer = TRUE)))
}

#' @rdname cspread
#' @export
cdistm <- function(a, b) {
  a <- .rmbl_num_input(a, "a")
  b <- .rmbl_num_input(b, "b")
  if (length(a) != length(b)) {
    stop("`a` and `b` must have the same length", call. = FALSE)
  }
  .Call(C_rmbl_euclid, a, b)
}

#' Normal log-density (C backend)
#'
#' The logarithm of the normal (Gaussian) density at each value of `x`,
#' computed directly from the formula rather than as `log(dnorm(x))`. Use
#' it for log-likelihoods: summing log-densities is how a normal model is
#' scored, and computing them directly keeps the sum finite far into the
#' tails, where the density itself underflows to zero and its logarithm
#' would be `-Inf`.
#'
#' @details
#' Each value is
#' \deqn{\log \phi(x; \mu, \sigma) = -\log \sigma - \tfrac12 \log(2\pi)
#'   - \frac{(x - \mu)^2}{2\sigma^2},}
#' evaluated by the shared core, and agrees with
#' `stats::dnorm(x, mean, sd, log = TRUE)` to rounding.
#'
#' `mean` and `sd` are single numbers: a vector of either is refused, so
#' this is not vectorised over the parameters the way
#' [stats::dnorm()] is.
#' A non-finite `mean`, and an `sd` that is not a positive finite number,
#' are errors, as in [cnormpdf()]; a missing
#' `x` gives `NA`. A
#' character, factor or list `x` is refused (`"must be numeric"`).
#'
#' @param x Numeric vector of quantiles (the observed values).
#' @param mean The distribution's mean, a single number in the units of
#'   `x` (default 0).
#' @param sd The distribution's standard deviation, a single positive
#'   number in the units of `x` (default 1).
#' @return A numeric vector the length of `x`: the natural-log density at
#'   each value (in log units per unit of `x`). Equivalent to
#'   `stats::dnorm(x, mean, sd, log = TRUE)`.
#' @seealso [cmom()] for estimating `mean` and
#'   `sd` from data.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' cnormlpdf(c(-1, 0, 1))
#'
#' # Identical to stats::dnorm(log = TRUE).
#' all.equal(cnormlpdf(-2:2, 0.3, 1.7),
#'           stats::dnorm(-2:2, 0.3, 1.7, log = TRUE))
#'
#' # Still finite where the density itself underflows to zero.
#' stats::dnorm(50)                  # 0
#' cnormlpdf(50)            # about -1251
#'
#' # A log-likelihood: the sum of the log-densities of a sample.
#' y <- c(4.8, 5.1, 5.6, 4.9, 5.3)
#' sum(cnormlpdf(y, mean = mean(y), sd = stats::sd(y)))
#'
#' # A standard deviation of zero has no density, and the parameters are
#' # single numbers.
#' try(cnormlpdf(1, sd = 0))
#' try(cnormlpdf(1, mean = c(0, 1)))
#' try(cnormlpdf("1"))
#' @export
cnormlpdf <- function(x, mean = 0, sd = 1) {
  # the core reads only the first element of each parameter, so a vector was used in part
  mean <- .rmbl_num(mean, "mean")
  sd <- .rmbl_num(sd, "sd")
  if (length(mean) != 1L || !is.finite(mean)) stop("cnormlpdf: `mean` must be a single finite number", call. = FALSE)
  if (length(sd) != 1L || !is.finite(sd) || sd <= 0) stop("cnormlpdf: `sd` must be a single positive number",
                                                          call. = FALSE)
  .Call(C_rmbl_normal_logpdf, .rmbl_num_input(x, "x"), mean, sd)
}

#' Mean, variance, skewness and kurtosis (C backend)
#'
#' The four standard descriptive moments of a numeric vector -- where it is
#' centred, how spread out it is, whether it leans to one side and how
#' heavy its tails are -- in one call to the compiled core. These are the
#' four numbers a data description or a drift check usually reports
#' together.
#'
#' @details
#' The mean is base R's (an extended-precision sum followed by a
#' corrective pass); the deviations from it are then divided by their
#' largest magnitude before any power is taken, and the scale is restored
#' at the end. That avoids both the cancellation of the textbook \dQuote{sum of
#' squares minus square of sum} formula and overflow of fourth powers for
#' values beyond about \eqn{10^{77}}. It reads the data three times
#' (mean, largest deviation, moments), in \eqn{O(n)} time. The variance uses
#' the `n - 1` denominator, matching [stats::var()]. The shape
#' statistics
#' use the *sample moment* definitions
#' \deqn{g_1 = m_3 / m_2^{3/2}, \qquad g_2 = m_4 / m_2^2 - 3,}
#' with \eqn{m_k = n^{-1} \sum_i (x_i - \bar x)^k}, so kurtosis is reported
#' as EXCESS kurtosis: a normal sample sits near zero, not near three.
#' These are the uncorrected moment ratios (type 1 in the classification
#' of Joanes and Gill, 1998), not the bias-adjusted versions some software
#' reports.
#'
#' Edge cases are `NaN`, never an error: an empty vector gives four `NaN`;
#' one value gives its mean and `NaN` for the rest; `skewness` needs at
#' least 3 values and `kurtosis` at least 4; any `NA` or `NaN` in `x`
#' makes
#' every entry `NaN`. A constant vector has variance 0 and `NaN` shape
#' statistics. A character, factor or list `x` is refused
#' (`"must be numeric"`).
#'
#' @param x Numeric (or logical) vector; coerced with
#'   [as.numeric()].
#' @return A named length-4 numeric vector: `mean` (units of `x`),
#'   `variance` (squared units of `x`, `n - 1` denominator),
#'   `skewness` and
#'   `kurtosis` (both unitless; kurtosis as excess over the normal's 3).
#' @seealso [csdev()],
#'   [cqnt()] and
#'   [cmad()] for robust
#'   alternatives that one extreme value cannot move.
#' @references Joanes DN, Gill CA (1998). Comparing measures of sample skewness and
#' kurtosis. *Journal of the Royal Statistical Society: Series D (The
#' Statistician)* 47(1), 183--189.
#' \doi{10.1111/1467-9884.00122}
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' cmom(c(2, 4, 4, 4, 5, 5, 7, 9))
#'
#' # The first two entries agree with base R.
#' m <- cmom(1:10)
#' all.equal(m[["mean"]], mean(1:10))
#' all.equal(m[["variance"]], stats::var(1:10))
#'
#' # A symmetric sample has no skew; excess kurtosis is near 0 for normal
#' # data and positive for a heavy-tailed sample.
#' cmom(c(-2, -1, 0, 1, 2))[["skewness"]]
#' cmom(c(rep(0, 20), -8, 8))[["kurtosis"]] > 0
#'
#' # Too short to define a shape statistic: NaN rather than a guess.
#' cmom(c(1, 2))
#' @export
cmom <- function(x) .Call(C_rmbl_moments, .rmbl_num_input(x, "x"))

#' Quantiles, median and robust spread (C backend)
#'
#' `cqnt()` is the type-7 quantile, which is R's default, so
#' it agrees with `stats::quantile(x, probs, type = 7)`.
#' `cmed()` is the 50% point. `cmad()` is the median
#' absolute deviation, scaled by `constant` so that it estimates the
#' standard deviation of a normal sample. `ciqr()` is the
#' interquartile range and `ctkyfnc()` the outlier fences
#' drawn at `k` IQRs beyond the quartiles.
#'
#' These are the robust counterparts of
#' [cmom()]: a single corrupted row can
#' move a mean or a variance arbitrarily far, but moves a median or a MAD
#' hardly at all -- which is what you want when deciding whether a freshly
#' fetched column is still the column a capsule was pinned against, or
#' when screening a column for values to inspect by hand.
#'
#' @details
#' The type-7 quantile at probability \eqn{p} interpolates linearly between
#' the order statistics \eqn{x_{(j)}} and \eqn{x_{(j+1)}} with
#' \eqn{h = (n - 1)p + 1}, \eqn{j = \lfloor h \rfloor}:
#' \eqn{Q(p) = x_{(j)} + (h - j)(x_{(j+1)} - x_{(j)})} (Hyndman and Fan,
#' 1996). The MAD is \eqn{c \cdot \mathrm{median}_i |x_i - \mathrm{median}(x)|}
#' with \eqn{c} = `constant`; the IQR is \eqn{Q(0.75) - Q(0.25)}; and the
#' fences are \eqn{Q(0.25) - k \cdot \mathrm{IQR}} and
#' \eqn{Q(0.75) + k \cdot \mathrm{IQR}} (Tukey, 1977).
#'
#' Missing values are not removed: an `NA` or `NaN` anywhere in `x` makes
#' every result `NaN` (unlike [stats::quantile()], which
#' stops). An empty
#' `x` gives `NaN`. `cqnt()` refuses an empty `probs`
#' (`"probs is empty"`) and any probability outside \eqn{[0, 1]} or missing
#' (`"must lie in [0, 1]"`); every function refuses a character, factor or
#' list `x` (`"must be numeric"`). The quantiles sort a copy of `x`, so
#' the
#' cost is \eqn{O(n \log n)}.
#'
#' @param x Numeric (or logical) vector; coerced with
#'   [as.numeric()].
#' @param probs Numeric vector of probabilities, each in \eqn{[0, 1]}
#'   (default the minimum, quartiles and maximum).
#' @param const Scale factor for `cmad()`. The
#' default `1.4826` makes the MAD consistent for the standard
#' deviation under normality, and is the same rounded value
#' [stats::mad()] uses, so the two agree exactly.
#' The unrounded consistency constant is `1 / qnorm(3/4)` =
#' 1.4826022185...; pass it explicitly if you want the extra digits, or
#' `1` for the unscaled median deviation.
#' @param k Fence width in IQRs, a single non-negative number (default
#'   1.5, Tukey's convention; 3 is the usual \dQuote{far out} cutoff).
#' @return `cqnt()`: a numeric vector the length of `probs`, in
#'   the units of `x`, named by percentage (`"25%"`, ...) as
#'   [stats::quantile()] names them. `cmed()`,
#'   `cmad()` and
#'   `ciqr()`: a length-1 numeric in the units of `x`.
#'   `ctkyfnc()`: a named length-2 numeric, `lower` and `upper`.
#' @references Hyndman RJ, Fan Y (1996). Sample quantiles in statistical
#'   packages. *The American Statistician* 50(4), 361--365.
#'   \doi{10.1080/00031305.1996.10473566}
#'
#' Tukey JW (1977). *Exploratory Data Analysis*. Addison-Wesley.
#' @seealso [cmom()] for the non-robust moments,
#'   [ctrmmean()] for a robust centre that still
#'   averages.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' x <- c(2, 4, 4, 4, 5, 5, 7, 9)
#' cqnt(x, c(0.25, 0.5, 0.75))
#' all.equal(cqnt(x, c(0.1, 0.9)),
#'           as.numeric(stats::quantile(x, c(0.1, 0.9))))
#'
#' cmed(x)
#' cmad(x)
#' all.equal(cmad(x), stats::mad(x))
#' cmad(x, const = 1)                  # unscaled median deviation
#' cmad(x, const = 1 / stats::qnorm(3/4))  # unrounded constant
#'
#' ciqr(x)
#' ctkyfnc(x)
#'
#' # Robustness: one wild value barely moves the median, but moves the
#' # mean a long way.
#' wild <- c(x, 1000)
#' c(mean = mean(wild), median = cmed(wild))
#'
#' # Values outside the fences are the candidates to inspect.
#' f <- ctkyfnc(wild)
#' wild[wild < f[["lower"]] | wild > f[["upper"]]]
#'
#' # A missing value is not dropped: the answer is NaN.
#' cmed(c(1, NA, 3))
#'
#' # A probability outside [0, 1] is refused.
#' try(cqnt(x, 1.5))
#' @name crob
#' @export
cqnt <- function(x, probs = c(0, 0.25, 0.5, 0.75, 1)) {
  x <- .rmbl_num_input(x, "x")
  probs <- .rmbl_num(probs, "probs")
  if (length(probs) == 0L) stop("`probs` is empty", call. = FALSE)
  if (anyNA(probs) || any(probs < 0 | probs > 1)) {
    stop("`probs` must lie in [0, 1]", call. = FALSE)
  }
  out <- .Call(C_rmbl_quantile, as.numeric(x), probs)
  names(out) <- paste0(format(100 * probs, trim = TRUE), "%")
  out
}

#' @rdname crob
#' @export
cmed <- function(x) .Call(C_rmbl_median, .rmbl_num_input(x, "x"))

#' @rdname crob
#' @export
cmad <- function(x, const = 1.4826) {
  .Call(C_rmbl_mad, .rmbl_num_input(x, "x"), .rmbl_scalar(const, "const", 0))
}

#' @rdname crob
#' @export
ciqr <- function(x) {
  q <- .Call(C_rmbl_quantile, .rmbl_num_input(x, "x"), c(0.25, 0.75))
  q[2L] - q[1L]
}

#' @rdname crob
#' @export
ctkyfnc <- function(x, k = 1.5) {
  k <- .rmbl_scalar(k, "k", 0)
  q <- .Call(C_rmbl_quantile, .rmbl_num_input(x, "x"), c(0.25, 0.75))
  iqr <- q[2L] - q[1L]
  c(lower = q[1L] - k * iqr, upper = q[2L] + k * iqr)
}

#' Trimmed and winsorized means (C backend)
#'
#' Two ways to stop a handful of extreme rows dominating a column's centre.
#' `ctrmmean()` DISCARDS the `floor(n * trim)` largest
#' and smallest values, as `mean(x, trim = )` does.
#' `cwinsmean()` instead PULLS THEM IN to the most extreme
#' surviving values, so every observation still contributes weight --
#' usually the better choice when the extremes are real measurements rather
#' than errors.
#'
#' @details
#' With \eqn{g = \lfloor n \cdot \mathrm{trim} \rfloor} and the sorted values
#' \eqn{x_{(1)} \le \dots \le x_{(n)}}, the trimmed mean is
#' \eqn{\frac{1}{n - 2g} \sum_{i=g+1}^{n-g} x_{(i)}} and the winsorized mean
#' replaces \eqn{x_{(1)}, \dots, x_{(g)}} by \eqn{x_{(g+1)}} and
#' \eqn{x_{(n-g+1)}, \dots, x_{(n)}} by \eqn{x_{(n-g)}} before averaging all
#' \eqn{n} values. At `trim = 0.5` both return the median, as `mean()` does.
#'
#' A `trim` that is not a single number in \eqn{[0, 0.5]} is an error. An
#' empty `x`, or any `NA`/`NaN` in `x`, gives `NaN` (missing
#' values are not
#' removed). A character, factor or list `x` is refused
#' (`"must be numeric"`). Both sort a copy of `x`, so the cost is
#' \eqn{O(n \log n)}.
#'
#' @param x Numeric (or logical) vector; coerced with
#'   [as.numeric()].
#' @param trim Proportion trimmed (or winsorized) at *each* end, a single
#'   number in \eqn{[0, 0.5]} (default 0.1, i.e. 10% at each end). At
#'   `0.5` both reduce to the median.
#' @return A length-1 numeric in the units of `x`.
#' @seealso [cmed()] and
#'   [cmad()] for the other robust
#'   summaries; [cmom()] for the ordinary mean.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 100)
#'
#' mean(x)                               # dragged up by the 100
#' ctrmmean(x, 0.1)             # the 100 and the 1 dropped
#' cwinsmean(x, 0.1)          # the 100 pulled back to 9
#'
#' # Agrees with base R's own trimming.
#' all.equal(ctrmmean(x, 0.2), mean(x, trim = 0.2))
#'
#' # trim = 0 is the plain mean; trim = 0.5 is the median.
#' all.equal(ctrmmean(x, 0), mean(x))
#' all.equal(ctrmmean(x, 0.5), cmed(x))
#'
#' # A trim past one half is not a trim.
#' try(cwinsmean(x, 0.7))
#' try(ctrmmean(letters))
#' @name ctrm
#' @export
ctrmmean <- function(x, trim = 0.1) {
  .Call(C_rmbl_trimmed_mean, .rmbl_num_input(x, "x"), .rmbl_trim(trim))
}

#' @rdname ctrm
#' @export
cwinsmean <- function(x, trim = 0.1) {
  .Call(C_rmbl_winsorized_mean, .rmbl_num_input(x, "x"), .rmbl_trim(trim))
}

#' One proportion in \[0, 0.5\]: outside it the core returned NaN, which reads as a result
#' @param trim The trimming proportion passed by the user.
#' @return The proportion as a double.
#' @noRd
.rmbl_trim <- function(trim) {
  trim <- .rmbl_num(trim, "trim")
  if (length(trim) != 1L || is.na(trim) || trim < 0 || trim > 0.5) {
    stop("`trim` must be a single number in [0, 0.5]", call. = FALSE)
  }
  trim
}

#' Weighted mean and variance (C backend)
#'
#' The weighted mean and weighted variance of a numeric vector, for data
#' where some observations count for more than others: an average over
#' areas weighted by population, or measurements weighted by how precise
#' each one is. Both come from the compiled core in one pass.
#'
#' @details
#' The mean is \eqn{\bar x_w = \sum_i w_i x_i / \sum_i w_i}. The weights
#' are treated as RELIABILITY weights (how precisely each observation is
#' known), so the variance is
#' \deqn{s_w^2 = \frac{\sum_i w_i (x_i - \bar x_w)^2}
#'   {\sum_i w_i - \sum_i w_i^2 / \sum_i w_i},}
#' the unbiased estimator under that reading. With every weight equal to 1
#' it reduces exactly to [stats::var()]. Frequency weights
#' (a weight of
#' 3
#' meaning three identical rows) call for the denominator
#' \eqn{\sum w - 1} instead, and survey design weights call for a
#' design-based variance, so do not use this variance for those.
#'
#' Refusals: `x` and `w` of different lengths
#' (`"must have the same length"`), any negative weight
#' (`"must be non-negative"`), and a character, factor or list argument
#' (`"must be numeric"`). All-zero weights, or an `NA` in either vector,
#' give `NaN` for both entries.
#'
#' @param x Numeric vector of observations.
#' @param w Numeric vector of non-negative weights, the same length as
#'   `x`. Only their relative sizes matter for the mean; the variance's
#'   correction uses them as given.
#' @return A named length-2 numeric vector: `mean` (units of `x`) and
#'   `variance` (squared units of `x`).
#' @seealso [cmom()] for the unweighted moments,
#'   [cipw()] for inverse-probability weights
#'   to feed in here.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' x <- c(10, 20, 30, 40)
#' w <- c(1, 1, 2, 4)
#' cwtd(x, w)
#'
#' # The mean agrees with base R.
#' all.equal(cwtd(x, w)[["mean"]], stats::weighted.mean(x, w))
#'
#' # Equal weights recover the unweighted variance.
#' all.equal(cwtd(x, rep(1, 4))[["variance"]], stats::var(x))
#'
#' # A single dominant weight pulls the mean onto that observation.
#' cwtd(x, c(1, 1, 1, 1000))[["mean"]]
#'
#' # A negative weight is refused.
#' try(cwtd(x, c(1, -1, 1, 1)))
#' @export
cwtd <- function(x, w) {
  x <- .rmbl_num_input(x, "x")
  w <- .rmbl_num_input(w, "w")
  if (length(x) != length(w)) {
    stop("`x` and `w` must have the same length", call. = FALSE)
  }
  if (any(w < 0, na.rm = TRUE)) {
    stop("`w` must be non-negative", call. = FALSE)
  }
  out <- .Call(C_rmbl_weighted, x, w)
  names(out) <- c("mean", "variance")
  out
}

#' Rank correlation and midranks (C backend)
#'
#' `cspr()` is Spearman's rho: the Pearson correlation of
#' the ranks, so it measures monotone association rather than linear
#' association and is unaffected by any order-preserving transformation of
#' either variable. `cmidrk()` exposes the ranks themselves;
#' tied values share the average of the ranks they span, which is what
#' makes the result agree with [stats::cor()] on
#' tied data. Use Spearman's rho when two variables rise and fall together
#' but not along a straight line (counts against rates, incomes against
#' ranks), or when a few extreme values would dominate a Pearson
#' correlation.
#'
#' @details
#' With \eqn{r_i} and \eqn{s_i} the midranks of \eqn{x_i} and \eqn{y_i},
#' \deqn{\rho = \frac{\sum_i (r_i - \bar r)(s_i - \bar s)}
#'   {\sqrt{\sum_i (r_i - \bar r)^2 \sum_i (s_i - \bar s)^2}},}
#' the Pearson correlation of the ranks (Spearman, 1904). Because ties get
#' midranks, the shortcut \eqn{1 - 6 \sum d_i^2 / (n(n^2 - 1))} is NOT what
#' is computed; the full formula above is, and it stays correct with ties.
#'
#' `cspr()` does not remove missing values: an `NA` in either
#' vector gives `NaN`, and so does a constant vector (its ranks have no
#' variance). `cmidrk()` leaves an `NA` in place and ranks the rest,
#' as `rank(x, na.last = "keep")` does. Refusals: vectors of different
#' lengths (`"must have the same length"`) and a character, factor or list
#' argument (`"must be numeric"`). Ranking sorts, so the cost is
#' \eqn{O(n \log n)}.
#'
#' @param x,y Numeric (or logical) vectors of the same length.
#' @return `cspr()`: a length-1 numeric in \eqn{[-1, 1]}
#'   (`NaN` as described above). `cmidrk()`: a numeric vector the
#'   length of `x`, the rank of each value (1 for the smallest; tied values
#'   share the mean of their ranks; `NA` kept as `NA`).
#' @references Spearman C (1904). The proof and measurement of association
#'   between two things. *The American Journal of Psychology* 15(1),
#'   72--101. \doi{10.2307/1412159}
#' @seealso [ccorr()] for the Pearson correlation.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' x <- c(1, 2, 3, 4, 5)
#' y <- c(2, 4, 9, 16, 25)
#'
#' # Perfectly monotone but not linear: rho is 1 where Pearson is not.
#' cspr(x, y)
#' ccorr(x, y)
#'
#' # Agrees with stats::cor(), ties included.
#' xt <- c(1, 2, 2, 2, 5, 5, 7)
#' yt <- c(3, 1, 1, 4, 4, 9, 2)
#' all.equal(cspr(xt, yt), stats::cor(xt, yt, method = "spearman"))
#'
#' # Tied values share the average of the ranks they cover.
#' cmidrk(xt)
#' all.equal(cmidrk(xt), rank(xt))
#'
#' # Invariant to any monotone rescaling.
#' all.equal(cspr(x, y), cspr(exp(x), log(y)))
#'
#' # Missing values are kept in place by cmidrk().
#' cmidrk(c(3, NA, 1, 3))
#' try(cspr(1:3, 1:4))
#' @name crank
#' @export
cspr <- function(x, y) {
  x <- .rmbl_num_input(x, "x")
  y <- .rmbl_num_input(y, "y")
  if (length(x) != length(y)) {
    stop("cspr: `x` and `y` must have the same length", call. = FALSE)
  }
  .Call(C_rmbl_cor_spearman, x, y)
}

#' @rdname crank
#' @export
cmidrk <- function(x) {
  x <- .rmbl_num_input(x, "x")
  out <- rep(NA_real_, length(x))
  ok <- !is.na(x)
  out[ok] <- .Call(C_rmbl_midranks, x[ok])
  out
}

#' Covariance matrix of a numeric matrix (C backend)
#'
#' The covariance of every pair of columns of a numeric matrix or data
#' frame, computed by the compiled core. Covariances describe how
#' variables move together; the matrix is the input to principal
#' components, Mahalanobis distances and multivariate drift checks.
#' Column names are carried through to both dimensions of the result.
#'
#' @details
#' Entry \eqn{(j, k)} is
#' \eqn{\frac{1}{n - 1} \sum_i (x_{ij} - \bar x_j)(x_{ik} - \bar x_k)}, the
#' `n - 1` denominator of [stats::cov()], with which it agrees to
#' rounding.
#' The diagonal holds the column variances.
#'
#' Missing values are not removed: an `NA` in a column makes every
#' covariance involving that column `NA` (pairwise or complete-case
#' deletion is not done; use [stats::cov()] with `use =` for
#' those). A
#' single row gives `NaN` throughout. Refusals: a vector that is not a
#' matrix (`"must be a matrix or data frame"`) and a data frame with a
#' non-numeric column (`"every column of x must be numeric"`). Logical and
#' integer matrices are converted to double. The cost is
#' \eqn{O(n p^2)} for \eqn{n} rows and \eqn{p} columns.
#'
#' @param x A numeric matrix, or a data frame whose columns are all
#'   numeric (rows = observations, columns = variables).
#' @return A symmetric `ncol(x)` by `ncol(x)` numeric matrix, with the
#'   column names of `x` (if any) as both row and column names; entry
#'   units are the product of the two columns' units.
#' @seealso [ccorr()] for a single Pearson correlation,
#'   [cmom()] for one column's variance.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' X <- cbind(a = c(1, 2, 3, 4), b = c(2, 4, 7, 8), c = c(5, 3, 2, 1))
#' ccovm(X)
#'
#' # Agrees with stats::cov().
#' all.equal(ccovm(X), stats::cov(X))
#'
#' # The diagonal is the column variances.
#' all.equal(diag(ccovm(X)), apply(X, 2, stats::var))
#'
#' # Data frames are accepted.
#' ccovm(data.frame(u = 1:5, v = c(2, 1, 4, 3, 6)))
#'
#' # A plain vector is not a matrix of variables.
#' try(ccovm(1:5))
#' @export
ccovm <- function(x) {
  if (is.data.frame(x)) {
    if (!all(vapply(x, is.numeric, logical(1)))) {
      stop("every column of `x` must be numeric", call. = FALSE)
    }
    x <- as.matrix(x)
  }
  if (!is.matrix(x)) stop("`x` must be a matrix or data frame", call. = FALSE)
  storage.mode(x) <- "double"
  out <- .Call(C_rmbl_cov_matrix, x)
  cn <- colnames(x)
  if (!is.null(cn)) dimnames(out) <- list(cn, cn)
  out
}

#' Bootstrap replicate means (C backend)
#'
#' `B` resamples of `x`, drawn with replacement and each the same
#' length as `x`, with the mean of every resample returned. The spread of
#' these replicate means estimates the standard error of the sample mean,
#' and their quantiles give a percentile confidence interval, without
#' assuming the data are normal (Efron and Tibshirani, 1993). The
#' resampling uses the core's own 64-bit Mersenne Twister seeded by
#' `seed`, NOT R's RNG, so a given `seed` reproduces the same
#' replicates in every binding of the core and R's own random stream is
#' left untouched.
#'
#' @details
#' Replicate \eqn{b} draws \eqn{n} indices uniformly from
#' \eqn{1, \dots, n} with replacement (C++ `std::mt19937_64` seeded with
#' `seed`, then `std::uniform_int_distribution`, whose algorithm is the C++
#' library's own, so the replicates for a seed can differ between libstdc++
#' and libc++) and returns the mean of the
#' drawn values, accumulated in extended precision. The replicates are a
#' single stream: the first `B` replicates for a seed are the same whatever
#' larger `B` is asked for later.
#'
#' Edge cases: an empty `x` gives `B` values of `NaN`; an `NA` in
#' `x` makes
#' every replicate that draws it `NA`, so remove missing values first.
#' `B` must be a whole number of at least 1
#' (`"B must be a single whole number >= 1"`); a character, factor or list `x`
#' is refused (`"must be numeric"`). `seed` must be a whole number from 0 to
#' below \eqn{2^{53}}:
#' `NA`, a negative or a fractional seed is refused.
#'
#' Performance: the work is \eqn{B \times n} draws (about 0.4 s for
#' \eqn{B = 2000}, \eqn{n = 20000} on a laptop). The kernel polls for a
#' Ctrl-C after about every million draws, so a long run can be
#' interrupted; while it runs, an interactive session (or one with
#' `options(morie.progress = TRUE)`) shows a spinner on stderr from 0.75 s
#' on, and `options(morie.quiet = TRUE)` silences it.
#'
#' @param x Numeric (or logical) vector to resample.
#' @param B Number of bootstrap replicates, a single whole number of at
#'   least 1 (default 1000).
#' @param seed Seed for the core's generator, a single non-negative whole
#'   number (default 42). It does not use or change [set.seed()]'s
#'   stream.
#' @return A numeric vector of length `B`: the replicate means, in the
#'   units of `x`.
#' @references Efron B, Tibshirani RJ (1993). *An Introduction to the
#'   Bootstrap*. Chapman and Hall.
#' @seealso [exprspplr()] for a bootstrap
#'   of a model estimate.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' set.seed(1)
#' x <- stats::rnorm(50, mean = 5)
#'
#' reps <- cbootmean(x, B = 500, seed = 7)
#' length(reps)
#'
#' # The replicates centre on the sample mean, and their spread estimates
#' # the standard error.
#' c(sample = mean(x), bootstrap = mean(reps))
#' c(bootstrapse = stats::sd(reps),
#'   formulase = stats::sd(x) / sqrt(length(x)))
#'
#' # A percentile confidence interval for the mean.
#' stats::quantile(reps, c(0.025, 0.975))
#'
#' # Reproducible: the same seed gives the same replicates, and R's own
#' # random stream is not consumed.
#' identical(cbootmean(x, 100, seed = 1),
#'           cbootmean(x, 100, seed = 1))
#'
#' # A longer run continues the same stream.
#' identical(cbootmean(x, 10, seed = 1),
#'           cbootmean(x, 100, seed = 1)[1:10])
#'
#' # At least one replicate is needed.
#' try(cbootmean(x, B = 0))
#' @export
#' @srrstats {G5.5} test-core-stats.R runs with set.seed(7) and seed = 11; the same seed reproduces the replicates
#'   exactly.
cbootmean <- function(x, B = 1000L, seed = 42L) {
  x <- .rmbl_num_input(x, "x")
  B <- .rmbl_num(B, "B")
  if (length(B) != 1L || is.na(B) || !is.finite(B) || B < 1 || B != floor(B)) {
    stop("`B` must be a single whole number >= 1", call. = FALSE)
  }
  if (B > .Machine$integer.max) stop("`B` must be at most 2147483647", call. = FALSE)
  seed <- .rmbl_seed(seed)
  # the kernel polls for a Ctrl-C about every million draws, and each poll turns the busy spinner
  .bl_busy(sprintf("bootstrap: %s replicates of %s values", .bl_n(B), .bl_n(length(x))),
           .Call(C_rmbl_bootstrap_mean, as.numeric(x), B, seed))
}

#' Trimmed inverse-probability weights (C backend)
#'
#' The inverse-probability-of-treatment weights \eqn{1/e} for the treated
#' and \eqn{1/(1-e)} for the untreated, with the propensity score clamped
#' into `[trimlo, trimhi]` FIRST. Clamping matters: an untrimmed
#' score near 0 or 1 produces a weight large enough for one observation to
#' dominate the entire estimate. These weights reweight a treated and an
#' untreated group so that each resembles the whole sample on the
#' covariates behind the propensity score, the basis of
#' inverse-probability-weighted estimates of a treatment effect
#' (Rosenbaum and Rubin, 1983).
#'
#' @details
#' For unit \eqn{i} with treatment \eqn{T_i} and propensity \eqn{e_i},
#' the clamped score is \eqn{\tilde e_i = \min(\max(e_i, l), u)} with
#' \eqn{l} = `trimlo` and \eqn{u} = `trimhi`, and the weight is
#' \eqn{1 / \tilde e_i} when \eqn{T_i = 1} and \eqn{1 / (1 - \tilde e_i)}
#' when \eqn{T_i = 0}. With the defaults no weight exceeds 100.
#'
#' Refusals: vectors of different lengths, a treatment coded other than
#' 0/1 (`"treat must be coded 0/1"`, naming the offending values), a
#' propensity outside \eqn{[0, 1]}, and bounds that do not satisfy
#' \eqn{0 < l < u < 1}. A missing treatment or propensity gives a missing
#' weight for that unit only. The weights are not normalised; divide by
#' their sum within each arm for stabilised (Hajek) estimates.
#'
#' @param treat Numeric or logical treatment indicator, coded 0/1
#'   (`1` / `TRUE` is treated); `NA` allowed.
#' @param ps Numeric vector of propensity scores (the estimated
#'   probability of treatment), each in \eqn{[0, 1]}, the same length as
#'   `treat`; `NA` allowed.
#' @param trimlo,trimhi Clamp bounds for the score, single numbers with
#'   `0 < trimlo < trimhi < 1` (defaults 0.01 and 0.99).
#' @return A numeric vector of weights the length of `treat`, each at
#'   least 1 (and at most `1 / trimlo` or `1 / (1 - trimhi)`), `NA`
#'   where
#'   the treatment or propensity is missing.
#' @references Rosenbaum PR, Rubin DB (1983). The central role of the
#'   propensity score in observational studies for causal effects.
#'   *Biometrika* 70(1), 41--55. \doi{10.1093/biomet/70.1.41}
#' @seealso [cwtd()] to average an outcome with
#'   these weights.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' treat <- c(1, 0, 1, 0)
#' e <- c(0.5, 0.25, 0.02, 0.9)
#'
#' cipw(treat, e)
#'
#' # A balanced score gives weight 2 to either arm.
#' cipw(c(1, 0), c(0.5, 0.5))
#'
#' # Without trimming the third observation would carry weight 50; the
#' # default clamp holds it to 100 at the 0.01 floor, and a looser floor
#' # tames it further.
#' cipw(treat, e, trimlo = 0.10)
#'
#' # Logical treatment indicators work too.
#' cipw(c(TRUE, FALSE), c(0.4, 0.4))
#'
#' # A treatment coded 1/2 is refused rather than read as all-control.
#' try(cipw(c(1, 2), c(0.5, 0.5)))
#' @export
cipw <- function(treat, ps, trimlo = 0.01,
                             trimhi = 0.99) {
  treat <- .rmbl_num_input(treat, "treat")
  ps <- .rmbl_num_input(ps, "ps")
  if (length(treat) != length(ps)) {
    stop("`treat` and `ps` must have the same length", call. = FALSE)
  }
  trimlo <- .rmbl_scalar(trimlo, "trimlo", 0, 1)
  trimhi <- .rmbl_scalar(trimhi, "trimhi", 0, 1)
  if (!(trimlo > 0 && trimhi < 1 && trimlo < trimhi)) {
    stop("need 0 < `trimlo` < `trimhi` < 1", call. = FALSE)
  }
  # a 1/2-coded or otherwise non-binary treatment used to send every unit
  # down the control branch, and a propensity outside [0, 1] was clipped
  # to the trim bound and became a weight; both are refused. A missing
  # treatment or propensity gives a missing weight.
  ok_t <- !is.na(treat)
  if (any(!(treat[ok_t] %in% c(0, 1)))) {
    stop("`treat` must be coded 0/1 (got values ",
         paste(utils::head(unique(treat[ok_t][!(treat[ok_t] %in% c(0, 1))]), 3),
               collapse = ", "), ")", call. = FALSE)
  }
  ok_p <- !is.na(ps)
  if (any(ps[ok_p] < 0 | ps[ok_p] > 1)) {
    stop("`ps` must lie in [0, 1]", call. = FALSE)
  }
  out <- rep(NA_real_, length(treat))
  keep <- ok_t & ok_p
  if (any(keep)) {
    out[keep] <- .Call(C_rmbl_ipw, treat[keep], ps[keep], trimlo,
                       trimhi)
  }
  out
}

#' Regularized incomplete gamma function (C backend)
#'
#' The lower regularized incomplete gamma function \eqn{P(a, x)}, which is
#' the CDF of a Gamma distribution with shape `a` and unit rate.
#' Exposed because it is the building block of the chi-square tail used by
#' [drftchisq()] and
#' [benfordtst()]: the p-value of a chi-square statistic
#' \eqn{q} on
#' \eqn{k} degrees of freedom is \eqn{1 - P(k/2, q/2)}.
#'
#' @details
#' \deqn{P(a, x) = \frac{1}{\Gamma(a)} \int_0^x t^{a-1} e^{-t} \, dt,}
#' evaluated by the shared core (a series for small \eqn{x}, a continued
#' fraction otherwise, the standard pairing), and agreeing with
#' `stats::pgamma(x, shape)` to rounding. For a gamma distribution with
#' rate \eqn{r}, pass `x * r`.
#'
#' `shape` must be a single positive number
#' (`"shape must be a single positive number"`). A negative `x` gives 0,
#' a missing `x` gives `NA`, and `Inf` gives 1, as in
#' [stats::pgamma()].
#'
#' @param shape Shape parameter \eqn{a}, a single positive number.
#' @param x Numeric vector of quantiles.
#' @return A numeric vector the length of `x`, each entry a probability in
#'   \eqn{[0, 1]}.
#' @seealso [stats::pgamma()], the base R equivalent.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' cgamcdf(3.5, c(0.5, 1, 4, 12))
#'
#' # Identical to the unit-rate gamma CDF.
#' all.equal(cgamcdf(3.5, c(0.5, 1, 4, 12)),
#'           stats::pgamma(c(0.5, 1, 4, 12), shape = 3.5))
#'
#' # Shape 1 is the exponential distribution.
#' all.equal(cgamcdf(1, c(0.5, 2)), stats::pexp(c(0.5, 2)))
#'
#' # A chi-square tail on k degrees of freedom is 1 - P(k/2, q/2).
#' 1 - cgamcdf(2 / 2, 5.99 / 2)      # about 0.05 on 2 df
#'
#' # The shape must be positive.
#' try(cgamcdf(0, 1))
#' @export
cgamcdf <- function(shape, x) {
  shape <- .rmbl_num(shape, "shape")
  if (length(shape) != 1L || is.na(shape) || shape <= 0) {
    stop("`shape` must be a single positive number", call. = FALSE)
  }
  .Call(C_rmbl_gamma_cdf, shape, .rmbl_num(x, "x"))
}

#' Hawkes-process negative log-likelihood (C backend)
#'
#' The negative log-likelihood of a univariate self-exciting Hawkes process
#' with constant baseline on `[0, horizon]`, for the event times
#' `times`. A Hawkes process is the natural model for arrivals that
#' trigger further arrivals -- repeat calls to a service, aftershocks,
#' retweet cascades, revisions to an open-data release.
#'
#' Four triggering kernels are available. `"exponential"` is
#' memoryless and evaluates by an O(n) recursion; the other three are not,
#' so they cost O(n^2).
#'
#' Parameters are passed on the scales the kernel is defined on:
#' `par = c(a0, eta, ...)` where `a0` is the LOG baseline
#' intensity ( \eqn{\nu = e^{a0}}) and `eta` the branching ratio in
#' (0, 1) -- the expected number of children per event, so the process is
#' stationary only for `eta < 1`. The remaining entries are the
#' kernel's own shape parameters: `beta` (exponential),
#' `alpha, lambda` (Weibull: shape and scale), `alpha, c` (Lomax: shape
#' and scale, \eqn{g(u) = \alpha c^\alpha (u + c)^{-(\alpha + 1)}}),
#' `alpha, beta` (gamma: shape and rate). This is the likelihood
#' [chwkfit()] maximises, on the same parameters.
#'
#' @details
#' The conditional intensity is
#' \eqn{\lambda(t) = \nu + \eta \sum_{t_i < t} g(t - t_i)} with \eqn{g} a
#' probability density on \eqn{(0, \infty)} (so \eqn{\eta} is the
#' branching ratio), and the value returned is
#' \deqn{-\ell = -\sum_i \log \lambda(t_i) + \int_0^T \lambda(t)\,dt,}
#' with \eqn{T} = `hor` (Hawkes, 1971). For the exponential kernel
#' \eqn{g(u) = \beta e^{-\beta u}}. With no events the value is the
#' compensator alone, \eqn{\nu T}.
#'
#' The feasible region, outside which the sentinel `1e12` is returned
#' instead of a value: \eqn{-20 < a_0 < 20}; \eqn{10^{-6} < \eta < 0.999};
#' and for the kernel parameters, exponential \eqn{0.05 \le \beta \le 30};
#' Weibull shape in \eqn{[0.05, 20]} and scale in \eqn{[0.001, 1000]};
#' Lomax shape in \eqn{[0.05, 30]} and scale in \eqn{[0.001, 100]}; gamma
#' shape in \eqn{[0.05, 20]} and rate in \eqn{[0.05, 30]}. A missing
#' parameter also gives the sentinel.
#'
#' Refusals (errors, not the sentinel): `times` with a missing value, not
#' sorted, or outside \eqn{[0, T]}; a `hor` that is not a single
#' positive finite number; a `kernel` not among the four; and a `par` of
#' the wrong length for the kernel. The quadratic kernels poll for a
#' Ctrl-C as they run, so a long evaluation can be interrupted.
#'
#' @param times Numeric vector of event times, sorted increasing, each in
#'   `[0, horizon]`, in the time unit of your data (days, hours, ...).
#'   May be empty.
#' @param hor End of the observation window, a single positive finite
#'   number in the same unit; the window starts at 0.
#' @param kernel The triggering kernel, one of `"exponential"` (the
#'   default), `"weibull"`, `"lomax"` and `"gamma"`. Partial names are
#'   matched.
#' @param par Numeric parameter vector, as described above: length 3
#'   (`a0`, `eta`, `beta`) for `"exponential"`, length 4 (`a0`,
#'   `eta` and
#'   the kernel's two parameters) for the others. Rates are per unit of
#'   `times`.
#' @return A length-1 numeric: the negative log-likelihood, to be
#'   MINIMISED. A parameter set outside the feasible region returns the
#'   sentinel `1e12` rather than erroring, so the value can be handed
#'   straight to [stats::optim()] without the optimiser walking off
#'   the
#'   domain.
#' @references Hawkes AG (1971). Spectra of some self-exciting and mutually
#' exciting point processes. *Biometrika* 58(1), 83--90.
#'   \doi{10.1093/biomet/58.1.83}
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' set.seed(4)
#' times <- sort(stats::runif(40, 0, 10))
#'
#' # Exponential kernel: log-baseline -0.5, branching 0.3, decay 1.2.
#' chwknll(times, 10, "exponential", c(-0.5, 0.3, 1.2))
#'
#' # Lower is better, so this is what an optimiser minimises.
#' nll <- function(p) chwknll(times, 10, "exponential", p)
#' fit <- stats::optim(c(-0.5, 0.3, 1.2), nll)
#' fit$par
#'
#' # A branching ratio at or above 1 is not a stationary process, and is
#' # reported as the infeasible sentinel rather than a number.
#' chwknll(times, 10, "exponential", c(-0.5, 1.5, 1.2)) == 1e12
#'
#' # The heavier-tailed kernels take two shape parameters.
#' chwknll(times, 10, "gamma", c(-0.5, 0.3, 2, 1.5))
#'
#' # Unsorted times are an error, not the sentinel.
#' try(chwknll(rev(times), 10, "exponential", c(-0.5, 0.3, 1.2)))
#' @export
#' @srrstats {TS2.3} The docs say the process is stationary only for eta < 1, and the example shows eta >= 1 returns
#'   the infeasible sentinel; stepchg documents its exchangeability assumption.
chwknll <- function(times, hor,
                            kernel = c("exponential", "weibull", "lomax",
                                       "gamma"),
                            par) {
  if (missing(par)) stop("`par` must be the kernel parameters", call. = FALSE)
  kernel <- .rmbl_arg(kernel)
  code <- switch(kernel, exponential = 0L, weibull = 1L, lomax = 2L,
                 gamma = 3L)
  times <- .rmbl_num(times, "times")
  if (anyNA(times)) stop("chwknll: `times` must not contain NA", call. = FALSE)
  if (length(times) > 1L && any(diff(times) < 0)) {
    stop("chwknll: `times` must be sorted in increasing order", call. = FALSE)
  }
  hor <- .rmbl_num(hor, "hor")
  if (length(hor) != 1L || !is.finite(hor) || hor <= 0) {
    stop("chwknll: `hor` must be a single positive finite number", call. = FALSE)
  }
  if (length(times) > 0L && (min(times) < 0 || max(times) > hor)) {
    stop("`times` must lie within [0, hor]", call. = FALSE)
  }
  par <- .rmbl_num(par, "par")
  need <- if (code == 0L) 3L else 4L
  if (length(par) != need) {
    stop(sprintf("the %s kernel needs `par` of length %d", kernel, need),
         call. = FALSE)
  }
  # outside the feasible region, the documented sentinel: a stationary branching ratio, a
  # bounded log-baseline and the kernel parameters' ranges (those of the earlier routine;
  # the Lomax takes chwkfit()'s)
  lo <- switch(kernel, exponential = 0.05, weibull = c(0.05, 1e-3), gamma = c(0.05, 0.05), lomax = c(0.05, 1e-3))
  hi <- switch(kernel, exponential = 30, weibull = c(20, 1e3), gamma = c(20, 30), lomax = c(30, 100))
  psi <- par[-(1:2)]
  if (anyNA(par) || !(par[[2L]] > 1e-6 && par[[2L]] < 0.999) || !(par[[1L]] > -20 && par[[1L]] < 20) ||
      any(psi < lo) || any(psi > hi)) {
    return(1e12)
  }
  # the likelihood chwkfit() maximises (the shared C++ core), so the
  # two agree for every kernel; the Lomax is g(u) = alpha c^alpha / (u + c)^(alpha + 1)
  .rmbl_hk_call(times, hor, kernel, "constant", par, "exact", 1e-12, FALSE)[[1L]]
}
