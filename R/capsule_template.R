# SPDX-License-Identifier: AGPL-3.0-or-later

#' Start a capsule from a template
#'
#' @description
#' Creates a new folder with the three files a reproducible analysis
#' "capsule" needs, ready to be filled in: a \code{data_provenance.json}
#' that says where the data come from, an \code{analysis.R} script that
#' fetches, checks, analyses and records, and a \code{README.md} that says
#' how to run it. Use it to start a new project in the package's
#' fetch-verify-analyse-record pattern instead of writing that scaffolding
#' by hand.
#'
#' @details
#' The files:
#' \describe{
#'   \item{\code{data_provenance.json}}{the fields
#'     \code{\link{loadprov}} and \code{\link{vrfcps}} expect:
#'     \code{name}, \code{source} (\code{url}, \code{publisher},
#'     \code{licence}, \code{retrieved}, \code{sha256}) and \code{table}
#'     (\code{value}, \code{period}, \code{by}, \code{rounding},
#'     \code{suplim}). Every field that must be filled in is
#'     marked \code{TODO}.}
#'   \item{\code{analysis.R}}{reads the provenance, downloads the source
#'     with \code{\link{fdl}} (a local path is read directly),
#'     computes its SHA-256 with \code{\link{sha256file}} and stops if it no
#'     longer matches the pinned value, runs \code{\link{anltab}},
#'     and writes \code{manifest.json}, \code{report.html} and \code{report.md}
#'     in \code{results/}.}
#'   \item{\code{README.md}}{the three steps to fill in and run the capsule.}
#' }
#' With \code{example = TRUE} the source is the OTIS table
#' \code{otis_a01_individuals.csv} shipped in the package's \code{extdata} folder, so
#' \code{Rscript analysis.R} runs as written. The table settings in the
#' template (\code{value = "individuals"}, \code{period = "year"},
#' \code{by = c("table", "group")}) fit that example and must be edited for
#' other data.
#'
#' Side effects: creates \code{path} (and its parents) and writes the three
#' files. Errors: \code{path} exists and is not empty; \code{name} is not a
#' single non-empty string. The \code{name} and source are written as escaped
#' JSON strings, so quotes and backslashes are safe.
#'
#' @param path Character string: the directory to create. It may exist only
#'   if it is empty.
#' @param name Character string: the capsule name written into the
#'   provenance and README. Defaults to the last part of \code{path}.
#' @param ex Logical, default \code{FALSE}. \code{TRUE} uses the
#'   shipped OTIS table as the source so the skeleton runs immediately;
#'   \code{FALSE} leaves a \code{TODO} URL.
#' @return The directory path, invisibly.
#' @seealso \code{\link{loadprov}}, \code{\link{vrfcps}},
#'   \code{\link{anltab}}.
#' @examples
#' d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
#' list.files(d)
#'
#' # the provenance file to fill in
#' cat(readLines(file.path(d, "data_provenance.json")), sep = "\n")
#'
#' # a blank template with a chosen name
#' d2 <- usecpstmpl(tempfile("capsule-"), name = "segregation-2024")
#' grep("TODO", readLines(file.path(d2, "data_provenance.json")), value = TRUE)
#'
#' # an existing, non-empty folder is never overwritten
#' try(usecpstmpl(d))
#' @export
usecpstmpl <- function(path, name = basename(path),
                                 ex = FALSE) {
  path <- .rmbl_string1(path, "path")
  ex <- .rmbl_flag1(ex, "ex")
  if (file.exists(path) && !dir.exists(path)) stop("`path` is a file, not a directory: ", path, call. = FALSE)
  if (dir.exists(path) && length(list.files(path))) {
    stop("`path` exists and is not empty", call. = FALSE)
  }
  if (!is.character(name) || length(name) != 1L || is.na(name) || !nzchar(name)) {
    stop("`name` must be a single non-empty string", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  # a JSON string literal for x: quotes, backslashes (Windows paths) and control characters escaped
  jstr <- function(x) sub("^\\[(.*)\\]$", "\\1", tojs(as.character(x)))
  src <- if (ex) {
    system.file("extdata", "otis_a01_individuals.csv",
                package = "rmoriebricklayer")
  } else {
    "TODO: https://example.org/open-data/table.csv"
  }
  # nolint start: indentation_linter, line_length_linter.
  prov <- c(
    "{",
    sprintf("  \"name\": %s,", jstr(name)),
    "  \"source\": {",
    sprintf("    \"url\": %s,", jstr(src)),
    "    \"publisher\": \"TODO: who publishes the table\",",
    "    \"licence\": \"TODO: e.g. Open Government Licence - Ontario\",",
    "    \"retrieved\": \"TODO: YYYY-MM-DD\",",
    "    \"sha256\": \"TODO: filled by analysis.R on first run\"",
    "  },",
    "  \"table\": {",
    "    \"value\": \"individuals\",",
    "    \"period\": \"year\",",
    "    \"by\": [\"table\", \"group\"],",
    "    \"rounding\": null,",
    "    \"suppression_limit\": null",
    "  }",
    "}")
  writeLines(prov, file.path(path, "data_provenance.json"))
  # nolint end
  # nolint start: indentation_linter, line_length_linter.
  script <- c(
    "# Reproducible capsule: fetch, verify, analyse, record.",
    "# Run with: Rscript analysis.R",
    "library(rmoriebricklayer)",
    "arg <- grep(\"^--file=\", commandArgs(), value = TRUE)",
    "here <- if (length(arg)) dirname(normalizePath(sub(\"^--file=\", \"\", arg[1]))) else getwd()",
    "prov <- loadprov(file.path(here, \"data_provenance.json\"))",
    "",
    "# 1. Fetch (a local path is read directly; a URL is downloaded with a",
    "#    Wayback Machine fallback) and pin the bytes.",
    "src <- prov$source$url",
    "local <- if (file.exists(src)) src else",
    "  fdl(src, file.path(here, basename(src)))",
    "digest <- sha256file(local)",
    "if (!grepl(\"^TODO\", prov$source$sha256) && !identical(digest, prov$source$sha256))",
    "  stop(\"the source bytes changed since the capsule was pinned: \", digest)",
    "data <- read.csv(local, check.names = FALSE)",
    "",
    "# 2. Analyse: change with exact intervals and adjusted p-values, trend,",
    "#    publication bounds if the release rounds or suppresses.",
    "tab <- prov$table",
    "a <- anltab(data, value = tab$value, prd = tab$period,",
    "                   by = unlist(tab$by),",
    "                   rnd = tab$rounding,",
    "                   suplim = tab$suppression_limit)",
    "print(a)",
    "",
    "# 3. Record: manifest with the digest and every number, plus the report.",
    "out <- file.path(here, \"results\")",
    "dir.create(out, showWarnings = FALSE)",
    "man <- mkmnf(list(project = prov$name, source = src,",
    "                          source_sha256 = digest))",
    "man <- recrd(man, \"rows\", nrow(data), nrow(data))",
    "man <- recrd(man, \"periods\", length(a$meta$periods), length(a$meta$periods))",
    "wrmnfjs(man, file.path(out, \"manifest.json\"))",
    "rptanl(a, file.path(out, \"report.html\"), title = prov$name)",
    "rptanl(a, file.path(out, \"report.md\"), title = prov$name)",
    "cat(\"results in\", out, \"\\n\")")
  writeLines(script, file.path(path, "analysis.R"))
  # nolint end
  # nolint start: indentation_linter, line_length_linter.
  readme <- c(
    sprintf("# %s", name), "",
    "A reproducible capsule built with rmoriebricklayer.", "",
    "1. Fill in every `TODO` in `data_provenance.json`.",
    "2. `Rscript analysis.R` fetches the source, pins its SHA-256, analyses",
    "   the table and writes `results/manifest.json`, `results/report.html`",
    "   and `results/report.md`.",
    "3. Copy the SHA-256 the first run prints into `data_provenance.json`;",
    "   later runs refuse to proceed if the bytes change.", "",
    "Anyone with this folder and the package can rerun it and compare",
    "manifests with `mnfrcmp()`.")
  writeLines(readme, file.path(path, "README.md"))
  # nolint end
  invisible(path)
}
