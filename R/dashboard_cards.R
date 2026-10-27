# SPDX-License-Identifier: AGPL-3.0-or-later What the dashboard's cards show:
# the headline numbers of a result and how to read them, the method in its help
# page's words, the table, the diagnostics, the plots (with a dark mode), the
# downloads, and the linked views (a column's distribution, a period's rows, a
# brushed range).

# the names a headline estimate goes by, in order of preference
.bl_hl_est <- c(
  "estimate",
  "att",
  "rr",
  "rateratio",
  "rate",
  "share",
  "slope",
  "pctchg",
  "change",
  "difference",
  "pooled",
  "paf",
  "power",
  "clearance",
  "probbet",
  "strratio",
  "survival",
  "smd",
  "correlation",
  "braratio",
  "psi",
  "alos"
)
# the lower bound of each, where it has one; the upper bound is named the same
# way
.bl_hl_lo <- c(
  estimate = "lower",
  rate = "lower",
  share = "lower",
  rateratio = "lower",
  change = "lower",
  probbet = "lower",
  clearance = "lower",
  slope = "slopelo",
  rr = "rrlo",
  pctchg = "pctlo",
  difference = "diflo",
  strratio = "ratiolo",
  survival = "conflo"
)
# the estimates that compare with no effect (0, or 1 for a ratio, or 0.5 for a
# probability of better)
.bl_hl_ref <- c(
  estimate = 0,
  att = 0,
  difference = 0,
  change = 0,
  pctchg = 0,
  slope = 0,
  smd = 0,
  correlation = 0,
  rr = 1,
  rateratio = 1,
  strratio = 1,
  probbet = 0.5
)

# the help pages, read once per session
.bl_rd_env <- new.env(parent = emptyenv())

#' A number for a card.
#' @param x A number or NULL.
#' @param digits Significant digits of the card's number (default 4).
#' @param big Whether to mark thousands.
#' @return One string, or NULL.
#' @noRd
.bl_num <- function(x, digits = 4L, big = TRUE) {
  if (is.null(x) || !length(x) || is.na(x[[1L]])) {
    return(NULL)
  }
  x <- as.numeric(x[[1L]])
  if (is.finite(x) && x != 0 && abs(x) < 1e-4) {
    return(formatC(x, digits = 2L, format = "e"))
  }
  trimws(formatC(
    signif(x, digits),
    digits = digits,
    format = "fg",
    big.mark = if (big) "," else ""
  ))
}

#' The headline of a result: the estimate, its interval, the p-value, n and a
#' verdict.
#' @param v The result.
#' @param n The rows of the data, or NULL.
#' @return A list: est, estlab, lo, up, p, n, rowlab, rows, verdict, good (TRUE
#'   when the verdict is evidence of an effect).
#' @noRd
.bl_headline <- function(v, n = NULL) {
  h <- .bl_hl_frame(v)
  rowlab <- NULL
  rows <- NULL
  if (is.data.frame(h)) {
    rows <- nrow(h)
    if (!nrow(h)) {
      return(list(n = n, rows = 0L, verdict = "No rows", good = FALSE))
    }
    r <- .bl_hl_row(h)
    rowlab <- r$rowlab
    h <- r$h
  }
  one <- function(nm) .bl_hl_one(h, nm)
  est <- Filter(function(nm) !is.null(one(nm)), .bl_hl_est)
  e <- if (length(est)) est[[1L]]
  lo <- if (!is.null(e) && !is.na(.bl_hl_lo[e])) one(.bl_hl_lo[[e]])
  up <- if (!is.null(e) && !is.na(.bl_hl_lo[e])) {
    one(sub("lo$", "up", sub("lower", "upper", .bl_hl_lo[[e]], fixed = TRUE)))
  }
  p <- one("p_value") %||%
    if (is.list(v) && !is.data.frame(v)) {
      x <- v$p_value
      if (is.numeric(x) && length(x) == 1L) x
    }
  nn <- one("n") %||%
    if (is.list(v) && is.numeric(v$n) && length(v$n) == 1L) v$n else n
  ref <- if (!is.null(e)) .bl_hl_ref[e]
  vd <- .bl_hl_verdict(v, h, p, ref, lo, up)
  list(
    est = if (!is.null(e)) one(e),
    estlab = e,
    lo = lo,
    up = up,
    p = p,
    n = nn,
    rowlab = if (!is.null(e)) rowlab,
    rows = rows,
    verdict = vd$verdict %||% "Descriptive: no test",
    good = vd$good,
    conf = if (is.list(v) && is.numeric(v$conflvl)) v$conflvl else 0.95
  )
}

#' The part of a result its headline is read from: a drift result's columns,
#' most drifted first, or a list's overall or estimate table.
#' @param v The result.
#' @return A data frame or a list.
#' @noRd
.bl_hl_frame <- function(v) {
  if (
    inherits(v, "bricklayer_drift") &&
      is.data.frame(v$columns) &&
      nrow(v$columns)
  ) {
    return(v$columns[order(-v$columns$psi), , drop = FALSE])
  }
  if (is.list(v) && !is.data.frame(v)) {
    if (is.data.frame(v$overall)) {
      return(v$overall)
    }
    if (is.data.frame(v$estimate)) {
      return(v$estimate)
    }
  }
  v
}

#' The row of a table the headline shows: the last finite estimate of a series,
#' else the first, and a label for it from its text and period columns.
#' @param h The table (with rows).
#' @return A list: h (the row, as a list) and rowlab.
#' @noRd
.bl_hl_row <- function(h) {
  est <- intersect(.bl_hl_est, names(h))
  fin <- if (length(est)) {
    which(is.finite(suppressWarnings(as.numeric(h[[est[[1L]]]]))))
  } else {
    integer()
  }
  series <- any(
    c("year", "period", "month", "evtm", "date", "prd") %in% names(h)
  )
  i <- if (!length(fin)) {
    1L
  } else if (series) {
    fin[[length(fin)]]
  } else {
    fin[[1L]]
  }
  chr <- names(h)[vapply(
    h,
    function(z) is.character(z) || is.factor(z),
    TRUE
  )]
  chr <- setdiff(chr, c("flag", "verdict", "note", "type", "method"))
  lab <- c(
    vapply(chr, function(z) as.character(h[[z]][[i]]), ""),
    vapply(
      intersect(c("year", "period", "month", "evtm"), setdiff(names(h), chr)),
      function(z) as.character(h[[z]][[i]]),
      ""
    )
  )
  list(
    h = lapply(h, function(z) z[[i]]),
    rowlab = if (length(lab)) toString(lab[!is.na(lab)])
  )
}

#' One number of the headline row.
#' @param h The row.
#' @param nm The headline field to read, kept when one number.
#' @return The number, or NULL.
#' @noRd
.bl_hl_one <- function(h, nm) {
  x <- if (is.list(h)) h[[nm]]
  if (is.numeric(x) && length(x) == 1L) x
}

#' The headline's verdict: drift, the result's own words, the p-value, or the
#' interval against the null value.
#' @param v The result.
#' @param h The headline row.
#' @param p,ref,lo,up The p-value, the null value and the interval.
#' @return A list: verdict (or NULL) and good.
#' @noRd
.bl_hl_verdict <- function(v, h, p, ref, lo, up) {
  vd <- if (is.list(h)) h$verdict
  if (inherits(v, "bricklayer_drift")) {
    good <- isTRUE(v$anydrft)
    return(list(
      verdict = if (good) {
        "Drift in at least one column"
      } else {
        "No column drifted"
      },
      good = good
    ))
  }
  if (is.character(vd) && length(vd) == 1L && !is.na(vd)) {
    return(list(verdict = vd, good = FALSE))
  }
  if (!is.null(p) && !is.na(p)) {
    good <- p < 0.05
    return(list(
      verdict = if (good) {
        "Unlikely to be chance (p < 0.05)"
      } else {
        sprintf("Could be chance (p = %s)", .bl_num(p, 2L))
      },
      good = good
    ))
  }
  iv <- .bl_hl_interval_verdict(ref, lo, up)
  if (!is.null(iv)) {
    return(iv)
  }
  if (is.list(v) && isFALSE(v$converged)) {
    return(list(verdict = "The fit did not converge", good = FALSE))
  }
  list(verdict = NULL, good = FALSE)
}

#' The verdict of an interval against the null value, when both are known.
#' @param ref The null value.
#' @param lo,up The interval.
#' @return A list (verdict, good), or NULL.
#' @noRd
.bl_hl_interval_verdict <- function(ref, lo, up) {
  known <- !is.null(ref) && !is.na(ref) && !is.null(lo) && !is.null(up)
  if (!known || !is.finite(lo) || !is.finite(up)) {
    return(NULL)
  }
  good <- lo > ref || up < ref
  list(
    verdict = sprintf(
      "The interval %s %s",
      if (good) "excludes" else "includes",
      format(unname(ref))
    ),
    good = good
  )
}

#' The value boxes of a headline.
#' @param h A .bl_headline() result.
#' @return A tag.
#' @noRd
.bl_vbox_ui <- function(h) {
  vb <- .bl_vbox
  iv <- if (!is.null(h$lo) && !is.null(h$up)) {
    sprintf("%s to %s", .bl_num(h$lo), .bl_num(h$up))
  }
  bslib::layout_column_wrap(
    width = "210px",
    fill = FALSE,
    heights_equal = "row",
    class = "mb-3",
    vb(.bl_vbox_title(h), .bl_vbox_value(h), h$rowlab, "primary"),
    vb(
      "Interval",
      iv %||% "None reported",
      if (!is.null(iv)) sprintf("%g%% confidence", 100 * h$conf)
    ),
    vb(
      "n",
      if (!is.null(h$n)) format(h$n, big.mark = ",") else "Not reported",
      if (!is.null(h$p)) sprintf("p = %s", .bl_num(h$p, 3L))
    ),
    vb(
      "Verdict",
      h$verdict,
      NULL,
      if (isTRUE(h$good)) "success" else "secondary"
    )
  )
}

#' One value box of the headline row.
#' @param title,value The box's title and value.
#' @param sub A line under the value, or NULL.
#' @param theme The box's theme, or NULL.
#' @return A bslib value box.
#' @noRd
.bl_vbox <- function(title, value, sub, theme = NULL) {
  bslib::value_box(
    title = title,
    value = value,
    if (!is.null(sub)) shiny::tags$p(sub),
    theme = theme,
    fill = FALSE,
    min_height = "110px"
  )
}

#' The title of the headline's estimate box.
#' @param h The headline.
#' @return One string.
#' @noRd
.bl_vbox_title <- function(h) {
  if (identical(h$estlab, "estimate")) {
    "Estimate"
  } else if (!is.null(h$estlab)) {
    paste("Estimate:", h$estlab)
  } else {
    "Result"
  }
}

#' The value of the headline's estimate box.
#' @param h The headline.
#' @return One string.
#' @noRd
.bl_vbox_value <- function(h) {
  .bl_num(h$est) %||%
    if (!is.null(h$rows)) {
      sprintf("%s rows", format(h$rows, big.mark = ","))
    } else {
      "See the table"
    }
}

#' The first sentence of a function's help page description.
#' @param fn The function's name.
#' @return One string (\code{""} when there is no help page).
#' @noRd
.bl_rd_method <- function(fn) {
  if (is.null(.bl_rd_env$db)) {
    # installed help pages, else the source man/ folder
    .bl_rd_env$db <- .bl_rd_db()
  }
  for (rd in .bl_rd_env$db) {
    tags <- vapply(rd, function(x) attr(x, "Rd_tag") %||% "", "")
    al <- vapply(
      rd[tags == "\\alias"],
      function(x) paste(unlist(x), collapse = ""),
      ""
    )
    if (!fn %in% al || !any(tags == "\\description")) {
      next
    }
    txt <- gsub(
      "\\s+",
      " ",
      trimws(paste(
        unlist(rd[[which(tags == "\\description")[[1L]]]]),
        collapse = ""
      ))
    )
    return(sub("^(.*?[.])\\s+[A-Z(].*$", "\\1", txt, perl = TRUE))
  }
  ""
}

#' How to read the effect sizes and fit statistics a result carries.
#' @param v The result.
#' @return A character vector of sentences.
#' @noRd
.bl_effect_lines <- function(v) {
  c(
    .bl_effect_smd(v),
    .bl_effect_spread(v),
    .bl_effect_ratio(v),
    .bl_effect_fit(v)
  )
}

#' One number of a result, when it is a non-empty numeric field.
#' @param v The result.
#' @param nm The result field to read, kept when a non-empty numeric.
#' @return The number(s), or NULL.
#' @noRd
.bl_eff_get <- function(v, nm) {
  x <- if (is.list(v)) v[[nm]]
  if (is.numeric(x) && length(x)) x
}

#' The band a size of effect falls in.
#' @param x The size.
#' @param cuts The bands' lower ends.
#' @param labs The bands' names, one more than `cuts`.
#' @return The name.
#' @noRd
.bl_eff_band <- function(x, cuts, labs) labs[findInterval(abs(x), cuts) + 1L]

#' The effect lines on association and heterogeneity.
#' @param v The result.
#' @return Lines of text, possibly none.
#' @noRd
.bl_effect_spread <- function(v) {
  out <- character()
  cv <- .bl_eff_get(v, "cramerv") %||%
    if (is.list(v) && is.data.frame(v$homogeneity)) v$homogeneity$cramerv
  if (!is.null(cv)) {
    out <- c(
      out,
      sprintf(
        "Cramer's V %s: a %s association (0.1 small, 0.3 moderate, 0.5 large).",
        .bl_num(cv, 2L),
        .bl_eff_band(
          cv,
          c(0.1, 0.3, 0.5),
          c("negligible", "small", "moderate", "large")
        )
      )
    )
  }
  i2 <- .bl_eff_get(v, "i2")
  if (!is.null(i2)) {
    out <- c(
      out,
      sprintf(
        paste(
          "I-squared %s%%: that share of the spread between groups is",
          "more than sampling",
          "error would give (%s heterogeneity)."
        ),
        .bl_num(100 * i2, 2L),
        .bl_eff_band(
          i2,
          c(0.25, 0.5, 0.75),
          c("low", "low", "moderate", "high")
        )
      )
    )
  }
  out
}

#' The effect lines on correlation and ratios.
#' @param v The result.
#' @return Lines of text, possibly none.
#' @noRd
.bl_effect_ratio <- function(v) {
  out <- character()
  r <- .bl_eff_get(v, "correlation") %||% .bl_eff_get(v, "tau")
  if (!is.null(r)) {
    m <- r[which.max(abs(r))]
    out <- c(
      out,
      sprintf(
        "Strongest correlation %s: %s (0.1 small, 0.3 moderate, 0.5 large).",
        .bl_num(m, 2L),
        .bl_eff_band(
          m,
          c(0.1, 0.3, 0.5),
          c("negligible", "small", "moderate", "large")
        )
      )
    )
  }
  rr <- .bl_eff_get(v, "rateratio") %||%
    .bl_eff_get(v, "rr") %||%
    .bl_eff_get(v, "strratio")
  if (!is.null(rr) && length(rr) == 1L && is.finite(rr)) {
    out <- c(
      out,
      sprintf(
        "A ratio of %s is %s%% %s than the reference.",
        .bl_num(rr, 3L),
        .bl_num(abs(100 * (rr - 1)), 2L),
        if (rr >= 1) "higher" else "lower"
      )
    )
  }
  br <- .bl_eff_get(v, "braratio")
  if (!is.null(br)) {
    out <- c(
      out,
      sprintf(
        paste(
          "Branching ratio %s: about %s%% of events are triggered by",
          "earlier ones; at 1 or",
          "above the process would explode."
        ),
        .bl_num(br, 2L),
        .bl_num(100 * br, 2L)
      )
    )
  }
  out
}

#' The effect lines on the fit of a model and on drift.
#' @param v The result.
#' @return Lines of text, possibly none.
#' @noRd
.bl_effect_fit <- function(v) {
  out <- character()
  ks <- .bl_eff_get(v, "kspva")
  if (!is.null(ks)) {
    out <- c(
      out,
      sprintf(
        "Time-rescaling KS p = %s: the fitted intensity %s the event times.",
        .bl_num(ks, 2L),
        if (ks >= 0.05) "is consistent with" else "does not fit"
      )
    )
  }
  dsp <- .bl_eff_get(v, "dispersion")
  if (!is.null(dsp)) {
    out <- c(
      out,
      sprintf(
        "Dispersion %s: %s.",
        .bl_num(dsp, 3L),
        if (isTRUE(v$overdispersed)) {
          "overdispersed, so the Poisson intervals are too narrow"
        } else {
          "no sign of overdispersion"
        }
      )
    )
  }
  if (inherits(v, "bricklayer_drift") && is.data.frame(v$columns)) {
    m <- max(v$columns$psi, na.rm = TRUE)
    out <- c(
      out,
      sprintf(
        paste0(
          "Largest PSI %s: %s (below 0.1 stable, 0.1 to 0.25 moderate, ",
          "above 0.25 major)."
        ),
        .bl_num(m, 3L),
        .bl_eff_band(
          m,
          c(0.1, 0.25),
          c("stable", "moderate shift", "major shift")
        )
      )
    )
  }
  out
}

#' What the headline numbers mean, in sentences.
#' @param h A .bl_headline() result, or NULL.
#' @return A character vector.
#' @noRd
.bl_meaning <- function(h) {
  if (is.null(h)) {
    return("Run the analysis to see its numbers.")
  }
  out <- character()
  if (!is.null(h$est)) {
    out <- sprintf(
      "The %s is %s%s.",
      h$estlab,
      .bl_num(h$est),
      if (!is.null(h$rowlab)) paste0(" (", h$rowlab, ")") else ""
    )
    if (!is.null(h$lo) && !is.null(h$up)) {
      out <- c(
        out,
        sprintf(
          paste(
            "Its %g%% interval runs from %s to %s: values in it are",
            "compatible with the data",
            "at that level."
          ),
          100 * h$conf,
          .bl_num(h$lo),
          .bl_num(h$up)
        )
      )
    }
  }
  if (!is.null(h$p)) {
    out <- c(
      out,
      sprintf(
        paste(
          "p = %s is the chance of an estimate at least this far from",
          "no effect if there",
          "were none; it is not the chance that there is no effect."
        ),
        .bl_num(h$p, 3L)
      )
    )
  }
  if (!length(out)) {
    out <- "A descriptive result: the table and the plot are the answer."
  }
  out
}

#' The method card: the method, its assumptions, what the numbers mean, and the
#' help.
#' @param f The analysis spec: its steps, method and assumptions.
#' @param s The tab spec, whose `assume` stands in when `f` has none.
#' @param h The headline, or NULL before a run.
#' @param v The result, or NULL.
#' @return A tag.
#' @noRd
.bl_method_ui <- function(f, s, h, v) {
  fn <- if (length(f$steps)) f$steps[[length(f$steps)]]$fn else f$plot$fn
  fn <- sub("^.*::", "", fn)
  t <- shiny::tags
  eff <- if (!is.null(v)) .bl_effect_lines(v)
  t$dl(
    class = "bl-method",
    t$dt("Method"),
    t$dd(f$method %||% .bl_rd_method(fn)),
    t$dt("Assumes"),
    t$dd(f$assume %||% s$assume %||% "See the help page."),
    t$dt("What the numbers mean"),
    t$dd(lapply(.bl_meaning(h), t$p)),
    if (length(eff)) {
      shiny::tagList(
        t$dt("Effect sizes and fit"),
        t$dd(t$ul(lapply(eff, t$li)))
      )
    },
    t$dt("Help"),
    t$dd(t$code(sprintf("?%s", fn)))
  )
}

#' A cell of a table, as text.
#' @param x One value.
#' @param digits Significant digits of a numeric cell.
#' @return One string.
#' @noRd
.bl_cell <- function(x, digits) {
  if (is.list(x)) {
    x <- unlist(x)
  }
  if (!length(x)) {
    return("")
  }
  if (is.numeric(x)) {
    return(toString(
      vapply(
        x,
        function(z) if (is.na(z)) "NA" else .bl_num(z, digits, FALSE),
        ""
      )
    ))
  }
  toString(as.character(x))
}

#' A data frame as an accessible HTML table; a `column` that names a data column
#' becomes a button that opens its distribution.
#' @param t The data frame.
#' @param digits Significant digits of the table's numeric cells (default 4).
#' @param link NULL, or list(ns, cols).
#' @return A tag.
#' @noRd
.bl_html_table <- function(t, digits = 4L, link = NULL) {
  tg <- shiny::tags
  body <- lapply(seq_len(nrow(t)), function(i) {
    tg$tr(lapply(names(t), function(nm) {
      val <- .bl_cell(t[[nm]][[i]], digits)
      if (!is.null(link) && nm == "column" && val %in% link$cols) {
        return(tg$td(tg$button(
          type = "button",
          class = "btn btn-link bl-col",
          onclick = sprintf(
            "Shiny.setInputValue('%s', %s, {priority: 'event'})",
            link$ns("pickcol"),
            encodeString(val, quote = "\"")
          ),
          `aria-label` = sprintf("The distribution of %s", val),
          val
        )))
      }
      tg$td(val)
    }))
  })
  tg$div(
    class = "bl-scroll",
    tabindex = "0",
    tg$table(
      class = "table table-sm table-striped table-hover mb-0",
      tg$thead(tg$tr(lapply(names(t), function(n) tg$th(scope = "col", n)))),
      tg$tbody(body)
    )
  )
}

#' The main table of a result: the result itself, its `table`, its first table,
#' or its scalar fields.
#' @param v The result.
#' @return A data frame.
#' @noRd
.bl_main_table <- function(v) {
  if (is.data.frame(v)) {
    return(as.data.frame(unclass(v), stringsAsFactors = FALSE, optional = TRUE))
  }
  if (is.list(v)) {
    if (is.data.frame(v$table)) {
      return(as.data.frame(v$table))
    }
    for (x in v) {
      if (is.data.frame(x)) {
        return(as.data.frame(
          unclass(x),
          stringsAsFactors = FALSE,
          optional = TRUE
        ))
      }
    }
    return(.bl_scalars(v))
  }
  if (is.atomic(v) && length(v)) {
    return(data.frame(value = v, stringsAsFactors = FALSE))
  }
  data.frame()
}

#' The length-one fields of a list, as a table.
#' @param v The list.
#' @return A data frame: field, value.
#' @noRd
.bl_scalars <- function(v) {
  if (!is.list(v) || is.data.frame(v)) {
    return(data.frame(
      field = character(),
      value = character(),
      stringsAsFactors = FALSE
    ))
  }
  keep <- names(v)[vapply(v, function(x) is.atomic(x) && length(x) == 1L, TRUE)]
  data.frame(
    field = keep,
    value = vapply(keep, function(k) .bl_cell(v[[k]], 4L), ""),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' The table card.
#' @param v The result.
#' @param digits Significant digits of the table card's numbers (default 4).
#' @param link NULL, or list(ns, cols) to make the profile's columns open their
#'   distribution.
#' @return A tag.
#' @noRd
.bl_table_ui <- function(v, digits = 4L, link = NULL) {
  if (is.character(v) && is.null(dim(v))) {
    return(shiny::tags$pre(paste(v, collapse = "\n")))
  }
  t <- .bl_main_table(v)
  if (!nrow(t)) {
    return(shiny::tags$p(
      class = "bl-about",
      "This result has no table: see the printed result."
    ))
  }
  shiny::tagList(
    if (!is.null(link)) {
      shiny::tags$p(
        class = "bl-about",
        "Choose a column name to see its distribution."
      )
    },
    .bl_html_table(utils::head(t, 200L), digits, link),
    if (nrow(t) > 200L) {
      shiny::tags$p(
        class = "bl-about",
        sprintf(
          "The first 200 of %s rows; the CSV has them all.",
          format(nrow(t), big.mark = ",")
        )
      )
    }
  )
}

#' The diagnostics card's tables: the checks and statistics a result carries,
#' its secondary tables, and its flags.
#' @param v The result.
#' @return A tag.
#' @noRd
.bl_diag_ui <- function(v) {
  tg <- shiny::tags
  parts <- list()
  sc <- .bl_scalars(v)
  if (nrow(sc)) {
    parts <- c(parts, list(tg$h6("Checks and statistics"), .bl_html_table(sc)))
  }
  if (is.list(v) && !is.data.frame(v)) {
    parts <- c(parts, .bl_diag_tables(v))
  }
  if (is.data.frame(v)) {
    parts <- c(parts, .bl_diag_flags(v))
  }
  if (!length(parts)) {
    return(tg$p(
      class = "bl-about",
      "This function returns no checks beyond its table."
    ))
  }
  shiny::tagList(parts)
}

#' The diagnostics card's tables: a result's data frames besides its main one.
#' @param v The result, a list.
#' @return A list of tags.
#' @noRd
.bl_diag_tables <- function(v) {
  tg <- shiny::tags
  parts <- list()
  dfs <- names(v)[vapply(v, is.data.frame, TRUE)]
  main <- if (is.data.frame(v$table)) "table" else dfs[1L]
  for (nm in setdiff(dfs, main)) {
    parts <- c(
      parts,
      list(
        tg$h6(nm),
        .bl_html_table(utils::head(as.data.frame(v[[nm]]), 15L))
      )
    )
  }
  parts
}

#' The diagnostics card's counts of a table's rows by its flag columns.
#' @param v The result, a data frame.
#' @return A list of tags.
#' @noRd
.bl_diag_flags <- function(v) {
  tg <- shiny::tags
  parts <- list()
  fl <- intersect(
    c(
      "flag",
      "verdict",
      "usewithcau",
      "poogrp",
      "quality",
      "drifted",
      "outlier",
      "pass"
    ),
    names(v)
  )
  for (nm in fl) {
    tb <- table(v[[nm]], useNA = "ifany")
    parts <- c(
      parts,
      list(
        tg$h6(sprintf("Rows by %s", nm)),
        .bl_html_table(data.frame(value = names(tb), rows = as.integer(tb)))
      )
    )
  }
  parts
}

#' The rows of a result that carry an estimate and an interval, for a plot of
#' intervals.
#' @param v The result.
#' @return A data frame (label, est, lo, up, ref) of at most 40 rows, or NULL.
#' @noRd
.bl_interval_rows <- function(v) {
  t <- tryCatch(.bl_main_table(v), error = function(e) data.frame())
  if (!nrow(t) || nrow(t) > 40L) {
    return(NULL)
  }
  for (e in intersect(names(.bl_hl_lo), names(t))) {
    lo <- .bl_hl_lo[[e]]
    up <- sub("lo$", "up", sub("lower", "upper", lo, fixed = TRUE))
    if (!all(c(lo, up) %in% names(t)) || !is.numeric(t[[e]])) {
      next
    }
    chr <- names(t)[vapply(
      t,
      function(z) is.character(z) || is.factor(z),
      TRUE
    )]
    chr <- setdiff(chr, c("flag", "verdict", "note"))
    lab <- if (length(chr)) {
      do.call(paste, c(lapply(t[chr], as.character), sep = ", "))
    } else {
      as.character(seq_len(nrow(t)))
    }
    ok <- is.finite(t[[e]]) & is.finite(t[[lo]]) & is.finite(t[[up]])
    if (!any(ok)) {
      return(NULL)
    }
    return(data.frame(
      label = lab[ok],
      est = t[[e]][ok],
      lo = t[[lo]][ok],
      up = t[[up]][ok],
      ref = unname(.bl_hl_ref[e]),
      name = e,
      stringsAsFactors = FALSE
    ))
  }
  NULL
}

#' Draws the estimates of a result with their intervals.
#' @param v The result.
#' @return TRUE when there was something to draw, else FALSE.
#' @noRd
.bl_forest <- function(v) {
  t <- .bl_interval_rows(v)
  if (is.null(t)) {
    return(FALSE)
  }
  k <- nrow(t)
  y <- rev(seq_len(k))
  op <- graphics::par(
    mar = c(4.2, min(16, max(5, 0.5 * max(nchar(t$label)))), 2.2, 1)
  )
  on.exit(graphics::par(op), add = TRUE)
  xr <- range(c(t$lo, t$up, t$ref), finite = TRUE)
  graphics::plot(
    xr,
    c(0.5, k + 0.5),
    type = "n",
    yaxt = "n",
    ylab = "",
    xlab = t$name[[1L]],
    main = "Estimates with their intervals",
    font.main = 1,
    cex.main = 0.95
  )
  graphics::axis(
    2,
    at = y,
    labels = t$label,
    las = 1,
    cex.axis = 0.8,
    tick = FALSE
  )
  if (!is.na(t$ref[[1L]])) {
    graphics::abline(v = t$ref[[1L]], lty = 2, col = "grey60")
  }
  graphics::segments(t$lo, y, t$up, y, col = .bl_cols(1L), lwd = 2.5)
  graphics::points(t$est, y, pch = 19, col = .bl_cols(1L))
  TRUE
}

#' A plot with a message and nothing else.
#' @param msg The message drawn in the middle of an empty plot.
#' @return NULL, invisibly.
#' @noRd
.bl_noplot <- function(msg) {
  op <- graphics::par(mar = c(0, 0, 0, 0))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot.new()
  graphics::text(0.5, 0.5, msg, col = graphics::par("col.lab"), cex = 0.95)
  invisible(NULL)
}

#' Sets the plot's ink for the page's colour mode.
#' @param mode \code{"light"} or \code{"dark"}.
#' @return The previous parameters, for `par(op)` (an empty list for light),
#'   invisibly.
#' @noRd
.bl_par_mode <- function(mode) {
  if (!identical(mode, "dark")) {
    return(invisible(list()))
  }
  # fg sets col too: col is saved with the rest, for par(op)
  invisible(.bl_par_set(
    fg = "#e6e3de",
    col.axis = "#cfcac3",
    col.lab = "#e6e3de",
    col.main = "#e6e3de",
    col.sub = "#cfcac3",
    keep = "col"
  ))
}

#' Draws a run's plot: its plot call, else its estimates with their intervals,
#' else a note.
#' @param pl The plot call or NULL.
#' @param r The run.
#' @param mode The colour mode.
#' @return NULL, invisibly.
#' @noRd
.bl_plot_run <- function(pl, r, mode = "light") {
  opm <- .bl_par_mode(mode)
  on.exit(graphics::par(opm), add = TRUE)
  if (!is.null(pl)) {
    eval(pl, r$env)
  } else if (!.bl_forest(r$value)) {
    .bl_noplot("No plot for this result:\nsee the Table card.")
  }
  invisible(NULL)
}

#' The diagnostic plots a run offers: the spec's, the observed and fitted values
#' where the result has them, and the intervals where the main plot is not
#' already them.
#' @param r The run.
#' @return A character vector of choices.
#' @noRd
.bl_diag_choices <- function(r) {
  v <- r$value
  c(
    names(r$diag),
    if (
      is.list(v) &&
        is.numeric(v$fitted) &&
        is.list(v$data) &&
        is.numeric(v$data$y)
    ) {
      "Observed and fitted"
    },
    if (!is.null(r$plot) && !is.null(.bl_interval_rows(v))) {
      "Estimates with their intervals"
    }
  )
}

#' Draws one diagnostic plot.
#' @param r The run.
#' @param w The choice.
#' @param mode The colour mode.
#' @return NULL, invisibly.
#' @noRd
.bl_draw_diag <- function(r, w, mode = "light") {
  opm <- .bl_par_mode(mode)
  on.exit(graphics::par(opm), add = TRUE)
  if (w %in% names(r$diag)) {
    eval(r$diag[[w]], r$env)
  } else if (identical(w, "Observed and fitted")) {
    v <- r$value
    op <- .bl_par_set(mfrow = c(1, 2), mar = c(4, 4, 2, 1))
    on.exit(graphics::par(op), add = TRUE)
    graphics::plot(
      v$data$x,
      v$data$y,
      pch = 19,
      col = .bl_cols(1L),
      xlab = "x",
      ylab = "observed",
      main = "Observed and fitted",
      font.main = 1
    )
    graphics::lines(v$data$x, v$fitted, col = .bl_cols(2L)[[2L]], lwd = 2)
    res <- (v$data$y - v$fitted) / sqrt(pmax(v$fitted, .Machine$double.eps))
    graphics::plot(
      v$fitted,
      res,
      pch = 19,
      col = .bl_cols(1L),
      xlab = "fitted",
      ylab = "Pearson residual",
      main = "Residuals",
      font.main = 1
    )
    graphics::abline(h = c(-2, 0, 2), lty = c(3, 2, 3), col = "grey60")
  } else {
    .bl_forest(r$value)
  }
  invisible(NULL)
}

#' The rows of the period nearest the pointer on a plot over periods.
#' @param v The result.
#' @param col The period column.
#' @param h The hover input, or NULL.
#' @return A tag.
#' @noRd
.bl_hover_ui <- function(v, col, h) {
  if (is.null(h) || !is.data.frame(v) || !col %in% names(v) || !nrow(v)) {
    return(shiny::tags$p(
      class = "bl-about",
      "Point at the plot to see the rows of the nearest period."
    ))
  }
  u <- sort(unique(v[[col]]))
  num <- suppressWarnings(as.numeric(as.character(u)))
  p <- if (!anyNA(num) && min(abs(num - h$x)) <= 1) {
    u[which.min(abs(num - h$x))]
  } else {
    u[max(1L, min(length(u), round(h$x)))]
  }
  rows <- as.data.frame(unclass(v), stringsAsFactors = FALSE, optional = TRUE)[
    v[[col]] == p,
    ,
    drop = FALSE
  ]
  shiny::tagList(shiny::tags$h6(sprintf("%s %s", col, p)), .bl_html_table(rows))
}

#' Writes a run's plot to a PNG or SVG file.
#' @param r The run.
#' @param file The PNG or SVG file the run's plot is written to.
#' @param type \code{"png"} or \code{"svg"}.
#' @return The file, invisibly.
#' @noRd
.bl_save_plot <- function(r, file, type) {
  if (identical(type, "svg")) {
    if (!.bl_have_cairo()) {
      stop(
        "this R has no SVG device (cairo): download the PNG instead",
        call. = FALSE
      )
    }
    grDevices::svg(file, width = 10, height = 6.2)
  } else {
    grDevices::png(file, width = 1600, height = 1000, res = 160)
  }
  on.exit(grDevices::dev.off(), add = TRUE)
  .bl_plot_run(r$plot, r)
  invisible(file)
}

#' The distribution of one column: histogram and distribution function, or the
#' counts of its values.
#' @param x The column whose distribution is drawn.
#' @param nm The column's name, the plots' title and axis label.
#' @param mode The colour mode.
#' @return NULL, invisibly.
#' @noRd
.bl_col_plot <- function(x, nm, mode = "light") {
  opm <- .bl_par_mode(mode)
  on.exit(graphics::par(opm), add = TRUE)
  if (is.numeric(x) && sum(is.finite(x)) > 1L) {
    op <- .bl_par_set(mfrow = c(1, 2), mar = c(4, 4, 2, 1))
    on.exit(graphics::par(op), add = TRUE)
    graphics::hist(
      x,
      breaks = "Sturges",
      col = .bl_cols(1L),
      border = "white",
      main = nm,
      xlab = nm,
      font.main = 1
    )
    graphics::plot(
      stats::ecdf(x[is.finite(x)]),
      main = "Distribution function",
      xlab = nm,
      col = .bl_cols(1L),
      font.main = 1
    )
  } else {
    tb <- utils::head(
      sort(table(as.character(x), useNA = "ifany"), decreasing = TRUE),
      20L
    )
    op <- graphics::par(
      mar = c(4, min(14, max(4, 0.5 * max(nchar(names(tb)), 1L))), 2, 1)
    )
    on.exit(graphics::par(op), add = TRUE)
    graphics::barplot(
      rev(tb),
      horiz = TRUE,
      las = 1,
      col = .bl_cols(1L),
      border = NA,
      main = nm,
      font.main = 1,
      xlab = "rows"
    )
  }
  invisible(NULL)
}

#' A summary of one column.
#' @param x The column summarised: quantiles if numeric, else counts.
#' @return A data frame: statistic, value.
#' @noRd
.bl_col_summary <- function(x) {
  if (is.numeric(x)) {
    q <- stats::quantile(
      x,
      c(0, 0.25, 0.5, 0.75, 1),
      na.rm = TRUE,
      names = FALSE
    )
    return(data.frame(
      statistic = c(
        "rows",
        "missing",
        "mean",
        "sd",
        "min",
        "q25",
        "median",
        "q75",
        "max"
      ),
      value = c(
        length(x),
        sum(is.na(x)),
        mean(x, na.rm = TRUE),
        stats::sd(x, na.rm = TRUE),
        q
      ),
      stringsAsFactors = FALSE
    ))
  }
  tb <- utils::head(
    sort(table(as.character(x), useNA = "ifany"), decreasing = TRUE),
    10L
  )
  data.frame(
    statistic = c("rows", "missing", "distinct", names(tb)),
    value = c(length(x), sum(is.na(x)), length(unique(x)), as.integer(tb)),
    stringsAsFactors = FALSE
  )
}

# ---- drift: brushing a range of the two densities ----------------------------

#' The card of the two snapshots' densities, whose brushed range gives each
#' one's share.
#' @param ns The module's namespace function for the card's output ids.
#' @return A tag.
#' @noRd
.bl_drift_brush_ui <- function(ns) {
  bslib::card(
    full_screen = TRUE,
    bslib::card_header("The two snapshots, column by column"),
    bslib::layout_columns(
      col_widths = bslib::breakpoints(sm = 12, lg = c(3, 9)),
      shiny::tagList(
        shiny::uiOutput(ns("dcolui")),
        shiny::uiOutput(ns("dshare"))
      ),
      shiny::plotOutput(
        ns("dens"),
        height = "300px",
        brush = shiny::brushOpts(
          ns("dbrush"),
          direction = "x",
          resetOnNew = TRUE
        )
      )
    )
  )
}

#' The two snapshots of a stacked table, by its `snapshot` column.
#' @param d The table.
#' @return A list of two data frames, or NULL.
#' @noRd
.bl_snaps <- function(d) {
  if (!is.data.frame(d) || !"snapshot" %in% names(d)) {
    return(NULL)
  }
  lv <- unique(d$snapshot)
  if (length(lv) != 2L) {
    return(NULL)
  }
  stats::setNames(
    lapply(lv, function(l) {
      d[d$snapshot == l, setdiff(names(d), "snapshot"), drop = FALSE]
    }),
    lv
  )
}

#' The share of each snapshot's rows in a range of a column.
#' @param sn The two snapshots.
#' @param col The numeric column whose rows in the range are counted.
#' @param lo,hi The range.
#' @return A data frame: snapshot, rows, share (percent).
#' @noRd
.bl_brush_share <- function(sn, col, lo, hi) {
  data.frame(
    snapshot = names(sn),
    rows = vapply(
      sn,
      function(d) sum(d[[col]] >= lo & d[[col]] <= hi, na.rm = TRUE),
      1
    ),
    share = vapply(
      sn,
      function(d) 100 * mean(d[[col]] >= lo & d[[col]] <= hi, na.rm = TRUE),
      1
    ),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

#' The server of the density card.
#' @param input,output,session The tab module's.
#' @param tabdata The tab's data.
#' @param mode The colour mode.
#' @return NULL, invisibly.
#' @noRd
.bl_drift_brush_server <- function(input, output, session, tabdata, mode) {
  sn <- shiny::reactive({
    d <- tabdata()
    shiny::req(!inherits(d, "bl_app_error"))
    shiny::req(.bl_snaps(d$data))
  })
  output$dcolui <- shiny::renderUI({
    s <- sn()
    num <- names(s[[1L]])[vapply(s[[1L]], is.numeric, TRUE)]
    shiny::selectInput(session$ns("dcol"), "Column", num)
  })
  output$dens <- shiny::renderPlot(
    {
      s <- sn()
      col <- shiny::req(input$dcol)
      shiny::req(col %in% names(s[[1L]]))
      .bl_drift_density(s, col, mode)
    },
    res = 96,
    bg = "transparent"
  )
  output$dshare <- shiny::renderUI({
    b <- input$dbrush
    s <- sn()
    if (is.null(b) || !shiny::isTruthy(input$dcol)) {
      return(shiny::tags$p(
        class = "bl-about",
        paste0(
          "Drag across the plot to see how many rows of each snapshot ",
          "fall in the range."
        )
      ))
    }
    sh <- .bl_brush_share(s, input$dcol, b$xmin, b$xmax)
    shiny::tagList(
      shiny::tags$h6(sprintf(
        "%s from %s to %s",
        input$dcol,
        .bl_num(b$xmin, 3L),
        .bl_num(b$xmax, 3L)
      )),
      .bl_html_table(sh, 3L)
    )
  })
  invisible(NULL)
}

#' Draws one column's density in the two snapshots, for brushing.
#' @param s The two snapshots.
#' @param col The numeric column whose two densities are drawn.
#' @param mode The reactive light or dark mode.
#' @return NULL, invisibly.
#' @noRd
.bl_drift_density <- function(s, col, mode) {
  opm <- .bl_par_mode(mode())
  on.exit(graphics::par(opm), add = TRUE)
  ds <- lapply(s, function(d) stats::density(d[[col]][is.finite(d[[col]])]))
  cl <- .bl_cols(2L)
  graphics::plot(
    ds[[1L]],
    col = cl[[1L]],
    lwd = 2,
    main = sprintf("%s: drag across a range", col),
    font.main = 1,
    xlab = col,
    ylim = c(0, max(vapply(ds, function(z) max(z$y), 1)))
  )
  graphics::lines(ds[[2L]], col = cl[[2L]], lwd = 2, lty = 2)
  graphics::legend(
    "topright",
    names(s),
    col = cl,
    lwd = 2,
    lty = 1:2,
    bty = "n"
  )
  invisible(NULL)
}

#' The effect line on balance: the largest standardised mean difference.
#' @param v The result.
#' @return Lines of text, possibly none.
#' @noRd
.bl_effect_smd <- function(v) {
  out <- character()
  smd <- .bl_eff_get(v, "smd") %||% .bl_eff_get(v, "smdafter")
  if (!is.null(smd)) {
    m <- max(abs(smd), na.rm = TRUE)
    out <- c(
      out,
      sprintf(
        paste0(
          "Largest standardised mean difference %s: %s (below 0.1 is ",
          "usually read as balanced)."
        ),
        .bl_num(m, 3L),
        if (m < 0.1) "balanced" else "not balanced"
      )
    )
  }
  out
}
