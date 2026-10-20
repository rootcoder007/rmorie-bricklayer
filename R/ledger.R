# SPDX-License-Identifier: AGPL-3.0-or-later
# Proof ledgers: the theorems of a formal-proof build, which package functions each covers, and a
# numeric check of each, read against a JSON Schema and checked in the verify-row shape.

#' Read and check a proof ledger
#'
#' A proof ledger records the theorems of a formal-proof build (Lean and Mathlib): each
#' theorem's statement, file and line, its status (`proved`, `sorry` or
#' `axiom`) and number of `sorry` placeholders, the package functions
#' whose behaviour it states, and optionally a numeric check of one of them in R. The
#' format is `schemapath("ledger")`, in the style of the capsule schemas;
#' nothing in it is specific to this package, so any package can ship a ledger in
#' `inst/ledger/` and any formal-proof project can write one.
#'
#' @details `ldgrread()` parses the file and validates it against the schema; a
#'   file that does not validate, or that repeats a theorem id, is refused with the
#'   first problems found.
#'
#' `ldgrchk()` returns check rows in the shape of `rmbl verify` (the
#' `rows` of [cpschk()]):
#' \describe{
#'   \item{`proved: ID`}{the theorem is `proved` with
#'     `sorry_count` 0. A `sorry` fails as an error; an `axiom`
#'     fails as a warning (it is assumed, not proved).}
#'   \item{`covered: ID PKG::FN`}{the covered function is exported by the
#'     installed package; a package that is not installed here is a note, not a failure
#'     (it cannot be checked).}
#'   \item{`check: ID`}{the theorem's `check$expr` evaluates within
#'     `check$tol` (default 1e-8) of `check$expect`. The expression is
#'     evaluated in a sandbox: an environment holding only the exported functions of
#'     the first R package the theorem covers and a short list of base arithmetic and
#'     constructors (`c`, `list`, `seq`, `rep`,
#'     `sum`, `+`, `$`, ...). Anything else is refused before
#'     evaluation: a call to any other function (`system()`, `file()`,
#'     `eval()`, another package), a free variable, or an expression whose outer
#'     call is not a call to that package (or an extraction from one). Evaluation is
#'     limited to 10 seconds.}
#'   \item{`ledger_commit_pinned`, `ledger_build_pinned`}{when the ledger
#'     is the data file of a capsule whose provenance says `kind: "ledger"`: the
#'     provenance's `source$commit` and `source$build_digest` equal the
#'     ledger's. The capsule's own rows ([vrfcps()], the bundle and
#'     attestation through [cpsbndlvrf()], the schemas) come
#'     with them, as `rmbl verify` reports them; `rmbl verify` adds the
#'     ledger rows to such a capsule too.}
#' }
#' @param path Character scalar, the ledger JSON file.
#' @param ledger A `ldgrread()` result, or the path of a ledger file.
#' @param pkgs Character vector: check only the covered functions and checks of these
#'   packages; `NULL` (the default) checks every package named.
#' @param x A `ldgrread()` result.
#' @param ... Not used.
#' @return `ldgrread()`: the ledger, a list of class `rmbl_ledger`,
#'   with the normalised path as the attribute `path`.
#'   `ldgrchk()`: a data frame with the columns `capsule`, `part`
#'   (`ledger`, or the capsule parts), `file`, `check`,
#'   `ok`, `detail`, `severity` (`error`, `warn` or
#'   `note`) and `line`.
#' @seealso [schemapath()], [cpschk()],
#'   [cpsbndlvrf()].
#' @examples
#' f <- system.file("extdata", "ledger_sample.json", package = "rmoriebricklayer")
#' l <- ldgrread(f)
#' l
#' r <- ldgrchk(l)
#' r[, c("check", "ok", "severity", "detail")]
#'
#' # a file that is not a ledger
#' bad <- tempfile(fileext = ".json")
#' writeLines('{"name": "x"}', bad)
#' try(ldgrread(bad))
#' unlink(bad)
#' @export
ldgrread <- function(path) {
  path <- .rmbl_file1(path, "path")
  x <- tryCatch(.bl_read_json_list(path), error = function(e) {
    stop("ldgrread: ", basename(path), " is not valid JSON: ", conditionMessage(e), call. = FALSE)
  })
  err <- .bl_schema_errors(x, .bl_read_json_list(schemapath("ledger")))
  if (length(err)) {
    stop(sprintf("ldgrread: %s is not a ledger: %s", basename(path), paste(utils::head(err, 3L), collapse = "; ")),
         call. = FALSE)
  }
  ids <- vapply(x$theorems, function(t) t$id, "")
  if (anyDuplicated(ids)) stop(sprintf("ldgrread: theorem id %s is repeated", ids[anyDuplicated(ids)]), call. = FALSE)
  structure(x, class = c("rmbl_ledger", "list"), path = normalizePath(path))
}

#' @rdname ldgrread
#' @export
print.rmbl_ledger <- function(x, ...) {
  st <- vapply(x$theorems, function(t) t$status, "")
  cat(sprintf("Proof ledger %s: %d theorems (%d proved, %d sorry, %d axiom)\n", x$name, length(st),
              sum(st == "proved"), sum(st == "sorry"), sum(st == "axiom")))
  cat(sprintf("  %s @ %s, Lean %s\n", x$source$repo, substr(x$source$commit, 1L, 12L), x$toolchain$lean))
  invisible(x)
}

#' @rdname ldgrread
#' @export
ldgrchk <- function(ledger, pkgs = NULL) {
  if (is.character(ledger)) ledger <- ldgrread(ledger)
  if (!inherits(ledger, "rmbl_ledger")) {
    stop("ldgrchk: `ledger` must be a ldgrread() result or the path of a ledger file", call. = FALSE)
  }
  if (!is.null(pkgs) && (!is.character(pkgs) || anyNA(pkgs))) {
    stop("ldgrchk: `pkgs` must be package names, or NULL", call. = FALSE)
  }
  path <- attr(ledger, "path") %||% ""
  d <- if (nzchar(path)) dirname(path) else ""
  prov <- if (nzchar(d) && file.exists(file.path(d, "data_provenance.json"))) {
    tryCatch(.bl_read_json_list(file.path(d, "data_provenance.json")), error = function(e) NULL)
  }
  if (identical(prov$kind, "ledger") && identical(prov$resource$filename, basename(path))) {
    return(.bl_verify_capsule(d, pkgs = pkgs))
  }
  .bl_ldgr_rows(ledger, pkgs, "", path)
}

#' The theorem rows of a ledger: proved, covered and check.
#' @param ledger A ldgrread() result.
#' @param pkgs The packages to check, or NULL for all.
#' @param capsule The capsule directory, or "".
#' @param file The ledger file.
#' @return Check rows.
#' @noRd
.bl_ldgr_rows <- function(ledger, pkgs, capsule, file) {
  row <- function(check, ok, detail, severity = "error") {
    .bl_check_row(capsule, "ledger", file, check, ok, detail, severity)
  }
  out <- list()
  for (t in ledger$theorems) {
    ok <- identical(t$status, "proved") && t$sorry_count == 0
    out[[length(out) + 1L]] <- row(paste("proved:", t$id), ok,
      if (ok) sprintf("%s, no sorry", t$name) else sprintf("%s is %s with %d sorry", t$name, t$status, t$sorry_count),
      if (identical(t$status, "axiom") && t$sorry_count == 0) "warn" else "error")
    rcov <- Filter(function(cv) is.null(pkgs) || cv$package %in% pkgs, t$covers)
    for (cv in rcov) {
      chk <- sprintf("covered: %s %s::%s", t$id, cv$package, cv$`function`)
      if (cv$language != "R" || !requireNamespace(cv$package, quietly = TRUE)) {
        out[[length(out) + 1L]] <- row(chk, TRUE, sprintf("%s (%s) is not installed here; not checked", cv$package,
                                                          cv$language), "note")
      } else {
        has <- cv$`function` %in% getNamespaceExports(cv$package)
        out[[length(out) + 1L]] <- row(chk, has, if (has) "exported by the installed package" else
          sprintf("%s does not export %s", cv$package, cv$`function`))
      }
    }
    if (!is.null(t$check)) {
      rp <- Filter(function(cv) cv$language == "R", t$covers)
      pk <- if (length(rp)) rp[[1L]]$package
      if (!is.null(pkgs) && !is.null(pk) && !pk %in% pkgs) next
      chk <- paste("check:", t$id)
      if (is.null(pk)) {
        out[[length(out) + 1L]] <- row(chk, FALSE, "a check needs an R package among the functions covered")
      } else if (!requireNamespace(pk, quietly = TRUE)) {
        out[[length(out) + 1L]] <- row(chk, TRUE, sprintf("%s is not installed here; not checked", pk), "note")
      } else {
        v <- tryCatch(.bl_ldgr_eval(t$check$expr, pk), error = function(e) e)
        tol <- t$check$tol %||% 1e-8
        out[[length(out) + 1L]] <- if (inherits(v, "error")) {
          row(chk, FALSE, conditionMessage(v))
        } else {
          good <- is.numeric(v) && length(v) == 1L && is.finite(v) && abs(v - t$check$expect) <= tol
          row(chk, good, sprintf("%s = %s, expected %s within %s", t$check$expr,
                                 if (is.numeric(v) && length(v) == 1L) format(v, digits = 15) else
                                   paste("a", class(v)[1L], "of length", length(v)),
                                 format(t$check$expect, digits = 15), format(tol)))
        }
      }
    }
  }
  do.call(rbind, out)
}

#' The base functions a ledger check may call besides the package's own.
#' @return A character vector.
#' @noRd
.bl_ldgr_base <- function() {
  c("c", "list", "(", "{", "+", "-", "*", "/", "^", "%%", "%/%", ":", "==", "!=", "<", ">", "<=", ">=", "!", "&",
    "|", "seq", "seq_len", "seq_along", "rep", "sum", "prod", "mean", "abs", "exp", "log", "sqrt", "max", "min",
    "range", "length", "round", "signif", "floor", "ceiling", "numeric", "integer", "character", "logical",
    "matrix", "data.frame", "as.numeric", "as.integer", "rev", "sort", "cumsum", "unlist", "$", "[[", "[")
}

#' Evaluates one ledger check in a sandbox.
#'
#' The expression is walked before it runs: every function called must be an export of
#' `pkg` (bare or as pkg::fn) or one of .bl_ldgr_base(), every free name is
#' refused, and the outer call must be a call to `pkg` or an extraction ($, [[,
#' [) from one. It is evaluated in an environment whose parent is the empty
#' environment, holding only those functions, for at most 10 seconds.
#' @param expr The expression, as text.
#' @param pkg The package.
#' @return The value.
#' @noRd
.bl_ldgr_eval <- function(expr, pkg) {
  e <- tryCatch(parse(text = expr, keep.source = FALSE), error = function(err) {
    stop("the check is not R code: ", conditionMessage(err), call. = FALSE)
  })
  if (length(e) != 1L) stop("the check must be one expression", call. = FALSE)
  e <- e[[1L]]
  ex <- getNamespaceExports(pkg)
  base <- .bl_ldgr_base()
  acc <- new.env(parent = emptyenv())
  acc$used <- character()
  walk <- function(z, field = FALSE) {
    if (is.call(z)) {
      f <- z[[1L]]
      if (is.call(f) && identical(f[[1L]], as.name("::"))) {
        if (!identical(as.character(f[[2L]]), pkg) || !as.character(f[[3L]]) %in% ex) {
          stop(sprintf("the check may call only %s and base arithmetic, not %s", pkg, deparse(f)), call. = FALSE)
        }
        z[[1L]] <- f[[3L]]
        f <- f[[3L]]
      }
      if (!is.name(f)) stop("the check calls something that is not a function name", call. = FALSE)
      nm <- as.character(f)
      if (!nm %in% c(ex, base)) {
        stop(sprintf("the check may call only %s and base arithmetic, not %s()", pkg, nm), call. = FALSE)
      }
      acc$used <- c(acc$used, nm)
      for (i in seq_along(z)[-1L]) {
        if (!missing_arg(z[[i]])) z[[i]] <- walk(z[[i]], field = nm == "$" && i == 3L)
      }
      return(z)
    }
    if (is.name(z) && !field && !identical(as.character(z), "pi")) {
      stop(sprintf("the check refers to `%s`, which is not a value it may use", as.character(z)), call. = FALSE)
    }
    z
  }
  missing_arg <- function(a) is.name(a) && !nzchar(as.character(a))
  top <- e
  while (is.call(top) && as.character(top[[1L]])[1L] %in% c("$", "[[", "[", "(")) top <- top[[2L]]
  head <- if (is.call(top)) top[[1L]]
  if (is.call(head) && identical(head[[1L]], as.name("::"))) head <- head[[3L]]
  if (!is.name(head) || !as.character(head) %in% ex) {
    stop(sprintf("the check must be a call to a function of %s", pkg), call. = FALSE)
  }
  e <- walk(e)
  env <- new.env(parent = emptyenv())
  env$pi <- pi
  for (nm in unique(acc$used)) {
    assign(nm, if (nm %in% ex) getExportedValue(pkg, nm) else get(nm, envir = baseenv()), envir = env)
  }
  setTimeLimit(elapsed = 10, transient = TRUE)
  on.exit(setTimeLimit(elapsed = Inf), add = TRUE)
  eval(e, env)
}

#' The ledger rows of a capsule whose provenance says kind "ledger".
#' @param d The capsule directory.
#' @param prov The provenance, parsed as a list.
#' @param pkgs The packages to check, or NULL.
#' @return Check rows.
#' @noRd
.bl_ldgr_capsule_rows <- function(d, prov, pkgs = NULL) {
  f <- file.path(d, prov$resource$filename %||% "ledger.json")
  led <- tryCatch(ldgrread(f), error = function(e) e)
  if (inherits(led, "error")) {
    return(.bl_check_row(d, "ledger", f, "ledger_readable", FALSE, conditionMessage(led)))
  }
  pin <- function(check, key) {
    want <- led$source[[key]] %||% ""
    got <- prov$source[[key]] %||% ""
    .bl_check_row(d, "ledger", f, check, nzchar(want) && identical(want, got),
                  if (identical(want, got) && nzchar(want)) sprintf("%s %s", key, want) else
                    sprintf("the provenance pins %s %s, the ledger records %s", key,
                            if (nzchar(got)) got else "nothing", if (nzchar(want)) want else "nothing"))
  }
  rbind(.bl_ldgr_rows(led, pkgs, d, f), pin("ledger_commit_pinned", "commit"),
        pin("ledger_build_pinned", "build_digest"))
}
