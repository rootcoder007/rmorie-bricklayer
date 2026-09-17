# SPDX-License-Identifier: AGPL-3.0-or-later

#' Start a capsule from a template
#'
#' Writes the skeleton of a reproducible capsule: a `data_provenance.json`
#' with the fields [load_provenance()] and
#' [verify_capsule()] expect, an
#' `analysis.R` that fetches the source, verifies it, runs
#' [analyse_table()] and writes the manifest and report,
#' and a README
#' that says how to run it. Every field that must be filled in is marked
#' `TODO`. The script runs as written against the shipped OTIS example
#' when `example = TRUE`.
#'
#' @param path Directory to create.
#' @param name Capsule name.
#' @param example Use the shipped OTIS table as the source so the
#'   skeleton runs immediately.
#' @return The directory path, invisibly.
#' @examples
#' d <- use_capsule_template(tempfile("capsule-"), example = TRUE)
#' list.files(d)
#' @export
use_capsule_template <- function(path, name = basename(path),
                                 example = FALSE) {
  if (dir.exists(path) && length(list.files(path))) {
    stop("`path` exists and is not empty", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  src <- if (example) {
    system.file("extdata", "otis_a01_individuals.csv",
                package = "rmoriebricklayer")
  } else {
    "TODO: https://example.org/open-data/table.csv"
  }
  # nolint start: indentation_linter, line_length_linter.
  prov <- c(
    "{",
    sprintf("  \"name\": \"%s\",", name),
    "  \"source\": {",
    sprintf("    \"url\": \"%s\",", src),
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
    "prov <- load_provenance(file.path(here, \"data_provenance.json\"))",
    "",
    "# 1. Fetch (a local path is read directly; a URL is downloaded with a",
    "#    Wayback Machine fallback) and pin the bytes.",
    "src <- prov$source$url",
    "local <- if (file.exists(src)) src else",
    "  friendly_download(src, file.path(here, basename(src)))",
    "digest <- sha256_file(local)",
    "if (!grepl(\"^TODO\", prov$source$sha256) && !identical(digest, prov$source$sha256))",
    "  stop(\"the source bytes changed since the capsule was pinned: \", digest)",
    "data <- read.csv(local, check.names = FALSE)",
    "",
    "# 2. Analyse: change with exact intervals and adjusted p-values, trend,",
    "#    publication bounds if the release rounds or suppresses.",
    "tab <- prov$table",
    "a <- analyse_table(data, value = tab$value, period = tab$period,",
    "                   by = unlist(tab$by),",
    "                   rounding = tab$rounding,",
    "                   suppression_limit = tab$suppression_limit)",
    "print(a)",
    "",
    "# 3. Record: manifest with the digest and every number, plus the report.",
    "out <- file.path(here, \"results\")",
    "dir.create(out, showWarnings = FALSE)",
    "man <- make_manifest(list(project = prov$name, source = src,",
    "                          source_sha256 = digest))",
    "man <- record(man, \"rows\", nrow(data), nrow(data))",
    "man <- record(man, \"periods\", length(a$meta$periods), length(a$meta$periods))",
    "write_manifest_json(man, file.path(out, \"manifest.json\"))",
    "report_analysis(a, file.path(out, \"report.html\"), title = prov$name)",
    "report_analysis(a, file.path(out, \"report.md\"), title = prov$name)",
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
    "manifests with `manifest_recompute()`.")
  writeLines(readme, file.path(path, "README.md"))
  # nolint end
  invisible(path)
}
