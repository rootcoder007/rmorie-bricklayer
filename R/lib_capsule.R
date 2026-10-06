# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Capsule-level integrity: one-call re-verification of a reproducible
# data capsule, environment capture for manifests, and data citations
# generated from provenance.

#' Re-Verify an Entire Reproducible Data Capsule
#'
#' Runs the full custody chain over a capsule directory in one call: the
#' provenance manifest is readable, the pinned data file exists and matches
#' its recorded `sha256` (and `size_bytes` / row count where
#' recorded), the schema still validates, a recorded analysis script still
#' matches its pinned hash, and every numeric cross-check stored in a
#' results manifest still reproduces its recorded `PASS` /
#' `DIFFER` status from its own `observed` / `expected` /
#' `tol` fields.
#'
#' Entirely offline: nothing is downloaded and nothing is written.
#'
#' @param capsule_dir Directory containing the capsule.
#' @param provenance_file Provenance JSON filename
#' inside `capsule_dir` (default `"data_provenance.json"`) .
#' @param data_file Data filename inside
#' `capsule_dir`. Defaults to the provenance's
#' `resource$filename`.
#' @param manifest_file Optional results-manifest JSON
#' (as written by
#' [write_manifest_json()]) inside
#' `capsule_dir`; checked when present.
#' @param script_file Optional analysis-script filename
#' inside `capsule_dir`; compared against the manifest's recorded
#' `meta$script_sha256` when both are present.
#' @return An object of class `bricklayer_capsule_check` (a list with a
#' print method): `ok` (logical scalar: every check passed AND the three
#' required checks -- `provenance_readable`, `data_present`,
#' `data_sha256` -- were all made), `checks` (data.frame with columns
#' `check`, `ok`, `detail`), `required` and `missing`. A check that
#' cannot be made because the provenance lacks the field is recorded as
#' a FAILED row, never skipped: a provenance of `{}` verifies nothing.
#' @examples
#' dir <- file.path(tempdir(), "capsule-example")
#' dir.create(dir, showWarnings = FALSE)
#' write.csv(data.frame(id = 1:3), file.path(dir, "d.csv"), row.names = FALSE)
#' prov <- list(resource = list(filename = "d.csv",
#'                              sha256 = sha256_file(file.path(dir, "d.csv"))))
#' writeLines(bricklayer_json_to_json(prov, auto_unbox = TRUE),
#'            file.path(dir, "data_provenance.json"))
#' verify_capsule(dir)$ok
#' @export
verify_capsule <- function(capsule_dir,
                           provenance_file = "data_provenance.json",
                           data_file = NULL,
                           manifest_file = NULL,
                           script_file = NULL) {
  capsule_dir <- .rmbl_string1(capsule_dir, "capsule_dir")
  if (!dir.exists(capsule_dir)) {
    stop("`capsule_dir` is not an existing directory: ", capsule_dir,
         call. = FALSE)
  }
  checks <- list()
  note <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }

  # The provenance selects the digests everything else is checked against,
  # so it is contained like every other path: a symlink out of the capsule,
  # or a caller-supplied "../evil.json", pinned tampered bytes as intact.
  ppath <- .rmbl_safe_rel(provenance_file, capsule_dir)
  prov <- if (is.null(ppath)) NULL else load_provenance(ppath)
  note("provenance_readable", !is.null(prov),
       if (is.null(ppath))
         sprintf("'%s' is not a plain relative path inside the capsule",
                 as.character(unlist(provenance_file))[1L])
       else ppath)
  # a field that should be one string: a nested object or an array in its
  # place is a different document, not a value to take element 1 of
  scalar <- function(v) {
    if (is.null(v)) return(NULL)
    if (is.list(v) && length(v) == 1L && !is.list(v[[1L]])) v <- v[[1L]]
    if (!is.atomic(v) || length(v) != 1L || is.na(v)) return(NA_character_)
    as.character(v)
  }

  # Every check that cannot be made is a FAILED check, recorded as a row:
  # the former version appended nothing when a field was absent, and
  # all() of the surviving rows said a capsule with altered data (or a
  # provenance of exactly {}) was intact. These three rows must exist and
  # pass for `ok`.
  # the load-bearing rows; manifest_consistent and script_sha256 join them
  # below whenever a manifest or a script is in play
  required <- c("provenance_readable", "data_present", "data_sha256",
                "data_not_synthetic")

  df <- NULL
  dpath <- NULL
  data_file <- data_file %||% scalar(prov$resource$filename)
  if (is.null(data_file)) {
    note("data_present", FALSE,
         "no data file: the provenance records no resource$filename and none was given")
  } else if (is.na(data_file)) {
    note("data_present", FALSE,
         "resource$filename is not a single string")
  } else {
    dpath <- .rmbl_safe_rel(data_file, capsule_dir)
    if (is.null(dpath)) {
      note("data_present", FALSE,
           sprintf("'%s' is not a plain relative path inside the capsule",
                   as.character(unlist(data_file))[1L]))
    } else {
      present <- file.exists(dpath) && !dir.exists(dpath)
      note("data_present", present,
           if (file.exists(dpath) && dir.exists(dpath))
             sprintf("%s is a directory, not a data file", dpath) else dpath)
      if (!present) dpath <- NULL
    }
  }
  synth_sidecar <- !is.null(dpath) && file.exists(paste0(dpath, ".synthetic"))
  if (!is.null(dpath)) {
    pinned <- scalar(prov$resource$sha256)
    if (is.null(pinned)) {
      note("data_sha256", FALSE,
           "no sha256 recorded in the provenance: the data cannot be verified")
    } else if (is.na(pinned) || !grepl("^[0-9a-fA-F]{64}$", trimws(pinned))) {
      note("data_sha256", FALSE,
           "resource$sha256 is not a single 64-character hex digest")
    } else {
      v <- tryCatch(verify_sha256(dpath, pinned), error = function(e) NULL)
      if (is.null(v)) {
        note("data_sha256", FALSE, "the data file could not be read")
      } else {
        note("data_sha256", v$match,
             if (v$match) v$actual else
               sprintf("expected %s, got %s", v$expected, v$actual))
      }
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
    } else if (!is.null(prov$resource$row_count_data_rows) ||
               !is.null(prov$schema)) {
      note("data_readable", FALSE,
           sprintf("%s is not a CSV: the recorded row count / schema cannot be checked",
                   basename(dpath)))
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
  # a capsule that carries manifest.json is checked against it by default:
  # verify_capsule(dir) used to open the data and never the manifest
  if (is.null(manifest_file) &&
      file.exists(file.path(capsule_dir, "manifest.json"))) {
    manifest_file <- "manifest.json"
  }
  if (!is.null(manifest_file)) {
    required <- c(required, "manifest_consistent")
    mpath <- .rmbl_safe_rel(manifest_file, capsule_dir)
    if (is.null(mpath) || !file.exists(mpath)) {
      note("manifest_consistent", FALSE,
           sprintf("manifest '%s' is missing or outside the capsule",
                   as.character(manifest_file)[1L]))
    } else {
      manifest <- load_provenance(mpath)
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
  }

  # A pinned script digest is checked whenever one exists, whether or not
  # the caller remembered `script_file`: a capsule with a pinned script
  # hash was never script-checked by default before.
  pinned_script <- manifest$meta$script_sha256 %||% prov$script$sha256
  script_file <- script_file %||% prov$script$filename %||%
    manifest$meta$script_file
  if (!is.null(script_file) || !is.null(pinned_script)) {
    required <- c(required, "script_sha256")
    spath <- if (!is.null(script_file)) .rmbl_safe_rel(script_file, capsule_dir)
    if (is.null(spath) || !file.exists(spath)) {
      note("script_sha256", FALSE,
           if (is.null(script_file))
             "a script digest is pinned but no script file is named (script_file)"
           else sprintf("script '%s' is missing or outside the capsule",
                        as.character(unlist(script_file))[1L]))
    } else if (is.null(pinned_script)) {
      note("script_sha256", FALSE,
           "no script digest is pinned in the manifest or the provenance")
    } else {
      actual <- sha256_file(spath)
      note("script_sha256", identical(actual, as.character(unlist(pinned_script))[1L]),
           actual)
    }
  }

  # Synthetic data is a recorded, required verdict: the sidecar
  # make_synthetic_csv() writes, the manifest's flag, or the provenance's
  # own flag. The row exists whether or not any of them is present --
  # deleting the sidecar used to delete the finding with it.
  synth_manifest <- isTRUE(manifest$meta$synthetic)
  synth_prov <- isTRUE(prov$synthetic) || isTRUE(prov$resource$synthetic)
  note("data_not_synthetic", !(synth_sidecar || synth_manifest || synth_prov),
       if (synth_sidecar)
         sprintf("%s.synthetic is present: these data were generated, not fetched",
                 basename(dpath))
       else if (synth_manifest) "the manifest records synthetic = true"
       else if (synth_prov) "the provenance records synthetic = true"
       else if (is.null(dpath)) "no data file to check"
       else "no synthetic marker: sidecar, manifest and provenance all say real data")

  checks <- do.call(rbind, checks)
  rownames(checks) <- NULL
  missing <- setdiff(required, checks$check)
  out <- list(ok = all(checks$ok) && length(missing) == 0L,
              checks = checks, required = required, missing = missing)
  class(out) <- c("bricklayer_capsule_check", "list")
  out
}

#' @export
format.bricklayer_capsule_check <- function(x, ...) {
  ck <- x$checks
  c(sprintf("Capsule verification: %s (%d of %d checks passed)",
            if (isTRUE(x$ok)) "intact" else "NOT VERIFIED",
            sum(ck$ok), nrow(ck)),
    sprintf("  %s  %-20s %s", ifelse(ck$ok, "ok  ", "FAIL"), ck$check, ck$detail),
    if (length(x$missing))
      sprintf("  FAIL  %-20s required check was never made", x$missing))
}

#' @export
print.bricklayer_capsule_check <- function(x, ...) {
  cat(format(x, ...), sep = "\n")
  invisible(x)
}

#' Capture the Analysis Environment for a Manifest
#'
#' Records the facts a replicator needs to rebuild the session: R version,
#' platform, operating system, a UTC timestamp, and the versions of the
#' requested packages.
#'
#' @param packages Character vector of package names to
#' record. Defaults to every currently loaded namespace.
#' @return A list with `r_version`, `platform`, `os`,
#' `captured_utc`, and `packages` (a named character vector of
#' versions).
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
    # Without the generator's identity a stochastic result cannot be
    # reproduced even on the same machine: R has changed its default
    # sample() algorithm before, and a recorded seed means nothing
    # without the kind it was fed to.
    rng_kind     = paste(RNGkind(), collapse = ","),
    rng_seeded   = exists(".Random.seed", envir = globalenv(),
                          inherits = FALSE),
    packages     = vapply(packages, function(p) {
      tryCatch(as.character(utils::packageVersion(p)),
               error = function(e) NA_character_)
    }, character(1))
  )
}

#' Generate a Data Citation From Provenance
#'
#' Builds a ready-to-paste data citation (plain text and BibTeX
#' `@misc`) from a provenance object's `dataset` and
#' `resource` blocks, using publisher, resource name, source system,
#' retrieval date, license, the pinned URL, and a DOI when one is recorded
#' ( `dataset$doi`) .
#'
#' @param provenance A provenance list as returned by
#' [load_provenance()].
#' @return A list with `text` and `bibtex` character scalars, or
#' `NULL` if `provenance` is `NULL`.
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
  if (!is.list(provenance)) stop("`provenance` must be a provenance list (read_provenance())", call. = FALSE)
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
