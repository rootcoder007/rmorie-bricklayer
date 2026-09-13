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
##   write_manifest_json(manifest, path)
##   write_summary_txt(manifest, output_dir, paths, what_was_done)
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
#' Creates an empty manifest object that accumulates cross-check entries
#' via [record()] and is later serialized with
#' [write_manifest_json()].
#'
#' @param meta A named list of run metadata (e.g.
#' `project`, `author`, `run_at`, `synthetic`) .
#' @param environment Logical; when `TRUE` (the
#' default) the manifest also records the analysis environment via
#' [capture_environment()] (R version,
#' platform, OS, UTC timestamp, loaded package versions).
#' @return A manifest list with elements `meta`, an empty
#' `results` list, and (when requested) `environment`.
#' @examples
#' # Minimal manifest, no environment capture.
#' man <- make_manifest(list(project = "demo-study", author = "A. Author"),
#'                      environment = FALSE)
#' names(man)          # "meta" "results"
#' man$meta$project
#'
#' # With environment = TRUE it also records R version / platform / packages.
#' full <- make_manifest(list(project = "demo"), environment = TRUE)
#' names(full)         # adds "environment"
#' full$environment$r_version
#' @export
make_manifest <- function(meta, environment = TRUE) {
  m <- list(meta = meta, results = list())
  if (isTRUE(environment)) m$environment <- capture_environment()
  m
}

#' Record a Cross-Check Result in a Manifest
#'
#' Appends one named cross-check entry to a manifest, classifying it as
#' `PASS`, `DIFFER`, or `INFO`, printing a formatted line to
#' the console, and returning the updated manifest.
#'
#' @param manifest A manifest as returned by
#' [make_manifest()].
#' @param name Unique name for this cross-check; used as the
#' result key.
#' @param observed The observed value (numeric or
#' otherwise).
#' @param expected The expected value to compare against.
#' @param tol Numeric tolerance; a numeric pair within
#' `tol` is `PASS`. Defaults to `0.0001`.
#' @param group Optional grouping label for the entry.
#' Defaults to `"general"`.
#' @param synthetic Logical; if `TRUE` the entry is
#' marked `INFO` because comparison against synthetic data is not
#' meaningful.
#' @return The updated manifest, returned so calls can be chained.
#' @examples
#' man <- make_manifest(list(project = "demo"), environment = FALSE)
#'
#' # Within tolerance -> PASS.
#' man <- record(man, "mean_matches", observed = 1.0001, expected = 1,
#'               tol = 0.001)
#' man$results$mean_matches$status      # "PASS"
#'
#' # Outside tolerance -> DIFFER.
#' man <- record(man, "sd_matches", observed = 2.5, expected = 2.0, tol = 0.01)
#' man$results$sd_matches$status        # "DIFFER"
#'
#' # Synthetic data -> INFO (comparison not meaningful).
#' man <- record(man, "synthetic_row", observed = 5, expected = 5,
#'               synthetic = TRUE)
#' man$results$synthetic_row$status     # "INFO"
#'
#' # Calls chain: record() returns the mutated manifest.
#' length(man$results)                  # 3
#' @export
record <- function(manifest, name, observed, expected,
                   tol = 0.0001, group = "general",
                   synthetic = FALSE) {
  diff <- if (is.numeric(observed) && is.numeric(expected))
    abs(observed - expected) else NA_real_
  status <- if (isTRUE(synthetic)) "INFO"
            else if (!is.na(diff) && diff <= tol) "PASS"
            else if (!is.na(diff)) "DIFFER"
            else "INFO"
  manifest$results[[name]] <- list(
    group    = group,
    observed = observed,
    expected = expected,
    diff     = diff,
    status   = status,
    tol      = tol,
    note     = if (isTRUE(synthetic))
                  "synthetic data -- comparison not meaningful" else NULL
  )
  message(sprintf("  %-44s observed = %-12s expected = %-12s [%s]",
                  name,
                  if (is.numeric(observed)) sprintf("%.4f", observed) else as.character(observed),
                  if (is.numeric(expected)) sprintf("%.4f", expected) else as.character(expected),
                  status))
  manifest
}

#' Write a Manifest to JSON
#'
#' Serializes a manifest to a pretty-printed JSON file with the native JSON
#' codec (
#' [bricklayer_json_to_json()]) ; no
#' jsonlite needed.
#'
#' @param manifest A manifest as returned by
#' [make_manifest()] / built up with
#' [record()].
#' @param path Destination path for the JSON file.
#' @param canonical Write the canonical form rather than
#' the pretty-printed one: one line, keys sorted, which is what
#' [manifest_digest()] hashes. Use it when
#' the file itself has to be byte-stable rather than read by a person.
#' @return The `path`, returned invisibly.
#' @examples
#' man <- make_manifest(list(project = "demo"), environment = FALSE)
#' man <- record(man, "row_count", observed = 20, expected = 20)
#' path <- write_manifest_json(man, tempfile(fileext = ".json"))
#' file.exists(path)
#'
#' # Round-trips back through the package's own codec.
#' back <- bricklayer_json_from_json(path, simplifyVector = FALSE)
#' back$results$row_count$status        # "PASS"
#' @export
write_manifest_json <- function(manifest, path, canonical = FALSE) {
  if (isTRUE(canonical)) {
    writeLines(manifest_canonical(manifest), path, useBytes = TRUE)
    return(invisible(path))
  }
  writeLines(bricklayer_json_to_json(manifest, auto_unbox = TRUE,
                                     pretty = TRUE, na = "null",
                                     null = "null",
                                     digits = I(17)),
             path, useBytes = TRUE)
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
#' @param manifest A manifest, as from
#' [make_manifest()].
#' @return `manifest_canonical()` a length-1 character vector;
#' `manifest_digest()` 64 hex characters.
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
#' m <- make_manifest(list(x = 1/3), environment = FALSE)
#' grepl("0.33333333333333331", manifest_canonical(m), fixed = TRUE)
#' @export
manifest_canonical <- function(manifest) {
  bricklayer_json_to_json(.rmbl_sort_keys(manifest), auto_unbox = TRUE,
                          pretty = FALSE, na = "null", null = "null",
                          digits = I(17))
}

#' @rdname manifest_canonical
#' @export
manifest_digest <- function(manifest) {
  core_sha256(charToRaw(manifest_canonical(manifest)))
}

# Recursively order the names of every list, leaving unnamed lists (JSON
# arrays, where order is content) alone.
.rmbl_sort_keys <- function(x) {
  if (!is.list(x)) return(x)
  x <- lapply(x, .rmbl_sort_keys)
  nm <- names(x)
  if (is.null(nm) || any(!nzchar(nm))) return(x)
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
#' Writes a human-readable `SUMMARY.txt` into the output directory,
#' covering run metadata, the exact absolute paths used, result counts, the
#' files produced, and optional notes, contact, and licence lines.
#'
#' @param manifest A manifest as returned by
#' [make_manifest()]; its `meta` supplies
#' project/author/run details.
#' @param output_dir Directory to write
#' `SUMMARY.txt` into and to list produced files from.
#' @param paths A named list of absolute paths to report (e.g.
#' `capsule`, `input`, `results`, `analysis_script`,
#' `provenance`) .
#' @param what_was_done Optional character vector of
#' bullet points describing what the run did.
#' @param contact Optional contact string appended to the
#' summary.
#' @param licence Optional licence string appended to the
#' summary.
#' @return The path to the written `SUMMARY.txt`, returned invisibly.
#' @examples
#' man <- make_manifest(list(project = "demo", author = "A. Author"),
#'                      environment = FALSE)
#' man <- record(man, "row_count", observed = 20, expected = 20)
#' out <- file.path(tempdir(), "demo-run")
#' dir.create(out, showWarnings = FALSE)
#' s <- write_summary_txt(man, out, paths = list(results = out))
#' readLines(s)[7:8]
#' @export
write_summary_txt <- function(manifest, output_dir, paths,
                              what_was_done = NULL,
                              contact = NULL,
                              licence = NULL) {
  counts <- summarise_counts(manifest)
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
    paste0("Author:    ", manifest$meta$author  %||% "(unknown)"),
    paste0("When:      ", manifest$meta$run_at %||%
                          format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("OS:        ", manifest$meta$os %||% Sys.info()[["sysname"]]),
    paste0("R:         ", manifest$meta$r_version %||% R.version.string),
    paste0("Mode:      ", if (is_synth)
                            "SYNTHETIC (not real data -- pipeline check only)"
                          else "real data"),
    "",
    "----------------------------------------------------------",
    "  PATHS -- exact absolute locations used in this run",
    "----------------------------------------------------------"
  )
  for (nm in names(paths)) {
    lines <- c(lines, sprintf("%-15s %s",
                              paste0(toupper(substr(nm, 1, 1)),
                                     substr(nm, 2, nchar(nm)), ":"),
                              paths[[nm]]))
  }
  lines <- c(lines, "",
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
    lines <- c(lines, "",
      "----------------------------------------------------------",
      "  R PACKAGE VERSIONS USED IN THIS RUN",
      "  (reference numbers were produced on specific versions;",
      "   drift here explains most WARN/convergence differences)",
      "----------------------------------------------------------",
      sprintf("  %-12s %s", names(vers),
              vapply(vers, function(v) as.character(v %||% "?"), character(1))))
  }
  if (!is.null(what_was_done)) {
    lines <- c(lines, "",
      "----------------------------------------------------------",
      "  WHAT WAS DONE",
      "----------------------------------------------------------",
      what_was_done)
  }
  if (!is.null(contact)) lines <- c(lines, "", paste0("Contact: ", contact))
  if (!is.null(licence)) lines <- c(lines, paste0("Licence: ", licence))

  writeLines(lines, file.path(output_dir, "SUMMARY.txt"))
  invisible(file.path(output_dir, "SUMMARY.txt"))
}
