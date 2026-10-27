# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The capsule checks of `rmbl verify`, `drift` and `report` as one R call,
# cpschk(): PSI bands, the per-column drift table with the Benford screen,
# manifests against a base copy, the source cache, file:// sources, Wayback
# snapshots, explerr() notes and the footprint. Then the report it renders and
# the GitHub pieces (annotations, sticky comment body, outputs) the rmbl action
# prints.

#' Check every capsule under a folder
#'
#' @description
#' Runs the checks of the rmbl GitHub Action on every capsule (a folder
#' holding \code{data_provenance.json} or \code{capsule_bundle.json}) under
#' \code{path}: each capsule file against its JSON Schema
#' (\code{\link{schemapath}}), then \code{\link{vrfcps}} and
#' \code{\link{cpsbndlvrf}}. With \code{mode = "drift"} or
#' \code{"refresh"} each source is fetched again and compared with the pin,
#' column by column (\code{\link{cpsdrft}} and \code{\link{benfordtst}});
#' \code{"refresh"} then writes and pins new bytes. \code{rmbl verify},
#' \code{drift} and \code{report} call it. \code{format()} renders the
#' Markdown report or the JSON, and \code{\link{ghann}},
#' \code{\link{ghcmt}} and \code{\link{ghout}} the GitHub pieces.
#'
#' @details
#' Each check is one row with a severity: \code{error}, \code{drift},
#' \code{warn} or \code{note} (a note never changes a result). A capsule's
#' result is the worst severity among its failed rows, and \code{status} the
#' worst over all capsules: \code{ok}, \code{warn}, \code{drift} or
#' \code{error}. Each failed row adds a note, and one more from
#' \code{\link{explerr}} where it finds what the row means or where its
#' message is raised.
#'
#' Drift: when the fetched source's SHA-256 differs from the pin and the
#' pinned data file is a CSV, \code{cpsdrft()} runs with
#' \code{psithr = psifail}. A column is \code{drift} when \code{cpsdrft()}
#' flags it and its PSI is above \code{psifail}, and \code{warn} when it is
#' flagged below that or its PSI is above \code{psiwarn}; an added or
#' removed column is drift. New bytes whose columns all stay within the
#' bands are a note; new bytes that cannot be compared are a warning.
#'
#' Refresh: the new bytes are written as the data file and pinned in the
#' provenance as \code{\link{cpsrfrsh}} does (refused when they fail the
#' schema the provenance pins, \code{\link{valsch}}); with
#' \code{wayback = TRUE} an http(s) source is first captured with
#' \code{\link{wbsave}}. The capsule is then verified again.
#'
#' Manifests: with \code{base}, each capsule's \code{manifest.json} and
#' \code{results/manifest.json} is compared with its base copy: the base's
#' recorded results against this copy's observed values, each within the
#' base's tolerance (\code{\link{mnfrcmp}}), and the resources of the two
#' (\code{\link{mnfdiff}}). A manifest only one side has is added or
#' removed.
#'
#' Cache: a fetched source is kept in the cache folder under
#' \code{source-} and the first 16 hex digits of the SHA-256 of its URL, one
#' file per source overwritten by each fetch, and is read only when the live
#' fetch fails.
#'
#' Side effects: \code{"drift"} and \code{"refresh"} fetch each source
#' (the network for http(s) ones), as \code{snapshot = TRUE} asks the
#' Wayback Machine once per capsule (\code{\link{wbsnpurl}});
#' \code{"refresh"} writes the capsules; a cache folder is written to.
#' Errors: \code{path} is not a directory; a bad argument. A capsule whose
#' checks stop is one failed row, not an error.
#'
#' @param path Character scalar, the folder searched recursively
#'   (\code{.git} and \code{.rmbl-cache} folders skipped).
#' @param mode \code{"verify"} (the default), \code{"drift"},
#'   \code{"refresh"} or \code{"report"} (the verify checks).
#' @param key Character scalar: the shared secret of HMAC bundles, or
#'   \code{""}.
#' @param pubkey Character scalar: the public key (hex) every bundle must be
#'   signed with (for an HMAC bundle, its key id), or \code{""}.
#' @param psiwarn,psifail Non-negative numbers, \code{psiwarn} at most
#'   \code{psifail}: the PSI bands, by default 0.1 and 0.25, the bands
#'   \code{\link{drftpsi}} documents.
#' @param base \code{NULL} (no comparison); the path of one manifest file
#'   each manifest is compared with; a folder holding the base copy of the
#'   tree under \code{path} (the same relative paths); or a function that
#'   takes a manifest's path and returns the path of its base copy, or
#'   \code{NULL} when the base has none (for a git ref, write what
#'   \code{git show} prints to a file). Its \code{"label"} attribute names
#'   it in the report.
#' @param cache \code{NULL} (the default: the user cache folder,
#'   \code{tools::R_user_dir("rmoriebricklayer", "cache")}, in an
#'   interactive session, none otherwise), \code{FALSE} (none) or a folder.
#' @param allowfile \code{FALSE} (the default), \code{TRUE} to accept
#'   \code{file://} sources and local files anywhere under \code{path}, or an
#'   existing folder whose files may be sources as well. Without it a local
#'   source must be a file inside its own capsule; a fetched one is
#'   \code{https://} only (see \code{\link{cpsrfrsh}}).
#' @param snapshot Logical: look up the latest Wayback snapshot of each
#'   http(s) source, a \code{snapshot} row (a note).
#' @param wayback Logical: with \code{"refresh"}, capture each changed
#'   http(s) source in the Wayback Machine first (archive.org keys, as
#'   \code{wbsave()} reads them).
#' @param archive Logical: use archive.rmorie.com when a source cannot be
#'   fetched. In \code{"drift"} and \code{"refresh"}, a source that neither
#'   answers nor has its pinned Wayback snapshot is fetched from a copy kept
#'   there with the pinned SHA-256 (public copies need no key); with
#'   \code{wayback = TRUE}, a changed source the Wayback Machine refuses is
#'   saved there instead (\code{wbsave(fallback = "rmorie")}, which needs a
#'   key: \code{dlogin()} or \env{MORIE_HOSTED_KEY}).
#' @param glob Character scalar: check only the capsule files whose path
#'   matches this glob (\code{*} also matches \code{/}), or \code{""}.
#' @param fp Logical: measure the footprint of the checks
#'   (\code{\link{co2fp}}) for the last lines of the report.
#' @param seenlog Character scalar: an XMSS seen-log (\code{\link{xmssidxseen}};
#'   \code{rmbl verify --seen-log}) read with the bundles under \code{path},
#'   or \code{""}. Every XMSS bundle gets an \code{xmss_index} row, failed
#'   when the same key signed its index with another signature in what was
#'   seen.
#' @param x An \code{rmbl_cpschk} result.
#' @param fmt \code{"md"} (the Markdown report), \code{"json"} or
#'   \code{"text"} (the console summary \code{print()} draws as a box).
#' @param failon Character scalar or \code{NULL}: the fail-on level, named
#'   in the report's last line.
#' @param ... Further arguments of \code{format()} and \code{print()}, ignored.
#' @return A list of class \code{rmbl_cpschk}: \code{status},
#'   \code{mode}, \code{path}, \code{glob}, \code{rows} (a data frame of
#'   every check: \code{capsule}, \code{part}, \code{file}, \code{check},
#'   \code{ok}, \code{detail}, \code{severity} and \code{line}, the line
#'   of the file where known), \code{capsules} (a list per capsule:
#'   \code{capsule}, \code{source}, \code{pinned_sha256},
#'   \code{fetched_sha256}, \code{changed}, \code{result},
#'   \code{checks_passed}, \code{checks_total} and \code{notes}, and where
#'   made \code{drift} with its \code{columns} table,
#'   \code{drift_summary}, \code{snapshot}, \code{snapshot_utc} and
#'   \code{manifests}), \code{base} (its label), \code{psiwarn},
#'   \code{psifail} and \code{footprint} (the \code{co2fp()} result
#'   without its value, or \code{NULL}). The \code{cpsdrft()} result
#'   of each capsule whose columns were compared, with its provenance and
#'   manifest diff, is in the attribute \code{drifts} (named by capsule),
#'   for \code{\link{drfthtml}} and \code{\link{drftapp}}.
#'   \code{format()} returns one string (\code{"md"}, \code{"json"}) or
#'   the lines of the console summary (\code{"text"}); \code{print()}
#'   draws that summary as a box.
#' @seealso \code{\link{blcli}} (the verbs), \code{\link{ghann}},
#'   \code{\link{cpsrfrsh}}, \code{\link{explerr}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' root <- tempfile("capsules-")
#' d <- usecpstmpl(file.path(root, "one"), ex = TRUE)
#' invisible(cpsrfrsh(d))
#' x <- cpschk(root, fp = FALSE)
#' x$status
#' x$rows[, c("check", "ok")]
#' x
#'
#' # the data changed: the digest row fails, and the notes say what it means
#' p <- loadprov(file.path(d, "data_provenance.json"))
#' cat("1,2\n", file = file.path(d, p$resource$filename), append = TRUE)
#' x <- cpschk(root, fp = FALSE)
#' x$status
#' x$capsules[[1]]$notes
#' substr(format(x, fmt = "json"), 1, 120)
#'
#' # drift: fetch the source again (here a local file) and compare
#' cpschk(root, "drift", psiwarn = 0.05, fp = FALSE)$status
#'
#' try(cpschk(tempfile()))
#' try(cpschk(root, psiwarn = 1))
#' @srrstats {G2.0} `path` must be one existing directory, `key`, `pubkey`
#'   and `glob` single strings, the PSI bands single non-negative numbers in
#'   order, the flags single logicals (test-capsule_check.R).
#' @srrstats {G2.3a} `mode` is matched against its four values with .rmbl_arg()
#'   (test-capsule_check.R).
#' @export
cpschk <- function(
  path = ".",
  mode = c("verify", "drift", "refresh", "report"),
  key = "",
  pubkey = "",
  psiwarn = 0.1,
  psifail = 0.25,
  base = NULL,
  cache = NULL,
  allowfile = FALSE,
  snapshot = FALSE,
  wayback = FALSE,
  glob = "",
  fp = TRUE,
  seenlog = "",
  archive = FALSE
) {
  path <- .rmbl_string1(path, "path")
  if (!dir.exists(path)) {
    stop(
      .rmbl_fn(),
      "`path` is not an existing directory: ",
      .rmbl_printable(path),
      call. = FALSE
    )
  }
  o <- .bl_cpschk_opts(
    list(path = path, mode = .rmbl_arg(mode)),
    key,
    pubkey,
    psiwarn,
    psifail,
    base,
    list(allowfile = allowfile, snapshot = snapshot, wayback = wayback),
    archive
  )
  glob <- .bl_str0(glob, "glob")
  fp <- .rmbl_flag1(fp, "fp")
  o$cache <- .bl_cache_arg(cache)
  seenlog <- .bl_str0(seenlog, "seenlog")
  # every XMSS signature under the path and in the log, for the index-reuse row
  # of each bundle
  o$seen <- xmssidxseen(path, if (nzchar(seenlog)) seenlog)
  dirs <- .bl_capsule_dirs(path, glob)
  foot <- if (fp) co2fp(.bl_cpschk_run(dirs, o))
  caps <- lapply(
    if (fp) foot$value else .bl_cpschk_run(dirs, o),
    .bl_cps_finish
  )
  .bl_cpschk_result(o, glob, caps, base, foot[names(foot) != "value"])
}

#' @rdname cpschk
#' @export
format.rmbl_cpschk <- function(
  x,
  fmt = c("md", "json", "text"),
  failon = NULL,
  ...
) {
  fmt <- .rmbl_arg(fmt)
  if (fmt == "md") {
    return(.bl_cpschk_md(x, failon))
  }
  if (fmt == "text") {
    return(.bl_cpschk_text(x))
  }
  caps <- lapply(x$capsules, function(cp) {
    if (is.null(cp$manifests)) {
      return(cp)
    }
    cp$manifests <- lapply(cp$manifests, function(m) {
      m$resources <- if (NROW(m$resources)) {
        as.data.frame(unclass(m$resources), stringsAsFactors = FALSE)
      }
      m
    })
    cp
  })
  paste0(
    tojs(
      list(
        status = x$status,
        mode = x$mode,
        path = x$path,
        capsules = caps,
        checks = x$rows
      ),
      auto_unbox = TRUE,
      pretty = TRUE,
      null = "null",
      digits = NA
    ),
    "\n"
  )
}

#' @rdname cpschk
#' @export
print.rmbl_cpschk <- function(x, ...) {
  rows <- x$rows
  verdict <- if (length(x$capsules)) {
    list(
      ok = identical(x$status, "ok"),
      checks = data.frame(ok = rows$ok | rows$severity == "note")
    )
  }
  .rmbl_cat(format(x, fmt = "text"), verdict)
  invisible(x)
}

# ---- GitHub-flavoured output: plain text the caller prints; nothing here calls
# GitHub ---

#' GitHub workflow annotations, sticky comment and outputs of a capsule check
#'
#' @description
#' Plain text for a GitHub Actions step, from a \code{\link{cpschk}}
#' result: nothing here talks to GitHub, the caller prints or posts it.
#' \code{ghann()} gives one workflow command per failed check, an
#' \code{::error} for an error row and a \code{::warning} for a warn or
#' drift row (notes give none), naming the file and, where the row has
#' one, the line, with the data and properties escaped as GitHub requires.
#' \code{ghcmt()} gives the body of a sticky pull-request comment: the
#' marker line that finds it again, the Markdown report and a link to the
#' run, cut to fit GitHub's 65,536-character limit. \code{ghout()} gives
#' the step outputs of the rmbl action as a named list (print each as
#' \code{name=value} to \code{$GITHUB_OUTPUT}).
#'
#' @param runurl Character scalar or \code{NULL}: the run's address, linked
#'   at the end of the comment.
#' @param marker Character scalar, the comment's first line (an HTML
#'   comment, invisible on GitHub).
#' @param limit Integer: the longest body; a longer one is cut and says so.
#' @param report,json Character scalars: the paths of the report and the
#'   JSON written, passed through as outputs.
#' @param comment Character scalar: what became of the comment
#'   (\code{off}, \code{dry-run}, \code{skipped}, \code{created},
#'   \code{updated} or \code{failed}), passed through.
#' @return \code{ghann()}: a character vector, one line per annotation.
#'   \code{ghcmt()}: one string. \code{ghout()}: a named list with
#'   \code{status}, \code{report}, \code{json}, \code{changed} (the
#'   capsules whose source bytes changed, comma-separated),
#'   \code{verified} (capsules without an error), \code{failed},
#'   \code{manifest-changed} (\code{"true"} or \code{"false"}) and
#'   \code{comment}. Error: \code{x} is not a \code{cpschk()} result.
#' @seealso \code{\link{cpschk}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' root <- tempfile("capsules-")
#' d <- usecpstmpl(file.path(root, "one"), ex = TRUE)
#' invisible(cpsrfrsh(d))
#' p <- loadprov(file.path(d, "data_provenance.json"))
#' cat("1,2\n", file = file.path(d, p$resource$filename), append = TRUE)
#' x <- cpschk(root, fp = FALSE)
#' ghann(x)
#' substr(ghcmt(x, runurl = "https://github.com/o/r/actions/runs/1"), 1, 80)
#' str(ghout(x, report = "rmbl-report.md", json = "rmbl-results.json"))
#'
#' # one output per line, as $GITHUB_OUTPUT takes them
#' o <- ghout(x)
#' cat(sprintf("%s=%s\n", names(o), unlist(o)), sep = "")
#'
#' try(ghann(list()))
#' @export
#' @inheritParams cpschk
ghann <- function(x) {
  .bl_is_cpschk(x)
  bad <- x$rows[!x$rows$ok & x$rows$severity != "note", , drop = FALSE]
  dat <- function(s) {
    gsub(
      "\n",
      "%0A",
      gsub("\r", "%0D", gsub("%", "%25", s, fixed = TRUE), fixed = TRUE),
      fixed = TRUE
    )
  }
  prop <- function(s) {
    gsub(",", "%2C", gsub(":", "%3A", dat(s), fixed = TRUE), fixed = TRUE)
  }
  sprintf(
    "::%s file=%s%s,title=%s::%s",
    ifelse(bad$severity == "error", "error", "warning"),
    prop(bad$file),
    ifelse(is.na(bad$line), "", paste0(",line=", bad$line)),
    prop(paste("rmbl", bad$part, bad$check)),
    dat(bad$detail)
  )
}

#' @rdname ghann
#' @export
ghcmt <- function(
  x,
  runurl = NULL,
  failon = NULL,
  marker = "<!-- rmbl-action -->",
  limit = 65000L
) {
  .bl_is_cpschk(x)
  marker <- .rmbl_string1(marker, "marker")
  limit <- .rmbl_scalar(limit, "limit", 100, integer = TRUE)
  if (!is.null(runurl)) {
    runurl <- .rmbl_string1(runurl, "runurl")
  }
  body <- paste(
    c(
      marker,
      format(x, failon = failon),
      if (!is.null(runurl)) {
        sprintf("[The run, with this report in its job summary](%s)", runurl)
      }
    ),
    collapse = "\n"
  )
  if (nchar(body) <= limit) {
    return(body)
  }
  paste0(
    substr(body, 1L, limit),
    "\n\n(report cut to fit a comment; the full one is in the job summary",
    if (!is.null(runurl)) paste0(": ", runurl),
    ")"
  )
}

#' @rdname ghann
#' @export
ghout <- function(x, report = "", json = "", comment = "off") {
  .bl_is_cpschk(x)
  # one of the documented outcomes: "bogus" was passed through to the action
  cm <- c("off", "dry-run", "skipped", "created", "updated", "failed")
  if (!.bl_str0(comment, "comment") %in% cm) {
    stop(
      .rmbl_fn(),
      "`comment` must be one of ",
      paste0("\"", cm, "\"", collapse = ", "),
      call. = FALSE
    )
  }
  st <- vapply(x$capsules, `[[`, "", "result")
  ms <- unlist(lapply(x$capsules, `[[`, "manifests"), recursive = FALSE)
  changed <- vapply(
    Filter(function(cp) isTRUE(cp$changed), x$capsules),
    `[[`,
    "",
    "capsule"
  )
  list(
    status = x$status,
    report = .bl_str0(report, "report"),
    json = .bl_str0(json, "json"),
    changed = paste(changed, collapse = ","),
    verified = sum(st != "error"),
    failed = sum(st == "error"),
    `manifest-changed` = tolower(any(vapply(
      ms,
      function(m) isTRUE(m$changed),
      NA
    ))),
    comment = .bl_str0(comment, "comment")
  )
}

#' Pin and sign every capsule under a folder
#'
#' @description
#' Seals each capsule (a folder holding \code{data_provenance.json}) under
#' \code{path}, so that a program in any language only has to write the
#' data file and a plain provenance naming it
#' (\code{{"resource": {"filename": "data.csv"}}}): on its first run the
#' provenance is pinned to the data file's bytes as \code{\link{cpsrfrsh}}
#' pins it (\code{resource$sha256}, \code{size_bytes},
#' \code{retrieved_utc}, the row count when one is recorded), then
#' \code{\link{cpsbndl}} signs every file of the capsule into
#' \code{capsule_bundle.json}, over its \code{manifest.json} when it has
#' one. \code{rmbl sign} calls it and then verifies (\code{\link{cpschk}}).
#'
#' @details
#' A provenance already pinned (one with \code{resource$sha256}) is left as
#' it is. Side effects: writes \code{data_provenance.json} (first run) and
#' \code{capsule_bundle.json} in each capsule. Errors, before anything is
#' written: no provenance under \code{path}; a capsule that already has a
#' bundle, unless \code{overwrite}; then, per capsule, a
#' \code{resource$filename} that is not a plain relative path to a file in
#' the capsule, and the refusals of \code{cpsbndl()} (a key it cannot sign
#' with).
#'
#' @param path Character scalar, the folder searched recursively.
#' @param key The signing key, as \code{cpsbndl()} takes it: a shared
#'   secret (a string or raw vector) for an \code{"hmac"} bundle, or a key
#'   from \code{\link{fipskg}} or \code{\link{fipskey}}, or an XMSS key
#'   from \code{\link{pqckg}}, which signs one capsule after another at
#'   consecutive indices (each reserved as \code{\link{cpssign}} reserves it).
#' @param overwrite Logical: sign a capsule that already has a bundle again.
#' @param glob Character scalar: only the provenance files whose path
#'   matches this glob (\code{*} also matches \code{/}), or \code{""}.
#' @return A data frame, one row per capsule: \code{capsule},
#'   \code{pinned} (whether the provenance was pinned now), \code{files}
#'   (the number signed) and \code{public} (the HMAC key id or the public
#'   key; never the secret).
#' @seealso \code{\link{cpsbndl}}, \code{\link{cpschk}},
#'   \code{\link{blcli}} (\code{rmbl sign}).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' root <- tempfile("capsules-")
#' d <- file.path(root, "one")
#' dir.create(d, recursive = TRUE)
#' utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"),
#'                  row.names = FALSE)
#' writeLines('{"resource": {"filename": "data.csv"}}',
#'            file.path(d, "data_provenance.json"))
#' s <- cpsseal(root, "a shared secret")
#' s
#' cpschk(root, key = "a shared secret", fp = FALSE)$status
#'
#' # a second run needs overwrite, and a post-quantum key signs too
#' try(cpsseal(root, "a shared secret"))
#' cpsseal(root, fipskg("ML-DSA-44"), overwrite = TRUE)$pinned
#' @srrstats {G2.0} `path` must be one existing directory, `overwrite` one
#'   logical and `glob` one string; the key is checked by cpsbndl()
#'   (test-capsule_check.R).
#' @export
cpsseal <- function(path = ".", key, overwrite = FALSE, glob = "") {
  dirs <- .bl_seal_dirs(path, overwrite, glob)
  rows <- list()
  for (d in dirs) {
    pf <- file.path(d, "data_provenance.json")
    prov <- loadprov(pf)
    pinned <- is.null(prov[["resource"]][["sha256"]])
    if (pinned) {
      fn <- .bl_s1(prov[["resource"]][["filename"]])
      df <- .rmbl_safe_rel(fn, d)
      if (is.null(df) || !file.exists(df) || dir.exists(df)) {
        stop(
          .rmbl_fn(),
          pf,
          ": resource$filename must name the data file, relative to the ",
          "capsule",
          call. = FALSE
        )
      }
      writeLines(
        tojs(
          .bl_pin(prov, df, fn),
          auto_unbox = TRUE,
          pretty = TRUE,
          null = "null",
          digits = NA
        ),
        pf
      )
    }
    mf <- file.path(d, "manifest.json")
    b <- cpsbndl(
      d,
      if (file.exists(mf)) loadprov(mf) else mkmnf(list(), env = FALSE),
      key
    )
    # an XMSS key moves past the index it just signed with, for the next capsule
    if (inherits(key, "bricklayer_signing_key")) {
      key$next_index <- b$attestation$signature$index + 1L
    }
    rows[[length(rows) + 1L]] <- data.frame(
      capsule = d,
      pinned = pinned,
      files = length(b$files),
      public = b$attestation$public,
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, rows)
}

#' The console summary of a capsule check: one titled block.
#' @param x An rmbl_cpschk result.
#' @return Lines.
#' @noRd
.bl_cpschk_text <- function(x) {
  caps <- x$capsules
  rows <- x$rows
  .an_block(
    sprintf("Capsule check (%s)", x$mode),
    facts = list(
      Status = x$status,
      Path = x$path,
      Glob = if (nzchar(x$glob %||% "")) x$glob,
      Capsules = length(caps),
      Checks = sprintf("%d of %d passed", sum(rows$ok), nrow(rows)),
      Footprint = if (length(x$footprint$co2eg)) {
        sprintf("%s g CO2e", .rmbl_fmt_num(x$footprint$co2eg, 3L))
      },
      Checked = sprintf(
        "rmoriebricklayer %s, %s",
        as.character(utils::packageVersion("rmoriebricklayer")),
        R.version.string
      )
    ),
    tables = list(.bl_cpschk_captab(caps)),
    reading = .bl_cpschk_reading(x, caps),
    notes = c(
      .bl_cpschk_rowlines(x),
      .bl_cpschk_footline(x$footprint)
    )
  )
}

#' One row per capsule of a capsule check: its result, its checks and what
#' its provenance pins (source, digest, size, rows, rounding bounds).
#' @param caps The capsules of an rmbl_cpschk result.
#' @return A data frame, or NULL for no capsules.
#' @noRd
.bl_cpschk_captab <- function(caps) {
  if (!length(caps)) {
    return(NULL)
  }
  num <- function(nm) {
    vapply(caps, function(cp) as.numeric(cp[[nm]] %||% NA), 1)
  }
  info <- lapply(caps, function(cp) .bl_capsule_info(cp$capsule %||% ""))
  pick <- function(k) vapply(info, function(i) as.character(i[[k]]), "")
  data.frame(
    capsule = vapply(caps, function(cp) basename(cp$capsule %||% ""), ""),
    result = vapply(caps, function(cp) cp$result %||% "", ""),
    passed = num("checks_passed"),
    checks = num("checks_total"),
    source = pick("host"),
    sha256 = pick("sha"),
    size = pick("size"),
    rows = pick("rows"),
    bounds = pick("bounds"),
    stringsAsFactors = FALSE
  )
}

#' Every check row of a capsule check, under a line per capsule naming its
#' source and pinned digest; at most 60 rows, then a pointer to format().
#' @param x An rmbl_cpschk result.
#' @return Lines.
#' @noRd
.bl_cpschk_rowlines <- function(x) {
  rows <- x$rows
  if (!NROW(rows)) {
    return(NULL)
  }
  shown <- 0L
  out <- character()
  for (cp in x$capsules) {
    ck <- rows[rows$capsule == cp$capsule, , drop = FALSE]
    take <- utils::head(ck, max(0L, 60L - shown))
    shown <- shown + nrow(take)
    out <- c(out, "", .bl_cpschk_caphead(cp), .rmbl_check_lines(take))
  }
  if (shown < nrow(rows)) {
    out <- c(out, sprintf("... and %d more rows", nrow(rows) - shown))
  }
  c(out[-1L], "format(x) gives the full Markdown report.")
}

#' The line above a capsule's check rows: its name, result, source and the
#' digest pinned (and fetched, in drift mode).
#' @param cp One capsule of an rmbl_cpschk result.
#' @return Lines.
#' @noRd
.bl_cpschk_caphead <- function(cp) {
  s <- function(v) {
    v <- as.character(v %||% "")
    if (length(v) && !is.na(v[1L]) && nzchar(v[1L])) v[1L]
  }
  c(
    sprintf("%s: %s", cp$capsule %||% "", cp$result %||% ""),
    if (!is.null(s(cp$source))) paste("  source:", s(cp$source)),
    if (!is.null(s(cp$pinned_sha256))) {
      paste("  pinned SHA-256:", s(cp$pinned_sha256))
    },
    if (!is.null(s(cp$fetched_sha256))) {
      paste("  fetched SHA-256:", s(cp$fetched_sha256))
    }
  )
}

#' The footprint of a capsule check as one plain line, as the Markdown
#' report gives it.
#' @param f The checks' co2fp() footprint, or NULL.
#' @return One line, or NULL.
#' @noRd
.bl_cpschk_footline <- function(f) {
  if (is.null(f)) {
    return(NULL)
  }
  md <- .bl_md_footprint(f)
  md[length(md)]
}

#' The reading of a capsule check's summary.
#' @param x An rmbl_cpschk result.
#' @param caps Its capsules.
#' @return One or two strings.
#' @noRd
.bl_cpschk_reading <- function(x, caps) {
  if (!length(caps)) {
    return(sprintf("No manifests were found under %s.", x$path))
  }
  switch(
    x$status,
    ok = "Every capsule is still the one its analysis was run on.",
    warn = "The capsules hold, with warnings worth a look below.",
    drift = "A source has moved since it was pinned: see the rows below.",
    "At least one capsule fails: its data or records changed since pinning."
  )
}

#' A single string argument that may be empty.
#' @param x The string to check; \code{""} stands for none.
#' @param what The argument's name.
#' @return The string.
#' @noRd
.bl_str0 <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a single string (\"\" for none)", what),
      call. = FALSE
    )
  }
  x
}

#' The first value of a JSON field as a string, or NULL.
#' @param v The JSON field, unlisted; its first non-missing value is kept.
#' @return A string or NULL.
#' @noRd
.bl_s1 <- function(v) {
  v <- unlist(v)
  if (length(v) && !is.na(v[[1L]])) as.character(v[[1L]])
}

#' The `base` argument of cpschk(): NULL, a function, or an existing file or
#' folder.
#' @param base The value.
#' @return The value.
#' @noRd
.bl_base_arg <- function(base) {
  if (is.null(base) || is.function(base)) {
    return(base)
  }
  base <- .rmbl_string1(base, "base")
  if (!file.exists(base)) {
    stop(
      .rmbl_fn(),
      "`base` is not an existing manifest file or folder: ",
      .rmbl_printable(base),
      call. = FALSE
    )
  }
  base
}

#' The cache folder when no `cache` is given: the user cache in an interactive
#' session, else none.
#' @return A folder or FALSE.
#' @noRd
.bl_default_cache <- function() {
  if (.bl_interactive()) {
    tools::R_user_dir("rmoriebricklayer", "cache")
  } else {
    FALSE
  }
}

#' The `cache` argument of cpschk(), the folder created.
#' @param cache NULL, FALSE or a folder.
#' @return The folder, or NULL for none.
#' @noRd
.bl_cache_arg <- function(cache) {
  if (is.null(cache)) {
    cache <- .bl_default_cache()
  }
  if (isFALSE(cache)) {
    return(NULL)
  }
  cache <- .rmbl_string1(cache, "cache")
  dir.create(cache, showWarnings = FALSE, recursive = TRUE)
  cache
}

#' The checks of one capsule: verify rows, the snapshot, drift and refresh, the
#' manifests.
#' @param d The capsule directory, checked for verify, drift and refresh.
#' @param o The options of cpschk().
#' @return A list: the capsule's fields and `rows`.
#' @noRd
.bl_cpschk_one <- function(d, o) {
  pf <- file.path(d, "data_provenance.json")
  prov <- if (file.exists(pf)) tryCatch(loadprov(pf), error = function(e) NULL)
  src <- .bl_s1(prov[["resource"]][["direct_url"]]) %||%
    .bl_s1(prov[["source"]][["url"]]) %||%
    ""
  cap <- list(
    capsule = d,
    source = src,
    pinned_sha256 = .bl_s1(prov[["resource"]][["sha256"]]) %||% "",
    fetched_sha256 = "",
    changed = FALSE,
    rows = .bl_verify_capsule(d, o$key, o$pubkey, seen = o$seen)
  )
  if (o$snapshot && !is.null(prov)) {
    s <- .bl_snapshot(src)
    cap$snapshot <- s$url
    cap$snapshot_utc <- s$utc
    cap$rows <- rbind(
      cap$rows,
      .bl_check_row(d, "source", pf, "snapshot", s$ok, s$detail, "note")
    )
  }
  if (o$mode %in% c("drift", "refresh") && !is.null(prov)) {
    dr <- .bl_drift_capsule(d, o)
    cap$rows <- rbind(cap$rows, dr$rows)
    for (nm in setdiff(names(dr), "rows")) {
      cap[[nm]] <- dr[[nm]]
    }
  }
  if (!is.null(o$base)) {
    cap$manifests <- .bl_manifests_vs_base(d, o)
  }
  cap
}

#' The latest Wayback snapshot of an http(s) source.
#' @param src The source URL.
#' @return A list: ok, url, utc and detail.
#' @noRd
.bl_snapshot <- function(src) {
  none <- list(
    ok = FALSE,
    url = "",
    utc = "",
    detail = "not looked up (not an http(s) source)"
  )
  if (!grepl("^https?://", src)) {
    return(none)
  }
  s <- tryCatch(wbsnpurl(src), error = function(e) NULL)
  if (is.null(s)) {
    return(utils::modifyList(
      none,
      list(detail = "none found (or the archive could not be reached)")
    ))
  }
  ts <- regmatches(s, regexpr("(?<=/web/)[0-9]{14}", s, perl = TRUE))
  utc <- if (length(ts)) {
    format(
      as.POSIXct(ts, format = "%Y%m%d%H%M%S", tz = "UTC"),
      "%Y-%m-%dT%H:%M:%SZ"
    )
  } else {
    ""
  }
  list(ok = TRUE, url = s, utc = utc, detail = sprintf("%s (%s)", s, utc))
}

#' The drift rows of one capsule: the source fetched again and compared with the
#' pin.
#'
#' A changed digest is a warning when the columns cannot be compared, and a note
#' when they are: then the columns decide (.bl_column_drift()). In refresh mode
#' the new bytes are then pinned.
#' @param d The capsule directory whose source is fetched again.
#' @param o The options of cpschk().
#' @return A list: `rows`, and the capsule fields found (fetched_sha256,
#'   changed, drift, drift_summary, notes).
#' @noRd
.bl_drift_capsule <- function(d, o) {
  pf <- file.path(d, "data_provenance.json")
  f <- tryCatch(
    .bl_fetch_pin(
      d,
      o$allowfile,
      o$cache,
      root = o$path,
      archive = isTRUE(o$archive)
    ),
    error = function(e) e
  )
  if (inherits(f, "error")) {
    return(list(rows = .bl_drift_fail(d, pf, "source_fetched", f)))
  }
  on.exit(.bl_fetch_cleanup(f), add = TRUE)
  out <- list(
    notes = .bl_cps_drift_note(f),
    fetched_sha256 = f$new$resource$sha256
  )
  diff <- mnfdiff(f$old, f$new)
  ch <- diff[diff$change != "unchanged", , drop = FALSE]
  out$changed <- nrow(ch) > 0L
  cmp <- .bl_drift_columns(d, f, ch, o)
  if (inherits(cmp, "error")) {
    return(c(out, list(rows = .bl_drift_fail(d, pf, "source_columns", cmp))))
  }
  if (!is.null(cmp)) {
    cmp$object$provenance <- f$old
    cmp$object$manifest <- diff
  }
  out <- .bl_drift_rows(out, d, pf, diff, ch, cmp)
  if (o$mode == "refresh" && nrow(ch)) {
    out <- .bl_refresh_capsule(d, f, o, out)
  }
  out
}

#' The per-column drift of a fetched CSV against the pinned one, in the PSI
#' bands, with Benford.
#' @param local The pinned data file.
#' @param got The fetched file.
#' @param o The options of cpschk().
#' @return NULL when either file does not read as a CSV, else a list: verdict,
#'   summary, the counts and `columns`, cpsdrft()'s table with band, verdict and
#'   the Benford p-values of both files.
#' @noRd
.bl_column_drift <- function(local, got, o) {
  ref <- .bl_read_csv_capped(local)
  cur <- .bl_read_csv_capped(got)
  if (is.null(ref) || is.null(cur)) {
    return(NULL)
  }
  dr <- cpsdrft(ref, cur, psithr = o$psifail)
  dr$bands <- c(warn = o$psiwarn, fail = o$psifail)
  # the tables themselves, for drftapp(): the fetched file is deleted when the
  # check ends
  attr(dr, "data") <- list(ref = ref, cur = cur)
  cols <- dr$columns
  cols$band <- .bl_psi_band(cols$psi, o$psiwarn, o$psifail)
  cols$verdict <- .bl_col_verdict(
    cols$drifted & !is.na(cols$drifted),
    cols$band
  )
  # the Benford first-digit screen of each numeric column, pinned and new
  cols$benford_ref <- vapply(
    cols$column,
    function(nm) .bl_benford_p(ref[[nm]]),
    0,
    USE.NAMES = FALSE
  )
  cols$benford_cur <- vapply(
    cols$column,
    function(nm) .bl_benford_p(cur[[nm]]),
    0,
    USE.NAMES = FALSE
  )
  list(
    verdict = .bl_cps_drift_verdict(cols, dr),
    summary = .bl_drift_summary(cols, dr),
    any = isTRUE(dr$anydrft),
    nref = dr$nref,
    ncur = dr$ncur,
    alpha = dr$alpha,
    added = as.list(dr$added),
    removed = as.list(dr$removed),
    psiwarn = o$psiwarn,
    psifail = o$psifail,
    columns = cols,
    object = dr
  )
}

#' Pins the new bytes of a capsule whose source changed (refresh mode), then
#' verifies it again.
#' @param d The capsule directory the changed source's bytes are pinned in.
#' @param f From .bl_fetch_pin().
#' @param o The options of cpschk().
#' @param out The drift result so far.
#' @return `out` with the refresh rows and notes added.
#' @noRd
.bl_refresh_capsule <- function(d, f, o, out) {
  pf <- file.path(d, "data_provenance.json")
  if (o$wayback && grepl("^https?://", f$src)) {
    wf <- .bl_refresh_wayback(d, f, o, out)
    f <- wf$f
    out <- wf$out
  }
  w <- tryCatch(.bl_write_pin(d, f), error = function(e) e)
  if (inherits(w, "error")) {
    out$rows <- rbind(
      out$rows,
      .bl_check_row(d, "refresh", pf, "refreshed", FALSE, conditionMessage(w))
    )
    return(out)
  }
  out$notes <- c(
    out$notes,
    "refreshed: new data and provenance written to the workspace",
    if (file.exists(file.path(d, "capsule_bundle.json"))) {
      paste0(
        "capsule_bundle.json no longer matches the data: sign it again ",
        "with cpsbndl()"
      )
    }
  )
  out$rows <- rbind(
    out$rows,
    .bl_result_rows(vrfcps(d), d, "after refresh", pf)
  )
  out
}

#' The manifests of one capsule against their base copies.
#' @param d The capsule directory whose manifests are compared with the base.
#' @param o The options of cpschk().
#' @return A list, one element per manifest either side has.
#' @noRd
.bl_manifests_vs_base <- function(d, o) {
  out <- list()
  for (r in c("manifest.json", file.path("results", "manifest.json"))) {
    m <- file.path(d, r)
    b <- .bl_base_copy(m, file.path(.bl_rel_dir(d, o$path), r), o)
    if (file.exists(m) || !is.null(b)) {
      out[[length(out) + 1L]] <- .bl_manifest_vs(m, b)
    }
  }
  out
}

#' A capsule directory relative to the folder searched, \code{"/"} separated on
#' every system.
#' @param d The capsule directory (under `root`).
#' @param root The folder searched.
#' @return The relative path, \code{"."} for the folder itself.
#' @noRd
.bl_rel_dir <- function(d, root) {
  a <- normalizePath(d, winslash = "/")
  r <- sub("/+$", "", normalizePath(root, winslash = "/"))
  if (a == r) "." else substring(a, nchar(r) + 2L)
}

#' The base copy of one manifest, as `base` locates it.
#' @param m The manifest's path (it may not exist).
#' @param rel Its path relative to the folder searched.
#' @param o The options of cpschk().
#' @return The path of an existing base copy, or NULL.
#' @noRd
.bl_base_copy <- function(m, rel, o) {
  b <- o$base
  p <- if (is.function(b)) {
    b(m)
  } else if (dir.exists(b)) {
    file.path(b, rel)
  } else if (file.exists(m)) {
    b # one manifest file pairs with every manifest present
  }
  if (!is.null(p) && file.exists(p)) p
}

#' One manifest against its base copy: results through mnfrcmp(), resources
#' through mnfdiff().
#' @param m The manifest's path.
#' @param b The base copy's path, or NULL.
#' @return A list: path, state, changed, and when compared results, removed and
#'   resources.
#' @noRd
.bl_manifest_vs <- function(m, b) {
  if (is.null(b)) {
    return(list(path = m, state = "added", changed = TRUE))
  }
  if (!file.exists(m)) {
    return(list(path = m, state = "removed", changed = TRUE))
  }
  base <- loadprov(b)
  pr <- loadprov(m)
  res <- mnfdiff(base, pr)
  res <- res[res$change != "unchanged", , drop = FALSE]
  if (!length(pr$results)) {
    return(list(
      path = m,
      state = "no results",
      changed = length(base$results) > 0L || nrow(res) > 0L,
      resources = res
    ))
  }
  # the base copy is the record; this copy's observed values are what is
  # "recomputed"
  stats <- lapply(pr$results, function(r) {
    v <- r$observed
    function(z) v
  })
  cmp <- tryCatch(mnfrcmp(base, NULL, stats), error = function(e) e)
  if (inherits(cmp, "error")) {
    return(list(
      path = m,
      state = paste("not compared:", conditionMessage(cmp)),
      changed = TRUE,
      resources = res
    ))
  }
  list(
    path = m,
    state = "compared",
    changed = !isTRUE(cmp$ok) || nrow(res) > 0L,
    results = cmp$results,
    removed = as.list(cmp$unchecked),
    resources = res
  )
}

#' A capsule's result, counts and notes from its rows.
#' @param cap From .bl_cpschk_one().
#' @return `cap` with result, checks_passed, checks_total and notes.
#' @noRd
.bl_cps_finish <- function(cap) {
  ck <- cap$rows
  counted <- ck$severity != "note"
  bad <- ck[!ck$ok, , drop = FALSE]
  cap$result <- .bl_worst(bad$severity)
  cap$checks_passed <- sum(ck$ok & counted)
  cap$checks_total <- sum(counted)
  lbl <- paste0(
    ifelse(
      bad$part %in% c("bundle", "after refresh"),
      paste0(bad$part, " "),
      ""
    ),
    bad$check
  )
  rn <- lapply(seq_len(nrow(bad)), function(i) {
    c(
      paste0(lbl[i], ": ", bad$detail[i]),
      if (bad$severity[i] != "note") {
        .bl_explain_note(bad$check[i], bad$detail[i])
      }
    )
  })
  cap$notes <- as.list(c(unlist(rn), cap$notes))
  cap
}

#' The explerr() notes of one failed row: what the check means, and where its
#' message is raised.
#' @param check The failed check's name, looked up for what it means.
#' @param detail The row's detail.
#' @return Zero, one or two strings starting \code{"explained:"}.
#' @noRd
.bl_explain_note <- function(check, detail) {
  m <- .bl_check_meaning(check)
  e <- if (nzchar(trimws(detail))) {
    tryCatch(explerr(detail, n = 1L), error = function(e) NULL)
  }
  c(
    if (m != "a failed check: see the detail") paste("explained:", m),
    if (NROW(e)) {
      sprintf(
        "explained: raised by %s() (reached from %s); as written: \"%s\"",
        e$raised_by[1L],
        e$exported[1L],
        e$message[1L]
      )
    }
  )
}

#' The Markdown report of cpschk(), in the rmbl action's layout.
#' @param x An rmbl_cpschk result.
#' @param failon The fail-on level for the last line, or NULL.
#' @return One string.
#' @noRd
.bl_cpschk_md <- function(x, failon) {
  mark <- c(ok = "\u2714", warn = "\u26a0", drift = "\u26a0", error = "\u2716")
  ver <- as.character(utils::packageVersion("rmoriebricklayer"))
  st <- vapply(x$capsules, `[[`, "", "result")
  md <- c(.bl_md_title(x$mode, ver), "")
  if (length(st)) {
    md <- c(
      md,
      .bl_md_table(x, st, mark),
      .bl_md_manifests(x)
    )
    for (cp in x$capsules) {
      md <- c(
        md,
        .bl_md_capsule(
          cp,
          x$rows[x$rows$capsule == cp$capsule, , drop = FALSE],
          mark
        )
      )
    }
  } else {
    md <- c(
      md,
      sprintf(
        "%s No manifests found under `%s`%s.",
        mark[["ok"]],
        x$path,
        if (nzchar(x$glob)) sprintf(" matching `%s`", x$glob) else ""
      )
    )
  }
  md <- c(
    md,
    .bl_md_footprint(x$footprint),
    "",
    "---",
    "",
    sprintf(
      "mode `%s`%s \u00b7 rmoriebricklayer %s \u00b7 %s",
      x$mode,
      if (is.null(failon)) "" else sprintf(" \u00b7 fail-on `%s`", failon),
      ver,
      R.version.string
    )
  )
  paste0(paste(md, collapse = "\n"), "\n")
}

#' A table cell: no line breaks, pipes escaped.
#' @param x Text.
#' @return Text.
#' @noRd
.bl_md_esc <- function(x) {
  gsub("|", "\\|", gsub("\n", " ", x, fixed = TRUE), fixed = TRUE)
}

#' A number for the report: three significant digits, \code{"-"} for NA.
#' @param x Numbers to format, NA shown as a dash.
#' @param digits Significant digits of each formatted number (default 3).
#' @return Text.
#' @noRd
.bl_md_num <- function(x, digits = 3) {
  ifelse(is.na(x), "-", trimws(formatC(x, digits = digits, format = "g")))
}

#' A list of names after a lead, or \code{""} when there are none.
#' @param lead The text before the names.
#' @param x The names, a list or a vector.
#' @return Text.
#' @noRd
.bl_md_list <- function(lead, x) {
  if (length(x)) paste0(lead, toString(unlist(x))) else ""
}

#' The manifests section of the report.
#' @param x An rmbl_cpschk result.
#' @return Lines.
#' @noRd
.bl_md_manifests <- function(x) {
  ms <- unlist(lapply(x$capsules, `[[`, "manifests"), recursive = FALSE)
  if (!length(ms)) {
    return(character())
  }
  chg <- any(vapply(ms, function(m) isTRUE(m$changed), NA))
  md <- c(
    "",
    sprintf(
      "### Manifests against `%s`: %s",
      x$base,
      if (chg) "changed" else "unchanged"
    )
  )
  for (m in ms) {
    if (identical(m$state, "compared")) {
      md <- c(md, .bl_md_compared(m))
    } else {
      md <- c(md, "", sprintf("`%s`: %s", m$path, m$state))
    }
    if (NROW(m$resources)) {
      md <- c(md, "", "```", .bl_mnfdiff_text(m$resources), "```")
    }
  }
  md
}

#' The details block of one capsule: its sources, its rows, the drift table and
#' the notes.
#' @param cp One capsule of an rmbl_cpschk result.
#' @param ck Its rows.
#' @param mark The status symbols.
#' @return Lines.
#' @noRd
.bl_md_capsule <- function(cp, ck, mark) {
  md <- c(.bl_md_cap_head(cp, mark), .bl_md_checks(ck, mark))
  dr <- cp$drift
  if (!is.null(dr)) {
    md <- c(md, .bl_md_drift(dr, mark))
    if (nrow(dr$columns)) {
      md <- c(md, .bl_md_drift_cols(dr$columns, mark))
    }
  }
  nt <- unlist(cp$notes)
  if (length(nt)) {
    md <- c(
      md,
      "",
      paste0(
        ifelse(startsWith(nt, "explained:"), "  - ", "- "),
        .bl_md_esc(nt)
      )
    )
  }
  c(md, "", "</details>")
}

#' Refuses anything but a cpschk() result.
#' @param x The value that must be an \code{rmbl_cpschk} result.
#' @return NULL, invisibly.
#' @noRd
.bl_is_cpschk <- function(x) {
  if (!inherits(x, "rmbl_cpschk")) {
    stop(.rmbl_fn(), "`x` must be a cpschk() result", call. = FALSE)
  }
  invisible(NULL)
}

#' The capsules cpsseal() signs, checked before anything is written.
#' @param path,overwrite,glob As for cpsseal().
#' @return The capsule directories.
#' @noRd
.bl_seal_dirs <- function(path, overwrite, glob) {
  path <- .rmbl_string1(path, "path")
  if (!dir.exists(path)) {
    stop(
      .rmbl_fn(),
      "`path` is not an existing directory: ",
      .rmbl_printable(path),
      call. = FALSE
    )
  }
  overwrite <- .rmbl_flag1(overwrite, "overwrite")
  dirs <- .bl_capsule_dirs(path, .bl_str0(glob, "glob"))
  dirs <- dirs[file.exists(file.path(dirs, "data_provenance.json"))]
  if (!length(dirs)) {
    stop(
      .rmbl_fn(),
      "no data_provenance.json under ",
      .rmbl_printable(path),
      call. = FALSE
    )
  }
  have <- dirs[file.exists(file.path(dirs, "capsule_bundle.json"))]
  if (length(have) && !overwrite) {
    stop(
      .rmbl_fn(),
      "capsule_bundle.json already exists in ",
      toString(have),
      "; pass overwrite = TRUE (rmbl sign --overwrite) to sign again",
      call. = FALSE
    )
  }
  dirs
}

#' cpschk()'s options, checked.
#' @param o A list with the checked `path` and `mode`.
#' @param key,pubkey,psiwarn,psifail,base,archive As for cpschk().
#' @param flags A list with cpschk()'s `allowfile`, `snapshot` and `wayback`.
#' @return The options list.
#' @noRd
.bl_cpschk_opts <- function(
  o,
  key,
  pubkey,
  psiwarn,
  psifail,
  base,
  flags,
  archive
) {
  o <- c(
    o,
    list(
      key = .bl_str0(key, "key"),
      pubkey = .bl_str0(pubkey, "pubkey"),
      psiwarn = .rmbl_scalar(psiwarn, "psiwarn", 0),
      psifail = .rmbl_scalar(psifail, "psifail", 0),
      base = .bl_base_arg(base),
      allowfile = .bl_allowfile_arg(flags$allowfile),
      snapshot = .rmbl_flag1(flags$snapshot, "snapshot"),
      wayback = .rmbl_flag1(flags$wayback, "wayback"),
      archive = .rmbl_flag1(archive, "archive")
    )
  )
  if (o$psiwarn > o$psifail) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`psiwarn` (%g) must not exceed `psifail` (%g)",
        o$psiwarn,
        o$psifail
      ),
      call. = FALSE
    )
  }
  o
}

#' Checks every capsule folder; a check that stops becomes a failed row.
#' @param dirs The capsule folders.
#' @param o The options of cpschk(), passed to each capsule's checks.
#' @return One result per folder.
#' @noRd
.bl_cpschk_run <- function(dirs, o) {
  lapply(dirs, function(d) {
    tryCatch(.bl_cpschk_one(d, o), error = function(e) {
      list(
        capsule = d,
        source = "",
        pinned_sha256 = "",
        fetched_sha256 = "",
        changed = FALSE,
        rows = .bl_check_row(
          d,
          "capsule",
          d,
          "check_stopped",
          FALSE,
          conditionMessage(e)
        )
      )
    })
  })
}

#' cpschk()'s check rows of every capsule, in one table.
#' @param caps The finished capsule results.
#' @return A data frame (with no rows when there are no capsules).
#' @noRd
.bl_cpschk_rows <- function(caps) {
  do.call(
    rbind,
    c(
      list(.bl_check_row(
        character(),
        character(),
        character(),
        character(),
        logical(),
        character(),
        character()
      )),
      lapply(caps, `[[`, "rows")
    )
  )
}

#' Takes the cpsdrft() results out of cpschk()'s capsules.
#'
#' They go to an attribute, for drfthtml() and drftapp() (rmbl drift --html,
#' --app), each with its capsule's check rows, for the report's chain of
#' provenance, bytes, manifest and attestation.
#' @param caps The finished capsule results.
#' @param rows The check rows.
#' @return A list with `caps` (without their rows and drift objects) and
#'   `drifts`, named by capsule.
#' @noRd
.bl_cpschk_drifts <- function(caps, rows) {
  caps <- lapply(caps, function(cp) cp[names(cp) != "rows"])
  drifts <- Filter(
    Negate(is.null),
    stats::setNames(
      lapply(caps, function(cp) cp$drift$object),
      vapply(caps, `[[`, "", "capsule")
    )
  )
  caps <- lapply(caps, function(cp) {
    if (!is.null(cp$drift)) {
      cp$drift$object <- NULL
    }
    cp
  })
  for (d in names(drifts)) {
    drifts[[d]]$checks <- rows[
      rows$capsule == d,
      c("part", "file", "check", "ok", "detail", "severity"),
      drop = FALSE
    ]
  }
  list(caps = caps, drifts = drifts)
}

#' The note on where a fetched source came from when it was unreachable.
#' @param f The fetch, from `.bl_fetch_pin()`.
#' @return A string, or `NULL` when the source itself answered.
#' @noRd
.bl_cps_drift_note <- function(f) {
  if (f$cached) {
    "source unreachable: used the copy cached by an earlier run"
  } else if (isTRUE(f$archived)) {
    paste0(
      "source unreachable: used the copy kept on archive.rmorie.com ",
      "with the pinned SHA-256"
    )
  }
}

#' The column drift of a changed CSV source against the capsule's copy.
#'
#' The pinned data file stays inside the capsule: "../../outside/outside.csv"
#' was read and its header printed (audit of 30bed8e, #7).
#' @param d The capsule folder.
#' @param f The fetch.
#' @param ch The changed manifest rows.
#' @param o The options of cpschk(), passed to the column drift.
#' @return The comparison, an error, or `NULL` when nothing is compared.
#' @noRd
.bl_drift_columns <- function(d, f, ch, o) {
  local <- .rmbl_safe_rel(.bl_s1(f$old[["resource"]][["filename"]]), d) %||% ""
  if (
    nrow(ch) &&
      grepl("\\.csv$", local, ignore.case = TRUE) &&
      file.exists(local)
  ) {
    tryCatch(.bl_column_drift(local, f$path, o), error = function(e) e)
  }
}

#' The drift check's rows: the source digest and, when compared, its
#' columns.
#' @param out The capsule's drift result so far.
#' @param d The capsule folder.
#' @param pf The provenance file.
#' @param diff,ch The manifest difference and its changed rows.
#' @param cmp The column comparison, or `NULL`.
#' @return `out` with `rows`, and `drift`, `drift_summary` or a note.
#' @noRd
.bl_drift_rows <- function(out, d, pf, diff, ch, cmp) {
  out$rows <- .bl_check_row(
    d,
    "drift",
    pf,
    "source_digest",
    !nrow(ch),
    if (nrow(ch)) {
      paste(trimws(.bl_mnfdiff_text(diff)[-1L]), collapse = "; ")
    } else {
      "the source matches the pin"
    },
    severity = if (is.null(cmp)) "warn" else "note"
  )
  if (!is.null(cmp)) {
    out$rows <- rbind(
      out$rows,
      .bl_check_row(
        d,
        "drift",
        pf,
        "source_columns",
        cmp$verdict == "ok",
        cmp$summary,
        severity = if (cmp$verdict == "ok") "drift" else cmp$verdict
      )
    )
    out$drift <- cmp
    out$drift_summary <- cmp$summary
  } else if (nrow(ch)) {
    out$notes <- c(
      out$notes,
      paste0(
        "the source's digest changed; the distributions could not be ",
        "compared (no CSV copy)"
      )
    )
  }
  out
}

#' Each column's PSI band: `"-"` without a PSI, else ok, warn or fail.
#' @param psi The columns' PSI.
#' @param warn,fail The two band edges (`warn` <= `fail`).
#' @return A character vector (a logical one of length 0 for no columns, as
#'   `ifelse()` gave).
#' @noRd
.bl_psi_band <- function(psi, warn, fail) {
  if (!length(psi)) {
    return(logical(0))
  }
  band <- rep("ok", length(psi))
  has <- !is.na(psi)
  band[has & psi > warn] <- "warn"
  band[has & psi > fail] <- "fail"
  band[!has] <- "-"
  band
}

#' Each column's verdict: drift when flagged and past the fail band, warn
#' when flagged or past a band, else ok.
#' @param flagged Whether the drift test flagged the column.
#' @param band The column's PSI band.
#' @return A character vector (a logical one of length 0 for no columns, as
#'   `ifelse()` gave).
#' @noRd
.bl_col_verdict <- function(flagged, band) {
  if (!length(flagged)) {
    return(logical(0))
  }
  v <- rep("ok", length(flagged))
  v[flagged | band %in% c("warn", "fail")] <- "warn"
  v[flagged & band == "fail"] <- "drift"
  v
}

#' The Benford first-digit p-value of a numeric column.
#' @param x The column; a non-numeric one gives NA.
#' @return The p-value, `NA` for a column that is not numeric or cannot be
#'   tested.
#' @noRd
.bl_benford_p <- function(x) {
  if (!is.numeric(x)) {
    return(NA_real_)
  }
  tryCatch(suppressWarnings(benfordtst(x)$p_value), error = function(e) {
    NA_real_
  })
}

#' The one-line summary of a column drift: the columns past a band (the
#' first three), the columns added and removed, and the row counts.
#' @param cols The column table, with verdicts.
#' @param dr The cpsdrft() result.
#' @return A single string.
#' @noRd
.bl_drift_summary <- function(cols, dr) {
  hit <- cols[cols$verdict != "ok", , drop = FALSE]
  g <- function(v) formatC(v, digits = 3, format = "g")
  paste0(
    sprintf("%d of %d columns past a band", nrow(hit), nrow(cols)),
    if (nrow(hit)) {
      paste0(
        ": ",
        paste(
          utils::head(
            sprintf(
              "%s (stat %s, p %s, PSI %s)",
              hit$column,
              g(hit$statistic),
              g(hit$p_value),
              g(hit$psi)
            ),
            3L
          ),
          collapse = "; "
        )
      )
    },
    if (length(dr$added)) paste0("; added ", toString(dr$added)),
    if (length(dr$removed)) {
      paste0("; removed ", toString(dr$removed))
    },
    sprintf("; rows %d -> %d", dr$nref, dr$ncur)
  )
}

#' Saves a refreshed capsule's source to the Wayback Machine (and, when it
#' is refused, to archive.rmorie.com if asked), noting what happened.
#' @param d The capsule folder.
#' @param f The fetch.
#' @param o The options of cpschk(); `archive` allows the rmorie fallback.
#' @param out The capsule's drift result so far.
#' @return A list with `f` (its snapshot recorded when saved) and `out` (with
#'   the notes).
#' @noRd
.bl_refresh_wayback <- function(d, f, o, out) {
  why <- sprintf(
    "Source of the data capsule %s, refreshed by cpschk()",
    basename(d)
  )
  wb <- tryCatch(
    wbsave(
      f$src,
      quiet = TRUE,
      fallback = if (isTRUE(o$archive)) "rmorie",
      reason = if (isTRUE(o$archive)) why
    ),
    error = function(e) e
  )
  if (inherits(wb, "error")) {
    out$notes <- c(out$notes, paste("wayback:", conditionMessage(wb)))
  } else if (wb$status[1L] %in% c("saved", "existing")) {
    f$new$wayback$csv_snapshot <- wb$snapshot[1L]
    f$new$wayback$captured_at_utc <- f$new$resource$retrieved_utc
  } else {
    out$notes <- c(
      out$notes,
      paste("wayback: capture", wb$status[1L], wb$message[1L]),
      .bl_archive_note(attr(wb, "archive"))
    )
  }
  list(f = f, out = out)
}

#' The note on the archive.rmorie.com fallback of a refused Wayback capture.
#' @param ar The `archive` attribute of the wbsave() result.
#' @return A string, or `NULL` when there is nothing to say.
#' @noRd
.bl_archive_note <- function(ar) {
  if (inherits(ar, "rmbl_fail")) {
    return(paste("archive.rmorie.com:", ar))
  }
  if (!is.null(ar) && nrow(as.data.frame(unclass(ar)))) {
    a1 <- as.data.frame(unclass(ar))[1L, ]
    if (identical(a1$status, "archived")) {
      paste("archive.rmorie.com: saved instead,", a1$archive)
    } else {
      paste("archive.rmorie.com:", a1$status)
    }
  }
}

#' The report's status line and its table of capsules.
#' @param x The cpschk() result.
#' @param st Each capsule's result.
#' @param mark The status marks.
#' @return Markdown lines.
#' @noRd
.bl_md_table <- function(x, st, mark) {
  n <- length(st)
  md <- c(
    sprintf(
      paste0(
        "**%s %s**: %d capsule%s under `%s`: %d ok, %d warn, %d drift, ",
        "%d error"
      ),
      mark[[x$status]],
      x$status,
      n,
      if (n == 1L) "" else "s",
      x$path,
      sum(st == "ok"),
      sum(st == "warn"),
      sum(st == "drift"),
      sum(st == "error")
    ),
    "",
    "| Capsule | Source | SHA-256 | Size | Rows | Bounds | Result |",
    "|---|---|---|---|---|---|---|"
  )
  for (cp in x$capsules) {
    i <- .bl_capsule_info(cp$capsule)
    md <- c(
      md,
      sprintf(
        "| `%s` | %s | `%s` | %s | %s | %s | %s %s |",
        .bl_md_esc(cp$capsule),
        .bl_md_esc(i$host),
        i$sha,
        i$size,
        i$rows,
        .bl_md_esc(i$bounds),
        mark[[cp$result]],
        cp$result
      )
    )
  }
  md
}

#' The report's footprint line.
#' @param f The checks' co2fp() footprint, or `NULL`.
#' @return Markdown lines (none without a footprint).
#' @noRd
.bl_md_footprint <- function(f) {
  if (is.null(f)) {
    return(NULL)
  }
  ci <- f$co2int
  c(
    "",
    "---",
    "",
    sprintf(
      paste(
        "Footprint of these checks (co2fp(), %s): %.1f s wall, %.1f s CPU,",
        "%.3g Wh, %.3g gCO2e at %.4g gCO2e/kWh (%s%s)."
      ),
      if (f$method == "rapl") {
        "measured with RAPL"
      } else {
        "modelled, Green Algorithms"
      },
      f$durs,
      f$cputms,
      f$enekwh$total * 1000,
      f$co2eg,
      ci$g_per_kwh,
      ci$name,
      if (is.na(ci$year)) "" else paste0(", ", ci$year)
    )
  )
}

#' A vectorised if / else-if chain, with the results nested ifelse() calls
#' give (`NA` where the deciding test is `NA`).
#' @param tests The tests, in order, each as long as the result.
#' @param values The value for each test, recycled.
#' @param otherwise The value where every test is FALSE, recycled.
#' @return A vector as long as the tests (logical when they are empty, as
#'   `ifelse()` gives).
#' @noRd
.bl_ifelse_chain <- function(tests, values, otherwise) {
  n <- length(tests[[1L]])
  if (!n) {
    return(logical(0))
  }
  out <- rep(otherwise, length.out = n)
  decided <- rep(FALSE, n)
  for (j in seq_along(tests)) {
    t <- tests[[j]]
    v <- rep(values[[j]], length.out = n)
    hit <- !decided & !is.na(t) & t
    out[hit] <- v[hit]
    na <- !decided & is.na(t)
    out[na] <- NA
    decided <- decided | hit | na
  }
  out
}

#' One compared manifest of the report: its results against the base.
#' @param m The manifest comparison.
#' @return Markdown lines.
#' @noRd
.bl_md_compared <- function(m) {
  num <- .bl_md_num
  rr <- m$results
  c(
    "",
    sprintf(
      "`%s`: %d result%s compared%s",
      m$path,
      nrow(rr),
      if (nrow(rr) == 1L) "" else "s",
      if (length(m$removed)) {
        paste0(", removed: ", toString(unlist(m$removed)))
      } else {
        ""
      }
    ),
    "",
    "| Status | Result | Base | PR | Change | Tol |",
    "|---|---|---|---|---|---|",
    sprintf(
      "| %s | %s | %s | %s | %s | %s |",
      .bl_ifelse_chain(
        list(rr$status == "MATCH", rr$status == "NOT_RECORDED"),
        list("\u2714 match", "new"),
        "\u2716 mismatch"
      ),
      .bl_md_esc(rr$name),
      num(rr$recorded, 6),
      num(rr$recomputed, 6),
      ifelse(
        is.na(rr$delta),
        "-",
        paste(
          num(rr$delta),
          c("(outside tol)", "(within tol)")[(rr$status == "MATCH") + 1L]
        )
      ),
      num(rr$tol)
    )
  )
}

#' The opening of a capsule's report section: its summary line and its
#' source and hashes.
#'
#' Inside <summary> the directory name is HTML: a name like "<img src=x
#' onerror=...>" went in raw (audit of 30bed8e, #17).
#' @param cp The capsule result.
#' @param mark The status marks.
#' @return Markdown lines.
#' @noRd
.bl_md_cap_head <- function(cp, mark) {
  md <- c(
    "",
    "<details>",
    sprintf(
      paste0(
        "<summary>%s <code>%s</code>: %s, %d of %d checks passed (click ",
        "to open)</summary>"
      ),
      mark[[cp$result]],
      .yoy_esc(cp$capsule),
      cp$result,
      cp$checks_passed,
      cp$checks_total
    ),
    ""
  )
  if (nzchar(cp$source)) {
    md <- c(md, sprintf("- Source: %s", .bl_md_esc(cp$source)))
  }
  if (nzchar(cp$pinned_sha256)) {
    md <- c(md, sprintf("- Pinned SHA-256: `%s`", cp$pinned_sha256))
  }
  if (nzchar(cp$fetched_sha256)) {
    md <- c(
      md,
      sprintf(
        "- Fetched SHA-256: `%s` (%s)",
        cp$fetched_sha256,
        if (cp$changed) "changed" else "same"
      )
    )
  }
  md
}

#' A capsule's table of checks.
#' @param ck The capsule's check rows.
#' @param mark The status marks.
#' @return Markdown lines.
#' @noRd
.bl_md_checks <- function(ck, mark) {
  esc <- .bl_md_esc
  st <- .bl_ifelse_chain(
    list(ck$ok, ck$severity == "error", ck$severity == "note"),
    list("\u2714 pass", "\u2716 fail", "- note"),
    paste(mark[ck$severity], ck$severity)
  )
  c(
    "",
    "| Status | Check | Detail |",
    "|---|---|---|",
    sprintf(
      "| %s | %s%s | %s |",
      st,
      ifelse(ck$part %in% c("provenance", "spec"), "", paste0(ck$part, ": ")),
      esc(ck$check),
      esc(ifelse(nzchar(ck$detail), ck$detail, "-"))
    )
  )
}

#' A capsule's drift verdict line.
#' @param dr The capsule's column drift.
#' @param mark The status marks.
#' @return Markdown lines.
#' @noRd
.bl_md_drift <- function(dr, mark) {
  cols <- dr$columns
  flag <- cols$column[cols$drifted & !is.na(cols$drifted)]
  c(
    "",
    sprintf(
      paste(
        "**Drift: %s %s.** %d of %d columns flagged by the package",
        "(%s)%s%s; PSI bands:",
        "warn above %g, fail above %g; rows %s to %s, alpha %s."
      ),
      mark[[dr$verdict]],
      c(
        ok = "no column crossed a band",
        warn = "a column crossed the warn band",
        drift = "drift above the fail band"
      )[[dr$verdict]],
      length(flag),
      nrow(cols),
      if (length(flag)) toString(flag) else "none",
      .bl_md_list("; added ", dr$added),
      .bl_md_list("; removed ", dr$removed),
      dr$psiwarn,
      dr$psifail,
      format(dr$nref, big.mark = ","),
      format(dr$ncur, big.mark = ","),
      dr$alpha
    )
  )
}

#' A capsule's table of drifting columns.
#' @param cols The column table of the drift.
#' @param mark The status marks.
#' @return Markdown lines.
#' @noRd
.bl_md_drift_cols <- function(cols, mark) {
  num <- .bl_md_num
  test <- c("\u03c7\u00b2", "KS D")[cols$type %in% c("numeric", "date") + 1L]
  c(
    "",
    paste0(
      "| Verdict | Column | Type | Statistic | p | PSI (band) | JS | ",
      "Benford p (pinned / new) |"
    ),
    "|---|---|---|---|---|---|---|---|",
    sprintf(
      "| %s | %s | %s | %s | %s | %s | %s | %s |",
      paste(mark[cols$verdict], cols$verdict),
      .bl_md_esc(cols$column),
      cols$type,
      ifelse(is.na(cols$statistic), "-", paste(test, num(cols$statistic))),
      num(cols$p_value),
      paste0(
        num(cols$psi),
        ifelse(cols$band == "-", "", paste0(" (", cols$band, ")"))
      ),
      num(cols$jsdiv),
      ifelse(
        is.na(cols$benford_ref) & is.na(cols$benford_cur),
        "-",
        paste(num(cols$benford_ref), "/", num(cols$benford_cur))
      )
    )
  )
}

#' cpschk()'s result: the status, the check rows and the capsules, with the
#' drift objects as an attribute.
#' @param o The options of cpschk(): its mode and path go in the result.
#' @param glob The checked glob.
#' @param caps The finished capsule results.
#' @param base As for cpschk().
#' @param foot The footprint without its value, or `NULL`.
#' @return An `rmbl_cpschk` object.
#' @noRd
.bl_cpschk_result <- function(o, glob, caps, base, foot) {
  rows <- .bl_cpschk_rows(caps)
  dc <- .bl_cpschk_drifts(caps, rows)
  caps <- dc$caps
  structure(
    list(
      status = .bl_worst(vapply(caps, `[[`, "", "result")),
      mode = o$mode,
      path = o$path,
      glob = glob,
      rows = rows,
      capsules = caps,
      base = if (is.function(base)) {
        attr(base, "label") %||% "the base"
      } else {
        base
      },
      psiwarn = o$psiwarn,
      psifail = o$psifail,
      footprint = foot
    ),
    class = "rmbl_cpschk",
    drifts = dc$drifts
  )
}

#' The report's title line.
#' @param mode The check mode.
#' @param ver The package version.
#' @return A Markdown line.
#' @noRd
.bl_md_title <- function(mode, ver) {
  sprintf(
    paste0(
      "## rmbl capsule %s with [rmoriebricklayer ",
      "%s](https://github.com/rootcoder007/rmorie-bricklayer)"
    ),
    mode,
    ver
  )
}

#' A failed drift-check row carrying an error's message.
#' @param d The capsule folder.
#' @param pf The provenance file.
#' @param check The name of the drift check that failed.
#' @param e The error whose message is the row's detail.
#' @return A check row.
#' @noRd
.bl_drift_fail <- function(d, pf, check, e) {
  .bl_check_row(d, "drift", pf, check, FALSE, conditionMessage(e))
}

#' A column drift's verdict: drift when a column drifted past the fail band
#' or columns came or went, warn when a column crossed a band, else ok.
#' @param cols The column table, with verdicts.
#' @param dr The cpsdrft() result.
#' @return `"drift"`, `"warn"` or `"ok"`.
#' @noRd
.bl_cps_drift_verdict <- function(cols, dr) {
  if (any(cols$verdict == "drift") || length(dr$added) || length(dr$removed)) {
    "drift"
  } else if (any(cols$verdict == "warn")) {
    "warn"
  } else {
    "ok"
  }
}
