# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SIU parse/resolve surface over the native core (src/siu_*.cpp is the
# canonical home; rmorie links to this same core, there is no separate
# SIU package). Everything here
# is deterministic and offline; the only network function remains
# bricklayer_fetch_siu().

#' The panel-reviewed SIU report field schema
#'
#' Returns the sixteen fields that the package extracts from every Ontario
#' Special Investigations Unit (SIU) director's report, with a one-line
#' description of each. Use it to see what
#' [bricklayer_parse_siu()] returns,
#' to build an empty coding sheet for hand review, or to check which fields
#' are counts before summing them across reports.
#'
#' @details
#' The schema is held in the native core (src/siu_schema.h) and is the same
#' list that [bricklayer_parse_siu()] fills. Three
#' fields are dates in ISO
#' \code{YYYY-MM-DD} form, five are counts and the rest are free text.
#' Count-type fields (\code{is_count = TRUE}) count distinct entities, and
#' zero is a real answer: a witness-official-only investigation has zero
#' subject officials. The function takes no arguments, reads no files and
#' uses no network.
#'
#' @return A data.frame with 16 rows and three columns: \code{name}
#'   (character, the field name used by
#'   [bricklayer_parse_siu()]),
#'   \code{is_count} (logical, \code{TRUE} for the five count fields) and
#'   \code{description} (character, what the field records).
#' @examples
#' s <- bricklayer_siu_schema()
#' s$name
#'
#' # only the count fields
#' s[s$is_count, c("name", "description")]
#'
#' # an empty hand-coding sheet with one column per field
#' sheet <- as.data.frame(setNames(replicate(nrow(s), character(0), simplify = FALSE),
#'                                  s$name))
#' ncol(sheet)
#' @export
bricklayer_siu_schema <- function() {
  as.data.frame(.Call(C_rmbl_siu_schema, NULL), stringsAsFactors = FALSE)
}

#' Convert SIU report HTML to plain text
#'
#' Strips the markup from one SIU director's report page and returns the
#' readable text, keeping line breaks so section headings ("Subject
#' Officials", "Witness Officials") stay on lines of their own. Use it
#' before [bricklayer_siu_resolve_so()], or to
#' read or search a saved report
#' without a browser.
#'
#' @details
#' The conversion runs in the native core: tags are removed, block-level
#' tags become line breaks, HTML entities are decoded and runs of spaces are
#' collapsed while newlines are kept. Nothing is fetched and nothing is
#' written.
#'
#' Errors: \code{html} must be a single non-NA character string ("html must
#' be a single non-NA character string"), and input over 2 MiB is refused
#' ("html is larger than 2 MiB: not a report page").
#'
#' @param html A length-1 character vector holding the raw HTML of one
#'   report page. A file path is not read here (use
#'   [bricklayer_parse_siu()], which accepts a path).
#' @section Limits:
#' The input is capped at 2 MiB (a report page is a few hundred KB). Before
#' the text is read, a line longer than 2000 characters is split at the
#' sentence end nearest the cap (else at a space), and a warning says how
#' many lines were split: a field that spans a split may be incomplete.
#' @return A length-1 character vector of plain text.
#' @examples
#' bricklayer_siu_text("<p>Number of SIU Investigators assigned: 3</p>")
#'
#' # the bundled synthetic report, as text
#' f <- system.file("extdata", "siu_synthetic_report.html", package = "rmoriebricklayer")
#' txt <- bricklayer_siu_text(paste(readLines(f), collapse = "\n"))
#' cat(substr(txt, 1, 200))
#'
#' # more than one string is refused
#' try(bricklayer_siu_text(c("<p>a</p>", "<p>b</p>")))
#' @export
bricklayer_siu_text <- function(html) {
  .bl_siu_split_warn(.Call(C_rmbl_siu_html_to_text, html))
}

#' Parse an SIU director's report into the schema fields
#'
#' Extracts every [bricklayer_siu_schema()] field
#' from the HTML of an
#' Ontario SIU director's report: the police service, the incident,
#' notification and decision dates, the investigator and witness counts,
#' the affected person's age and sex, the injuries, the legislation
#' considered and the director's name. The extraction is rule-based,
#' deterministic and offline, so the same report always gives the same
#' answer; use it to turn a folder of saved reports into a data set.
#'
#' @details
#' The text is first converted as in
#' [bricklayer_siu_text()], then the
#' report language is detected from section headings (English or French;
#' the SIU publishes both) and each field is read by its own rule set in
#' the native core. Dates are converted with the same rules as
#' [bricklayer_siu_iso_date()]. The
#' subject-official count uses the rules
#' of [bricklayer_siu_resolve_so()]. Fields the
#' report does not state come
#' back as \code{""}; a page that is not a report gives all fields
#' \code{""} and \code{_language} \code{"unknown"}.
#'
#' A single string with no \code{<} that is shorter than 1000 bytes and
#' names an existing file is read as a path. A string that looks like a path
#' (ends in \code{.htm}/\code{.html} or contains a slash) but names no file is
#' an error, not an empty report.
#'
#' Errors: \code{html} not character, empty or \code{NA}; a missing file
#' ("no such file"); input over 2 MiB.
#'
#' @param html A character vector. Each element is either the raw HTML of
#'   one report or the path to a saved report file (for example one written
#'   by [bricklayer_fetch_siu()]). With more than one
#'   element, each is
#'   parsed and the results are bound into a data frame.
#' @section Limits:
#' The input is capped at 2 MiB (a report page is a few hundred KB). Before
#' the text is read, a line longer than 2000 characters is split at the
#' sentence end nearest the cap (else at a space), and a warning says how
#' many lines were split: a field that spans a split may be incomplete.
#' @return For one input, a named character vector of 17 elements: the 16
#'   schema fields plus \code{_language} (\code{"en"}, \code{"fr"} or
#'   \code{"unknown"}), in alphabetical order of name. Every value is a
#'   string, counts included (\code{"2"}); convert with
#'   \code{as.integer()} as needed. For several inputs, a data.frame with one
#'   row per input and one character column per field (\code{NA} where a
#'   field is absent from a row).
#' @examples
#' f <- bricklayer_parse_siu(system.file("extdata",
#'                                       "siu_synthetic_report.html",
#'                                       package = "rmoriebricklayer"))
#' f[["number_of_subject_officials"]]
#' f[c("police_service", "date_of_incident_iso", "date_of_director_decision_iso")]
#'
#' # several reports at once give a data frame, one row each
#' path <- system.file("extdata", "siu_synthetic_report.html", package = "rmoriebricklayer")
#' html <- paste(readLines(path), collapse = "\n")
#' df <- bricklayer_parse_siu(c(html, "<p>not a report</p>"))
#' df[, c("_language", "police_service", "number_of_witness_officials")]
#'
#' # a mistyped path is an error, not an empty report
#' try(bricklayer_parse_siu("no-such-report.html"))
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
#' Downloads one director's report from the SIU web site with
#' [bricklayer_fetch_siu()] and parses it with
#' [bricklayer_parse_siu()], in
#' one call. It is meant for loops over many report ids: a report that
#' cannot be retrieved gives \code{NULL} and a message instead of stopping
#' the loop.
#'
#' @details
#' The arguments are checked before any network use, so a bad id or
#' language fails at once. The report is downloaded to a temporary file,
#' which is deleted on exit. Any error from the download (network failure,
#' an HTTP error, no report at that id) is caught and turned into a message
#' of the form \code{"bricklayer: could not fetch SIU report <drid>: <reason>"}
#' and a \code{NULL} return. Errors from parsing are not caught.
#'
#' Errors: \code{drid} that is not one positive whole number;
#' \code{lang} other than \code{"en"} or \code{"fr"}.
#'
#' @param drid The director's report id: one positive whole number (or a
#'   string of one), the \code{drid=} query parameter of the report URL on
#'   the SIU site.
#' @param lang Report language: \code{"en"} (default, the English page) or
#'   \code{"fr"} (the French page). Partial matching is allowed.
#' @return A named character vector of parsed fields, as from
#'   [bricklayer_parse_siu()], or \code{NULL} when the
#'   fetch fails.
#' @examples
#' # argument errors come before any network use
#' try(bricklayer_fetch_parse_siu("abc"))
#' try(bricklayer_fetch_parse_siu(648, lang = "de"))
#'
#' \dontrun{
#' # needs the network: downloads report 648 from the SIU site
#' f <- bricklayer_fetch_parse_siu(648)
#' if (!is.null(f)) f[["police_service"]]
#' fr <- bricklayer_fetch_parse_siu(648, lang = "fr")
#' }
#' @export
bricklayer_fetch_parse_siu <- function(drid, lang = c("en", "fr")) {
  lang <- .rmbl_arg(lang)  # argument errors, before any network
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
#' Turns the written-out dates found in SIU reports, in English or French,
#' into ISO \code{YYYY-MM-DD} strings that sort and convert with
#' \code{as.Date()}. \code{"January 5, 2023"}, \code{"January 5 2023"},
#' \code{"5 January 2023"} and \code{"5 janvier 2023"} all become
#' \code{"2023-01-05"}.
#'
#' @details
#' Each element is parsed by the native core. Month names may be English or
#' French (accents optional), full or abbreviated, before or after the day;
#' ordinals such as \code{"1er"} are accepted, and an ISO date is passed
#' through. A date that does not exist (\code{"February 30, 2023"}) or text
#' that is not a date gives \code{""}. \code{NA} stays \code{NA}.
#'
#' Error: \code{x} that is neither character nor all \code{NA} ("x must be
#' a character vector of dates").
#'
#' @param x A character vector of human-readable dates. A vector that is
#'   all \code{NA} (of any type) is accepted.
#' @return A character vector the same length as \code{x}: \code{YYYY-MM-DD}
#'   strings, \code{""} for unparseable input and \code{NA} for \code{NA}.
#'   Unnamed.
#' @examples
#' bricklayer_siu_iso_date(c("January 5, 2023", "not a date"))
#'
#' # French, day-first and impossible dates
#' bricklayer_siu_iso_date(c("5 janvier 2023", "5 January 2023", "February 30, 2023", NA))
#' as.Date(bricklayer_siu_iso_date("April 28, 2023"))
#'
#' # numbers are refused
#' try(bricklayer_siu_iso_date(20230105))
#' @export
bricklayer_siu_iso_date <- function(x) {
  if (!is.character(x) && !all(is.na(x))) stop("`x` must be a character vector of dates", call. = FALSE)
  x <- as.character(x)
  vapply(x, function(v) if (is.na(v)) NA_character_ else .Call(C_rmbl_siu_to_iso_date, v), character(1),
         USE.NAMES = FALSE)
}

#' Resolve the subject-official count from SIU report text
#'
#' Counts the subject officials (SO), the officers whose conduct the SIU
#' investigated, from the plain text of one report, and says which rule
#' gave the answer. Use it for reports where a model panel or a human coder
#' is unsure, so that the number is reproducible and its evidence can be
#' checked.
#'
#' @details
#' The standard SIU privacy paragraph and the witness-officer glossary note
#' are stripped first (both mention "subject officer" without naming one).
#' The rules then run most-specific first and the first that applies wins:
#' \enumerate{
#'   \item the roster under the "Subject Officials"/"Subject Officers"
#'     heading: the larger of the highest \code{SO #N} ordinal and the number
#'     of entries;
#'   \item the highest \code{SO #N} ordinal in the whole document, trusted
#'     only when \code{SO #1} is also present;
#'   \item a spelled-out or numeric plural ("two subject officials");
#'   \item a singular subject official present (1);
#'   \item an explicit statement that there was no subject official, or
#'     witness officials listed and no subject official anywhere (0, a real
#'     answer);
#'   \item otherwise unresolved (\code{NA}).
#' }
#' French reports use the same rules in their vocabulary (the subject
#' official is tagged "AI no 1", the witness official "AT no 1").
#'
#' This function is the pure rule set. For reports that already have a
#' panel-reviewed count, prefer that verified value; use these rules for
#' unreviewed reports.
#'
#' Error: \code{text} that is not a single non-NA string.
#'
#' @param text A length-1 character vector of plain report text
#'   (see [bricklayer_siu_text()]), not HTML.
#' @return A list with two elements: \code{count} (integer, \code{NA} when
#'   unresolved) and \code{reason} (character, the rule that fired and its
#'   evidence, for example \code{"plural cue 'three subject officials'"}).
#' @examples
#' bricklayer_siu_resolve_so(
#'   "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#'
#' # witness officials only: zero is the answer
#' bricklayer_siu_resolve_so("Witness Officials\nWO #1 Interviewed\nWO #2 Interviewed")
#'
#' # a spelled-out plural, and an unresolved text
#' bricklayer_siu_resolve_so("Three subject officials were designated.")$count
#' bricklayer_siu_resolve_so("No officers are named here.")
#'
#' # HTML or several strings are not text
#' try(bricklayer_siu_resolve_so(c("a", "b")))
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
