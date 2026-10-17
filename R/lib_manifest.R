# SPDX-License-Identifier: AGPL-3.0-or-later
## =====================================================================
## lib_manifest.R -- cross-check accounting + SUMMARY.txt + manifest.json
##
## Part of rmorie-bricklayer. Provides the `record()` machinery and the
## end-of-run summary writers.
##
## Provides:
##   make_manifest(meta)                Construct a manifest object
##   record(manifest, name, observed,   Append a cross-check entry; returns
##          expected, tol, group,         the mutated manifest
##          synthetic)
##   write_manifest_json: the manifest to a JSON path
##   write_summary_txt: the manifest summary next to the outputs
##
## Licence: AGPL-3.0-or-later
## =====================================================================

#' Null-Coalescing Operator
#'
#' Returns `a` unless it is `NULL`, in which case it returns
#' `b`.
#'
#' @param a Left-hand value.
#' @param b Fallback used when `a` is `NULL`.
#' @return `a` if it is not `NULL`, otherwise `b`.
#' @keywords internal
#' @noRd
`%||%` <- function(a, b) if (is.null(a)) b else a

#' Construct a Reproducibility Manifest
#'
#' Creates an empty manifest: the record of one analysis run that collects
#' the run's metadata, the cross-checks of its results against expected
#' values (added with [record()]), and optionally a snapshot of the
#' R
#' environment it ran in. Write it out with
#' [write_manifest_json()] and
#' [write_summary_txt()], or hash and sign it with
#' [manifest_digest()] and
#' [capsule_attest()], so a reader can later see what was
#' run, where, and
#' whether the numbers matched.
#'
#' @details
#' The manifest is a plain list, so you can add your own elements to
#' \code{meta} before writing it. The package owns the synthetic-data flag:
#' \code{meta$synthetic} is set to \code{TRUE} when you pass it, when the
#' environment variable \code{BRICKLAYER_SYNTHETIC} is set to a value other
#' than \code{0}, \code{false}, \code{no} or \code{off}, or when the package
#' generated synthetic data earlier in the session. It is written only when
#' \code{TRUE}, so a manifest of real data keeps the digest it had before the
#' flag existed. On a synthetic manifest every [record()] entry is
#' \code{INFO}.
#'
#' Fields of \code{meta} that [write_summary_txt()]
#' reads: \code{project},
#' \code{author}, \code{run_at}, \code{os}, \code{r_version} and
#' \code{r_package_versions} (a named list or vector of versions).
#'
#' Errors when \code{meta} is not a list. Nothing is written.
#'
#' @param meta A list of run metadata, normally named (for example
#'   \code{project}, \code{author}, \code{run_at}, \code{synthetic}). May be
#'   \code{list()}.
#' @param environment Logical scalar; when \code{TRUE} (the default) the
#'   manifest also records the analysis environment via
#'   [capture_environment()]: R version, platform, OS,
#'   UTC timestamp, random
#'   number generator kind and whether it was seeded, and the version of
#'   every loaded package. Any other value leaves it out.
#' @return A list with elements \code{meta} (the list given, plus
#'   \code{synthetic = TRUE} when flagged), \code{results} (an empty list,
#'   filled by [record()]) and, when \code{environment = TRUE},
#'   \code{environment} (the list from
#'   [capture_environment()]).
#' @seealso [record()],
#'   [write_manifest_json()],
#'   [write_summary_txt()],
#'   [manifest_digest()].
#' @examples
#' # Minimal manifest, no environment capture.
#' man <- make_manifest(list(project = "demo-study", author = "A. Author"),
#'   environment = FALSE
#' )
#' names(man) # "meta" "results"
#' man$meta$project
#'
#' # With environment = TRUE it also records R version / platform / packages.
#' full <- make_manifest(list(project = "demo"), environment = TRUE)
#' names(full) # adds "environment"
#' full$environment$r_version
#'
#' # a run on generated data is flagged, and its checks become INFO
#' syn <- make_manifest(list(project = "demo", synthetic = TRUE), environment = FALSE)
#' syn$meta$synthetic
#'
#' # meta must be a list
#' try(make_manifest("demo"))
#' @export
make_manifest <- function(meta, environment = TRUE) {
  if (!is.list(meta)) stop("`meta` must be a list", call. = FALSE)
  # the package owns the synthetic flag: set here from BRICKLAYER_SYNTHETIC
  # (the reference pipeline sets it for its analysis subprocess), so a
  # manifest written on generated data says so whatever the script did
  # the flag is written only when it is TRUE: a manifest of real data keeps
  # the digest it had before the flag existed
  if (isTRUE(meta$synthetic) || .rmbl_synthetic_flag()) meta$synthetic <- TRUE
  m <- list(meta = meta, results = list())
  if (isTRUE(environment)) m$environment <- capture_environment()
  m
}

#' Record a Cross-Check Result in a Manifest
#'
#' Appends one named cross-check to a manifest: a number your analysis
#' produced (\code{observed}) next to the number it should reproduce
#' (\code{expected}, for example a published table value). Each entry is
#' classified \code{PASS}, \code{DIFFER} or \code{INFO}, a one-line report
#' is shown as a message, and the updated manifest is returned so calls can
#' be chained. The tallies appear in
#' [write_summary_txt()] and the entries in
#' [write_manifest_json()].
#'
#' @details
#' The status is decided in this order: \code{INFO} when \code{synthetic =
#' TRUE} or the manifest's \code{meta$synthetic} is \code{TRUE} (a comparison
#' on generated data is not meaningful); \code{PASS} when both values are
#' numeric and \eqn{|observed - expected| \le tol}; \code{DIFFER} when both are
#' numeric and further apart; \code{INFO} otherwise (for example a text or
#' logical value, or an \code{NA}). The tolerance is absolute, not relative:
#' scale it to the size of the quantity.
#'
#' \code{observed} and \code{expected} must be single values: a vector of
#' another length (including an empty one) is an error naming the argument;
#' record a vector's elements under separate names, or a summary of it.
#' Recording under an existing \code{name} replaces that
#' entry. The message line is a side effect; wrap the call in
#' \code{suppressMessages()} to silence it.
#'
#' @param manifest A manifest as returned by
#'   [make_manifest()].
#' @param name Character scalar, the name of this cross-check; used as the
#'   key in \code{manifest$results}, so it should be unique.
#' @param observed The value the analysis produced: a numeric scalar for a
#'   tolerance check, or any single value to be stored as information.
#' @param expected The value to compare against, of the same kind.
#' @param tol Numeric scalar, the absolute tolerance: a numeric pair at most
#'   \code{tol} apart is \code{PASS}. Default \code{0.0001}.
#' @param group Character scalar, a grouping label stored with the entry (for
#'   example the table the number comes from). Default \code{"general"}.
#' @param synthetic Logical scalar; \code{TRUE} marks this entry \code{INFO}
#'   because a comparison on synthetic data is not meaningful. Default
#'   \code{FALSE}.
#' @return The manifest with \code{results[[name]]} set to a list with
#'   \code{group}, \code{observed}, \code{expected}, \code{diff} (the
#'   absolute difference, \code{NA} when the pair is not numeric),
#'   \code{status} (\code{"PASS"}, \code{"DIFFER"} or \code{"INFO"}),
#'   \code{tol} and \code{note} (a sentence for synthetic entries, else
#'   \code{NULL}).
#' @seealso [make_manifest()],
#'   [write_summary_txt()].
#' @examples
#' man <- make_manifest(list(project = "demo"), environment = FALSE)
#'
#' # Within tolerance -> PASS.
#' man <- record(man, "mean_matches",
#'   observed = 1.0001, expected = 1,
#'   tol = 0.001
#' )
#' man$results$mean_matches$status # "PASS"
#'
#' # Outside tolerance -> DIFFER.
#' man <- record(man, "sd_matches", observed = 2.5, expected = 2.0, tol = 0.01)
#' man$results$sd_matches$status # "DIFFER"
#'
#' # Synthetic data -> INFO (comparison not meaningful).
#' man <- record(man, "synthetic_row",
#'   observed = 5, expected = 5,
#'   synthetic = TRUE
#' )
#' man$results$synthetic_row$status # "INFO"
#'
#' # a non-numeric value is stored as information, silently
#' man <- suppressMessages(record(man, "country", observed = "CA", expected = "CA",
#'                                group = "metadata"))
#' man$results$country$status # "INFO"
#'
#' # Calls chain: record() returns the mutated manifest.
#' length(man$results) # 4
#' @export
record <- function(manifest, name, observed, expected,
                   tol = 0.0001, group = "general",
                   synthetic = FALSE) {
  .rmbl_no_fn(observed = observed, expected = expected)
  if (!is.list(manifest)) stop("`manifest` must be a manifest from make_manifest()", call. = FALSE)
  name <- .rmbl_string1(name, "name")
  # one value each: a vector made the PASS test `diff <= tol` a vector and
  # failed in R's own words ('length = 2' in coercion to 'logical(1)')
  lens <- c(observed = length(observed), expected = length(expected))
  if (any(lens != 1L)) {
    bad <- which(lens != 1L)[1L]
    stop(sprintf("`%s` must be a single value, got %d", names(lens)[bad], lens[[bad]]), call. = FALSE)
  }
  diff <- if (is.numeric(observed) && is.numeric(expected)) {
    abs(observed - expected)
  } else {
    NA_real_
  }
  # a manifest built on synthetic data makes every comparison INFO
  synthetic <- isTRUE(synthetic) || isTRUE(manifest$meta$synthetic)
  status <- if (synthetic) {
    "INFO"
  } else if (!is.na(diff) && diff <= tol) {
    "PASS"
  } else if (!is.na(diff)) {
    "DIFFER"
  } else {
    "INFO"
  }
  manifest$results[[name]] <- list(
    group = group,
    observed = observed,
    expected = expected,
    diff = diff,
    status = status,
    tol = tol,
    note = if (isTRUE(synthetic)) {
      "synthetic data -- comparison not meaningful"
    } else {
      NULL
    }
  )
  message(sprintf(
    "  %-44s observed = %-12s expected = %-12s [%s]",
    name,
    if (is.numeric(observed)) sprintf("%.4f", observed) else as.character(observed),
    if (is.numeric(expected)) sprintf("%.4f", expected) else as.character(expected),
    status
  ))
  manifest
}

#' Write a Manifest to JSON
#'
#' Writes a manifest to a JSON file, so the record of a run (its metadata,
#' cross-checks and environment) can be kept next to the outputs, shared,
#' and read back by any JSON reader. By default the file is pretty-printed
#' for people; \code{canonical = TRUE} writes the byte-stable form that
#' [manifest_digest()] hashes. The package's own JSON codec
#' ([bricklayer_json_to_json()]) is used; jsonlite
#' is not needed.
#'
#' @details
#' Numbers are written with 17 significant digits, so every double reads
#' back exactly; \code{NA} and \code{NULL} are written as \code{null}, and
#' length-one vectors as scalars. When the manifest's \code{meta$synthetic}
#' is \code{TRUE}, or the session is flagged synthetic (see
#' [make_manifest()]), \code{meta$synthetic = true} is
#' written whatever the
#' list says, so a file written from generated data always says so. An
#' existing file at \code{path} is overwritten; the folder must exist.
#'
#' Errors when \code{path} is not a single non-empty string, and (from base
#' R) when the file cannot be opened for writing.
#'
#' @param manifest A manifest as returned by
#'   [make_manifest()] and built up
#'   with [record()].
#' @param path Character scalar, the destination file path.
#' @param canonical Logical scalar, default \code{FALSE}. \code{TRUE} writes
#'   the canonical form instead of the pretty-printed one: one line, keys
#'   sorted, which is what [manifest_digest()] hashes. Use
#'   it when the file
#'   itself has to be byte-stable rather than read by a person.
#' @return \code{path} (character scalar), invisibly.
#' @seealso [manifest_canonical()],
#'   [write_summary_txt()].
#' @examples
#' man <- make_manifest(list(project = "demo"), environment = FALSE)
#' man <- record(man, "row_count", observed = 20, expected = 20)
#' path <- write_manifest_json(man, tempfile(fileext = ".json"))
#' file.exists(path)
#'
#' # Round-trips back through the package's own codec.
#' back <- bricklayer_json_from_json(path, simplifyVector = FALSE)
#' back$results$row_count$status # "PASS"
#'
#' # the canonical form: one line whose SHA-256 is the manifest digest
#' cpath <- write_manifest_json(man, tempfile(fileext = ".json"), canonical = TRUE)
#' identical(readLines(cpath), manifest_canonical(man))
#'
#' # the path must be one string
#' try(write_manifest_json(man, c("a.json", "b.json")))
#' @export
write_manifest_json <- function(manifest, path, canonical = FALSE) {
  path <- .rmbl_string1(path, "path")
  if (!is.list(manifest)) stop("`manifest` must be a manifest from make_manifest()", call. = FALSE)
  # never written without the flag (see make_manifest())
  if (isTRUE(manifest$meta$synthetic) || .rmbl_synthetic_flag()) {
    manifest$meta$synthetic <- TRUE
  }
  if (isTRUE(canonical)) {
    writeLines(manifest_canonical(manifest), path, useBytes = TRUE)
    return(invisible(path))
  }
  writeLines(
    bricklayer_json_to_json(manifest,
      auto_unbox = TRUE,
      pretty = TRUE, na = "null",
      null = "null",
      digits = I(17)
    ),
    path,
    useBytes = TRUE
  )
  invisible(path)
}

#' The canonical serialisation of a manifest, and its digest
#'
#' `manifest_canonical()` renders a manifest as one line of JSON with
#' every object's keys in sorted order and every number at full double
#' precision. `manifest_digest()` is the SHA-256 of those bytes.
#'
#' Why this is needed. Two manifests that record the same thing can easily
#' differ as bytes: R lists keep insertion order, so building `meta`
#' before `results` or the other way round gives different JSON, and a
#' signature over the JSON would then depend on the order a script happened
#' to assemble the list. Sorting the keys removes that. The precision
#' matters for a different reason: the default JSON writer emits four
#' significant digits, which is right for a human-readable report and wrong
#' for a record something will later be checked against, because `1/3`
#' comes back as `0.3333` and no recomputation can match it.
#'
#' Sign [manifest_digest()], not the pretty
#' JSON. The digest is stable across the assembly order, across
#' `pretty`, and across a round trip through a file.
#'
#' Full precision means full precision on every platform, which took more
#' than writing enough digits. Seventeen significant digits recover any
#' double exactly, but only through a reader that converts decimal to
#' binary with correct rounding, and not every C library does -- macOS
#' arm64 reads the correct decimal for the largest double as infinity. So
#' this package converts decimals itself rather than asking the platform,
#' in integer arithmetic with a remainder that decides the rounding. A
#' manifest written on one machine reads back bit-identically on another,
#' and a caller does nothing to get that.
#'
#' Errors when \code{manifest} is not a list.
#'
#' @param manifest A manifest (a list), as from
#'   [make_manifest()]; any list
#'   is accepted.
#' @return \code{manifest_canonical()}: a character scalar, the one-line
#'   JSON. \code{manifest_digest()}: a character scalar of 64 lower-case
#'   hexadecimal characters, the SHA-256 of the canonical bytes.
#' @seealso
#' [make_manifest()],
#' [write_manifest_json()],
#' [capsule_attest()].
#' @examples
#' a <- make_manifest(list(b = 2, a = 1), environment = FALSE)
#' b <- make_manifest(list(a = 1, b = 2), environment = FALSE)
#' # the same content in a different order has the same digest
#' identical(manifest_digest(a), manifest_digest(b))
#'
#' # full precision, so a recorded number can be checked later
#' m <- make_manifest(list(x = 1 / 3), environment = FALSE)
#' grepl("0.33333333333333331", manifest_canonical(m), fixed = TRUE)
#'
#' # any change to a recorded value changes the digest
#' m2 <- record(m, "check", observed = 1, expected = 1)
#' manifest_digest(m) == manifest_digest(m2)
#'
#' # only lists can be serialised this way
#' try(manifest_digest("not a manifest"))
#' @export
manifest_canonical <- function(manifest) {
  if (!is.list(manifest)) stop("`manifest` must be a list", call. = FALSE)
  # keep_empty_names: an empty-string key is written as "", not renamed to
  # its position, so two documents differing only there do not share a digest
  # keep_vec_names: a named atomic vector is an object too ({"a":1} is not
  # [1]); the names attribute, present or absent, is what tells an object
  # from an array at every level, so the encoding is one-to-one
  bricklayer_json_to_json(.rmbl_sort_keys(manifest),
    auto_unbox = TRUE,
    pretty = FALSE, na = "null", null = "null",
    digits = I(17), keep_empty_names = TRUE, keep_vec_names = TRUE,
    quiet_vec_names = TRUE
  )
}

#' @rdname manifest_canonical
#' @export
manifest_digest <- function(manifest) {
  .rmbl_sha256_bytes(charToRaw(manifest_canonical(manifest)))
}

# Inside the package: the compiled core; sourced standalone in a capsule
# bundle: the pure-R implementation from sha256_native.R.
#' @noRd
.rmbl_sha256_bytes <- function(bytes,
                               native = exists("core_sha256",
                                 mode = "function"
                               )) {
  if (native) {
    return(core_sha256(bytes))
  }
  .rmbl_sha256_hex(bytes)
}

# Recursively order the names of every list, leaving unnamed lists (JSON
# arrays, where order is content) alone.
.rmbl_sort_keys <- function(x) {
  if (!is.list(x)) {
    return(x)
  }
  x <- lapply(x, .rmbl_sort_keys)
  nm <- names(x)
  if (is.null(nm)) {
    return(x)
  }
  # A list with a names attribute is a JSON object, and an empty string is
  # a legal key that sorts first: {"":"X"} and {"1":"X"} are different
  # documents (the encoder writes "" as "", see manifest_canonical()). That
  # holds when EVERY name is empty too: {"":"X"} is not ["X"], and 0.5.7's
  # "all names empty is an array" rule made one attestation verify both.
  # The parser sets the names attribute on objects and never on arrays, so
  # its presence is the distinction, not the names' contents.
  x[order(nm, method = "radix")]
}

#' Summarise Manifest Result Counts
#'
#' Tallies the status of every recorded cross-check in a manifest.
#'
#' @param manifest A manifest whose `results` entries
#' each carry a `status` of `"PASS"`, `"DIFFER"`, or
#' `"INFO"`.
#' @return A list with integer counts `total`, `pass`,
#' `differ`, `warn`, and `info`.
#' @keywords internal
#' @noRd
summarise_counts <- function(manifest) {
  statuses <- vapply(manifest$results, function(x) x$status, character(1))
  list(
    total  = length(statuses),
    pass   = sum(statuses == "PASS"),
    differ = sum(statuses == "DIFFER"),
    warn   = sum(statuses == "WARN"),
    info   = sum(statuses == "INFO")
  )
}

## ----- SUMMARY.txt -----
## `paths` is a named list: capsule, input, results, script, provenance
## `what_was_done` is an optional character vector of bullet points

#' Write a Plain-Language Run Summary
#'
#' Writes \code{SUMMARY.txt} into an output folder: a plain-text page a
#' person can read without any software, giving the project, author, time,
#' operating system and R version of the run, whether it ran on real or
#' synthetic data, the paths it used, the tally of cross-check results, the
#' files in the folder, and optional notes, contact and licence lines. It is
#' the human-readable companion of
#' [write_manifest_json()].
#'
#' @details
#' Header fields come from \code{manifest$meta}: \code{project} (default
#' \code{"(unnamed)"}), \code{author} (\code{"(unknown)"}), \code{run_at}
#' (default the current time), \code{os} (default \code{Sys.info()}),
#' \code{r_version} (default \code{R.version.string}) and \code{synthetic}.
#' When \code{meta$r_package_versions} is present a section lists those
#' versions. Result counts are tallied from the \code{status} of each entry
#' of \code{manifest$results} (PASS, DIFFER, WARN, INFO).
#'
#' The file list is \code{list.files(output_dir)} at the time of the call,
#' sorted, so write the summary last. The paths are printed as given (they
#' are not made absolute). An existing \code{SUMMARY.txt} is overwritten.
#'
#' Errors when \code{manifest} is not a list, and (from base R) when
#' \code{output_dir} does not exist or cannot be written.
#'
#' @param manifest A manifest as returned by
#'   [make_manifest()]; its
#'   \code{meta} supplies the header and its \code{results} the counts.
#' @param output_dir Character scalar, an existing folder to write
#'   \code{SUMMARY.txt} into and to list the files of.
#' @param paths A named list (or named character vector) of paths to report,
#'   one line each, labelled by the capitalised name (for example
#'   \code{capsule}, \code{input}, \code{results}, \code{analysis_script},
#'   \code{provenance}). \code{list()} reports none.
#' @param what_was_done Optional character vector, one line each, describing
#'   what the run did. Default \code{NULL} (no section).
#' @param contact Optional character scalar appended as a \code{Contact:}
#'   line. Default \code{NULL}.
#' @param licence Optional character scalar appended as a \code{Licence:}
#'   line. Default \code{NULL}.
#' @return The path to the written \code{SUMMARY.txt} (character scalar),
#'   invisibly.
#' @seealso [make_manifest()],
#'   [record()],
#'   [write_manifest_json()].
#' @examples
#' man <- make_manifest(list(project = "demo", author = "A. Author"),
#'   environment = FALSE
#' )
#' man <- record(man, "row_count", observed = 20, expected = 20)
#' out <- file.path(tempdir(), "demo-run")
#' dir.create(out, showWarnings = FALSE)
#' s <- write_summary_txt(man, out, paths = list(results = out))
#' readLines(s)[7:8]
#'
#' # with notes, contact and licence lines
#' s <- write_summary_txt(man, out, paths = list(results = out),
#'   what_was_done = c("- read the extract", "- recomputed table 2"),
#'   contact = "analyst at example.org", licence = "CC BY 4.0")
#' tail(readLines(s), 6)
#'
#' # the manifest has to be a list
#' try(write_summary_txt("demo", out, paths = list()))
#' @export
write_summary_txt <- function(manifest, output_dir, paths,
                              what_was_done = NULL,
                              contact = NULL,
                              licence = NULL) {
  if (!is.list(manifest)) stop("`manifest` must be a manifest from make_manifest()", call. = FALSE)
  counts <- summarise_counts(manifest)
  output_dir <- .rmbl_string1(output_dir, "output_dir")
  if (!dir.exists(output_dir)) stop("`output_dir` is not a directory: ", output_dir, call. = FALSE)
  files <- sort(list.files(output_dir))
  is_synth <- isTRUE(manifest$meta$synthetic)

  lines <- c(
    "##########################################################",
    "#                                                        #",
    "#   REPRODUCIBILITY RUN -- SUMMARY                        #",
    "#                                                        #",
    "##########################################################",
    "",
    paste0("Project:   ", manifest$meta$project %||% "(unnamed)"),
    paste0("Author:    ", manifest$meta$author %||% "(unknown)"),
    paste0("When:      ", manifest$meta$run_at %||%
      format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("OS:        ", manifest$meta$os %||% Sys.info()[["sysname"]]),
    paste0("R:         ", manifest$meta$r_version %||% R.version.string),
    paste0("Mode:      ", if (is_synth) {
      "SYNTHETIC (not real data -- pipeline check only)"
    } else {
      "real data"
    }),
    "",
    "----------------------------------------------------------",
    "  PATHS -- exact absolute locations used in this run",
    "----------------------------------------------------------"
  )
  for (nm in names(paths)) {
    lines <- c(lines, sprintf(
      "%-15s %s",
      paste0(
        toupper(substr(nm, 1, 1)),
        substr(nm, 2, nchar(nm)), ":"
      ),
      paths[[nm]]
    ))
  }
  lines <- c(
    lines, "",
    "----------------------------------------------------------",
    "  RESULT COUNTS",
    "----------------------------------------------------------",
    sprintf("Total checks: %d", counts$total),
    sprintf("PASS:         %d", counts$pass),
    sprintf("DIFFER:       %d", counts$differ),
    sprintf("WARN:         %d", counts$warn %||% 0L),
    sprintf("INFO:         %d", counts$info),
    "",
    "----------------------------------------------------------",
    "  FILES IN THIS RESULTS FOLDER",
    "----------------------------------------------------------",
    paste0("  ", files)
  )
  vers <- manifest$meta$r_package_versions
  if (!is.null(vers) && length(vers) > 0L) {
    lines <- c(
      lines, "",
      "----------------------------------------------------------",
      "  R PACKAGE VERSIONS USED IN THIS RUN",
      "  (reference numbers were produced on specific versions;",
      "   drift here explains most WARN/convergence differences)",
      "----------------------------------------------------------",
      sprintf(
        "  %-12s %s", names(vers),
        vapply(vers, function(v) as.character(v %||% "?"), character(1))
      )
    )
  }
  if (!is.null(what_was_done)) {
    lines <- c(
      lines, "",
      "----------------------------------------------------------",
      "  WHAT WAS DONE",
      "----------------------------------------------------------",
      what_was_done
    )
  }
  if (!is.null(contact)) lines <- c(lines, "", paste0("Contact: ", contact))
  if (!is.null(licence)) lines <- c(lines, paste0("Licence: ", licence))

  writeLines(lines, file.path(output_dir, "SUMMARY.txt"))
  invisible(file.path(output_dir, "SUMMARY.txt"))
}
