# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SIU parse/resolve surface over the native core (src/siu_*.cpp is the
# canonical home; rmorie links to this same core, there is no separate
# SIU package). Everything here
# is deterministic and offline; the only network function remains
# bricklayer_fetch_siu().

#' The panel-reviewed SIU report field schema
#'
#' The sixteen fields extracted from every Special Investigations Unit
#' director's report. Count-type fields ( `is_count = TRUE`) count
#' distinct entities and zero is a real answer -- a witness-official-only
#' investigation has zero subject officials.
#'
#' @return A data.frame with columns `name`, `is_count`, and
#' `description`.
#' @examples
#' bricklayer_siu_schema()
#' @export
bricklayer_siu_schema <- function() {
  as.data.frame(.Call(C_rmbl_siu_schema, NULL), stringsAsFactors = FALSE)
}

#' Convert SIU report HTML to plain text
#'
#' @param html A length-1 character vector of raw report HTML.
#' @section Limits:
#' The input is capped at 2 MiB (a report page is a few hundred KB). Before
#' the text is read, a line longer than 2000 characters is split at the
#' sentence end nearest the cap (else at a space), and a warning says how
#' many lines were split: a field that spans a split may be incomplete.
#' @return A length-1 character vector of plain text.
#' @examples
#' bricklayer_siu_text("<p>Number of SIU Investigators assigned: 3</p>")
#' @export
bricklayer_siu_text <- function(html) {
  .bl_siu_split_warn(.Call(C_rmbl_siu_html_to_text, html))
}

#' Parse an SIU director's report into the schema fields
#'
#' Deterministic, offline extraction of every
#' [bricklayer_siu_schema()] field
#' (plus `_language`) from report HTML. Fields the report does not
#' state come back as `""`.
#'
#' @param html A length-1 character vector of raw report HTML,
#' or the path to a saved report file (e.g. from
#' [bricklayer_fetch_siu()]) .
#' @section Limits:
#' The input is capped at 2 MiB (a report page is a few hundred KB). Before
#' the text is read, a line longer than 2000 characters is split at the
#' sentence end nearest the cap (else at a space), and a warning says how
#' many lines were split: a field that spans a split may be incomplete.
#' @return A named character vector: the 16 schema fields plus
#' `_language`.
#' @examples
#' f <- bricklayer_parse_siu(system.file("extdata",
#'                                       "siu_synthetic_report.html",
#'                                       package = "rmoriebricklayer"))
#' f[["number_of_subject_officials"]]
#' @export
bricklayer_parse_siu <- function(html) {
  if (!is.character(html) || anyNA(html) || !length(html)) {
    stop("`html` must be report HTML (or the path of a saved report), not ",
         if (!length(html)) "an empty vector" else if (anyNA(html)) "NA" else class(html)[1L], call. = FALSE)
  }
  if (length(html) > 1L) {
    # several reports: one row each
    rows <- lapply(html, bricklayer_parse_siu)
    cols <- unique(unlist(lapply(rows, names)))
    out <- lapply(cols, function(cn) vapply(rows, function(r) if (cn %in% names(r)) r[[cn]] else NA_character_, ""))
    names(out) <- cols
    return(as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE))
  }
  # a path is short: file.exists() on a 4096-byte "path" warns (0.5.8 diff review)
  if (!grepl("<", html, fixed = TRUE) && nchar(html, type = "bytes") < 1000L && file.exists(html)) {
    html <- paste(readLines(html, warn = FALSE, encoding = "UTF-8"),
                  collapse = "\n")
  } else if (!grepl("[<\n]", html) && grepl("\\.html?$|[/\\\\]", html, ignore.case = TRUE)) {
    # a mistyped path is not an empty report
    stop("`html`: no such file: ", html, call. = FALSE)
  }
  .bl_siu_split_warn(.Call(C_rmbl_siu_parse_html, html))
}

#' Fetch and parse one SIU director's report
#'
#' Convenience: [bricklayer_fetch_siu()]
#' then [bricklayer_parse_siu()]. Fails
#' gracefully -- returns `NULL` with a message when the report cannot
#' be retrieved.
#'
#' @param drid Director's-report id (the `drid=` query
#' parameter).
#' @param lang `"en"` (default) or `"fr"`.
#' @return A named character vector of parsed fields, or `NULL` when
#' the fetch fails.
#' @examples
#' \donttest{
#' f <- try(bricklayer_fetch_parse_siu(648), silent = TRUE)
#' if (is.character(f)) f[["police_service"]]
#' }
#' @export
bricklayer_fetch_parse_siu <- function(drid, lang = c("en", "fr")) {
  lang <- match.arg(lang)  # argument errors, before any network
  drid <- .rmbl_drid(drid)
  dest <- tempfile(fileext = ".html")
  on.exit(unlink(dest), add = TRUE)
  ok <- tryCatch(bricklayer_fetch_siu(drid, dest, lang = lang),
                 error = function(e) {
                   message("bricklayer: could not fetch SIU report ", drid,
                           ": ", conditionMessage(e))
                   NULL
                 })
  if (is.null(ok) || !file.exists(dest)) return(NULL)
  bricklayer_parse_siu(dest)
}

#' Convert a human-readable SIU report date to ISO format
#'
#' `"January 5, 2023"` (or `"January 5 2023"`) becomes
#' `"2023-01-05"`; unparseable input becomes `""`.
#'
#' @param x A character vector of human-readable dates.
#' @return A character vector of `YYYY-MM-DD` strings (or `""`) .
#' @examples
#' bricklayer_siu_iso_date(c("January 5, 2023", "not a date"))
#' @export
bricklayer_siu_iso_date <- function(x) {
  if (!is.character(x) && !all(is.na(x))) stop("`x` must be a character vector of dates", call. = FALSE)
  x <- as.character(x)
  vapply(x, function(v) if (is.na(v)) NA_character_ else .Call(C_rmbl_siu_to_iso_date, v), character(1),
         USE.NAMES = FALSE)
}

#' Resolve the subject-official count from SIU report text
#'
#' Deterministic, reproducible extraction of the subject-official (SO)
#' count for reports where a model panel (or a human) is unsure. The
#' standard SIU privacy boilerplate is stripped first, then rules apply
#' most-specific first: highest `SO #N` ordinal; spelled-out plural;
#' singular subject official present (1); witness-official-only (0, a real
#' answer); otherwise unresolved ( `NA`) .
#'
#' @param text A length-1 character vector of plain report text
#' (see [bricklayer_siu_text()]) .
#' @return A list with `count` (integer, `NA` when unresolved)
#' and `reason` (the human-readable evidence).
#'
#' @details This function is the pure rule set. For reports that already
#' have a panel-reviewed count, prefer that verified value; use these rules
#' for unreviewed reports.
#' @examples
#' bricklayer_siu_resolve_so(
#'   "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#' @export
bricklayer_siu_resolve_so <- function(text) {
  if (!is.character(text) || length(text) != 1L || is.na(text)) {
    stop("`text` must be a single string of report text", call. = FALSE)
  }
  .bl_siu_split_warn(.Call(C_rmbl_siu_resolve_so, text))
}


# The core splits any line longer than 2000 characters before the extractors
# run (their regexes recurse once per character); it prefers a sentence end
# and counts what it split. A field spanning a split can come back incomplete,
# so the count is said, never swallowed (the SIU review's silent truncation).
.bl_siu_split_warn <- function(x) {
  n <- attr(x, "split_lines", exact = TRUE)
  if (!is.null(n)) {
    attr(x, "split_lines") <- NULL
    warning(sprintf(paste("%d line%s longer than 2000 characters %s split for extraction;",
                          "a field spanning a split may be incomplete"),
                    n, if (n == 1L) "" else "s", if (n == 1L) "was" else "were"), call. = FALSE)
  }
  x
}
