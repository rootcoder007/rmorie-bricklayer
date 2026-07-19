# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Capsule-level integrity: one-call re-verification of a reproducible
# data capsule, environment capture for manifests, and data citations
# generated from provenance.

#' Re-Verify an Entire Reproducible Data Capsule
#'
#' Runs the full custody chain over a capsule directory in one call:
#' the provenance manifest is readable, the pinned data file exists and
#' matches its recorded `sha256` (and `size_bytes` / row count where
#' recorded), the schema still validates, a recorded analysis script
#' still matches its pinned hash, and every numeric cross-check stored
#' in a results manifest still reproduces its recorded `PASS`/`DIFFER`
#' status from its own `observed`/`expected`/`tol` fields.
#'
#' Entirely offline: nothing is downloaded and nothing is written.
#'
#' @param capsule_dir Directory containing the capsule.
#' @param provenance_file Provenance JSON filename inside `capsule_dir`
#'   (default `"data_provenance.json"`).
#' @param data_file Data filename inside `capsule_dir`. Defaults to the
#'   provenance's `resource$filename`.
#' @param manifest_file Optional results-manifest JSON (as written by
#'   [write_manifest_json()]) inside `capsule_dir`; checked when present.
#' @param script_file Optional analysis-script filename inside
#'   `capsule_dir`; compared against the manifest's recorded
#'   `meta$script_sha256` when both are present.
#' @return A list with `ok` (logical scalar: every check passed) and
#'   `checks` (data.frame with columns `check`, `ok`, `detail`).
#' @examples
#' dir <- file.path(tempdir(), "capsule-example")
#' dir.create(dir, showWarnings = FALSE)
#' write.csv(data.frame(id = 1:3), file.path(dir, "d.csv"), row.names = FALSE)
#' prov <- list(resource = list(filename = "d.csv",
#'                              sha256 = sha256_file(file.path(dir, "d.csv"))))
#' jsonlite::write_json(prov, file.path(dir, "data_provenance.json"),
#'                      auto_unbox = TRUE)
#' verify_capsule(dir)$ok
#' @export
verify_capsule <- function(capsule_dir,
                           provenance_file = "data_provenance.json",
                           data_file = NULL,
                           manifest_file = NULL,
                           script_file = NULL) {
  checks <- list()
  note <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }

  prov <- load_provenance(file.path(capsule_dir, provenance_file))
  note("provenance_readable", !is.null(prov),
       file.path(capsule_dir, provenance_file))

  df <- NULL
  data_file <- data_file %||% prov$resource$filename
  if (!is.null(data_file)) {
    dpath <- file.path(capsule_dir, data_file)
    note("data_present", file.exists(dpath), dpath)
    if (file.exists(dpath)) {
      if (!is.null(prov$resource$sha256)) {
        v <- verify_sha256(dpath, prov$resource$sha256)
        note("data_sha256", v$match,
             if (v$match) v$actual else
               sprintf("expected %s, got %s", v$expected, v$actual))
      }
      if (!is.null(prov$resource$size_bytes)) {
        note("data_size_bytes",
             file.size(dpath) == as.numeric(prov$resource$size_bytes),
             sprintf("%d bytes on disk", file.size(dpath)))
      }
      if (grepl("\\.csv$", dpath, ignore.case = TRUE)) {
        df <- tryCatch(
          utils::read.csv(dpath, check.names = FALSE,
                          stringsAsFactors = FALSE),
          error = function(e) NULL
        )
        note("data_readable", !is.null(df), dpath)
      }
    }
  }

  if (!is.null(df)) {
    if (!is.null(prov$resource$row_count_data_rows)) {
      note("data_row_count",
           nrow(df) == as.numeric(prov$resource$row_count_data_rows),
           sprintf("%d rows on disk", nrow(df)))
    }
    if (!is.null(prov$schema)) {
      issues <- validate_schema(df, prov)
      fatal <- vapply(issues, function(i) identical(i$severity, "fatal"),
                      logical(1))
      note("schema_valid", !any(fatal),
           if (length(issues))
             paste(vapply(issues, `[[`, character(1), "message"),
                   collapse = "; ")
           else "")
    }
  }

  manifest <- NULL
  if (!is.null(manifest_file) &&
      file.exists(file.path(capsule_dir, manifest_file))) {
    manifest <- load_provenance(file.path(capsule_dir, manifest_file))
    mismatch <- character(0)
    for (nm in names(manifest$results)) {
      r <- manifest$results[[nm]]
      if (is.numeric(r$observed) && is.numeric(r$expected) &&
          !is.null(r$tol) && r$status %in% c("PASS", "DIFFER")) {
        want <- if (abs(r$observed - r$expected) <= r$tol) "PASS" else "DIFFER"
        if (!identical(want, r$status)) mismatch <- c(mismatch, nm)
      }
    }
    note("manifest_consistent", length(mismatch) == 0L,
         if (length(mismatch)) paste(mismatch, collapse = ", ") else
           sprintf("%d results re-checked", length(manifest$results)))
  }

  if (!is.null(script_file) &&
      file.exists(file.path(capsule_dir, script_file))) {
    actual <- sha256_file(file.path(capsule_dir, script_file))
    pinned <- manifest$meta$script_sha256 %||% prov$script$sha256
    if (!is.null(pinned)) {
      note("script_sha256", identical(actual, pinned), actual)
    }
  }

  checks <- do.call(rbind, checks)
  list(ok = all(checks$ok), checks = checks)
}

#' Capture the Analysis Environment for a Manifest
#'
#' Records the facts a replicator needs to rebuild the session: R
#' version, platform, operating system, a UTC timestamp, and the
#' versions of the requested packages.
#'
#' @param packages Character vector of package names to record.
#'   Defaults to every currently loaded namespace.
#' @return A list with `r_version`, `platform`, `os`, `captured_utc`,
#'   and `packages` (a named character vector of versions).
#' @examples
#' # Record specific packages' versions alongside the session facts.
#' env <- capture_environment(c("stats", "utils"))
#' env$r_version
#' env$os
#' env$packages          # named character vector of versions
#'
#' # Default captures every currently loaded namespace.
#' names(capture_environment())[1:4]
#' @export
capture_environment <- function(packages = loadedNamespaces()) {
  packages <- sort(unique(packages))
  list(
    r_version    = as.character(getRversion()),
    platform     = R.version$platform,
    os           = paste(Sys.info()[["sysname"]], Sys.info()[["release"]]),
    captured_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    packages     = vapply(packages, function(p) {
      tryCatch(as.character(utils::packageVersion(p)),
               error = function(e) NA_character_)
    }, character(1))
  )
}

#' Generate a Data Citation From Provenance
#'
#' Builds a ready-to-paste data citation (plain text and BibTeX
#' `@misc`) from a provenance object's `dataset` and `resource` blocks,
#' using publisher, resource name, source system, retrieval date,
#' license, the pinned URL, and a DOI when one is recorded
#' (`dataset$doi`).
#'
#' @param provenance A provenance list as returned by
#'   [load_provenance()].
#' @return A list with `text` and `bibtex` character scalars, or `NULL`
#'   if `provenance` is `NULL`.
#' @examples
#' prov <- list(
#'   captured_at_utc = "2026-06-23T04:41:40Z",
#'   dataset = list(publisher = "Ontario Ministry of the Solicitor General",
#'                  licence_short = "OGL-Ontario",
#'                  package_slug = "data-on-inmates-in-ontario"),
#'   resource = list(name = "Restrictive Confinement - Detailed Dataset",
#'                   direct_url = "https://data.ontario.ca/example.csv")
#' )
#' cit <- cite_capsule(prov)
#'
#' # Plain-text citation ready to paste.
#' cat(cit$text)
#'
#' # BibTeX @misc entry for LaTeX bibliographies.
#' cat(cit$bibtex)
#'
#' # NULL provenance returns NULL (composes safely).
#' cite_capsule(NULL)
#' @export
cite_capsule <- function(provenance) {
  if (is.null(provenance)) return(NULL)
  ds  <- provenance$dataset
  res <- provenance$resource
  year <- substr(provenance$captured_at_utc %||% "", 1, 4)
  if (!nzchar(year)) year <- format(Sys.Date(), "%Y")
  publisher <- ds$publisher %||% "Unknown publisher"
  title <- res$name %||% ds$package_slug %||% "Untitled dataset"
  url <- res$direct_url %||% ds$catalogue_page %||% ""
  licence <- ds$licence_short %||% ds$licence_name %||% NULL
  doi <- ds$doi %||% NULL
  retrieved <- substr(provenance$captured_at_utc %||% "", 1, 10)

  text <- paste0(
    publisher, " (", year, "). ", title, " [Data set].",
    if (!is.null(doi)) paste0(" https://doi.org/", doi) else
      if (nzchar(url)) paste0(" ", url) else "",
    if (nzchar(retrieved)) paste0(" Retrieved ", retrieved, ".") else "",
    if (!is.null(licence)) paste0(" Licence: ", licence, ".") else ""
  )

  key <- paste0(
    gsub("[^A-Za-z0-9]", "", ds$package_slug %||% "dataset"), year
  )
  bib_lines <- c(
    paste0("@misc{", key, ","),
    paste0("  author = {{", publisher, "}},"),
    paste0("  title = {", title, "},"),
    paste0("  year = {", year, "},"),
    if (!is.null(doi)) paste0("  doi = {", doi, "},"),
    if (nzchar(url)) paste0("  url = {", url, "},"),
    if (nzchar(retrieved)) paste0("  note = {Retrieved ", retrieved,
                                  if (!is.null(licence))
                                    paste0("; licence: ", licence) else "",
                                  "},"),
    "}"
  )
  list(text = text, bibtex = paste(bib_lines, collapse = "\n"))
}
