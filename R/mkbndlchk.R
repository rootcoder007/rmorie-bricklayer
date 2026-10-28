# SPDX-License-Identifier: AGPL-3.0-or-later
#
# mkbndlchk(): the check an author runs on a bundle before shipping it.

#' Check a reproducibility bundle before shipping it
#'
#' Unzips a bundle built by [mkbndl()] into a new
#' folder, runs it the way a recipient would
#' (\code{Rscript setup_and_run.R --quick}) and reads the
#' \file{manifest.json} the run writes. The bundle passes when the run
#' finishes, writes its manifest, no cross-check is DIFFER and, on real
#' data, the number of checks and of passes is the one the \code{expected}
#' block of its \file{config.json} gives (\code{pass_csv} for a CSV input,
#' \code{pass_real} for the \file{.RData}). A run on synthetic data marks
#' every check INFO, so it is not compared with \code{expected}. A launcher
#' (\file{start_here.sh}, \file{START_HERE.command}) the zip does not mark
#' executable is reported as a warning: it still runs as
#' \code{bash start_here.sh}.
#'
#' Errors: \code{bundle} that is not an existing \file{.zip} file; a zip
#' without \file{setup_and_run.R}; \code{data} that is not an existing
#' file; \code{dir} that already exists.
#'
#' @param bundle Path to the bundle zip.
#' @param data Optional path to the data file, passed to the run as
#'   \code{--data}. \code{NULL} (default): the bundle finds the file,
#'   downloads it or, with \code{synthetic = TRUE}, generates data.
#' @param synthetic Run on synthetic data (\code{--synthetic}), default
#'   \code{FALSE}; needs no data file and no network.
#' @param dir A folder to unzip into, which must not exist yet. Default: a
#'   new folder under \code{tempdir()}.
#' @param keep Keep that folder after the check, default \code{FALSE}.
#' @return An object of class \code{rmbl_bundle_audit}: a list with
#'   \code{ok}, \code{checks} (a data frame of \code{check}, \code{ok},
#'   \code{detail} and \code{severity}), \code{mode} (the input the run
#'   used, from its manifest: \code{synthetic} when it is marked
#'   synthetic, else its \code{meta$input_mode} when it records one, such
#'   as \code{csv}, else \code{real}), \code{counts} (\code{total}, \code{pass},
#'   \code{differ}, \code{info}), \code{log} (the last 30 lines the run
#'   printed), \code{bundle} and \code{dir} (the unzipped bundle, or
#'   \code{NA} once removed). It prints as a box.
#' @seealso [mkbndl()] builds the bundle;
#'   [mkbndlproj()] starts a project.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' proj <- file.path(tempdir(), "audit-demo")
#' mkbndlproj(proj, title = "Demo analysis")
#' b <- mkbndl(proj, dest = tempdir(), overwrite = TRUE)
#' a <- mkbndlchk(b$path, synthetic = TRUE)
#' a
#' a$counts
#' @export
mkbndlchk <- function(bundle, data = NULL, synthetic = FALSE, dir = NULL,
                      keep = FALSE) {
  a <- .bndlchk_args(bundle, data, synthetic, dir, keep)
  dir.create(a$dir, recursive = TRUE)
  if (!a$keep) {
    on.exit(unlink(a$dir, recursive = TRUE), add = TRUE)
  }
  root <- .bndlchk_unzip(a$bundle, a$dir)
  run <- .bndlchk_run(root, a$data, a$synthetic)
  man <- .bndlchk_manifest(root)
  checks <- rbind(
    .bndlchk_row("run finished", run$status == 0L,
                 sprintf("exit status %d", run$status)),
    .bndlchk_row("manifest written", !is.null(man),
                 if (is.null(man)) "no results_*/manifest.json" else man$path),
    .bndlchk_differ(man),
    .bndlchk_expected(root, man),
    .bndlchk_launchers(.bndlchk_modes(a$bundle))
  )
  hard <- checks$severity == "error"
  .rmbl_cls(list(
    ok = all(checks$ok[hard]),
    checks = checks,
    mode = man$mode %||% NA_character_,
    counts = man$counts %||% c(total = NA, pass = NA, differ = NA, info = NA),
    log = utils::tail(run$log, 30L),
    bundle = normalizePath(a$bundle, winslash = "/"),
    dir = if (a$keep) normalizePath(root, winslash = "/") else NA_character_
  ), "rmbl_bundle_audit")
}

#' @export
format.rmbl_bundle_audit <- function(x, ...) {
  n <- x$counts
  .rmbl_stat_block(
    sprintf(
      "Bundle audit: %s", if (isTRUE(x$ok)) "VERIFIED" else "NOT VERIFIED"
    ),
    facts = list(
      Bundle = basename(x$bundle),
      `Input mode` = x$mode,
      Checks = n[["total"]],
      PASS = n[["pass"]],
      DIFFER = n[["differ"]],
      INFO = n[["info"]]
    ),
    reading = .rmbl_check_reading(
      x$ok,
      "the bundle runs as a recipient's copy will and is safe to ship",
      "do not ship it yet: fix what failed and build it again"
    ),
    notes = c(
      .rmbl_check_lines(x$checks),
      if (!isTRUE(x$ok) && length(x$log)) {
        c("", "The run's last lines:", x$log)
      }
    )
  )
}

#' mkbndlchk()'s arguments, checked.
#' @param bundle,data,synthetic,dir,keep As for mkbndlchk().
#' @return A list of the five.
#' @noRd
.bndlchk_args <- function(bundle, data, synthetic, dir, keep) {
  bundle <- .rmbl_string1(bundle, "bundle")
  if (!file.exists(bundle) || dir.exists(bundle) ||
        !grepl("[.]zip$", bundle, ignore.case = TRUE)) {
    stop(sprintf("`bundle` is not an existing .zip file: %s", bundle),
         call. = FALSE)
  }
  if (!is.null(data)) {
    data <- .rmbl_string1(data, "data")
    if (!file.exists(data) || dir.exists(data)) {
      stop(sprintf("`data` is not an existing file: %s", data), call. = FALSE)
    }
    data <- normalizePath(data, winslash = "/")
  }
  dir <- if (is.null(dir)) tempfile("bndlchk") else .rmbl_string1(dir, "dir")
  if (file.exists(dir)) {
    stop(sprintf("`dir` already exists: %s", dir), call. = FALSE)
  }
  list(
    bundle = bundle,
    data = data,
    synthetic = .rmbl_flag1(synthetic, "synthetic"),
    dir = dir,
    keep = .rmbl_flag1(keep, "keep")
  )
}

#' Unzips a bundle and finds its runner.
#' @param bundle The zip.
#' @param dir The folder to unzip into.
#' @return The folder holding setup_and_run.R.
#' @noRd
.bndlchk_unzip <- function(bundle, dir) {
  utils::unzip(bundle, exdir = dir)
  cand <- c(dir, list.dirs(dir, recursive = FALSE))
  root <- cand[file.exists(file.path(cand, "setup_and_run.R"))][1L]
  if (is.na(root)) {
    stop("the bundle has no setup_and_run.R", call. = FALSE)
  }
  root
}

#' Runs the bundle as a recipient would, in a child R.
#' @param root The unzipped bundle.
#' @param data The data file to pass as --data, or NULL.
#' @param synthetic Whether to run on synthetic data.
#' @return A list: the exit status and the lines the run printed.
#' @noRd
.bndlchk_run <- function(root, data, synthetic) {
  args <- c(
    "setup_and_run.R", "--quick",
    if (synthetic) "--synthetic",
    if (!is.null(data)) c("--data", shQuote(data))
  )
  log <- tempfile("bndlchk", fileext = ".log")
  on.exit(unlink(log), add = TRUE)
  # a check run inside R CMD check would hand the child its test startup
  withr::local_envvar(R_TESTS = NA)
  withr::local_dir(root)
  exe <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  rscript <- file.path(R.home("bin"), exe)
  # a run that never ends is stopped (option rmbl.bundle.timeout, seconds)
  tmout <- suppressWarnings(as.integer(getOption("rmbl.bundle.timeout",
                                                 7200L)))
  if (length(tmout) != 1L || is.na(tmout) || tmout < 1L) tmout <- 7200L
  status <- suppressWarnings(
    system2(rscript, args, stdout = log, stderr = log, timeout = tmout)
  )
  if (identical(as.integer(status), 124L)) {
    cat(sprintf("\nstopped: the run took longer than %d seconds\n", tmout),
        file = log, append = TRUE)
  }
  list(
    status = as.integer(status),
    log = if (file.exists(log)) readLines(log, warn = FALSE) else character()
  )
}

#' The newest manifest the run wrote, counted.
#' @param root The unzipped bundle.
#' @return NULL when there is none, else a list: path, mode, counts.
#' @noRd
.bndlchk_manifest <- function(root) {
  res <- list.files(root, pattern = "^results_", full.names = TRUE)
  res <- res[file.exists(file.path(res, "manifest.json"))]
  if (!length(res)) {
    return(NULL)
  }
  path <- file.path(res[which.max(file.mtime(res))], "manifest.json")
  m <- fromjs(path, simplifyVector = FALSE)
  st <- vapply(m$results, function(r) as.character(r$status %||% ""), "")
  list(
    path = normalizePath(path, winslash = "/"),
    mode = if (isTRUE(m$meta$synthetic)) {
      "synthetic"
    } else {
      as.character(m$meta$input_mode %||% "real")
    },
    counts = c(
      total = length(st),
      pass = sum(st == "PASS"),
      differ = sum(st == "DIFFER"),
      info = sum(st == "INFO")
    )
  )
}

#' One row of the checks table.
#' @param check Its name.
#' @param ok Whether the check passed.
#' @param detail What the check found.
#' @param severity "error" (fails the audit) or "warn".
#' @return A one-row data frame.
#' @noRd
.bndlchk_row <- function(check, ok, detail, severity = "error") {
  data.frame(
    check = check, ok = isTRUE(ok), detail = detail, severity = severity,
    stringsAsFactors = FALSE
  )
}

#' The check that no cross-check differs.
#' @param man The manifest, from .bndlchk_manifest().
#' @return A one-row data frame.
#' @noRd
.bndlchk_differ <- function(man) {
  if (is.null(man)) {
    return(.bndlchk_row("no cross-check differs", FALSE, "no manifest"))
  }
  d <- man$counts[["differ"]]
  .bndlchk_row("no cross-check differs", d == 0L, sprintf("%d DIFFER", d))
}

#' The check that a real-data run gives the counts config.json expects.
#' @param root The unzipped bundle.
#' @param man The manifest, from .bndlchk_manifest().
#' @return A one-row data frame.
#' @noRd
.bndlchk_expected <- function(root, man) {
  nm <- "counts match config.json"
  if (is.null(man)) {
    return(.bndlchk_row(nm, FALSE, "no manifest"))
  }
  if (identical(man$mode, "synthetic")) {
    return(.bndlchk_row(nm, TRUE, "not compared: a synthetic run"))
  }
  cfg <- file.path(root, "config.json")
  ex <- if (file.exists(cfg)) fromjs(cfg, simplifyVector = FALSE)$expected
  key <- if (identical(man$mode, "csv")) "pass_csv" else "pass_real"
  tot <- ex$total_checks
  pass <- ex[[key]]
  if (is.null(tot) || is.null(pass)) {
    return(.bndlchk_row(nm, TRUE, "not compared: config.json expects none"))
  }
  n <- man$counts
  .bndlchk_row(
    nm, n[["total"]] == tot && n[["pass"]] == pass,
    sprintf("%s expects %s/%s PASS; the %s run gave %d/%d",
            key, pass, tot, man$mode, n[["pass"]], n[["total"]])
  )
}

#' The check that the launchers are executable inside the zip.
#' @param modes The Unix modes of the zip's entries, named by path.
#' @return A one-row data frame (a warning, not an error).
#' @noRd
.bndlchk_launchers <- function(modes) {
  l <- modes[grepl("[.](sh|command)$", names(modes))]
  bad <- names(l)[bitwAnd(as.integer(l), 64L) == 0L]
  .bndlchk_row(
    "launchers executable", !length(bad),
    if (length(bad)) {
      paste("not executable in the zip:", toString(bad))
    } else {
      sprintf("%d launcher(s)", length(l))
    },
    severity = "warn"
  )
}

#' The Unix modes the zip's central directory records.
#' @param zip The bundle zip.
#' @return A numeric vector named by path (empty when none is found).
#' @noRd
.bndlchk_modes <- function(zip) {
  sz <- file.size(zip)
  con <- file(zip, "rb")
  on.exit(close(con), add = TRUE)
  n <- min(sz, 65557)
  seek(con, sz - n)
  tl <- readBin(con, "raw", n)
  at <- grepRaw(as.raw(c(0x50, 0x4b, 0x05, 0x06)), tl, all = TRUE)
  if (!length(at)) {
    return(numeric())
  }
  e <- tl[at[length(at)] + 0:21]
  off <- .bndlchk_u32(e, 17L)
  len <- .bndlchk_u32(e, 13L)
  # a directory claimed beyond the file's end (a damaged or hostile zip)
  # is not read: readBin() would allocate the size it is given
  if (off + len > sz) {
    return(numeric())
  }
  seek(con, off)
  .bndlchk_cd_modes(readBin(con, "raw", len))
}

#' Walks a central directory, reading each entry's name and Unix mode.
#' @param cd The central directory's bytes.
#' @return A numeric vector named by path.
#' @noRd
.bndlchk_cd_modes <- function(cd) {
  out <- numeric()
  i <- 1L
  while (i + 45L <= length(cd)) {
    ln <- .bndlchk_u16(cd, i + 28L)
    skip <- ln + .bndlchk_u16(cd, i + 30L) + .bndlchk_u16(cd, i + 32L)
    nm <- rawToChar(cd[i + 46L + seq_len(ln) - 1L])
    out[[nm]] <- .bndlchk_u32(cd, i + 38L) %/% 65536
    i <- i + 46L + skip
  }
  out
}

#' A little-endian unsigned 16-bit integer from raw bytes.
#' @param b The bytes.
#' @param i The 1-based position of its first byte.
#' @return A number.
#' @noRd
.bndlchk_u16 <- function(b, i) {
  as.numeric(b[i]) + 256 * as.numeric(b[i + 1L])
}

#' A little-endian unsigned 32-bit integer from raw bytes.
#' @param b The bytes.
#' @param i The 1-based position of its first byte.
#' @return A number.
#' @noRd
.bndlchk_u32 <- function(b, i) {
  .bndlchk_u16(b, i) + 65536 * .bndlchk_u16(b, i + 2L)
}
