# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Capsule-level integrity: one-call re-verification of a reproducible
# data capsule, environment capture for manifests, and data citations
# generated from provenance.

#' Re-Verify an Entire Reproducible Data Capsule
#'
#' Runs the full custody chain over a capsule directory in one call and
#' reports, check by check, whether the capsule is still the one the
#' analysis was run on: the provenance record is readable, the pinned data
#' file is present and has its recorded SHA-256, the schema still validates,
#' a recorded analysis script still has its pinned hash, every numeric
#' cross-check in a results manifest still reproduces its recorded verdict,
#' and the data are real rather than synthetic. Use it before re-running or
#' publishing an analysis, or when receiving a capsule from someone else.
#'
#' @details The checks, in the order they appear in \code{checks}: \describe{
#' \item{\code{provenance_readable}}{\code{provfile} is a plain relative path
#' inside the capsule (no \code{..}, no absolute path, no symlink out) and
#' parses as JSON.} \item{\code{data_present}}{the data file (\code{dfile}, else
#' the provenance's \code{resource$filename}) is inside the capsule and is a
#' file.} \item{\code{data_sha256}}{[vrfsha256()] finds that its
#' SHA-256 equals \code{resource$sha256} (64 hex characters).}
#' \item{\code{data_size_bytes}}{when \code{resource$size_bytes} is recorded:
#' the size on disk matches.} \item{\code{data_readable}}{a \code{.csv} file is
#' read with \code{utils::read.csv()}; a non-CSV file fails this row when a row
#' count or schema is recorded (they cannot be checked).}
#' \item{\code{data_row_count}}{when \code{resource$row_count_data_rows} is
#' recorded: the CSV has that many rows.} \item{\code{schema_valid}}{when a
#' \code{schema} is recorded: [valsch()] finds no fatal issue
#' (warnings are listed in \code{detail} but pass).}
#' \item{\code{manifest_consistent}}{when \code{mnffile} is given, or the
#' capsule holds \code{manifest.json}: every result with numeric \code{observed}
#' and \code{expected}, a \code{tol} and a status of \code{PASS} or
#' \code{DIFFER} still gets that status from \eqn{|observed - expected| \le
#' tol}.} \item{\code{script_sha256}}{when a script is named (by \code{scrfile},
#' by \code{script$filename} in the provenance or by \code{meta$scrfile} in the
#' manifest) or a script digest is pinned (\code{meta$script_sha256} or
#' \code{script$sha256}): the script's SHA-256 matches the pin.}
#' \item{\code{data_not_synthetic}}{no \code{<data>.synthetic} sidecar (written
#' by [mksyncsv()]), and neither the manifest nor the provenance
#' records \code{synthetic = true}.} } A check that cannot be made because the
#' provenance lacks a field is a FAILED row, never skipped: a provenance of
#' \code{{}} verifies nothing. \code{ok} is \code{TRUE} only when every row
#' passed and every required check was made. The required checks are
#' \code{provenance_readable}, \code{data_present}, \code{data_sha256} and
#' \code{data_not_synthetic}, plus \code{manifest_consistent} and
#' \code{script_sha256} when a manifest or a script is in play.
#'
#' Entirely offline: nothing is downloaded and nothing is written. Error:
#' \code{cpsdir} that is not one existing directory. Every other problem
#' is a failed row, not an error.
#'
#' @param cpsdir Directory containing the capsule, a single string.
#' @param provfile Provenance JSON filename, relative to \code{cpsdir}.
#'   \code{"data_provenance.json"} is the default.
#' @param dfile Data filename relative to \code{cpsdir}. \code{NULL}
#'   (the default) uses the provenance's \code{resource$filename}.
#' @param mnffile Optional results-manifest JSON (as written by
#'   [wrmnfjs()]), relative to
#'   \code{cpsdir}. \code{NULL}
#'   (the default) uses \code{manifest.json} when the capsule has one.
#' @param scrfile Optional analysis-script filename relative to
#'   \code{cpsdir}; compared against the pinned script digest.
#'   \code{NULL} (the default) uses the script named in the provenance or
#'   the manifest, if any.
#' @return An object of class \code{c("bricklayer_capsule_check", "list")},
#'   printed as one line per check: \describe{ \item{\code{ok}}{logical scalar,
#'   the overall verdict described in Details.} \item{\code{checks}}{data.frame
#'   with columns \code{check} (character, the check name), \code{ok} (logical)
#'   and \code{detail} (character: the path checked, the digest found, or why it
#'   failed).} \item{\code{required}}{character, the checks that had to be
#'   made.} \item{\code{missing}}{character, required checks that were never
#'   made (\code{character(0)} when none).} }
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' dir <- file.path(tempdir(), "capsule-example")
#' dir.create(dir, showWarnings = FALSE)
#' write.csv(data.frame(id = 1:3), file.path(dir, "d.csv"), row.names = FALSE)
#' prov <- list(resource = list(filename = "d.csv",
#'                              sha256 = sha256file(file.path(dir, "d.csv")),
#'                              row_count_data_rows = 3),
#'              schema = list(expected_columns = "id"))
#' writeLines(tojs(prov, auto_unbox = TRUE),
#'            file.path(dir, "data_provenance.json"))
#' vrfcps(dir)$ok
#' vrfcps(dir)
#'
#' # an edited data file fails its digest and its row count
#' write.csv(data.frame(id = 1:4), file.path(dir, "d.csv"), row.names = FALSE)
#' chk <- vrfcps(dir)
#' chk$ok
#' chk$checks[!chk$checks$ok, c("check", "detail")]
#'
#' # a path out of the capsule is a failed check, not a read
#' vrfcps(dir, provfile = "../elsewhere.json")$ok
#'
#' # a missing directory is an error
#' try(vrfcps(file.path(tempdir(), "no-such-capsule")))
#' unlink(dir, recursive = TRUE)
#' @export
vrfcps <- function(
  cpsdir,
  provfile = "data_provenance.json",
  dfile = NULL,
  mnffile = NULL,
  scrfile = NULL
) {
  cpsdir <- .rmbl_string1(cpsdir, "cpsdir")
  if (!dir.exists(cpsdir)) {
    stop("`cpsdir` is not an existing directory: ", cpsdir, call. = FALSE)
  }
  provfile <- .rmbl_string1(provfile, "provfile")
  if (!is.null(dfile)) {
    dfile <- .rmbl_string1(dfile, "dfile")
  }
  if (!is.null(mnffile)) {
    mnffile <- .rmbl_string1(mnffile, "mnffile")
  }
  if (!is.null(scrfile)) {
    scrfile <- .rmbl_string1(scrfile, "scrfile")
  }
  acc <- new.env(parent = emptyenv())
  acc$checks <- list()
  # Every check that cannot be made is a FAILED check, recorded as a row:
  # the former version appended nothing when a field was absent, and
  # all() of the surviving rows said a capsule with altered data (or a
  # provenance of exactly {}) was intact. These three rows must exist and
  # pass for `ok`.
  # the load-bearing rows; manifest_consistent and script_sha256 join them
  # below whenever a manifest or a script is in play
  acc$required <- c(
    "provenance_readable",
    "data_present",
    "data_sha256",
    "data_not_synthetic"
  )
  prov <- .vc_provenance(acc, provfile, cpsdir)
  dpath <- .vc_data_file(acc, dfile, prov, cpsdir)
  synth_sidecar <- !is.null(dpath) && file.exists(paste0(dpath, ".synthetic"))
  df <- if (!is.null(dpath)) .vc_data_checks(acc, dpath, prov)
  if (!is.null(df)) {
    .vc_frame_checks(acc, df, prov)
  }
  # a capsule that carries manifest.json is checked against it by default:
  # vrfcps(dir) used to open the data and never the manifest
  if (
    is.null(mnffile) &&
      file.exists(file.path(cpsdir, "manifest.json"))
  ) {
    mnffile <- "manifest.json"
  }
  manifest <- if (!is.null(mnffile)) .vc_manifest(acc, mnffile, cpsdir)
  .vc_script(acc, scrfile, prov, manifest, cpsdir)
  .vc_synthetic(acc, dpath, synth_sidecar, manifest, prov)

  checks <- do.call(rbind, acc$checks)
  rownames(checks) <- NULL
  missing <- setdiff(acc$required, checks$check)
  out <- list(
    ok = all(checks$ok) && length(missing) == 0L,
    checks = checks,
    required = acc$required,
    missing = missing
  )
  class(out) <- c("bricklayer_capsule_check", "list")
  out
}

#' Records one check of vrfcps().
#' @param acc The checks so far.
#' @param check The check's name.
#' @param ok Whether it passed.
#' @param detail What was found.
#' @noRd
.vc_note <- function(acc, check, ok, detail = "") {
  acc$checks[[length(acc$checks) + 1L]] <- data.frame(
    check = check,
    ok = isTRUE(ok),
    detail = as.character(detail),
    stringsAsFactors = FALSE
  )
}

#' A field that should be one string: a nested object or an array in its place
#' is a different document, not a value to take element 1 of.
#' @param v The field.
#' @return The string, NA when it is not one, or NULL when absent.
#' @noRd
.vc_scalar <- function(v) {
  if (is.null(v)) {
    return(NULL)
  }
  if (is.list(v) && length(v) == 1L && !is.list(v[[1L]])) {
    v <- v[[1L]]
  }
  if (!is.atomic(v) || length(v) != 1L || is.na(v)) {
    return(NA_character_)
  }
  as.character(v)
}

#' Reads the provenance.
#'
#' The provenance selects the digests everything else is checked against, so it
#' is contained like every other path: a symlink out of the capsule, or a
#' caller-supplied "../evil.json", pinned tampered bytes as intact. A record
#' that does not parse is a failed row, not an error: the verdict of the capsule
#' is what the caller asked for, and morie's verify() answers the same way.
#' @param acc The checks so far.
#' @param provfile,cpsdir As for vrfcps().
#' @return The provenance, or NULL.
#' @noRd
.vc_provenance <- function(acc, provfile, cpsdir) {
  ppath <- .rmbl_safe_rel(provfile, cpsdir)
  loaded <- if (is.null(ppath)) {
    list(prov = NULL, err = NULL)
  } else {
    tryCatch(list(prov = loadprov(ppath), err = NULL), error = function(e) {
      list(prov = NULL, err = conditionMessage(e))
    })
  }
  prov <- loaded$prov
  .vc_note(
    acc,
    "provenance_readable",
    !is.null(prov),
    if (is.null(ppath)) {
      sprintf(
        "'%s' is not a plain relative path inside the capsule",
        as.character(unlist(provfile))[1L]
      )
    } else if (!is.null(loaded$err)) {
      sprintf("%s: %s", ppath, loaded$err)
    } else {
      ppath
    }
  )
  prov
}

#' Finds the data file: given, or the one the provenance names.
#' @param acc The checks so far.
#' @param dfile,cpsdir As for vrfcps().
#' @param prov The provenance.
#' @return The data file's path, or NULL when there is none to check.
#' @noRd
.vc_data_file <- function(acc, dfile, prov, cpsdir) {
  dfile <- dfile %||% .vc_scalar(prov$resource$filename)
  if (is.null(dfile)) {
    .vc_note(
      acc,
      "data_present",
      FALSE,
      paste0(
        "no data file: the provenance records no resource$filename and ",
        "none was given"
      )
    )
    return(NULL)
  }
  if (is.na(dfile)) {
    .vc_note(
      acc,
      "data_present",
      FALSE,
      "resource$filename is not a single string"
    )
    return(NULL)
  }
  dpath <- .rmbl_safe_rel(dfile, cpsdir)
  if (is.null(dpath)) {
    .vc_note(
      acc,
      "data_present",
      FALSE,
      sprintf(
        "'%s' is not a plain relative path inside the capsule",
        as.character(unlist(dfile))[1L]
      )
    )
    return(NULL)
  }
  present <- file.exists(dpath) && !dir.exists(dpath)
  .vc_note(
    acc,
    "data_present",
    present,
    if (file.exists(dpath) && dir.exists(dpath)) {
      sprintf("%s is a directory, not a data file", dpath)
    } else {
      dpath
    }
  )
  if (present) dpath else NULL
}

#' The data file's digest, size and readability.
#' @param acc The checks so far.
#' @param dpath The data file.
#' @param prov The provenance.
#' @return The data as a data frame (a CSV that reads), or NULL.
#' @noRd
.vc_data_checks <- function(acc, dpath, prov) {
  .vc_sha(acc, dpath, prov)
  if (!is.null(prov$resource$size_bytes)) {
    .vc_note(
      acc,
      "data_size_bytes",
      file.size(dpath) == as.numeric(prov$resource$size_bytes),
      sprintf("%d bytes on disk", file.size(dpath))
    )
  }
  if (grepl("\\.csv$", dpath, ignore.case = TRUE)) {
    df <- tryCatch(
      utils::read.csv(dpath, check.names = FALSE, stringsAsFactors = FALSE),
      error = function(e) NULL
    )
    .vc_note(acc, "data_readable", !is.null(df), dpath)
    return(df)
  }
  if (
    !is.null(prov$resource$row_count_data_rows) ||
      !is.null(prov$schema)
  ) {
    .vc_note(
      acc,
      "data_readable",
      FALSE,
      sprintf(
        "%s is not a CSV: the recorded row count / schema cannot be checked",
        basename(dpath)
      )
    )
  }
  NULL
}

#' The data file's SHA-256 against the one the provenance pins.
#' @param acc The checks so far.
#' @param dpath The data file.
#' @param prov The provenance.
#' @noRd
.vc_sha <- function(acc, dpath, prov) {
  pinned <- .vc_scalar(prov$resource$sha256)
  if (is.null(pinned)) {
    .vc_note(
      acc,
      "data_sha256",
      FALSE,
      "no sha256 recorded in the provenance: the data cannot be verified"
    )
    return(invisible(NULL))
  }
  if (is.na(pinned) || !grepl("^[0-9a-fA-F]{64}$", trimws(pinned))) {
    .vc_note(
      acc,
      "data_sha256",
      FALSE,
      "resource$sha256 is not a single 64-character hex digest"
    )
    return(invisible(NULL))
  }
  v <- tryCatch(vrfsha256(dpath, pinned), error = function(e) NULL)
  if (is.null(v)) {
    .vc_note(acc, "data_sha256", FALSE, "the data file could not be read")
    return(invisible(NULL))
  }
  .vc_note(
    acc,
    "data_sha256",
    v$match,
    if (v$match) {
      v$actual
    } else {
      sprintf("expected %s, got %s", v$expected, v$actual)
    }
  )
}

#' The data's row count and schema against the provenance.
#' @param acc The checks so far.
#' @param df The data.
#' @param prov The provenance.
#' @noRd
.vc_frame_checks <- function(acc, df, prov) {
  if (!is.null(prov$resource$row_count_data_rows)) {
    .vc_note(
      acc,
      "data_row_count",
      nrow(df) == as.numeric(prov$resource$row_count_data_rows),
      sprintf("%d rows on disk", nrow(df))
    )
  }
  if (!is.null(prov$schema)) {
    issues <- valsch(df, prov)
    fatal <- vapply(
      issues,
      function(i) identical(i$severity, "fatal"),
      logical(1)
    )
    .vc_note(
      acc,
      "schema_valid",
      !any(fatal),
      if (length(issues)) {
        paste(vapply(issues, `[[`, character(1), "message"), collapse = "; ")
      } else {
        ""
      }
    )
  }
}

#' The manifest's results re-checked: each recorded PASS or DIFFER against its
#' tolerance.
#' @param acc The checks so far.
#' @param mnffile,cpsdir As for vrfcps().
#' @return The manifest, or NULL.
#' @noRd
.vc_manifest <- function(acc, mnffile, cpsdir) {
  acc$required <- c(acc$required, "manifest_consistent")
  mpath <- .rmbl_safe_rel(mnffile, cpsdir)
  if (is.null(mpath) || !file.exists(mpath)) {
    .vc_note(
      acc,
      "manifest_consistent",
      FALSE,
      sprintf(
        "manifest '%s' is missing or outside the capsule",
        as.character(mnffile)[1L]
      )
    )
    return(NULL)
  }
  manifest <- loadprov(mpath)
  mismatch <- character(0)
  for (nm in names(manifest$results)) {
    r <- manifest$results[[nm]]
    if (
      is.numeric(r$observed) &&
        is.numeric(r$expected) &&
        !is.null(r$tol) &&
        r$status %in% c("PASS", "DIFFER")
    ) {
      want <- if (abs(r$observed - r$expected) <= r$tol) {
        "PASS"
      } else {
        "DIFFER"
      }
      if (!identical(want, r$status)) mismatch <- c(mismatch, nm)
    }
  }
  .vc_note(
    acc,
    "manifest_consistent",
    length(mismatch) == 0L,
    if (length(mismatch)) {
      paste(mismatch, collapse = ", ")
    } else {
      sprintf("%d results re-checked", length(manifest$results))
    }
  )
  manifest
}

#' The script's digest: a pinned script digest is checked whenever one exists,
#' whether or not the caller remembered `scrfile` (a capsule with a pinned
#' script hash was never script-checked by default before).
#' @param acc The checks so far.
#' @param scrfile,cpsdir As for vrfcps().
#' @param prov,manifest The provenance and the manifest.
#' @noRd
.vc_script <- function(acc, scrfile, prov, manifest, cpsdir) {
  pinned_script <- manifest$meta$script_sha256 %||% prov$script$sha256
  scrfile <- scrfile %||% prov$script$filename %||% manifest$meta$script_file
  if (is.null(scrfile) && is.null(pinned_script)) {
    return(invisible(NULL))
  }
  acc$required <- c(acc$required, "script_sha256")
  spath <- if (!is.null(scrfile)) .rmbl_safe_rel(scrfile, cpsdir)
  if (is.null(spath) || !file.exists(spath)) {
    .vc_note(
      acc,
      "script_sha256",
      FALSE,
      if (is.null(scrfile)) {
        "a script digest is pinned but no script file is named (script_file)"
      } else {
        sprintf(
          "script '%s' is missing or outside the capsule",
          as.character(unlist(scrfile))[1L]
        )
      }
    )
  } else if (is.null(pinned_script)) {
    .vc_note(
      acc,
      "script_sha256",
      FALSE,
      "no script digest is pinned in the manifest or the provenance"
    )
  } else {
    actual <- sha256file(spath)
    .vc_note(
      acc,
      "script_sha256",
      identical(actual, as.character(unlist(pinned_script))[1L]),
      actual
    )
  }
}

#' Synthetic data is a recorded, required verdict: the sidecar mksyncsv()
#' writes, the manifest's flag, or the provenance's own flag. The row exists
#' whether or not any of them is present -- deleting the sidecar used to delete
#' the finding with it.
#' @param acc The checks so far.
#' @param dpath The data file, or NULL.
#' @param synth_sidecar Whether the data file has a .synthetic sidecar.
#' @param manifest,prov The manifest and the provenance.
#' @noRd
.vc_synthetic <- function(acc, dpath, synth_sidecar, manifest, prov) {
  synth_manifest <- isTRUE(manifest$meta$synthetic)
  synth_prov <- isTRUE(prov$synthetic) || isTRUE(prov$resource$synthetic)
  .vc_note(
    acc,
    "data_not_synthetic",
    !(synth_sidecar || synth_manifest || synth_prov),
    if (synth_sidecar) {
      sprintf(
        "%s.synthetic is present: these data were generated, not fetched",
        basename(dpath)
      )
    } else if (synth_manifest) {
      "the manifest records synthetic = true"
    } else if (synth_prov) {
      "the provenance records synthetic = true"
    } else if (is.null(dpath)) {
      "no data file to check"
    } else {
      "no synthetic marker: sidecar, manifest and provenance all say real data"
    }
  )
}

#' @export
format.bricklayer_capsule_check <- function(x, ...) {
  ck <- x$checks
  c(
    sprintf(
      "Capsule verification: %s (%d of %d checks passed)",
      if (isTRUE(x$ok)) "intact" else "NOT VERIFIED",
      sum(ck$ok),
      nrow(ck)
    ),
    sprintf(
      "  %s  %-20s %s",
      ifelse(ck$ok, "ok  ", "FAIL"),
      ck$check,
      ck$detail
    ),
    if (length(x$missing)) {
      sprintf("  FAIL  %-20s required check was never made", x$missing)
    }
  )
}

#' @export
#' @method print bricklayer_capsule_check
print.bricklayer_capsule_check <- .rmbl_print_via_format

#' Capture the Analysis Environment for a Manifest
#'
#' Records the facts a replicator needs to rebuild the session in which a
#' result was produced: the R version, platform and operating system, a UTC
#' timestamp, the random number generator in use and whether it was seeded,
#' and the versions of the packages involved. Store the result in a results
#' manifest (for example with [wrmnfjs()])
#' next to the numbers
#' it produced, and compare two captures with
#' [envdiff()].
#'
#' @details
#' Package versions come from \code{utils::packageVersion()}; a package that
#' is not installed gets \code{NA} rather than an error. The packages are
#' sorted and de-duplicated. The generator kinds come from \code{RNGkind()}
#' (R has changed its default \code{sample()} algorithm before, so a
#' recorded seed means nothing without the kind it was fed to), and
#' \code{rng_seeded} says whether \code{.Random.seed} exists in the global
#' environment. Nothing is written and the random state is not touched.
#'
#' @param pkgs Character vector of package names to record. Defaults to
#'   every currently loaded namespace (\code{loadedNamespaces()}).
#' @return A list of seven elements: \describe{
#'   \item{\code{r_version}}{character, e.g. \code{"4.5.1"}.}
#'   \item{\code{platform}}{character, \code{R.version$platform}.}
#'   \item{\code{os}}{character, the system name and release.}
#'   \item{\code{captured_utc}}{character, ISO 8601 time
#'   \code{YYYY-MM-DDThh:mm:ssZ}.} \item{\code{rng_kind}}{character, the three
#'   \code{RNGkind()} values joined by commas.}
#'   \item{\code{rng_seeded}}{logical, whether \code{.Random.seed} exists.}
#'   \item{\code{packages}}{named list of version strings, sorted by name
#'   (\code{NA} for a package that is not installed). A list, not a vector, so
#'   the names survive the manifest's JSON: a named vector is written as a bare
#'   array.} }
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Record specific packages' versions alongside the session facts.
#' env <- capenv(c("stats", "utils"))
#' env$r_version
#' env$os
#' env$packages          # named list of versions
#'
#' # Default captures every currently loaded namespace.
#' names(capenv())
#'
#' # the generator and whether it was seeded
#' set.seed(42)
#' capenv("stats")[c("rng_kind", "rng_seeded")]
#'
#' # a package that is not installed is recorded as NA, not an error
#' capenv(c("stats", "notapackage123"))$packages
#' @export
capenv <- function(pkgs = loadedNamespaces()) {
  if (!is.character(pkgs) || anyNA(pkgs)) {
    stop("`pkgs` must be package names", call. = FALSE)
  }
  pkgs <- sort(unique(pkgs))
  list(
    r_version = as.character(getRversion()),
    platform = R.version$platform,
    os = paste(Sys.info()[["sysname"]], Sys.info()[["release"]]),
    captured_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    # Without the generator's identity a stochastic result cannot be
    # reproduced even on the same machine: R has changed its default
    # sample() algorithm before, and a recorded seed means nothing
    # without the kind it was fed to.
    rng_kind = paste(RNGkind(), collapse = ","),
    rng_seeded = exists(".Random.seed", envir = globalenv(), inherits = FALSE),
    packages = as.list(vapply(
      pkgs,
      function(p) {
        tryCatch(as.character(utils::packageVersion(p)), error = function(e) {
          NA_character_
        })
      },
      character(1)
    ))
  )
}

#' Generate a Data Citation From Provenance
#'
#' Builds a ready-to-paste data citation, as plain text and as a BibTeX
#' \code{@misc} entry, from the \code{dataset} and \code{resource} blocks of a
#' provenance record. Use it so that every report and paper built from a
#' capsule cites the data set in the same words, with the retrieval date and
#' licence that were actually pinned.
#'
#' @details The fields used, with their fallbacks: \itemize{ \item author:
#' \code{dataset$publisher}, else \code{"Unknown publisher"}; \item title:
#' \code{resource$name}, else \code{dataset$package_slug}, else \code{"Untitled
#' dataset"}; \item year: the first four characters of \code{captured_at_utc},
#' else the current year; retrieval date: its first ten characters (omitted if
#' absent); \item link: \code{https://doi.org/<dataset$doi>} if a DOI is
#' recorded, else \code{resource$direct_url}, else
#' \code{dataset$catalogue_page}; \item licence: \code{dataset$licence_short},
#' else \code{dataset$licence_name}. } The text form is \code{Publisher (year).
#' Title [Data set]. link Retrieved date. Licence: x.} The BibTeX key is the
#' package slug with non-alphanumeric characters removed, followed by the year.
#' In the BibTeX entry the licence is written in the \code{note} field only when
#' a retrieval date is present. No character in the fields is escaped for LaTeX.
#' Error: \code{prov} that is not a list.
#'
#' @param prov A provenance list as returned by
#'   [loadprov()],
#'   or \code{NULL}.
#' @return A list with \code{text} and \code{bibtex}, each a length-1
#'   character string (the BibTeX entry has embedded newlines), or \code{NULL}
#'   if \code{provenance} is \code{NULL}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' prov <- list(
#'   captured_at_utc = "2026-06-23T04:41:40Z",
#'   dataset = list(publisher = "Ontario Ministry of the Solicitor General",
#'                  licence_short = "OGL-Ontario",
#'                  package_slug = "data-on-inmates-in-ontario"),
#'   resource = list(name = "Restrictive Confinement - Detailed Dataset",
#'                   direct_url = "https://data.ontario.ca/example.csv")
#' )
#' cit <- citecps(prov)
#'
#' # Plain-text citation ready to paste.
#' cat(cit$text)
#'
#' # BibTeX @misc entry for LaTeX bibliographies.
#' cat(cit$bibtex)
#'
#' # a recorded DOI replaces the URL
#' prov$dataset$doi <- "10.5683/SP3/EXAMPLE"
#' cat(citecps(prov)$text)
#'
#' # NULL provenance returns NULL (composes safely).
#' citecps(NULL)
#'
#' # anything else that is not a list is an error
#' try(citecps("data-on-inmates-in-ontario"))
#' @export
citecps <- function(prov) {
  if (is.null(prov)) {
    return(NULL)
  }
  if (!is.list(prov)) {
    stop(
      "citecps: `prov` must be a provenance list (loadprov())",
      call. = FALSE
    )
  }
  ds <- prov$dataset
  res <- prov$resource
  year <- substr(prov$captured_at_utc %||% "", 1, 4)
  if (!nzchar(year)) {
    year <- format(Sys.Date(), "%Y")
  }
  publisher <- ds$publisher %||% "Unknown publisher"
  title <- res$name %||% ds$package_slug %||% "Untitled dataset"
  url <- res$direct_url %||% ds$catalogue_page %||% ""
  licence <- ds$licence_short %||% ds$licence_name %||% NULL
  doi <- ds$doi %||% NULL
  retrieved <- substr(prov$captured_at_utc %||% "", 1, 10)

  text <- paste0(
    publisher,
    " (",
    year,
    "). ",
    title,
    " [Data set].",
    if (!is.null(doi)) {
      paste0(" https://doi.org/", doi)
    } else if (nzchar(url)) {
      paste0(" ", url)
    } else {
      ""
    },
    if (nzchar(retrieved)) paste0(" Retrieved ", retrieved, ".") else "",
    if (!is.null(licence)) paste0(" Licence: ", licence, ".") else ""
  )

  key <- paste0(
    gsub("[^A-Za-z0-9]", "", ds$package_slug %||% "dataset"),
    year
  )
  bib_lines <- c(
    paste0("@misc{", key, ","),
    paste0("  author = {{", publisher, "}},"),
    paste0("  title = {", title, "},"),
    paste0("  year = {", year, "},"),
    if (!is.null(doi)) paste0("  doi = {", doi, "},"),
    if (nzchar(url)) paste0("  url = {", url, "},"),
    if (nzchar(retrieved)) {
      paste0(
        "  note = {Retrieved ",
        retrieved,
        if (!is.null(licence)) {
          paste0("; licence: ", licence)
        } else {
          ""
        },
        "},"
      )
    },
    "}"
  )
  list(text = text, bibtex = paste(bib_lines, collapse = "\n"))
}
