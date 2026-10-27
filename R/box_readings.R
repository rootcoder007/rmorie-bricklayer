# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The readings of the boxed results: plain sentences built from the numbers
# of the result itself (which group is highest, whether an interval clears
# the value of no difference, whether a test rejects at the result's level),
# so that two different results never read the same. The format() methods
# put the definitions of their measures in the notes and these sentences in
# the reading.

#' Labels as an English list: "a, b and c", the rest counted.
#' @param lab The labels to list.
#' @param most The most labels named.
#' @return One string ("none" for no labels).
#' @noRd
.rd_list <- function(lab, most = 5L) {
  lab <- as.character(lab)
  n <- length(lab)
  if (!n) {
    return("none")
  }
  if (n > most) {
    return(sprintf(
      "%s and %d more",
      toString(lab[seq_len(most)]),
      n - most
    ))
  }
  if (n == 1L) {
    return(lab)
  }
  paste(toString(lab[-n]), "and", lab[n])
}

#' A number with its interval, "4.42 \[4.29, 4.56\]", for a sentence.
#' @param v The number shown.
#' @param lo,hi Its bounds, or NULL.
#' @return One string.
#' @noRd
.rd_num_ci <- function(v, lo = NULL, hi = NULL) {
  s <- .rd_num(v)
  if (length(lo) && length(hi) && is.finite(lo) && is.finite(hi)) {
    s <- paste(s, .rmbl_fmt_ci(lo, hi))
  }
  s
}

#' A number for a sentence: four significant digits, but whole thousands
#' and more in full, so 13,796 never reads as 13800.
#' @param v The number written out.
#' @return One string.
#' @noRd
.rd_num <- function(v) {
  if (is.finite(v) && abs(v) >= 1000) {
    return(formatC(round(v), format = "d", big.mark = ","))
  }
  .rmbl_fmt_num(v)
}

#' Which groups are highest and lowest, and whether their intervals part.
#' @param lab The group labels, one per estimate.
#' @param est Their estimates.
#' @param lo,hi Their bounds, or NULL.
#' @param what The name of the estimate in the sentence, e.g. "rate".
#' @return One or two sentences.
#' @noRd
.rd_groups <- function(lab, est, lo = NULL, hi = NULL, what = "estimate") {
  ok <- which(is.finite(est))
  if (!length(ok)) {
    return(sprintf("No group has a %s to compare.", what))
  }
  b <- function(v, i) if (length(v)) v[i]
  if (length(ok) == 1L) {
    return(sprintf(
      "%s: %s %s.",
      lab[ok],
      what,
      .rd_num_ci(est[ok], b(lo, ok), b(hi, ok))
    ))
  }
  i <- ok[which.max(est[ok])]
  j <- ok[which.min(est[ok])]
  if (est[i] == est[j]) {
    return(sprintf(
      "Every group has the same %s, %s.",
      what,
      .rd_num(est[i])
    ))
  }
  top <- sprintf(
    "Highest %s: %s (%s); lowest: %s (%s).",
    what,
    lab[i],
    .rd_num(est[i]),
    lab[j],
    .rd_num(est[j])
  )
  c(top, .rd_apart(b(lo, i), b(hi, j)))
}

#' Whether the interval of the highest group lies above that of the lowest.
#' @param top_lo The lower bound of the highest group, or NULL.
#' @param bottom_hi The upper bound of the lowest group, or NULL.
#' @return One sentence, or NULL without both bounds.
#' @noRd
.rd_apart <- function(top_lo, bottom_hi) {
  if (!length(top_lo) || !length(bottom_hi) || !is.finite(top_lo) ||
    !is.finite(bottom_hi)) {
    return(NULL)
  }
  if (top_lo > bottom_hi) {
    "Their intervals do not overlap: the gap is more than sampling error."
  } else {
    "Their intervals overlap: the data cannot tell the two apart."
  }
}

#' Which rows lie above, below or across the value of no difference.
#' @param lab The row labels, one per interval.
#' @param lo,hi Their bounds.
#' @param null The value of no difference (0 for a difference, 1 for a
#'   ratio).
#' @param up,down How a row above and below it reads, e.g. "Above the
#'   reference".
#' @return Sentences, one for each side that has rows.
#' @noRd
.rd_null <- function(lab, lo, hi, null, up, down) {
  known <- is.finite(lo) & is.finite(hi)
  above <- known & lo > null
  below <- known & hi < null
  mid <- known & !above & !below
  nv <- format(null)
  c(
    if (any(above)) {
      sprintf("%s (interval above %s): %s.", up, nv, .rd_list(lab[above]))
    },
    if (any(below)) {
      sprintf("%s (interval below %s): %s.", down, nv, .rd_list(lab[below]))
    },
    if (any(mid)) {
      sprintf(
        "Not distinguishable from %s (interval includes it): %s.",
        nv,
        .rd_list(lab[mid])
      )
    },
    if (!any(known)) "No row has an interval to judge it by."
  )
}

#' Whether a test rejects at a level, in a sentence.
#' @param p The test's p-value.
#' @param alpha The level it is judged at.
#' @param yes What a rejection means.
#' @param no What no rejection means.
#' @return One sentence.
#' @noRd
.rd_test <- function(p, alpha, yes, no) {
  if (!length(p) || !is.finite(p[1L])) {
    return("The test has no p-value, so it decides nothing.")
  }
  pt <- sprintf("p %s", .rmbl_p_txt(p[1L]))
  if (p[1L] < alpha) {
    sprintf("%s (%s, below %s).", yes, pt, format(alpha))
  } else {
    sprintf("%s (%s, not below %s).", no, pt, format(alpha))
  }
}

#' The level a result's interval implies for its tests: 1 - conflvl, or 0.05.
#' @param conflvl The confidence level recorded, or NULL.
#' @return One number.
#' @noRd
.rd_alpha <- function(conflvl) {
  if (is.numeric(conflvl) && length(conflvl) == 1L && is.finite(conflvl)) {
    return(signif(1 - conflvl, 6L))
  }
  0.05
}

# ---- the readings of the results, by family ----------------------------------

#' Group labels with " (pooled)" where the row is a pan-Indigenous total.
#' @param lab The labels as shown.
#' @param flag The rows' pooled flags (poogrp), or NULL.
#' @return The labels.
#' @noRd
.an_pooled <- function(lab, flag) {
  paste0(lab, ifelse(.an_true(flag), " (pooled)", ""))
}

#' The reading of an exposure trend: how the odds at the highest level
#' compare with the lowest, and what the trend test says.
#' @param d The exptrnd() rows, lowest level first.
#' @param tr The trend test (an htest), or NULL.
#' @return Sentences.
#' @noRd
.an_et_reading <- function(d, tr) {
  k <- nrow(d)
  or <- d$orratio[k]
  s1 <- if (k > 1L && is.finite(or)) {
    sprintf(
      paste0(
        "At the highest level (%s) the odds of a case are %s times those ",
        "at the lowest (%s)."
      ),
      format(d$dose[k]),
      .rd_num_ci(or, d$lower[k], d$upper[k]),
      format(d$dose[1L])
    )
  }
  s2 <- if (inherits(tr, "htest")) {
    .rd_test(
      tr$p.value,
      0.05,
      sprintf(
        "The odds %s with exposure: the trend test rejects a flat trend",
        if (isTRUE(or < 1)) "fall" else "rise"
      ),
      "The trend test finds no steady change in the odds with exposure"
    )
  }
  c(s1, s2)
}

#' The reading of a wellness profile: on how many indicators the highest
#' and the lowest group are apart by more than their intervals.
#' @param d The welprof() rows.
#' @return Sentences.
#' @noRd
.an_wp_reading <- function(d) {
  ind <- unique(d$indicator)
  apart <- vapply(
    ind,
    function(k) {
      g <- d[d$indicator == k & is.finite(d$estimate), , drop = FALSE]
      if (nrow(g) < 2L) {
        return(FALSE)
      }
      i <- which.max(g$estimate)
      j <- which.min(g$estimate)
      isTRUE(g$lower[i] > g$upper[j])
    },
    NA
  )
  if (!any(apart)) {
    return(sprintf(
      "On none of the %d indicators do the groups' intervals part: %s",
      length(ind),
      "the data cannot rank the groups on any of them."
    ))
  }
  sprintf(
    paste0(
      "On %d of %d indicators the highest and lowest groups' intervals do ",
      "not overlap: %s."
    ),
    sum(apart),
    length(ind),
    .rd_list(ind[apart], 3L)
  )
}

#' The reading of a holistic balance: the most and least balanced groups and
#' the domain that most often falls behind.
#' @param d The holbal() rows.
#' @return Sentences.
#' @noRd
.an_hb_reading <- function(d) {
  tb <- sort(table(d$weadom), decreasing = TRUE)
  c(
    .rd_groups(
      .an_star(d$group, d$usewithcau),
      d$balance,
      d$ballo,
      d$balup,
      "balance"
    ),
    if (length(tb)) {
      sprintf(
        "The weakest domain is %s for %d of %d groups.",
        names(tb)[1L],
        as.integer(tb[1L]),
        nrow(d)
      )
    }
  )
}

#' The highest and lowest direction of each group of a wellness continuum.
#' @param d The mhcont() rows.
#' @return One sentence per group with two or more levels.
#' @noRd
.an_wc_levels <- function(d) {
  unlist(lapply(unique(d$group), function(g) {
    r <- d[d$group == g & is.finite(d$estimate), , drop = FALSE]
    if (nrow(r) < 2L) {
      return(NULL)
    }
    i <- which.max(r$estimate)
    j <- which.min(r$estimate)
    sprintf(
      "%s: highest %s (%s), lowest %s (%s).",
      g,
      r$indicator[i],
      .rmbl_fmt_num(r$estimate[i]),
      r$indicator[j],
      .rmbl_fmt_num(r$estimate[j])
    )
  }))
}

#' Which way the two sides of a healing change moved, by more than chance.
#' @param d The healchg() rows.
#' @return Sentences.
#' @noRd
.an_hc_sides <- function(d) {
  up <- d$lower > 0
  dn <- d$upper < 0
  n <- function(v, side) sum(v & d$side == side, na.rm = TRUE)
  wu <- n(up, "wellness")
  wd <- n(dn, "wellness")
  du <- n(up, "distress")
  dd <- n(dn, "distress")
  verdict <- if (wd > wu && du > dd) {
    "Both sides point away from healing: wellness down, distress up."
  } else if (wu > wd && dd > du) {
    "Both sides point toward healing: wellness up, distress down."
  } else if (wu + wd + du + dd == 0L) {
    "No change is larger than its interval, on either side."
  } else {
    "The two sides do not point the same way."
  }
  c(
    sprintf(
      paste0(
        "Wellness: %d rose and %d fell by more than chance; distress: %d ",
        "rose and %d fell."
      ),
      wu,
      wd,
      du,
      dd
    ),
    verdict
  )
}

#' The columns of a tidied census profile shown in its block: every column
#' it holds, the value with thousands separators.
#' @param df The rows shown.
#' @return A data frame.
#' @noRd
.an_cp_table <- function(df) {
  cols <- c(
    "geo", "dguid", "geolvl", "residence", "gender", "age", "group", "chaid",
    "characteristic", "level", "parid", "rootid", "value", "sample",
    "quality", "tnrsf", "tnrlf"
  )
  out <- df[intersect(cols, names(df))]
  if ("value" %in% names(out)) {
    out$value <- .an_count(out$value)
  }
  rownames(out) <- NULL
  out
}

#' The reading of a census profile: how many values carry a quality flag.
#' @param d The profile rows.
#' @return Sentences.
#' @noRd
.an_cp_reading <- function(d) {
  q <- as.character(d$quality %||% rep(NA_character_, nrow(d)))
  bad <- !is.na(q) & q != "ok"
  s1 <- sprintf(
    "%s values of %d characteristics in %d geographies.",
    format(nrow(d), big.mark = ","),
    length(unique(d$chaid)),
    length(unique(d$geo))
  )
  s2 <- if (any(bad)) {
    sprintf(
      "%d %s a quality flag (%s): read those with caution.",
      sum(bad),
      if (sum(bad) == 1L) "carries" else "carry",
      .an_counts(q[bad])
    )
  } else {
    "None carries a quality flag."
  }
  c(s1, s2)
}

#' Row labels of a census share: the geography, residence, gender, age and
#' group columns that vary across its rows.
#' @param d The share rows.
#' @return One label per row.
#' @noRd
.an_ps_labels <- function(d) {
  cols <- intersect(c("geo", "residence", "gender", "age", "group"), names(d))
  vary <- cols[vapply(cols, function(k) length(unique(d[[k]])) > 1L, NA)]
  if (!length(vary)) {
    vary <- cols[length(cols)]
  }
  if (!length(vary)) {
    return(paste("row", seq_len(nrow(d))))
  }
  do.call(paste, c(lapply(d[vary], as.character), sep = ", "))
}

#' The reading of a census CWB table: the highest and lowest scores, and the
#' geography where the groups are furthest apart.
#' @param d The cnscwb() rows.
#' @return Sentences.
#' @noRd
.an_cwb_reading <- function(d) {
  lab <- paste0(d$geo, ", ", d$group)
  gap <- vapply(
    split(d$cwb, d$geo),
    function(v) {
      if (sum(is.finite(v)) > 1L) diff(range(v, na.rm = TRUE)) else NA
    },
    1
  )
  gap <- gap[is.finite(gap)]
  c(
    .rd_groups(lab, d$cwb, what = "score"),
    if (length(gap)) {
      sprintf(
        paste0(
          "Within a geography the groups' scores are furthest apart in %s ",
          "(%s points) and closest in %s (%s)."
        ),
        names(gap)[which.max(gap)],
        .rmbl_fmt_num(max(gap), 3L),
        names(gap)[which.min(gap)],
        .rmbl_fmt_num(min(gap), 3L)
      )
    }
  )
}

#' The verdict of a case flow: whether clearance over the whole run is
#' below, above or indistinguishable from 1, and how many periods were.
#' @param x The caseflow() table.
#' @param m The case flow's totals, window and level.
#' @return Sentences.
#' @noRd
.jx_cf_reading <- function(x, m) {
  ci <- .jx_ratio_ci(m$totaldis, m$totalrec, m$conflvl)
  net <- m$totalrec - m$totaldis
  over <- if (isTRUE(ci$upper < 1)) {
    sprintf(
      paste0(
        "Clearance is below 1 over the whole run (interval below 1): %s ",
        "more cases came in than were disposed, so the caseload grew."
      ),
      format(net, big.mark = ",")
    )
  } else if (isTRUE(ci$lower > 1)) {
    sprintf(
      paste0(
        "Clearance is above 1 over the whole run (interval above 1): %s ",
        "more cases were disposed than came in, so the caseload shrank."
      ),
      format(-net, big.mark = ",")
    )
  } else {
    paste0(
      "Over the whole run the interval includes 1: cases were disposed ",
      "about as fast as they came in."
    )
  }
  c(
    over,
    sprintf(
      "Period by period: %d below 1, %d above 1, %d indistinguishable from 1.",
      sum(x$upper < 1, na.rm = TRUE),
      sum(x$lower > 1, na.rm = TRUE),
      sum(x$lower <= 1 & x$upper >= 1, na.rm = TRUE)
    )
  )
}

#' How many outcome shares of a disposition mix trend, at the Holm-adjusted
#' level the result's intervals imply.
#' @param x The outcome mix whose trends are counted.
#' @return One sentence, or NULL without trend tests.
#' @noRd
.jx_dm_trends <- function(x) {
  tr <- x$trend
  if (is.null(tr) || !nrow(tr)) {
    return(NULL)
  }
  a <- .rd_alpha(x$conflvl)
  sig <- is.finite(tr$pholm) & tr$pholm < a
  up <- sig & tr$change > 0
  dn <- sig & tr$change < 0
  sprintf(
    paste0(
      "%d of %d shares trend at the Holm-adjusted %s level: %d up (%s), %d ",
      "down (%s)."
    ),
    sum(sig),
    nrow(tr),
    format(a),
    sum(up),
    .rd_list(tr$outcome[up], 3L),
    sum(dn),
    .rd_list(tr$outcome[dn], 3L)
  )
}

#' The reading of a Mahalanobis screen: which rows lie beyond alpha, or how
#' far the farthest one is.
#' @param d The rows, the largest distance first.
#' @param alpha The level.
#' @return One sentence.
#' @noRd
.rmbl_maha_reading <- function(d, alpha) {
  out <- .an_true(d$outlier)
  if (any(out)) {
    r <- d[out, , drop = FALSE]
    return(sprintf(
      "%d of %d rows lie beyond alpha = %s: %s.",
      nrow(r),
      nrow(d),
      format(alpha),
      .rd_list(sprintf(
        "row %s (distance %s)",
        r$row,
        .rmbl_fmt_num(r$distance, 3L)
      ))
    ))
  }
  if (!nrow(d) || !is.finite(d$distance[1L])) {
    return("No row has a distance to judge.")
  }
  sprintf(
    paste0(
      "No row lies beyond alpha = %s; the farthest, row %s, has distance ",
      "%s (p %s)."
    ),
    format(alpha),
    d$row[1L],
    .rmbl_fmt_num(d$distance[1L], 3L),
    .rmbl_p_txt(d$p_value[1L])
  )
}

#' The reading of a certificate: whether it is in force at a time, and what
#' kind of certificate it is.
#' @param x The certprs() result.
#' @param now The time it is judged at.
#' @return Sentences.
#' @noRd
.rmbl_cert_reading <- function(x, now) {
  day <- function(t) format(t, "%Y-%m-%d", tz = "UTC")
  left <- as.numeric(difftime(x$not_after, now, units = "days"))
  when <- if (now < x$not_before) {
    sprintf("Not yet valid: it comes into force on %s.", day(x$not_before))
  } else if (left < 0) {
    sprintf(
      "Expired on %s, %s days ago.",
      day(x$not_after),
      format(floor(-left), big.mark = ",")
    )
  } else {
    sprintf(
      "In force now, for %s more days (until %s).",
      format(floor(left), big.mark = ","),
      day(x$not_after)
    )
  }
  kind <- if (isTRUE(x$is_ca) && isTRUE(x$self_signed)) {
    "A self-signed CA certificate: a root, trusted or not, never verified."
  } else if (isTRUE(x$is_ca)) {
    sprintf("An intermediate CA certificate, issued by %s.", x$issuer)
  } else {
    sprintf("An end-entity certificate, issued by %s.", x$issuer)
  }
  c(when, kind)
}

#' The reading of a proof ledger: how many theorems are proved, and what the
#' rest rest on.
#' @param st The theorems' statuses.
#' @return One sentence.
#' @noRd
.bl_ldgr_reading <- function(st) {
  n <- length(st)
  if (!n) {
    return("The ledger lists no theorems.")
  }
  if (all(st == "proved")) {
    return(sprintf("All %d theorems are proved; ldgrchk() confirms it.", n))
  }
  rest <- table(st[st != "proved"])
  sprintf(
    "%d of %d theorems are proved; the others are %s: not proofs yet.",
    sum(st == "proved"),
    n,
    .rd_list(sprintf("%d %s", as.integer(rest), names(rest)))
  )
}

#' The reading of a distribution fit: the best family by AIC and how far
#' ahead of the next it is.
#' @param t The converged families, ranked by AIC.
#' @return One sentence.
#' @noRd
.rmbl_dstfit_reading <- function(t) {
  if (!nrow(t)) {
    return("No family converged, so none can be read as a fit.")
  }
  t <- t[order(t$aic), , drop = FALSE]
  if (nrow(t) == 1L) {
    return(sprintf("Only %s converged; it has nothing to beat.", t$family[1L]))
  }
  d <- t$aic[2L] - t$aic[1L]
  how <- if (d < 2) {
    "the data do not choose between the two"
  } else if (d < 10) {
    "some support for the best"
  } else {
    "strong support for the best"
  }
  sprintf(
    "%s fits best (AIC %s); %s, next, is %s AIC worse: %s.",
    t$family[1L],
    .rmbl_fmt_num(t$aic[1L]),
    t$family[2L],
    .rmbl_fmt_num(d, 3L),
    how
  )
}

#' The reading of a hot-spot table: the share the hot cells hold and how
#' much of the hot set carries over between periods.
#' @param p The periods table.
#' @param chronic The cells hot in at least half the periods.
#' @param k How many cells count as hot.
#' @return Sentences.
#' @noRd
.hp_reading <- function(p, chronic, k) {
  hs <- p$hotshr[is.finite(p$hotshr)]
  jac <- p$jacpre[is.finite(p$jacpre)]
  s1 <- if (length(hs)) {
    sprintf(
      "The busiest %d cells hold %.1f%% to %.1f%% of a period's incidents.",
      k,
      100 * min(hs),
      100 * max(hs)
    )
  }
  s2 <- if (length(jac)) {
    m <- mean(jac)
    sprintf(
      "Their overlap with the period before averages %s: %s.",
      .rmbl_fmt_num(m, 3L),
      if (m >= 0.5) {
        "the hot spots persist"
      } else if (m >= 0.2) {
        "the hot spots shift"
      } else {
        "the hot set is mostly new each period, so these spots do not persist"
      }
    )
  }
  c(s1, s2, sprintf("%d cells are hot in at least half the periods.", chronic))
}

#' Row labels of a rate table: its group columns, or row numbers.
#' @param x The rate table.
#' @param by Its group columns, or NULL.
#' @return One label per row.
#' @noRd
.rate_labels <- function(x, by) {
  by <- intersect(as.character(by), names(x))
  if (!length(by)) {
    return(paste("row", seq_len(nrow(x))))
  }
  do.call(paste, c(lapply(by, function(b) as.character(x[[b]])), sep = " "))
}

#' The reading of a rate table: the highest and lowest rate, and the rows
#' that rest on few events.
#' @param x The rtcalc() table.
#' @param m The rate's record: groups, base and small-count limit.
#' @return Sentences.
#' @noRd
.rate_reading <- function(x, m) {
  lab <- .rate_labels(x, m$by)
  small <- isTRUE(m$mincnt > 0) & !is.na(x$count) & x$count <= m$mincnt
  c(
    .rd_groups(lab, x$rate, x$lower, x$upper, "rate"),
    if (any(small)) {
      sprintf(
        "%s %s on %s or fewer events: %s.",
        .rd_list(lab[small]),
        if (sum(small) == 1L) "rests" else "rest",
        format(m$mincnt),
        "read their rates with their wide intervals"
      )
    }
  )
}

#' The reading of a rate change: which changes are larger than chance.
#' @param x The ratechg() table.
#' @param m The change's record: groups, period column and lag.
#' @return Sentences.
#' @noRd
.rate_chg_reading <- function(x, m) {
  ok <- is.finite(x$pctchg)
  if (!any(ok)) {
    return("No period has one `lag` periods before it to compare with.")
  }
  prd <- if (length(m$period) && m$period %in% names(x)) {
    paste0(" ", format(x[[m$period]]))
  } else {
    ""
  }
  lab <- sprintf(
    "%s%s (%+.1f%%)",
    .rate_labels(x, m$by),
    prd,
    x$pctchg
  )
  lab <- trimws(sub("^row [0-9]+ ", "", lab))
  .rd_null(
    lab[ok],
    x$pctlo[ok],
    x$pctup[ok],
    0,
    "Rose by more than chance",
    "Fell by more than chance"
  )
}

#' Row labels of a survey comparison, with each difference's p-value.
#' @param x The svycmp() table.
#' @return One label per row.
#' @noRd
.svy_cmp_labels <- function(x) {
  lab <- as.character(x$domain)
  if ("level" %in% names(x) && length(unique(x$level)) > 1L) {
    lab <- paste0(lab, " (level ", x$level, ")")
  }
  p <- x$p_value %||% rep(NA_real_, nrow(x))
  paste0(lab, " (p ", vapply(p, .rmbl_p_txt, ""), ")")
}

#' The reading of a survey estimate: whether its cvs allow publishing, and
#' for domains the highest and lowest.
#' @param x The svyest() table.
#' @param m Its attributes.
#' @return Sentences.
#' @noRd
.svy_est_reading <- function(x, m) {
  cols <- intersect(m$by, names(x))
  if ("level" %in% names(x) && length(unique(x$level)) > 1L) {
    cols <- c(cols, "level")
  }
  lab <- if (length(cols)) {
    do.call(paste, c(lapply(x[cols], as.character), sep = " "))
  } else {
    rep("the estimate", nrow(x))
  }
  cv <- x$cv
  bad <- is.finite(cv) & cv > 33.3
  mid <- is.finite(cv) & cv >= 16.6 & !bad
  c(
    if (nrow(x) > 1L && length(cols)) {
      .rd_groups(lab, x$estimate, x$lower, x$upper, m$stat %||% "estimate")
    },
    if (!any(bad | mid) && any(is.finite(cv))) {
      sprintf(
        "Every cv is below 16.6 (the largest %s): precise enough to publish.",
        .rmbl_fmt_num(max(cv, na.rm = TRUE), 3L)
      )
    },
    if (any(mid)) {
      sprintf("Use with caution (cv 16.6 to 33.3): %s.", .rd_list(lab[mid]))
    },
    if (any(bad)) {
      sprintf(
        "Too unstable to publish (cv above 33.3): %s.",
        .rd_list(lab[bad])
      )
    }
  )
}

#' The reading of a parallel-trends sensitivity: how large a departure the
#' effect survives.
#' @param x The tse() table.
#' @param bd Its breakdown value.
#' @return Sentences.
#' @noRd
.rmbl_tse_reading <- function(x, bd) {
  if (!length(bd) || is.na(bd)) {
    return("The breakdown value is not recorded.")
  }
  if (bd == 0) {
    return(paste(
      "Even with exactly parallel trends (Mbar 0) the robust interval",
      "includes 0: the data do not distinguish the effect from zero."
    ))
  }
  sign <- if (isTRUE(x$upper[1L] < 0)) "negative" else "positive"
  if (is.infinite(bd)) {
    return(sprintf(
      paste0(
        "The %s effect stays clear of zero for every Mbar up to 10: it ",
        "survives departures from parallel trends ten times the largest ",
        "seen before adoption."
      ),
      sign
    ))
  }
  c(
    sprintf(
      paste0(
        "The %s effect stays clear of zero while the trend after adoption ",
        "departs from parallel by up to %s times the largest departure ",
        "before it."
      ),
      sign,
      .rmbl_fmt_num(bd, 3L)
    ),
    if (bd < 1) {
      paste0(
        "A departure as large as the pre-period's (Mbar 1) is enough to ",
        "lose it: the conclusion leans on parallel trends."
      )
    } else {
      paste0(
        "It survives a departure as large as the largest seen before ",
        "adoption (Mbar 1)."
      )
    }
  )
}

# ---- single-number statistics (rmbl_measure) ----------------------------

#' A measure's named values as a small table, p-values as a paper prints
#' them.
#' @param x A measure with named values.
#' @return A data frame of `statistic` and `value` (text).
#' @noRd
.rmbl_msr_table <- function(x) {
  v <- .rmbl_measure_plain(x)
  nm <- names(v) %||% rep("", length(v))
  txt <- vapply(
    seq_along(v),
    function(i) {
      if (.rmbl_is_p_col(nm[i])) .rmbl_fmt_p(v[i]) else .rmbl_fmt_num(v[i])
    },
    ""
  )
  data.frame(statistic = nm, value = txt, stringsAsFactors = FALSE)
}

#' How concentrated a Gini coefficient says a total is, in words.
#' @param g The coefficient.
#' @param n The number of units.
#' @return Sentences.
#' @noRd
.rmbl_gini_reading <- function(g, n) {
  band <- if (g < 0.2) {
    "close to equal shares"
  } else if (g < 0.4) {
    "moderately concentrated"
  } else if (g < 0.6) {
    "highly concentrated"
  } else {
    "very highly concentrated"
  }
  top <- 1 - 1 / n
  c(
    sprintf("A Gini of %s: the total is %s.", .rmbl_fmt_num(g), band),
    if (top > 0) {
      sprintf(
        paste0(
          "That is %.0f%% of the way from equal shares (0) to one unit ",
          "holding all of it (%s for %s units)."
        ),
        100 * g / top,
        .rmbl_fmt_num(top),
        .rmbl_fmt_num(n)
      )
    }
  )
}

#' What a population attributable fraction says, with its interval.
#' @param paf The fraction.
#' @param ci Its named limits, or NULL.
#' @return Sentences.
#' @noRd
.rmbl_paf_reading <- function(paf, ci) {
  s1 <- if (paf >= 0) {
    sprintf(
      paste0(
        "About %.1f%% of the cases in this population would not occur ",
        "without the exposure, if the relative risk is causal."
      ),
      100 * paf
    )
  } else {
    sprintf(
      paste0(
        "The exposure is protective: without it there would be about ",
        "%.1f%% more cases."
      ),
      -100 * paf
    )
  }
  s2 <- if (length(ci) == 2L) {
    if (ci[["lower"]] > 0) {
      "Its interval stays above 0: some burden is attributable."
    } else if (ci[["upper"]] < 0) {
      "Its interval stays below 0: the exposure protects."
    } else {
      "Its interval includes 0: the data allow no attributable burden at all."
    }
  }
  c(s1, s2)
}

#' The reading of a Kolmogorov-Smirnov test: whether it rejects at 0.05 and
#' how large the gap is.
#' @param x The drftks() result.
#' @return Sentences.
#' @noRd
.rmbl_ks_reading <- function(x) {
  c(
    .rd_test(
      x[["p_value"]],
      0.05,
      "The two samples differ in distribution",
      "No difference in distribution is detected"
    ),
    sprintf(
      paste0(
        "At its widest the two cumulative distributions are %.1f ",
        "percentage points apart."
      ),
      100 * x[["statistic"]]
    )
  )
}

#' The reading of a population stability index: its band, and the JS
#' divergence as a share of its bound.
#' @param x The drftpsi() result.
#' @return Sentences.
#' @noRd
.rmbl_psi_reading <- function(x) {
  psi <- x[["psi"]]
  band <- if (psi < 0.1) {
    "stable"
  } else if (psi < 0.25) {
    "a shift worth a look"
  } else {
    "a material shift"
  }
  c(
    sprintf("PSI %s: by the usual bands, %s.", .rmbl_fmt_num(psi), band),
    sprintf(
      "The JS divergence is %.1f%% of its largest possible value.",
      100 * x[["jsdiv"]] / log(2)
    )
  )
}

#' The reading of a chi-square measure at 0.05, with its special cases.
#' @param x A drftchisq() or drfthomog() result.
#' @param yes What a rejection means.
#' @param no What no rejection means.
#' @return One sentence.
#' @noRd
.rmbl_chisq_reading <- function(x, yes, no) {
  if (is.infinite(x[["statistic"]])) {
    return(paste(
      "A category the reference rules out occurs: a flat contradiction of",
      "the reference, not a large finite statistic."
    ))
  }
  if (isTRUE(x[["df"]] == 0)) {
    return("One category on both sides: there is nothing to test.")
  }
  .rd_test(x[["p_value"]], 0.05, yes, no)
}

# ---- provenance objects: manifest, environment, provenance, citation --------

#' The first value of a field as text, or NULL when it is absent or empty.
#' @param v The field.
#' @return One string, or NULL.
#' @noRd
.mf_s1 <- function(v) {
  v <- unlist(v)
  if (length(v) && !is.na(v[[1L]]) && nzchar(as.character(v[[1L]]))) {
    as.character(v[[1L]])
  }
}

#' A manifest's meta fields as facts: each one's value as text.
#' @param meta The manifest's meta list.
#' @return A named list.
#' @noRd
.mf_meta_facts <- function(meta) {
  if (!length(meta)) {
    return(list())
  }
  out <- lapply(meta, function(v) {
    if (is.atomic(v) && length(v) <= 6L) {
      toString(v)
    } else {
      sprintf("<%s of %d>", class(v)[1L], length(v))
    }
  })
  names(out) <- names(meta) %||% paste0("meta", seq_along(meta))
  out
}

#' The tally of a manifest's cross-checks, "3 (2 PASS, 1 DIFFER)".
#' @param res The manifest's results.
#' @return One string.
#' @noRd
.mf_tally <- function(res) {
  if (!length(res)) {
    return("none recorded")
  }
  st <- vapply(res, function(r) as.character(r$status %||% "?"), "")
  sprintf("%d (%s)", length(st), .rmbl_tally(st))
}

#' A manifest's cross-checks as a table.
#' @param res The manifest's results.
#' @return A data frame, or NULL for none.
#' @noRd
.mf_results <- function(res) {
  if (!length(res)) {
    return(NULL)
  }
  txt <- function(k) {
    vapply(res, function(r) {
      v <- r[[k]]
      if (is.null(v) || !length(v)) "" else toString(format(v))
    }, "")
  }
  data.frame(
    check = names(res),
    group = txt("group"),
    observed = txt("observed"),
    expected = txt("expected"),
    diff = txt("diff"),
    tol = txt("tol"),
    status = txt("status"),
    stringsAsFactors = FALSE
  )
}

#' The reading of a manifest: how its cross-checks came out.
#' @param res The manifest's results.
#' @param meta Its meta list.
#' @return Sentences.
#' @noRd
.mf_reading <- function(res, meta) {
  syn <- if (isTRUE(meta$synthetic)) {
    "Built on synthetic data: every cross-check is INFO, not evidence."
  }
  if (!length(res)) {
    return(c("No cross-checks recorded yet: recrd() adds them.", syn))
  }
  st <- vapply(res, function(r) as.character(r$status %||% "?"), "")
  bad <- names(res)[st == "DIFFER"]
  main <- if (length(bad)) {
    sprintf(
      "%d of %d cross-checks differ by more than their tolerance: %s.",
      length(bad),
      length(st),
      .rd_list(bad)
    )
  } else if (all(st == "PASS")) {
    sprintf(
      "All %d cross-checks reproduce their expected values within tolerance.",
      length(st)
    )
  } else {
    sprintf(
      "No cross-check differs; %d of %d pass and the rest are INFO.",
      sum(st == "PASS"),
      length(st)
    )
  }
  c(main, syn)
}

#' The reading of a captured environment: packages missing, seed set.
#' @param v The package versions (NA when not installed).
#' @param seeded Whether a seed was set before the capture.
#' @return Sentences.
#' @noRd
.mf_env_reading <- function(v, seeded) {
  c(
    if (anyNA(v)) {
      sprintf(
        "%d of %d packages are not installed here: %s.",
        sum(is.na(v)),
        length(v),
        .rd_list(names(v)[is.na(v)])
      )
    } else {
      sprintf("All %d packages recorded with their versions.", length(v))
    },
    if (isTRUE(seeded)) {
      "A seed was set: with the same RNG kind the run can be replayed."
    } else {
      paste0(
        "No seed was set before the capture: a random result cannot be ",
        "replayed from this record."
      )
    }
  )
}

#' A nested list flattened to one row per leaf: its path and its value.
#' @param x The list.
#' @param pre The path so far.
#' @return A data frame of `field` and `value`.
#' @noRd
.mf_flat <- function(x, pre = "") {
  if (!is.list(x) || !length(x)) {
    v <- if (is.null(x) || !length(x)) "" else toString(format(unlist(x)))
    return(data.frame(field = pre, value = v, stringsAsFactors = FALSE))
  }
  nm <- names(x) %||% rep("", length(x))
  nm[!nzchar(nm)] <- paste0("[", which(!nzchar(nm)), "]")
  path <- if (nzchar(pre)) paste(pre, nm, sep = "$") else nm
  do.call(rbind, lapply(seq_along(x), function(i) .mf_flat(x[[i]], path[i])))
}

#' The reading of a provenance record: whether the data file is pinned.
#' @param x The loadprov() result.
#' @return Sentences.
#' @noRd
.mf_prov_reading <- function(x) {
  sha <- .mf_s1(x$resource$sha256) %||% .mf_s1(x$source$sha256)
  pinned <- !is.null(sha) && grepl("^[0-9a-fA-F]{64}$", sha)
  c(
    if (pinned) {
      sprintf(
        paste0(
          "Pinned: the data file's SHA-256 starts %s; cpschk() checks the ",
          "file against it."
        ),
        substr(sha, 1L, 12L)
      )
    } else {
      paste0(
        "Not pinned yet: no SHA-256 of the data file is recorded; ",
        "cpsrfrsh() pins it."
      )
    },
    if (isTRUE(x$synthetic) || isTRUE(x$resource$synthetic)) {
      "The record marks its data as synthetic."
    }
  )
}

#' The reading of a data citation: what its link is.
#' @param text The citation text.
#' @return One sentence.
#' @noRd
.mf_cite_reading <- function(text) {
  if (grepl("https://doi.org/", text, fixed = TRUE)) {
    "Cites the data by DOI, which outlives any one download address."
  } else if (grepl("https?://", text)) {
    paste0(
      "Cites the data by its download address; a DOI, when the publisher ",
      "has one, lasts longer."
    )
  } else {
    "The citation has no link: the record holds neither a DOI nor an address."
  }
}

# ---- the summaries of the cleaning functions ---------------------------------

#' Draws block lines as a box on the message stream (stderr), so
#' suppressMessages() silences it and the function's value is untouched.
#' @param lines The block: a titled rule, body lines, a closing rule.
#' @return NULL, invisibly.
#' @noRd
.rmbl_note_box <- function(lines) {
  lines <- as.character(lines)
  cap <- .rmbl_print_caps()
  if (.rmbl_is_block(lines, cap)) {
    lines <- .rmbl_box(lines, NULL, cap)
  }
  message(paste(lines, collapse = "\n"))
  invisible(NULL)
}

#' Rows and columns before and after, as one fact.
#' @param d The dimensions, or NULL for a vector of names.
#' @return One string.
#' @noRd
.rmbl_dim_txt <- function(d) {
  if (length(d) != 2L) {
    return(NULL)
  }
  sprintf(
    "%s row%s, %s column%s",
    format(d[1L], big.mark = ","),
    if (d[1L] == 1L) "" else "s",
    format(d[2L], big.mark = ","),
    if (d[2L] == 1L) "" else "s"
  )
}

#' The summary block of drpempty() or drpconst().
#' @param title The summary's title.
#' @param before,after The table's dimensions before and after.
#' @param dropped Named list: the label and the names of the columns
#'   dropped.
#' @return Block lines.
#' @noRd
.rmbl_clean_box <- function(title, before, after, dropped) {
  cols <- dropped[[1L]]
  rows <- before[1L] - after[1L]
  .an_block(
    title,
    facts = c(
      list(Before = .rmbl_dim_txt(before), After = .rmbl_dim_txt(after)),
      stats::setNames(
        list(if (length(cols)) toString(cols) else "none"),
        names(dropped)[1L]
      ),
      list(`Rows dropped` = if (rows > 0L) format(rows, big.mark = ","))
    ),
    reading = if (!length(cols) && rows == 0L) {
      "Nothing to drop: the table came back as it was."
    } else {
      sprintf(
        "%d column%s and %s row%s dropped.",
        length(cols),
        if (length(cols) == 1L) "" else "s",
        format(rows, big.mark = ","),
        if (rows == 1L) "" else "s"
      )
    },
    notes = "quiet = TRUE, or suppressMessages(), silences this summary."
  )
}

#' The summary block of clncolnms(): the names it changed.
#' @param old,new The names before and after.
#' @param d The table's dimensions, or NULL for a vector of names.
#' @return Block lines.
#' @noRd
.rmbl_rename_box <- function(old, new, d) {
  ch <- old != new
  tab <- if (any(ch)) {
    utils::head(
      data.frame(from = old[ch], to = new[ch], stringsAsFactors = FALSE),
      40L
    )
  }
  .an_block(
    "Column names cleaned",
    facts = list(
      Table = .rmbl_dim_txt(d),
      Names = length(old),
      Renamed = sum(ch)
    ),
    tables = list(tab),
    reading = if (any(ch)) {
      sprintf(
        "%d of %d names changed%s.",
        sum(ch),
        length(old),
        if (length(d) == 2L) {
          "; attr(x, \"orignms\") keeps the originals"
        } else {
          ""
        }
      )
    } else {
      "Every name was already clean: nothing changed."
    },
    notes = c(
      if (sum(ch) > 40L) sprintf("... and %d more renamed.", sum(ch) - 40L),
      "quiet = TRUE, or suppressMessages(), silences this summary."
    )
  )
}

#' The summary block of duprows(): how many rows are duplicates.
#' @param data The table checked.
#' @param out duprows()'s result.
#' @param cols The columns that define a duplicate, or NULL.
#' @return Block lines.
#' @noRd
.rmbl_dup_box <- function(data, out, cols) {
  groups <- if (nrow(out)) {
    sum(1 / out$dupe_count)
  } else {
    0
  }
  .an_block(
    "Duplicate rows",
    facts = list(
      Table = .rmbl_dim_txt(dim(data)),
      `Compared on` = if (length(cols)) toString(cols) else "every column",
      `Duplicate rows` = format(nrow(out), big.mark = ","),
      Groups = format(round(groups), big.mark = ","),
      `Extra copies` = format(nrow(out) - round(groups), big.mark = ",")
    ),
    reading = if (nrow(out)) {
      sprintf(
        paste0(
          "%s rows fall in %s groups of identical rows: dropping the ",
          "repeats would remove %s."
        ),
        format(nrow(out), big.mark = ","),
        format(round(groups), big.mark = ","),
        format(nrow(out) - round(groups), big.mark = ",")
      )
    } else {
      "No two rows are the same on these columns."
    },
    notes = "quiet = TRUE, or suppressMessages(), silences this summary."
  )
}
