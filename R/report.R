# SPDX-License-Identifier: AGPL-3.0-or-later
#
# One command, one verdict. The pieces of this package each answer a
# narrow question -- is the schema satisfied, did the distribution move,
# where are the gaps, who signed it -- and a person deciding whether to
# trust a capsule has to run all of them and hold the answers in their
# head. This runs them all and puts the findings in one place, worst
# first.

#' Assess a capsule in one call
#'
#' Runs the checks this package provides over one data frame and collects
#' the findings into a single report: the structural schema check, the
#' distributional comparison against a reference, the missingness picture,
#' the multivariate outliers, a Benford screen on the wide numeric columns,
#' and the integrity digests. Use it as the first look at a capsule or a fresh
#' extract, before any analysis, and keep the Markdown version
#' ([rptmd()]) with the outputs.
#'
#' Nothing here is new arithmetic. The value is that the answers arrive
#' together and ordered by severity, because the failure mode this is built
#' against is a person running one check, seeing it pass, and concluding
#' the data is fine.
#'
#' # What `severity` means
#'
#' * `fatal` -- nothing downstream can run as it stands: a schema check or a
#' rule of severity `"fatal"` failed (for example a required column is
#' missing), or a column of the reference is absent from the data.
#' * `warn` -- something moved or is badly incomplete: a schema check, or a
#' rule of severity `"warning"`, failed (a value left its pinned range, a type
#' changed), a column drifted from the reference, a column is entirely
#' missing or more than half missing, or a signature did not verify (or came
#' with no key).
#' * `note` -- worth a look but not necessarily wrong: a column not in the
#' reference, a column whose drift could not be tested, a contiguous run of
#' missing values (one outage rather than scattered gaps), a constant column,
#' values beyond the Tukey fences, multivariate outliers or collinear columns,
#' a Benford departure.
#'
#' # How each check runs
#'
#' The drift comparison is [cpsdrft()] at level
#' `alpha`. The missing
#' run is the longest run from [missruns()] of at least
#' `max(2, nrow(data) %/% 20)` rows. The outlier scan is
#' [mahaoutl()] on the numeric columns
#' that are not constant or
#' entirely missing, run only when there are at least two of them, at most
#' `maxrowsoutl` rows and more complete rows than columns. The Benford
#' screen ([benfordtst()]) runs on a numeric column with at
#' least 200
#' non-zero finite values whose largest absolute value is more than 1,000
#' times its smallest, and reports p below 0.01. The digest is
#' [dgstobj()] of the data; a signature is checked with
#' [cpsvrf()] against that digest.
#'
#' Findings are sorted by severity, then check, then subject. Nothing is
#' written and nothing is fetched. Errors when `data` is not a data frame or
#' has no columns, and when `schema` or `rules` are malformed (from
#' [valsch()] and
#' [valrules()]).
#'
#' A clean report is not proof the data is correct. It means these
#' particular checks found nothing, and every one of them has a stated
#' blind spot -- see [cpsdrft()] on
#' statistical power and [benfordtst()] on why
#' a departure is a screen rather than a verdict.
#'
#' @param data The data frame to assess.
#' @param ref Optional data frame the capsule was
#' pinned against. Supplying it enables the drift comparison, which is the
#' check a digest cannot make.
#' @param schema Optional schema from
#' [infsch()], or a provenance list
#' containing one. Supplying it enables the structural check.
#' @param rules Optional list of [rul()]
#' objects.
#' @param chunks Optional character vector of capsule chunks
#' (see [chnkfile()]) to pin with a Merkle root.
#' @param sig,key Optional signature and
#' verifying key, as from [cpssign()],
#' checked against the data's own digest.
#' @param alpha Numeric scalar, the significance level passed to
#' [cpsdrft()]; default `0.01`.
#' @param maxrowsoutl Integer scalar: skip the outlier scan
#' above this many rows (default 20000), since it factors a covariance per
#' call.
#' @return A list of class `c("bricklayer_report", "list")`: `findings` (a
#' data frame of character columns `severity`, `check` (`"schema"`,
#' `"rule"`, `"drift"`, `"missing"`, `"shape"`, `"outliers"`,
#' `"benford"` or
#' `"signature"`), `subject` (the column, rule or row count concerned) and
#' `detail`), `verdict` (the worst severity: `"fatal"`, `"warn"`,
#' `"note"`, or
#' `"clean"` when there is no finding), `profile` (from
#' [profcols()]),
#' `missingness` (from [misssmry()]),
#' `drift` (the
#' [cpsdrft()] result, or `NULL` without a
#' reference), `digest` (a list
#' with `data_digest`, and with `chunks` also `merkle_root`,
#' `merkle_scheme`
#' (the [mrkroot()] hashing scheme, 2) and `n_chunks`,
#' and, with a signature and key, the logical `signature_valid`), and `nrows` /
#' `n_cols`. `print()` shows the verdict and the findings; `summary()`
#' gives
#' the verdict and the count of each severity.
#' @seealso
#' [cpsdrft()],
#' [profcols()],
#' [valsch()],
#' [rptmd()] to write it out.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' ref <- data.frame(
#'   id = 1:200,
#'   score = stats::runif(200, 0, 10),
#'   grade = sample(c("a", "b", "c"), 200, TRUE),
#'   stringsAsFactors = FALSE
#' )
#'
#' # A fresh extract from the same process: nothing to report.
#' cur <- ref
#' cur$score <- stats::runif(200, 0, 10)
#' cpsrpt(cur, ref = ref, schema = infsch(ref))
#'
#' # One rescaled column and a new category: both surface, worst first.
#' bad <- cur
#' bad$score <- bad$score * 5
#' bad$grade[1:80] <- "z"
#' r <- cpsrpt(bad, ref = ref, schema = infsch(ref))
#' r
#' r$verdict
#' r$findings[, c("severity", "check", "subject")]
#'
#' # A missing column is fatal, because nothing downstream can run.
#' cpsrpt(bad[, c("id", "score")], ref = ref, schema = infsch(ref))$verdict
#'
#' # validation rules join the findings, and chunks are pinned with a Merkle
#' # root
#' r2 <- cpsrpt(
#'   bad,
#'   rules = list(ruleinset("grade", c("a", "b", "c"))),
#'   chunks = c("part one", "part two")
#' )
#' summary(r2)
#' r2$digest$merkle_root
#'
#' # a data frame is required
#' try(cpsrpt(1:10))
#' @export
cpsrpt <- function(
  data,
  ref = NULL,
  schema = NULL,
  rules = NULL,
  chunks = NULL,
  sig = NULL,
  key = NULL,
  alpha = 0.01,
  maxrowsoutl = 20000L
) {
  maxrowsoutl <- .rpt_check_args(data, maxrowsoutl)
  f <- .rpt_empty()

  prof <- profcols(data)
  miss <- misssmry(data)

  f <- .rpt_structure(f, data, schema, rules)
  dr <- NULL
  if (!is.null(ref)) {
    dr <- cpsdrft(ref, data, alpha = alpha)
    f <- .rpt_drift(f, dr)
  }
  f <- .rpt_missing(f, data, prof, miss)
  # An entirely-missing column is reported above; calling it constant
  # too, and then failing the outlier scan because of it, would report
  # one problem three times and bury the others.
  all_missing <- prof$column[prof$n_missing == prof$n & prof$n > 0]
  const <- setdiff(prof$column[prof$n_distinct <= 1L], all_missing)
  f <- .rpt_shape(f, prof, const)
  # A constant column makes the covariance singular on its own, and is
  # already reported above, so it is excluded here too. What remains
  # means the collinearity note fires only for a genuinely duplicated or
  # derived column -- the case that tells the reader something new.
  numeric_cols <- setdiff(
    names(data)[vapply(data, is.numeric, logical(1))],
    c(all_missing, const)
  )
  f <- .rpt_outliers(f, data, numeric_cols, maxrowsoutl)
  f <- .rpt_benford(f, data, numeric_cols)
  ig <- .rpt_integrity(f, data, chunks, sig, key)
  f <- ig$f

  f <- .rpt_sort(f)
  verdict <- .rpt_verdict(f)

  out <- list(
    findings = f,
    verdict = verdict,
    profile = prof,
    missingness = miss,
    drift = dr,
    digest = ig$dig,
    n_rows = nrow(data),
    n_cols = ncol(data)
  )
  class(out) <- c("bricklayer_report", "list")
  out
}

#' @export
format.bricklayer_report <- function(x, ...) {
  g <- .rmbl_glyphs()
  f <- x$findings
  head_line <- switch(
    x$verdict,
    fatal = paste0(g$bad, " FATAL: the data cannot be used as it stands"),
    warn = paste0(g$bad, " WARNINGS: something moved"),
    note = paste0(g$warn, " notes only: worth a look, nothing blocking"),
    clean = paste0(g$ok, " these checks found nothing")
  )
  facts <- list(
    Verdict = head_line,
    Rows = format(x$n_rows, big.mark = ","),
    Columns = x$n_cols,
    `Missing cells` = sprintf("%.1f%%", x$missingness[["pct_missing"]]),
    `Complete rows` = sprintf("%.1f%%", x$missingness[["pct_complete_rows"]]),
    Digest = substring(x$digest$data_digest, 1L, 32L),
    `Merkle root` = if (!is.null(x$digest$merkle_root)) {
      sprintf(
        "%s (%s chunks)",
        substring(x$digest$merkle_root, 1L, 32L),
        x$digest$n_chunks
      )
    },
    Signature = .rpt_sig_text(x$digest$signature_valid, g),
    Findings = nrow(f)
  )
  .rmbl_stat_block(
    "Capsule report",
    facts = facts,
    reading = c(
      "No finding is proof of correctness: each check has a",
      "stated blind spot, and a small sample has little power."
    ),
    notes = if (nrow(f)) {
      sprintf(
        "%s %-5s %-10s %s: %s",
        ifelse(f$severity == "note", "!   ", "FAIL"),
        f$severity,
        f$check,
        substring(f$subject, 1L, 22L),
        f$detail
      )
    }
  )
}

#' @rdname printmeth
#' @export
summary.bricklayer_report <- function(object, ...) {
  c(
    verdict = object$verdict,
    fatal = sum(object$findings$severity == "fatal"),
    warn = sum(object$findings$severity == "warn"),
    note = sum(object$findings$severity == "note")
  )
}

#' Write a capsule report as Markdown
#'
#' Renders a [cpsrpt()] as Markdown,
#' so the assessment can travel with the capsule instead of living in a
#' console someone has since closed. The document renders on GitHub, in
#' R Markdown and Quarto, and in any Markdown viewer, and reads well as plain
#' text.
#'
#' @details The document has a level-one heading (`title`), the verdict in one
#' sentence, a two-column table of rows, columns, missing cells, complete rows
#' and the full data digest (with the Merkle root and the signature result when
#' the report has them), a \code{"Findings"} table of severity, check, subject
#' and detail (left out when there is none), and a closing caveat that no
#' finding is proof of correctness. The text of the findings is written as it
#' is: a `|` in a column name would break the table. An existing file at `path`
#' is overwritten. Errors when `report` does not come from
#' [cpsrpt()].
#'
#' @param report A `bricklayer_report` from
#'   [cpsrpt()].
#' @param path Optional character scalar, the file to write. Without one
#' (`NULL`, the default) the lines are returned.
#' @param title Character scalar, the heading for the document; default
#' `"Capsule report"`.
#' @return A character vector of Markdown lines; returned visibly when `path`
#' is `NULL`, invisibly when written to a file.
#' @seealso [cpsrpt()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' df <- data.frame(v = stats::rnorm(100), g = rep("x", 100),
#'                  stringsAsFactors = FALSE)
#' r <- cpsrpt(df)
#'
#' md <- rptmd(r)
#' cat(head(md, 8), sep = "\n")
#'
#' # Written beside the capsule it describes.
#' p <- tempfile(fileext = ".md")
#' rptmd(r, p)
#' file.exists(p)
#' unlink(p)
#'
#' # a report with findings, under its own title
#' r2 <- cpsrpt(transform(df, v = ifelse(seq_along(v) <= 60, NA, v)))
#' md2 <- rptmd(r2, title = "Extract of 2024-03-01")
#' md2[1]
#' md2[grep("^## Findings", md2) + 0:4]
#'
#' # only a cpsrpt() result is accepted
#' try(rptmd(list(verdict = "clean")))
#' @export
rptmd <- function(report, path = NULL, title = "Capsule report") {
  if (!inherits(report, "bricklayer_report")) {
    stop("`report` must come from cpsrpt()", call. = FALSE)
  }
  if (!is.null(path)) {
    path <- .rmbl_out_file(path, "path")
  }
  title <- .rmbl_text1(title, "title")
  md <- .rpt_md_head(report, title)
  if (nrow(report$findings)) {
    md <- c(
      md,
      "## Findings",
      "",
      "| severity | check | subject | detail |",
      "|---|---|---|---|",
      sprintf(
        "| %s | %s | %s | %s |",
        report$findings$severity,
        report$findings$check,
        report$findings$subject,
        report$findings$detail
      ),
      ""
    )
  }
  md <- c(
    md,
    "## Caveat",
    "",
    paste(
      "No finding is proof of correctness. Each check has a",
      "stated blind spot, a small sample has little power, and",
      "the Benford screen in particular is a reason to look",
      "rather than a verdict."
    )
  )
  if (is.null(path)) {
    return(md)
  }
  .rmbl_wlines(md, path)
  invisible(md)
}

#' Adds one finding to the report's findings.
#' @param acc The findings so far.
#' @param severity,check,subject,detail The finding.
#' @return The findings.
#' @noRd
.rpt_add <- function(acc, severity, check, subject, detail) {
  rbind(
    acc,
    data.frame(
      severity = severity,
      check = check,
      subject = subject,
      detail = detail,
      stringsAsFactors = FALSE
    )
  )
}

#' Structure: the schema's and the rules' issues.
#' @param f The findings so far.
#' @param data,schema,rules As for cpsrpt().
#' @return The findings.
#' @noRd
.rpt_structure <- function(f, data, schema, rules) {
  if (!is.null(schema)) {
    prov <- if (is.list(schema) && !is.null(schema$schema)) {
      schema
    } else {
      list(schema = schema)
    }
    issues <- valsch(data, prov)
    for (nm in names(issues)) {
      iss <- issues[[nm]]
      f <- .rpt_add(
        f,
        if (identical(iss$severity, "fatal")) "fatal" else "warn",
        "schema",
        nm,
        iss$message
      )
    }
  }
  if (!is.null(rules)) {
    riss <- valrules(data, rules)
    for (nm in names(riss)) {
      it <- riss[[nm]]
      f <- .rpt_add(
        f,
        if (identical(it$severity, "fatal")) "fatal" else "warn",
        "rule",
        nm,
        it$message
      )
    }
  }
  f
}

#' Distribution: the drift against the reference.
#' @param f The findings so far.
#' @param dr The drift result (cpsdrft()).
#' @return The findings.
#' @noRd
.rpt_drift <- function(f, dr) {
  if (length(dr$removed)) {
    f <- .rpt_add(
      f,
      "fatal",
      "drift",
      toString(dr$removed),
      "column(s) present in the reference and absent here"
    )
  }
  if (length(dr$added)) {
    f <- .rpt_add(
      f,
      "note",
      "drift",
      toString(dr$added),
      "column(s) not in the reference"
    )
  }
  if (!nrow(dr$columns)) {
    return(f)
  }
  moved <- dr$columns[which(dr$columns$drifted), , drop = FALSE]
  for (i in seq_len(nrow(moved))) {
    f <- .rpt_add(
      f,
      "warn",
      "drift",
      moved$column[i],
      sprintf("%s test, p = %s", moved$type[i], .rmbl_fmt_p(moved$p_value[i]))
    )
  }
  for (u in dr$columns$column[is.na(dr$columns$drifted)]) {
    f <- .rpt_add(
      f,
      "note",
      "drift",
      u,
      "not testable: no non-missing values on one side"
    )
  }
  f
}

#' Missingness: columns entirely or mostly missing, and a long run of missing
#' values.
#' @param f The findings so far.
#' @param data The data checked for runs of missing values.
#' @param prof,miss Its column profile and missingness summary.
#' @return The findings.
#' @noRd
.rpt_missing <- function(f, data, prof, miss) {
  if (miss[["n_cols_all_missing"]] > 0) {
    allna <- prof$column[prof$n_missing == prof$n & prof$n > 0]
    f <- .rpt_add(
      f,
      "warn",
      "missing",
      toString(allna),
      "column(s) entirely missing"
    )
  }
  gappy <- prof$column[prof$pct_missing > 50 & prof$pct_missing < 100]
  if (length(gappy)) {
    f <- .rpt_add(
      f,
      "warn",
      "missing",
      toString(gappy),
      "over half the values missing"
    )
  }
  runs <- missruns(data, minrun = max(2L, nrow(data) %/% 20L))
  if (nrow(runs)) {
    f <- .rpt_add(
      f,
      "note",
      "missing",
      runs$column[1],
      sprintf(
        paste0(
          "a contiguous run of %d missing values from ",
          "row %d -- one outage rather than scattered ",
          "failures"
        ),
        runs$length[1],
        runs$start[1]
      )
    )
  }
  f
}

#' Shape: constant columns, and values beyond the Tukey fences.
#' @param f The findings so far.
#' @param prof The column profile.
#' @param const The constant columns.
#' @return The findings.
#' @noRd
.rpt_shape <- function(f, prof, const) {
  if (length(const)) {
    f <- .rpt_add(
      f,
      "note",
      "shape",
      toString(const),
      "constant: no information, and it breaks anything scaled by variance"
    )
  }
  num <- prof$column[!is.na(prof$n_outliers) & prof$n_outliers > 0]
  if (length(num)) {
    f <- .rpt_add(
      f,
      "note",
      "shape",
      toString(utils::head(num, 5)),
      "value(s) beyond the Tukey fences"
    )
  }
  f
}

#' Multivariate outliers (Mahalanobis), and collinearity.
#' @param f The findings so far.
#' @param data The data whose numeric columns are screened for outliers.
#' @param numeric_cols The numeric columns that vary.
#' @param maxrowsoutl As for cpsrpt().
#' @return The findings.
#' @noRd
.rpt_outliers <- function(f, data, numeric_cols, maxrowsoutl) {
  usable <- length(numeric_cols) >= 2L &&
    nrow(data) <= maxrowsoutl &&
    sum(stats::complete.cases(data[, numeric_cols, drop = FALSE])) >
      length(numeric_cols)
  if (!usable) {
    return(f)
  }
  mo <- tryCatch(
    mahaoutl(data[, numeric_cols, drop = FALSE]),
    error = function(e) e
  )
  if (inherits(mo, "error")) {
    # Only collinearity is worth surfacing here, and only because it
    # means a duplicated or derived column is present. Anything else
    # is this check declining to run, which is not a finding about the
    # data.
    if (grepl("collinear", conditionMessage(mo), fixed = TRUE)) {
      f <- .rpt_add(
        f,
        "note",
        "shape",
        toString(numeric_cols),
        "collinear: a duplicated or derived column is present"
      )
    }
    return(f)
  }
  if (any(mo$outlier, na.rm = TRUE)) {
    k <- sum(mo$outlier, na.rm = TRUE)
    f <- .rpt_add(
      f,
      "note",
      "outliers",
      sprintf("%d row(s)", k),
      sprintf(
        paste0(
          "jointly improbable given the correlations; ",
          "worst is row %d"
        ),
        mo$row[1]
      )
    )
  }
  f
}

#' Benford's law on columns spanning orders of magnitude: a screen, not a
#' verdict.
#' @param f The findings so far.
#' @param data The data whose numeric columns get a Benford screen.
#' @param numeric_cols The numeric columns that vary.
#' @return The findings.
#' @noRd
.rpt_benford <- function(f, data, numeric_cols) {
  for (nm in numeric_cols) {
    v <- data[[nm]][is.finite(data[[nm]]) & data[[nm]] != 0]
    # only meaningful on a column spanning orders of magnitude
    if (
      length(v) < 200L ||
        diff(range(abs(v))) <= 0 ||
        max(abs(v)) / min(abs(v)) <= 1000
    ) {
      next
    }
    b <- tryCatch(benfordtst(v), error = function(e) NULL)
    if (!is.null(b) && !is.na(b$p_value) && b$p_value < 0.01) {
      f <- .rpt_add(
        f,
        "note",
        "benford",
        nm,
        sprintf(
          paste0(
            "leading digits depart from Benford's law ",
            "(p = %s); a screen, not a verdict"
          ),
          .rmbl_fmt_p(b$p_value)
        )
      )
    }
  }
  f
}

#' Integrity: the data's digest, its Merkle root, and the signature.
#' @param f The findings so far.
#' @param data,chunks,sig,key As for cpsrpt().
#' @return A list: f (the findings) and dig (the digests).
#' @noRd
.rpt_integrity <- function(f, data, chunks, sig, key) {
  dig <- list(data_digest = dgstobj(data))
  if (!is.null(chunks)) {
    dig$merkle_root <- mrkroot(chunks)
    dig$merkle_scheme <- 2L
    dig$n_chunks <- length(chunks)
  }
  if (is.null(sig)) {
    return(list(f = f, dig = dig))
  }
  if (is.null(key)) {
    f <- .rpt_add(
      f,
      "warn",
      "signature",
      "-",
      "a signature was supplied with no key to verify it against"
    )
    return(list(f = f, dig = dig))
  }
  ok <- isTRUE(tryCatch(
    cpsvrf(dig$data_digest, sig, key),
    error = function(e) FALSE
  ))
  dig$signature_valid <- ok
  if (!ok) {
    f <- .rpt_add(
      f,
      "warn",
      "signature",
      sig$scheme,
      "did NOT verify against the data's digest"
    )
  }
  list(f = f, dig = dig)
}

#' Checks cpsrpt()'s `data` and `maxrowsoutl`.
#' @param data The data passed.
#' @param maxrowsoutl The row cap passed.
#' @return `maxrowsoutl` as a number.
#' @noRd
.rpt_check_args <- function(data, maxrowsoutl) {
  if (!is.data.frame(data)) {
    stop("cpsrpt: `data` must be a data frame", call. = FALSE)
  }
  if (ncol(data) == 0L) {
    stop("`data` has no columns to assess", call. = FALSE)
  }
  maxrowsoutl <- .rmbl_num(maxrowsoutl, "maxrowsoutl")
  if (length(maxrowsoutl) != 1L || is.na(maxrowsoutl) || maxrowsoutl < 0) {
    stop("`maxrowsoutl` must be one non-negative number of rows", call. = FALSE)
  }
  maxrowsoutl
}

#' The report's findings table with no rows.
#' @return A data frame of severity, check, subject and detail.
#' @noRd
.rpt_empty <- function() {
  data.frame(
    severity = character(0),
    check = character(0),
    subject = character(0),
    detail = character(0),
    stringsAsFactors = FALSE
  )
}

#' Orders the findings: fatal first, then warn, then note.
#' @param f The findings.
#' @return The findings, sorted, row names reset.
#' @noRd
.rpt_sort <- function(f) {
  rank <- c(fatal = 1L, warn = 2L, note = 3L)
  if (nrow(f)) {
    f <- f[order(rank[f$severity], f$check, f$subject), , drop = FALSE]
    rownames(f) <- NULL
  }
  f
}

#' The report's verdict: its worst finding, or "clean".
#' @param f The findings.
#' @return One of "fatal", "warn", "note" or "clean".
#' @noRd
.rpt_verdict <- function(f) {
  if (any(f$severity == "fatal")) {
    "fatal"
  } else if (any(f$severity == "warn")) {
    "warn"
  } else if (nrow(f)) {
    "note"
  } else {
    "clean"
  }
}

#' The signature result of a printed report, in words.
#' @param valid The report's `signature_valid`, or NULL.
#' @param g The glyphs from .rmbl_glyphs(), for the verified mark.
#' @return One string, or NULL when the data were not signed.
#' @noRd
.rpt_sig_text <- function(valid, g) {
  if (is.null(valid)) {
    return(NULL)
  }
  if (isTRUE(valid)) paste(g$ok, "verified") else paste(g$bad, "NOT verified")
}

#' The title, verdict and summary table of rptmd()'s Markdown.
#' @param report A cpsrpt() result.
#' @param title The checked title, as the report's heading.
#' @return A character vector of Markdown lines, ending in a blank one.
#' @noRd
.rpt_md_head <- function(report, title) {
  verdict <- switch(
    report$verdict,
    fatal = "**FATAL** -- the data cannot be used as it stands.",
    warn = "**Warnings** -- something moved.",
    note = "Notes only -- worth a look, nothing blocking.",
    clean = "These checks found nothing."
  )
  md <- c(
    paste("#", title),
    "",
    verdict,
    "",
    "| | |",
    "|---|---|",
    sprintf("| rows | %s |", format(report$n_rows, big.mark = ",")),
    sprintf("| columns | %d |", report$n_cols),
    sprintf("| missing cells | %.1f%% |", report$missingness[["pct_missing"]]),
    sprintf(
      "| complete rows | %.1f%% |",
      report$missingness[["pct_complete_rows"]]
    ),
    sprintf("| data digest | `%s` |", report$digest$data_digest)
  )
  if (!is.null(report$digest$merkle_root)) {
    md <- c(md, sprintf("| merkle root | `%s` |", report$digest$merkle_root))
  }
  if (!is.null(report$digest$signature_valid)) {
    md <- c(
      md,
      sprintf(
        "| signature | %s |",
        if (isTRUE(report$digest$signature_valid)) {
          "verified"
        } else {
          "**NOT verified**"
        }
      )
    )
  }
  c(md, "")
}
