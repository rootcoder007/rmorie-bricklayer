# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The Truth and Reconciliation Commission's Calls to Action 19 (health gaps) and
# 55 (annual reporting), measured from the published tables: which table
# measures which indicator, and every gap in one place.

#' The indicators of Calls to Action 19 and 55, and the tables that measure them
#'
#' Call to Action 19 asks the federal government to \dQuote{establish measurable
#' goals to identify and close the gaps in health outcomes between Aboriginal
#' and non-Aboriginal communities, and to publish annual progress reports and
#' assess long-term trends}, focusing on \dQuote{infant mortality, maternal
#' health, suicide, mental health, addictions, life expectancy, birth rates,
#' infant and child health issues, chronic diseases, illness and injury
#' incidence, and the availability of appropriate health services}. Call to
#' Action 55 asks for annual data on, among others, \dQuote{the number of
#' Aboriginal children--including Metis and Inuit children--in care, compared
#' with non-Aboriginal children} and \dQuote{the educational and income
#' attainments of Aboriginal peoples in Canada compared with non-Aboriginal
#' people}. This lists, for each indicator, the Statistics Canada tables at the
#' data service (or the census profile) that measure it, the measure, and which
#' direction is better.
#'
#' @details The list is a map of what the published tables can measure, not a
#' judgement of what the Calls require: maternal health is measured here only
#' through birth outcomes in Inuit regions, and several indicators (addictions,
#' the availability of services) only through proxies. The direction is the
#' direction of better health for the people measured.
#'
#' @return A data frame with \code{call}, \code{indicator} (the Call's words),
#'   \code{table}, \code{measure}, \code{better} (\code{"higher"} or
#'   \code{"lower"}) and \code{note}.
#' @references Truth and Reconciliation Commission of Canada (2015). Truth and
#' Reconciliation Commission of Canada: Calls to Action. Winnipeg. Government of
#' Canada catalogue IR4-8/2015E.
#' publications.gc.ca/collections/collection_2015/trc/IR4-8-2015-eng.pdf
#' @seealso \code{\link{trchlthgap}}, \code{\link{trcprog}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' ti <- trcind()
#' ti[ti$call == "19", c("indicator", "table", "measure", "better")]
#' @export
trcind <- function() {
  r <- function(call, indicator, table, measure, better, note = "") {
    data.frame(
      call = call,
      indicator = indicator,
      table = table,
      measure = measure,
      better = better,
      note = note,
      stringsAsFactors = FALSE
    )
  }
  do.call(
    rbind,
    list(
      r(
        "19",
        "infant mortality",
        "17-10-0161",
        "Infant mortality rate",
        "lower",
        "by Indigenous identity, Canada; Inuit regions in 13-10-0100"
      ),
      r(
        "19",
        "maternal health",
        "13-10-0064",
        "Low birth weight; Pre-term births",
        "lower",
        "birth outcomes only, Canada and Inuit regions"
      ),
      r(
        "19",
        "suicide",
        "41-10-0021",
        "Seriously contemplated suicide in the past 12 months",
        "lower",
        "suicidal thoughts; deaths by cause in Inuit regions in 13-10-0157"
      ),
      r(
        "19",
        "mental health",
        "13-10-0924",
        "Perceived mental health, very good or excellent",
        "higher"
      ),
      r("19", "mental health", "13-10-0924", "Mood disorder", "lower"),
      r("19", "mental health", "13-10-0924", "Anxiety disorder", "lower"),
      r(
        "19",
        "mental health",
        "13-10-0924",
        "Perceived life stress, most days quite a bit or extremely stressful",
        "lower"
      ),
      r("19", "addictions", "13-10-0924", "Heavy drinking", "lower", "a proxy"),
      r(
        "19",
        "addictions",
        "13-10-0924",
        "Current smoker, daily or occasional",
        "lower",
        "a proxy"
      ),
      r(
        "19",
        "life expectancy",
        "17-10-0160",
        "Life expectancy at birth",
        "higher",
        paste0(
          "by Indigenous identity, Canada and regions; Inuit regions in ",
          "13-10-0403"
        )
      ),
      r(
        "19",
        "birth rates",
        "census profile",
        "Population aged 0 to 4",
        "",
        "no direction: a measure of population, not of health"
      ),
      r(
        "19",
        "infant and child health issues",
        "13-10-0064",
        "Small for gestational age",
        "lower",
        "Canada and Inuit regions"
      ),
      r(
        "19",
        "chronic diseases",
        "13-10-0924",
        "At least one underlying chronic health condition",
        "lower"
      ),
      r("19", "chronic diseases", "13-10-0924", "Diabetes", "lower"),
      r("19", "chronic diseases", "13-10-0924", "High blood pressure", "lower"),
      r("19", "chronic diseases", "13-10-0924", "Arthritis", "lower"),
      r(
        "19",
        "illness and injury incidence",
        "13-10-0157",
        "Mortality",
        "lower",
        "deaths by cause, injuries among them, Canada and Inuit regions"
      ),
      r(
        "19",
        "availability of appropriate health services",
        "13-10-0924",
        "Has a regular healthcare provider",
        "higher",
        "a proxy: having a provider, not its cultural safety"
      ),
      r(
        "55",
        "children in care",
        "census profile",
        "Foster children",
        "lower",
        "foster children among children in census families (profshr)"
      ),
      r(
        "55",
        "educational attainment",
        "census profile",
        "No certificate, diploma or degree",
        "lower",
        "aged 25 and over"
      ),
      r(
        "55",
        "educational attainment",
        "census profile",
        "Bachelor's degree or higher",
        "higher",
        "aged 25 and over"
      ),
      r(
        "55",
        "income attainment",
        "census profile",
        paste0(
          "Prevalence of low income based on the Low-income measure, ",
          "after tax (LIM-AT) (%)"
        ),
        "lower"
      ),
      r(
        "55",
        "income attainment",
        "census profile",
        "Average total income in 2020 among recipients ($)",
        "higher"
      )
    )
  )
}

#' The Call to Action 19 health gaps, in one place
#'
#' For each health indicator of Call to Action 19 that the published tables
#' measure, each group's estimate against non-Indigenous people's, with its
#' interval, turned into one scale, the disadvantage ratio: the factor by which
#' the group's outcome is worse (above
#' 1) or better (below 1).
#'
#' @details The gaps come from \code{\link{indgap}} on the latest period of each
#' table, with \code{ref} (non-Indigenous people) as the reference. To put
#' years, rates and percentages on one scale, each gap is given as a ratio
#' oriented by the indicator's better direction (\code{\link{trcind}}): the
#' group's estimate over the reference's where lower is better (infant
#' mortality, chronic conditions), the reference's over the group's where higher
#' is better (life expectancy, good mental health, a regular provider): \deqn{D
#' = \hat\theta_g / \hat\theta_r \ \textrm{(lower is better)}, \qquad D =
#' \hat\theta_r / \hat\theta_g \ \textrm{(higher is better)}.}{D = g / r (lower
#' is better), D = r / g (higher is better).} It is a ratio of the published
#' estimates, not a relative risk: for life expectancy, D = 1.1 means the
#' reference lives 10% longer, not that the group's risk is 10% higher. Above 1
#' the group fares worse; the interval is the published one carried through
#' (\code{indgap}'s log-scale interval, inverted where needed). The difference
#' on the indicator's own scale is kept beside it.
#'
#' This is a description of gaps that Call 19 asks to be closed, measured as the
#' surveys measure them; it is not a ranking of peoples. Report it with the
#' trends (\code{\link{healchg}}) and the strengths (\code{\link{welprof}}) that
#' sit beside it.
#'
#' Each table is in the long layout of \code{\link{scests}} (or
#' \code{indiex()}): columns \code{group}, \code{indicator} or \code{measure},
#' \code{period}, \code{estimate}, \code{lower}, \code{upper}, \code{quality},
#' and \code{age} for the health and suicidal-ideation tables (the all-ages
#' total is used). The latest period with estimates is taken. Table 41-10-0021
#' publishes Indigenous groups only, so it adds a gap only when given a table
#' with \code{ref} rows.
#'
#' @param health A health indicators table (default
#'   \code{indiex("health")}, table 13-10-0924), or \code{NULL}.
#' @param lifeexp Life expectancy (default
#'   \code{indiex("lifeexp")}, table 17-10-0160), or \code{NULL}.
#' @param infmort Infant mortality (default
#'   \code{indiex("infmort")}, table 17-10-0161), or \code{NULL}.
#' @param suiide Suicidal thoughts (default
#'   \code{indiex("suiide")}, table 41-10-0021), or \code{NULL}.
#' @param ref The reference group's label (default \code{"Non-Indigenous"}).
#' @return A data frame of class \code{rmbl_trc_gaps}: \code{indicator},
#'   \code{measure}, \code{period}, \code{group}, \code{estimate},
#'   \code{refest}, \code{difference} (group minus reference, on the indicator's
#'   scale), \code{disratio}, \code{lower}, \code{upper}, \code{worse} (the
#'   interval above 1), \code{usewithcau}. \code{plot()} draws it.
#' @references Truth and Reconciliation Commission of Canada (2015), see
#'   \code{\link{trcind}}.
#' @seealso \code{\link{trcind}}, \code{\link{indgap}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' g <- trchlthgap()
#' g[g$group == "Inuit", c("indicator", "measure", "period", "disratio",
#'                         "lower",
#'                         "upper")]
#' plot(g)
#' @export
trchlthgap <- function(
  health = indiex("health"),
  lifeexp = indiex("lifeexp"),
  infmort = indiex("infantmort"),
  suiide = indiex("suicide"),
  ref = "Non-Indigenous"
) {
  ref <- .rmbl_string1(ref, "ref")
  for (nm in c("health", "lifeexp", "infmort", "suiide")) {
    v <- get(nm)
    if (is.null(v)) {
      next
    }
    if (!is.data.frame(v) || !all(c("group", "estimate") %in% names(v))) {
      stop(
        sprintf(
          paste(
            "`%s` must be a data frame of indicators as indiex()",
            "returns them (columns group,",
            "estimate): the tables must be data frames or NULL"
          ),
          nm
        ),
        call. = FALSE
      )
    }
  }
  ti <- trcind()
  ti <- ti[ti$call == "19" & nzchar(ti$better), ]
  pieces <- list()
  one <- function(d, measure, period, indicator, better) {
    d <- d[!is.na(d$group), ]
    if (!ref %in% d$group) {
      return(NULL)
    }
    if (anyDuplicated(d$group)) {
      warning(
        sprintf(
          paste0(
            "%s (%s): more than one row per group, skipped; filter the ",
            "table to one row each"
          ),
          measure,
          period
        ),
        call. = FALSE
      )
      return(NULL)
    }
    g <- suppressWarnings(indgap(
      d,
      "group",
      "estimate",
      "lower",
      "upper",
      ref = ref,
      qual = "quality"
    ))
    low <- better == "lower"
    data.frame(
      indicator = indicator,
      measure = measure,
      period = period,
      group = g$group,
      estimate = g$estimate,
      refest = g$refest,
      difference = g$difference,
      disratio = if (low) g$ratio else 1 / g$ratio,
      lower = if (low) g$ratiolo else 1 / g$ratioup,
      upper = if (low) g$ratioup else 1 / g$ratiolo,
      usewithcau = g$usewithcau,
      stringsAsFactors = FALSE
    )
  }
  latest <- function(p) sort(unique(p))[length(unique(p))]
  if (!is.null(health)) {
    h <- health[health$age == "Total, 18 years and over", ]
    pr <- latest(h$period)
    for (i in which(ti$table == "13-10-0924")) {
      d <- h[h$period == pr & h$indicator == ti$measure[i], ]
      pieces[[length(pieces) + 1L]] <- one(
        d,
        ti$measure[i],
        pr,
        ti$indicator[i],
        ti$better[i]
      )
    }
  }
  for (src in list(list(lifeexp, "17-10-0160"), list(infmort, "17-10-0161"))) {
    d <- src[[1L]]
    if (is.null(d)) {
      next
    }
    i <- which(ti$table == src[[2L]])
    ok <- d[is.finite(d$estimate), ]
    pr <- latest(ok$period)
    pieces[[length(pieces) + 1L]] <- one(
      d[d$period == pr, ],
      ti$measure[i],
      pr,
      ti$indicator[i],
      ti$better[i]
    )
  }
  if (!is.null(suiide)) {
    i <- which(ti$table == "41-10-0021")
    d <- suiide[
      suiide$measure == ti$measure[i] &
        suiide$age == "Total, 15 years and over",
    ]
    # 41-10-0021 has no non-Indigenous rows: Indigenous groups only, so it is
    # not part of the gaps
    if (ref %in% d$group) {
      pieces[[length(pieces) + 1L]] <- one(
        d,
        ti$measure[i],
        "2017",
        ti$indicator[i],
        ti$better[i]
      )
    }
  }
  out <- do.call(rbind, pieces)
  if (is.null(out)) {
    stop(
      sprintf(
        "no table given measures a Call 19 indicator against \"%s\"",
        ref
      ),
      call. = FALSE
    )
  }
  out$worse <- is.finite(out$lower) & out$lower > 1
  rownames(out) <- NULL
  class(out) <- c("rmbl_trc_gaps", "data.frame")
  out
}

#' @rdname plot-methods
#' @export
plot.rmbl_trc_gaps <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_trc_gaps")
  d <- as.data.frame(x)
  d <- d[is.finite(d$disratio), ]
  grp <- unique(d$group)
  cols <- .bl_cols(length(grp), col, palette)[match(d$group, grp)]
  grp_short <- sub(
    "^First Nations \\(Registered or Treaty\\)",
    "FN registered",
    d$group
  )
  grp_short <- sub(
    "^First Nations, without registered status",
    "FN not registered",
    grp_short
  )
  meas <- sub("^Life expectancy at birth$", "Life expectancy", d$measure)
  meas <- sub("^Infant mortality rate$", "Infant mortality", meas)
  lab <- paste0(
    .bl_short_label(meas, 24L),
    ": ",
    .bl_short_label(grp_short, 26L),
    ifelse(d$usewithcau, " (E)", "")
  )
  .bl_dot_interval(
    lab,
    d$disratio,
    d$lower,
    d$upper,
    .bl_main(
      main,
      "Call to Action 19: health gaps against non-Indigenous people"
    ),
    "Disadvantage ratio against the reference (log scale; 1 = no gap)",
    cols,
    ref = 1,
    log = "x",
    key = list(
      legend = grp_short[match(grp, d$group)],
      col = .bl_cols(length(grp), col, palette)
    ),
    ...
  )
  invisible(d[c("indicator", "measure", "group", "disratio", "lower", "upper")])
}
