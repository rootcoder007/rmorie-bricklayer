# SPDX-License-Identifier: AGPL-3.0-or-later
## =====================================================================
## lib_manifest.R -- cross-check accounting + SUMMARY.txt + manifest.json
##
## Part of rmorie-bricklayer. Provides the `recrd()` machinery and the
## end-of-run summary writers.
##
## Provides:
##   mkmnf(meta)                Construct a manifest object
##   record(manifest, name, observed,   Append a cross-check entry; returns
##          expected, tol, group,         the mutated manifest
##          synthetic)
##   wrmnfjs: the manifest to a JSON path
##   wrsmrytxt: the manifest summary next to the outputs
##
## Licence: AGPL-3.0-or-later
## =====================================================================

#' Construct a Reproducibility Manifest
#'
#' Creates an empty manifest: the record of one analysis run that collects
#' the run's metadata, the cross-checks of its results against expected
#' values (added with [recrd()]), and optionally a snapshot of the
#' R
#' environment it ran in. Write it out with
#' [wrmnfjs()] and
#' [wrsmrytxt()], or hash and sign it with
#' [mnfdgst()] and
#' [cpsatst()], so a reader can later see what was
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
#' flag existed. On a synthetic manifest every [recrd()] entry is
#' \code{INFO}.
#'
#' The fields of \code{meta} that [wrsmrytxt()] reads are
#' \code{project},
#' \code{author}, \code{run_at}, \code{os}, \code{r_version} and, as a named
#' list or vector of versions, \code{r_package_versions}.
#'
#' Errors when \code{meta} is not a list. Nothing is written.
#'
#' @param meta A list of run metadata, normally named (for example
#'   \code{project}, \code{author}, \code{run_at}, \code{synthetic}). May be
#'   \code{list()}.
#' @param env Logical scalar; when \code{TRUE} (the default) the
#'   manifest also records the analysis environment via
#'   [capenv()]: R version, platform, OS,
#'   UTC timestamp, random
#'   number generator kind and whether it was seeded, and the version of
#'   every loaded package. Any other value leaves it out.
#' @return A list with elements \code{meta} (the list given, plus
#'   \code{synthetic = TRUE} when flagged), \code{results} (an empty list,
#'   filled by [recrd()]) and, when \code{environment = TRUE},
#'   \code{environment} (the list from
#'   [capenv()]).
#' @seealso [recrd()],
#'   [wrmnfjs()],
#'   [wrsmrytxt()],
#'   [mnfdgst()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Minimal manifest, no environment capture.
#' man <- mkmnf(list(project = "demo-study", author = "A. Author"),
#'   env = FALSE
#' )
#' names(man) # "meta" "results"
#' man$meta$project
#'
#' # With environment = TRUE it also records R version / platform / packages.
#' full <- mkmnf(list(project = "demo"), env = TRUE)
#' names(full) # adds "environment"
#' full$environment$r_version
#'
#' # a run on generated data is flagged, and its checks become INFO
#' syn <- mkmnf(list(project = "demo", synthetic = TRUE), env = FALSE)
#' syn$meta$synthetic
#'
#' # meta must be a list
#' try(mkmnf("demo"))
#' @export
mkmnf <- function(meta, env = TRUE) {
  if (!is.list(meta)) {
    stop("`meta` must be a list", call. = FALSE)
  }
  # the package owns the synthetic flag: set here from BRICKLAYER_SYNTHETIC
  # (the reference pipeline sets it for its analysis subprocess), so a
  # manifest written on generated data says so whatever the script did
  # the flag is written only when it is TRUE: a manifest of real data keeps
  # the digest it had before the flag existed
  if (isTRUE(meta$synthetic) || .rmbl_synthetic_flag()) {
    meta$synthetic <- TRUE
  }
  m <- list(meta = meta, results = list())
  if (isTRUE(env)) {
    m$environment <- capenv()
  }
  m
}

#' Record a Cross-Check Result in a Manifest
#'
#' Appends one named cross-check to a manifest: a number your analysis
#' produced (\code{obs}) next to the number it should reproduce
#' (\code{expd}, for example a published table value). Each entry is
#' classified \code{PASS}, \code{DIFFER} or \code{INFO}, a one-line report
#' is shown as a message, and the updated manifest is returned so calls can
#' be chained. The tallies appear in
#' [wrsmrytxt()] and the entries in
#' [wrmnfjs()].
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
#' \code{obs} and \code{expd} must be single values: a vector of
#' another length (including an empty one) is an error naming the argument;
#' record a vector's elements under separate names, or a summary of it.
#' Recording under an existing \code{name} replaces that
#' entry. The message line is a side effect; wrap the call in
#' \code{suppressMessages()} to silence it.
#'
#' @param man A manifest as returned by
#'   [mkmnf()].
#' @param name Character scalar, the name of this cross-check. It is the key
#'   of the entry in \code{manifest$results}, so it should be unique.
#' @param obs The value the analysis produced: a numeric scalar for a
#'   tolerance check, or any single value to be stored as information.
#' @param expd The value to compare against, of the same kind.
#' @param tol Numeric scalar, the absolute tolerance: a numeric pair at most
#'   \code{tol} apart is \code{PASS}. Default \code{0.0001}.
#' @param grp Character scalar, a grouping label stored with the entry (for
#'   example the table the number comes from). Default \code{"general"}.
#' @param syn Logical scalar; \code{TRUE} marks this entry \code{INFO}
#'   because a comparison on synthetic data is not meaningful. Default
#'   \code{FALSE}.
#' @return The manifest with \code{results[[name]]} set to a list with
#'   \code{group}, \code{observed}, \code{expected}, \code{diff} (the
#'   absolute difference, \code{NA} when the pair is not numeric),
#'   \code{status} (\code{"PASS"}, \code{"DIFFER"} or \code{"INFO"}),
#'   \code{tol} and \code{note} (a sentence for synthetic entries, else
#'   \code{NULL}).
#' @seealso [mkmnf()],
#'   [wrsmrytxt()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' man <- mkmnf(list(project = "demo"), env = FALSE)
#'
#' # Within tolerance -> PASS. (Every status below is INFO instead in a
#' # session that has already generated synthetic data, because mkmnf()
#' # then marks the manifest synthetic; see mkmnf().)
#' man <- recrd(man, "meanmatches",
#'   obs = 1.0001, expd = 1,
#'   tol = 0.001
#' )
#' man$results$meanmatches$status # "PASS"
#'
#' # Outside tolerance -> DIFFER.
#' man <- recrd(man, "sdmatches", obs = 2.5, expd = 2.0, tol = 0.01)
#' man$results$sdmatches$status # "DIFFER"
#'
#' # Synthetic data -> INFO (comparison not meaningful).
#' man <- recrd(man, "syntheticrow",
#'   obs = 5, expd = 5,
#'   syn = TRUE
#' )
#' man$results$syntheticrow$status # "INFO"
#'
#' # a non-numeric value is stored as information, silently
#' man <- suppressMessages(recrd(man, "country", obs = "CA", expd = "CA",
#'                                grp = "metadata"))
#' man$results$country$status # "INFO"
#'
#' # Calls chain: record() returns the mutated manifest.
#' length(man$results) # 4
#' @export
recrd <- function(
  man,
  name,
  obs,
  expd,
  tol = 0.0001,
  grp = "general",
  syn = FALSE
) {
  .rmbl_no_fn(observed = obs, expected = expd)
  if (!is.list(man) || is.data.frame(man)) {
    stop("recrd: `man` must be a manifest from mkmnf()", call. = FALSE)
  }
  name <- .rmbl_string1(name, "name")
  tol <- .rmbl_scalar(tol, "tol", 0)
  # one value each: a vector made the PASS test `diff <= tol` a vector and
  # failed in R's own words ('length = 2' in coercion to 'logical(1)')
  lens <- c(observed = length(obs), expected = length(expd))
  if (any(lens != 1L)) {
    bad <- which(lens != 1L)[1L]
    arg <- c(observed = "obs", expected = "expd", tol = "tol")
    stop(
      sprintf(
        "`%s` must be a single value, got %d",
        arg[[names(lens)[bad]]],
        lens[[bad]]
      ),
      call. = FALSE
    )
  }
  diff <- if (is.numeric(obs) && is.numeric(expd)) {
    abs(obs - expd)
  } else {
    NA_real_
  }
  # a manifest built on synthetic data makes every comparison INFO
  syn <- isTRUE(syn) || isTRUE(man$meta$synthetic)
  status <- if (syn) {
    "INFO"
  } else if (!is.na(diff) && diff <= tol) {
    "PASS"
  } else if (!is.na(diff)) {
    "DIFFER"
  } else {
    "INFO"
  }
  man$results[[name]] <- list(
    group = grp,
    observed = obs,
    expected = expd,
    diff = diff,
    status = status,
    tol = tol,
    note = if (isTRUE(syn)) {
      "synthetic data -- comparison not meaningful"
    } else {
      NULL
    }
  )
  message(sprintf(
    "  %-44s observed = %-12s expected = %-12s [%s]",
    name,
    if (is.numeric(obs)) sprintf("%.4f", obs) else as.character(obs),
    if (is.numeric(expd)) sprintf("%.4f", expd) else as.character(expd),
    status
  ))
  man
}

#' Write a Manifest to JSON
#'
#' Writes a manifest to a JSON file, so the record of a run (its metadata,
#' cross-checks and environment) can be kept next to the outputs, shared,
#' and read back by any JSON reader. By default the file is pretty-printed
#' for people; \code{canonical = TRUE} writes the byte-stable form that
#' [mnfdgst()] hashes. The package's own JSON codec
#' ([tojs()]) is used; jsonlite
#' is not needed.
#'
#' @details
#' Numbers are written with 17 significant digits, so every double reads
#' back exactly; \code{NA} and \code{NULL} are written as \code{null}, and
#' length-one vectors as scalars. When the manifest's \code{meta$synthetic}
#' is \code{TRUE}, or the session is flagged synthetic (see
#' [mkmnf()]), \code{meta$synthetic = true} is
#' written whatever the
#' list says, so a file written from generated data always says so. An
#' existing file at \code{path} is overwritten; the folder must exist.
#'
#' Errors when \code{path} is not a single non-empty string, and (from base
#' R) when the file cannot be opened for writing.
#'
#' @param man A manifest as returned by
#'   [mkmnf()] and built up
#'   with [recrd()].
#' @param path Character scalar, the destination file path.
#' @param canon Logical scalar, default \code{FALSE}. \code{TRUE} writes
#'   the canonical form instead of the pretty-printed one: one line, keys
#'   sorted, which is what [mnfdgst()] hashes. Use
#'   it when the file
#'   itself has to be byte-stable rather than read by a person.
#' @return \code{path} (character scalar), invisibly.
#' @seealso [mnfcanon()],
#'   [wrsmrytxt()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' man <- mkmnf(list(project = "demo"), env = FALSE)
#' man <- recrd(man, "rowcount", obs = 20, expd = 20)
#' path <- wrmnfjs(man, tempfile(fileext = ".json"))
#' file.exists(path)
#'
#' # Round-trips back through the package's own codec.
#' back <- fromjs(path, simplifyVector = FALSE)
#' # "PASS" ("INFO" after synthetic data, see mkmnf())
#' back$results$rowcount$status
#'
#' # the canonical form: one line whose SHA-256 is the manifest digest
#' cpath <- wrmnfjs(man, tempfile(fileext = ".json"), canon = TRUE)
#' identical(readLines(cpath), as.character(mnfcanon(man)))
#'
#' # the path must be one string
#' try(wrmnfjs(man, c("a.json", "b.json")))
#' @export
wrmnfjs <- function(man, path, canon = FALSE) {
  path <- .rmbl_string1(path, "path")
  if (!is.list(man)) {
    stop("wrmnfjs: `man` must be a manifest from mkmnf()", call. = FALSE)
  }
  # never written without the flag (see mkmnf())
  if (isTRUE(man$meta$synthetic) || .rmbl_synthetic_flag()) {
    man$meta$synthetic <- TRUE
  }
  if (isTRUE(canon)) {
    writeLines(mnfcanon(man), path, useBytes = TRUE)
    return(invisible(path))
  }
  writeLines(
    tojs(
      man,
      auto_unbox = TRUE,
      pretty = TRUE,
      na = "null",
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
#' `mnfcanon()` renders a manifest as one line of JSON with
#' every object's keys in sorted order and every number at full double
#' precision. `mnfdgst()` is the SHA-256 of those bytes.
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
#' Sign [mnfdgst()], not the pretty
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
#' Errors when \code{man} is not a list.
#'
#' @param man A manifest (a list), as from
#'   [mkmnf()]; any list
#'   is accepted.
#' @return \code{mnfcanon()}: a character scalar, the one-line
#'   JSON. \code{mnfdgst()}: a character scalar of 64 lower-case
#'   hexadecimal characters, the SHA-256 of the canonical bytes.
#' @seealso
#' [mkmnf()],
#' [wrmnfjs()],
#' [cpsatst()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' a <- mkmnf(list(b = 2, a = 1), env = FALSE)
#' b <- mkmnf(list(a = 1, b = 2), env = FALSE)
#' # the same content in a different order has the same digest
#' identical(mnfdgst(a), mnfdgst(b))
#'
#' # full precision, so a recorded number can be checked later
#' m <- mkmnf(list(x = 1 / 3), env = FALSE)
#' grepl("0.33333333333333331", mnfcanon(m), fixed = TRUE)
#'
#' # any change to a recorded value changes the digest
#' m2 <- recrd(m, "check", obs = 1, expd = 1)
#' mnfdgst(m) == mnfdgst(m2)
#'
#' # only lists can be serialised this way
#' try(mnfdgst("not a manifest"))
#' @export
mnfcanon <- function(man) {
  if (!is.list(man)) {
    stop("`man` must be a list", call. = FALSE)
  }
  # keep_empty_names: an empty-string key is written as "", not renamed to
  # its position, so two documents differing only there do not share a digest
  # keep_vec_names: a named atomic vector is an object too ({"a":1} is not
  # [1]); the names attribute, present or absent, is what tells an object
  # from an array at every level, so the encoding is one-to-one
  tojs(
    .rmbl_sort_keys(man),
    auto_unbox = TRUE,
    pretty = FALSE,
    na = "null",
    null = "null",
    digits = I(17),
    keep_empty_names = TRUE,
    keep_vec_names = TRUE,
    quiet_vec_names = TRUE
  )
}

#' @rdname mnfcanon
#' @export
mnfdgst <- function(man) {
  .rmbl_sha256_bytes(charToRaw(mnfcanon(man)))
}

#' Hashes bytes with SHA-256, natively when the compiled core is there.
#'
#' Inside the package: the compiled core; sourced standalone in a capsule
#' bundle: the pure-R implementation from sha256_native.R.
#' @param bytes A raw vector.
#' @param native Whether the compiled csha256() is used.
#' @return The hex digest.
#' @noRd
.rmbl_sha256_bytes <- function(
  bytes,
  native = exists("csha256", mode = "function")
) {
  if (native) {
    return(csha256(bytes))
  }
  .rmbl_sha256_hex(bytes)
}

#' Recursively order the names of every list, leaving unnamed lists (JSON
#' arrays, where order is content) alone.
#' @param x A parsed JSON value.
#' @return `x` with the names of every named list in sorted order.
#' @noRd
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
  # documents (the encoder writes "" as "", see mnfcanon()). That
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
    total = length(statuses),
    pass = sum(statuses == "PASS"),
    differ = sum(statuses == "DIFFER"),
    warn = sum(statuses == "WARN"),
    info = sum(statuses == "INFO")
  )
}

## ----- SUMMARY.txt -----
## `paths` is a named list: capsule, input, results, script, provenance
## `whatwasdone` is an optional character vector of bullet points

#' Write a Plain-Language Run Summary
#'
#' Writes \code{SUMMARY.txt} into an output folder: a plain-text page a
#' person can read without any software, giving the project, author, time,
#' operating system and R version of the run, whether it ran on real or
#' synthetic data, the paths it used, the tally of cross-check results, the
#' files in the folder, and optional notes, contact and licence lines. It is
#' the human-readable companion of
#' [wrmnfjs()].
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
#' The file list is \code{list.files(outdir)} at the time of the call,
#' sorted, so write the summary last. The paths are printed as given (they
#' are not made absolute). An existing \code{SUMMARY.txt} is overwritten.
#'
#' Errors when \code{man} is not a list, and (from base R) when
#' \code{outdir} does not exist or cannot be written.
#'
#' @param man A manifest as returned by
#'   [mkmnf()]; its
#'   \code{meta} supplies the header and its \code{results} the counts.
#' @param outdir Character scalar, an existing folder to write
#'   \code{SUMMARY.txt} into and to list the files of.
#' @param paths A named list (or named character vector) of paths to report,
#'   one line each, labelled by the capitalised name. Names such as
#'   \code{capsule}, \code{input}, \code{results}, \code{analysis_script} and
#'   \code{provenance} are typical. \code{list()} reports none.
#' @param whatwasdone Optional character vector, one line each, describing
#'   what the run did. Default \code{NULL} (no section).
#' @param contact Optional character scalar appended as a \code{Contact:}
#'   line. Default \code{NULL}.
#' @param lic Optional character scalar appended as a \code{Licence:}
#'   line. Default \code{NULL}.
#' @return The path to the written \code{SUMMARY.txt} (character scalar),
#'   invisibly.
#' @seealso [mkmnf()],
#'   [recrd()],
#'   [wrmnfjs()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' man <- mkmnf(list(project = "demo", author = "A. Author"),
#'   env = FALSE
#' )
#' man <- recrd(man, "rowcount", obs = 20, expd = 20)
#' out <- file.path(tempdir(), "demo-run")
#' dir.create(out, showWarnings = FALSE)
#' s <- wrsmrytxt(man, out, paths = list(results = out))
#' readLines(s)[7:8]
#'
#' # with notes, contact and licence lines
#' s <- wrsmrytxt(man, out, paths = list(results = out),
#'   whatwasdone = c("- read the extract", "- recomputed table 2"),
#'   contact = "analyst at example.org", lic = "CC BY 4.0")
#' tail(readLines(s), 6)
#'
#' # the manifest has to be a list
#' try(wrsmrytxt("demo", out, paths = list()))
#' @export
wrsmrytxt <- function(
  man,
  outdir,
  paths,
  whatwasdone = NULL,
  contact = NULL,
  lic = NULL
) {
  if (!is.list(man)) {
    stop("wrsmrytxt: `man` must be a manifest from mkmnf()", call. = FALSE)
  }
  counts <- summarise_counts(man)
  outdir <- .rmbl_string1(outdir, "outdir")
  if (!dir.exists(outdir)) {
    stop("`outdir` is not a directory: ", outdir, call. = FALSE)
  }
  for (nm in c("whatwasdone", "contact", "lic")) {
    v <- get(nm)
    if (!is.null(v) && (!is.character(v) || anyNA(v))) {
      stop(
        sprintf("`%s` must be text (a character vector), or NULL", nm),
        call. = FALSE
      )
    }
  }
  files <- sort(list.files(outdir))
  is_synth <- isTRUE(man$meta$synthetic)

  lines <- c(
    "##########################################################",
    "#                                                        #",
    "#   REPRODUCIBILITY RUN -- SUMMARY                        #",
    "#                                                        #",
    "##########################################################",
    "",
    paste0("Project:   ", man$meta$project %||% "(unnamed)"),
    paste0("Author:    ", man$meta$author %||% "(unknown)"),
    paste0(
      "When:      ",
      man$meta$run_at %||%
        format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
    ),
    paste0("OS:        ", man$meta$os %||% Sys.info()[["sysname"]]),
    paste0("R:         ", man$meta$r_version %||% R.version.string),
    paste0(
      "Mode:      ",
      if (is_synth) {
        "SYNTHETIC (not real data -- pipeline check only)"
      } else {
        "real data"
      }
    ),
    "",
    "----------------------------------------------------------",
    "  PATHS -- exact absolute locations used in this run",
    "----------------------------------------------------------"
  )
  for (nm in names(paths)) {
    lines <- c(
      lines,
      sprintf(
        "%-15s %s",
        paste0(
          toupper(substr(nm, 1, 1)),
          substr(nm, 2, nchar(nm)),
          ":"
        ),
        paths[[nm]]
      )
    )
  }
  lines <- c(
    lines,
    "",
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
  vers <- man$meta$r_package_versions
  if (!is.null(vers) && length(vers) > 0L) {
    lines <- c(
      lines,
      "",
      "----------------------------------------------------------",
      "  R PACKAGE VERSIONS USED IN THIS RUN",
      "  (reference numbers were produced on specific versions;",
      "   drift here explains most WARN/convergence differences)",
      "----------------------------------------------------------",
      sprintf(
        "  %-12s %s",
        names(vers),
        vapply(vers, function(v) as.character(v %||% "?"), character(1))
      )
    )
  }
  if (!is.null(whatwasdone)) {
    lines <- c(
      lines,
      "",
      "----------------------------------------------------------",
      "  WHAT WAS DONE",
      "----------------------------------------------------------",
      whatwasdone
    )
  }
  if (!is.null(contact)) {
    lines <- c(lines, "", paste0("Contact: ", contact))
  }
  if (!is.null(lic)) {
    lines <- c(lines, paste0("Licence: ", lic))
  }

  writeLines(lines, file.path(outdir, "SUMMARY.txt"))
  invisible(file.path(outdir, "SUMMARY.txt"))
}
