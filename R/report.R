# SPDX-License-Identifier: AGPL-3.0-or-later
#
# One command, one verdict. The pieces of this package each answer a
# narrow question -- is the schema satisfied, did the distribution move,
# where are the gaps, who signed it -- and a person deciding whether to
# trust a capsule has to run all of them and hold the answers in their
# head. This runs the battery and puts the findings in one place, worst
# first.

#' Assess a capsule in one call
#'
#' Runs the checks this package provides over one data frame and collects
#' the findings into a single report: the structural schema check, the
#' distributional comparison against a reference, the missingness
#' picture, the multivariate outliers, a Benford screen on the wide
#' numeric columns, and the integrity digests.
#'
#' Nothing here is new arithmetic. The value is that the answers arrive
#' together and ordered by severity, because the failure mode this is
#' built against is a person running one check, seeing it pass, and
#' concluding the data is fine.
#'
#' # What "severity" means
#'
#' * `fatal` -- a required column is missing. Nothing downstream can run.
#' * `warn` -- something moved: a column drifted, a value left its pinned
#'   range, missingness rose, a signature did not verify.
#' * `note` -- worth a look but not necessarily wrong: outliers, a
#'   Benford departure, a constant column.
#'
#' A clean report is not proof the data is correct. It means these
#' particular checks found nothing, and every one of them has a stated
#' blind spot -- see [capsule_drift()] on statistical power and
#' [benford_test()] on why a departure is a screen rather than a verdict.
#'
#' @param data The data frame to assess.
#' @param reference Optional data frame the capsule was pinned against.
#'   Supplying it enables the drift comparison, which is the check a
#'   digest cannot make.
#' @param schema Optional schema from [infer_schema()], or a provenance
#'   list containing one. Supplying it enables the structural check.
#' @param rules Optional list of [rule()] objects.
#' @param chunks Optional character vector of capsule chunks (see
#'   [chunk_file()]) to pin with a Merkle root.
#' @param signature,key Optional signature and verifying key, as from
#'   [capsule_sign()], checked against the data's own digest.
#' @param alpha Significance level passed to [capsule_drift()].
#' @param max_rows_outliers Skip the outlier scan above this many rows
#'   (default 20000), since it factors a covariance per call.
#' @return A list of class `bricklayer_report`: `findings` (a data frame
#'   of `severity`, `check`, `subject`, `detail`), `verdict`
#'   (`"fatal"`, `"warn"`, `"note"` or `"clean"`), `profile`,
#'   `missingness`, `drift`, `digest`, and `n_rows`/`n_cols`.
#' @seealso [capsule_drift()], [profile_columns()], [validate_schema()],
#'   [report_markdown()] to write it out.
#' @examples
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
#' capsule_report(cur, reference = ref, schema = infer_schema(ref))
#'
#' # One rescaled column and a new category: both surface, worst first.
#' bad <- cur
#' bad$score <- bad$score * 5
#' bad$grade[1:80] <- "z"
#' r <- capsule_report(bad, reference = ref, schema = infer_schema(ref))
#' r
#' r$verdict
#' r$findings[, c("severity", "check", "subject")]
#'
#' # A missing column is fatal, because nothing downstream can run.
#' capsule_report(bad[, c("id", "score")], reference = ref,
#'                schema = infer_schema(ref))$verdict
#' @export
capsule_report <- function(data, reference = NULL, schema = NULL,
                           rules = NULL, chunks = NULL, signature = NULL,
                           key = NULL, alpha = 0.01,
                           max_rows_outliers = 20000L) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame", call. = FALSE)
  }
  if (ncol(data) == 0L) {
    stop("`data` has no columns to assess", call. = FALSE)
  }
  add <- function(acc, severity, check, subject, detail) {
    rbind(acc, data.frame(severity = severity, check = check,
                          subject = subject, detail = detail,
                          stringsAsFactors = FALSE))
  }
  f <- data.frame(severity = character(0), check = character(0),
                  subject = character(0), detail = character(0),
                  stringsAsFactors = FALSE)

  prof <- profile_columns(data)
  miss <- missingness_summary(data)

  # --- structure -------------------------------------------------------
  if (!is.null(schema)) {
    prov <- if (is.list(schema) && !is.null(schema$schema)) schema else
      list(schema = schema)
    for (nm in names(issues <- validate_schema(data, prov))) {
      iss <- issues[[nm]]
      f <- add(f, if (identical(iss$severity, "fatal")) "fatal" else "warn",
               "schema", nm, iss$message)
    }
  }
  if (!is.null(rules)) {
    for (nm in names(riss <- validate_rules(data, rules))) {
      it <- riss[[nm]]
      f <- add(f, if (identical(it$severity, "fatal")) "fatal" else "warn",
               "rule", nm, it$message)
    }
  }

  # --- distribution ----------------------------------------------------
  dr <- NULL
  if (!is.null(reference)) {
    dr <- capsule_drift(reference, data, alpha = alpha)
    if (length(dr$removed)) {
      f <- add(f, "fatal", "drift", paste(dr$removed, collapse = ", "),
               "column(s) present in the reference and absent here")
    }
    if (length(dr$added)) {
      f <- add(f, "note", "drift", paste(dr$added, collapse = ", "),
               "column(s) not in the reference")
    }
    if (nrow(dr$columns)) {
      moved <- dr$columns[which(dr$columns$drifted), , drop = FALSE]
      for (i in seq_len(nrow(moved))) {
        f <- add(f, "warn", "drift", moved$column[i],
                 sprintf("%s test, p = %s", moved$type[i],
                         .rmbl_fmt_p(moved$p_value[i])))
      }
      untest <- dr$columns$column[is.na(dr$columns$drifted)]
      for (u in untest) {
        f <- add(f, "note", "drift", u,
                 "not testable: no non-missing values on one side")
      }
    }
  }

  # --- missingness -----------------------------------------------------
  if (miss[["n_cols_all_missing"]] > 0) {
    allna <- prof$column[prof$n_missing == prof$n & prof$n > 0]
    f <- add(f, "warn", "missing", paste(allna, collapse = ", "),
             "column(s) entirely missing")
  }
  gappy <- prof$column[prof$pct_missing > 50 & prof$pct_missing < 100]
  if (length(gappy)) {
    f <- add(f, "warn", "missing", paste(gappy, collapse = ", "),
             "over half the values missing")
  }
  runs <- missing_runs(data, min_run = max(2L, nrow(data) %/% 20L))
  if (nrow(runs)) {
    f <- add(f, "note", "missing", runs$column[1],
             sprintf(paste0("a contiguous run of %d missing values from ",
                            "row %d -- one outage rather than scattered ",
                            "failures"),
                     runs$length[1], runs$start[1]))
  }

  # --- shape -----------------------------------------------------------
  # An entirely-missing column is reported above; calling it constant
  # too, and then failing the outlier scan because of it, would report
  # one problem three times and bury the others.
  all_missing <- prof$column[prof$n_missing == prof$n & prof$n > 0]
  const <- setdiff(prof$column[prof$n_distinct <= 1L], all_missing)
  if (length(const)) {
    f <- add(f, "note", "shape", paste(const, collapse = ", "),
             "constant: no information, and it breaks anything scaled by variance")
  }
  num <- prof$column[!is.na(prof$n_outliers) & prof$n_outliers > 0]
  if (length(num)) {
    f <- add(f, "note", "shape", paste(utils::head(num, 5), collapse = ", "),
             "value(s) beyond the Tukey fences")
  }

  # --- multivariate outliers -------------------------------------------
  # A constant column makes the covariance singular on its own, and is
  # already reported above, so it is excluded here too. What remains
  # means the collinearity note fires only for a genuinely duplicated or
  # derived column -- the case that tells the reader something new.
  numeric_cols <- setdiff(names(data)[vapply(data, is.numeric,
                                             logical(1))],
                          c(all_missing, const))
  usable <- length(numeric_cols) >= 2L &&
    nrow(data) <= max_rows_outliers &&
    sum(stats::complete.cases(data[, numeric_cols, drop = FALSE])) >
      length(numeric_cols)
  if (usable) {
    mo <- tryCatch(mahalanobis_outliers(data[, numeric_cols, drop = FALSE]),
                   error = function(e) e)
    if (inherits(mo, "error")) {
      # Only collinearity is worth surfacing here, and only because it
      # means a duplicated or derived column is present. Anything else
      # is this check declining to run, which is not a finding about the
      # data.
      if (grepl("collinear", conditionMessage(mo))) {
        f <- add(f, "note", "shape", paste(numeric_cols, collapse = ", "),
                 "collinear: a duplicated or derived column is present")
      }
    } else if (any(mo$outlier, na.rm = TRUE)) {
      k <- sum(mo$outlier, na.rm = TRUE)
      f <- add(f, "note", "outliers", sprintf("%d row(s)", k),
               sprintf(paste0("jointly improbable given the correlations; ",
                              "worst is row %d"), mo$row[1]))
    }
  }

  # --- Benford ---------------------------------------------------------
  for (nm in numeric_cols) {
    v <- data[[nm]][is.finite(data[[nm]]) & data[[nm]] != 0]
    # only meaningful on a column spanning orders of magnitude
    if (length(v) >= 200L && diff(range(abs(v))) > 0 &&
        max(abs(v)) / min(abs(v)) > 1000) {
      b <- tryCatch(benford_test(v), error = function(e) NULL)
      if (!is.null(b) && !is.na(b$p_value) && b$p_value < 0.01) {
        f <- add(f, "note", "benford", nm,
                 sprintf(paste0("leading digits depart from Benford's law ",
                                "(p = %s); a screen, not a verdict"),
                         .rmbl_fmt_p(b$p_value)))
      }
    }
  }

  # --- integrity -------------------------------------------------------
  dig <- list(data_digest = digest_object(data))
  if (!is.null(chunks)) {
    dig$merkle_root <- merkle_root(chunks)
    dig$n_chunks <- length(chunks)
  }
  if (!is.null(signature)) {
    if (is.null(key)) {
      f <- add(f, "warn", "signature", "-",
               "a signature was supplied with no key to verify it against")
    } else {
      ok <- isTRUE(tryCatch(capsule_verify(dig$data_digest, signature, key),
                            error = function(e) FALSE))
      dig$signature_valid <- ok
      if (!ok) {
        f <- add(f, "warn", "signature", signature$scheme,
                 "did NOT verify against the data's digest")
      }
    }
  }

  rank <- c(fatal = 1L, warn = 2L, note = 3L)
  if (nrow(f)) {
    f <- f[order(rank[f$severity], f$check, f$subject), , drop = FALSE]
    rownames(f) <- NULL
  }
  verdict <- if (any(f$severity == "fatal")) "fatal" else
    if (any(f$severity == "warn")) "warn" else
      if (nrow(f)) "note" else "clean"

  out <- list(findings = f, verdict = verdict, profile = prof,
              missingness = miss, drift = dr, digest = dig,
              n_rows = nrow(data), n_cols = ncol(data))
  class(out) <- c("bricklayer_report", "list")
  out
}

#' @export
format.bricklayer_report <- function(x, ...) {
  g <- .rmbl_glyphs()
  head_line <- switch(x$verdict,
    fatal = paste0(g$bad, " FATAL: the data cannot be used as it stands"),
    warn = paste0(g$bad, " WARNINGS: something moved"),
    note = paste0(g$warn, " notes only: worth a look, nothing blocking"),
    clean = paste0(g$ok, " these checks found nothing"))
  lines <- c(.rmbl_rule("Capsule report"),
             paste0("  ", head_line),
             "",
             .rmbl_kv(list(
               rows = format(x$n_rows, big.mark = ","),
               columns = x$n_cols,
               "missing cells" = sprintf("%.1f%%",
                                         x$missingness[["pct_missing"]]),
               "complete rows" = sprintf("%.1f%%",
                          x$missingness[["pct_complete_rows"]]),
               digest = substring(x$digest$data_digest, 1L, 32L))))
  if (!is.null(x$digest$merkle_root)) {
    lines <- c(lines, .rmbl_kv(list(
      "merkle root" = substring(x$digest$merkle_root, 1L, 32L),
      chunks = x$digest$n_chunks)))
  }
  if (!is.null(x$digest$signature_valid)) {
    lines <- c(lines, .rmbl_kv(list(signature =
      if (isTRUE(x$digest$signature_valid)) paste(g$ok, "verified") else
        paste(g$bad, "NOT verified"))))
  }
  if (nrow(x$findings) == 0L) {
    return(c(lines, "",
             "  No finding is proof of correctness: each check has a",
             "  stated blind spot, and a small sample has little power.",
             .rmbl_rule()))
  }
  sym <- c(fatal = g$bad, warn = g$bad, note = g$warn)
  rows <- sprintf("  %s %-9s %-10s %-22s %s", sym[x$findings$severity],
                  x$findings$severity, x$findings$check,
                  substring(x$findings$subject, 1L, 22L),
                  x$findings$detail)
  c(lines, "", .rmbl_rule(sprintf("Findings (%d)", nrow(x$findings))),
    rows, .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_report <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @rdname rmbl_print_methods
#' @export
summary.bricklayer_report <- function(object, ...) {
  c(verdict = object$verdict,
    fatal = sum(object$findings$severity == "fatal"),
    warn = sum(object$findings$severity == "warn"),
    note = sum(object$findings$severity == "note"))
}

#' Write a capsule report as Markdown
#'
#' Renders a [capsule_report()] as Markdown, so the assessment can travel
#' with the capsule instead of living in a console someone has since
#' closed.
#'
#' @param report A `bricklayer_report`.
#' @param path Optional file to write. Without one the lines are
#'   returned.
#' @param title Heading for the document.
#' @return The Markdown lines, invisibly when written to a file.
#' @seealso [capsule_report()]
#' @examples
#' set.seed(1)
#' df <- data.frame(v = stats::rnorm(100), g = rep("x", 100),
#'                  stringsAsFactors = FALSE)
#' r <- capsule_report(df)
#'
#' md <- report_markdown(r)
#' cat(head(md, 8), sep = "\n")
#'
#' # Written beside the capsule it describes.
#' p <- tempfile(fileext = ".md")
#' report_markdown(r, p)
#' file.exists(p)
#' unlink(p)
#' @export
report_markdown <- function(report, path = NULL,
                            title = "Capsule report") {
  if (!inherits(report, "bricklayer_report")) {
    stop("`report` must come from capsule_report()", call. = FALSE)
  }
  verdict <- switch(report$verdict,
    fatal = "**FATAL** -- the data cannot be used as it stands.",
    warn = "**Warnings** -- something moved.",
    note = "Notes only -- worth a look, nothing blocking.",
    clean = "These checks found nothing.")
  md <- c(paste("#", title), "", verdict, "",
          "| | |", "|---|---|",
          sprintf("| rows | %s |", format(report$n_rows, big.mark = ",")),
          sprintf("| columns | %d |", report$n_cols),
          sprintf("| missing cells | %.1f%% |",
                  report$missingness[["pct_missing"]]),
          sprintf("| complete rows | %.1f%% |",
                  report$missingness[["pct_complete_rows"]]),
          sprintf("| data digest | `%s` |", report$digest$data_digest))
  if (!is.null(report$digest$merkle_root)) {
    md <- c(md, sprintf("| merkle root | `%s` |",
                        report$digest$merkle_root))
  }
  if (!is.null(report$digest$signature_valid)) {
    md <- c(md, sprintf("| signature | %s |",
                        if (isTRUE(report$digest$signature_valid))
                          "verified" else "**NOT verified**"))
  }
  md <- c(md, "")
  if (nrow(report$findings)) {
    md <- c(md, "## Findings", "",
            "| severity | check | subject | detail |",
            "|---|---|---|---|",
            sprintf("| %s | %s | %s | %s |",
                    report$findings$severity, report$findings$check,
                    report$findings$subject, report$findings$detail),
            "")
  }
  md <- c(md, "## Caveat", "",
          paste("No finding is proof of correctness. Each check has a",
                "stated blind spot, a small sample has little power, and",
                "the Benford screen in particular is a reason to look",
                "rather than a verdict."))
  if (is.null(path)) return(md)
  writeLines(md, path)
  invisible(md)
}
