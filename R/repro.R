# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Closing the loop from "the record is intact" to "the record is right".
#
# verify_capsule() checks a manifest against itself: that the recorded
# observed and expected values are consistent with the status recorded
# beside them. That catches a corrupted or edited manifest and cannot
# catch a manifest that was wrong when it was written. Re-running the
# statistics against the data is the only thing that can.

#' Recompute a manifest's recorded statistics against the data
#'
#' Re-evaluates named statistics against `data` and compares each to
#' what the manifest recorded. This is the check
#' [verify_capsule()] cannot make: that one
#' confirms the record is internally consistent, which an
#' edited-at-the-time manifest also is.
#'
#' Every recorded result that was NOT recomputed is reported too, as
#' `unchecked`. An analysis that recorded twenty statistics and
#' re-derives three has seventeen it has not re-derived, and a report that
#' quietly omitted them would read as a clean bill of health.
#'
#' @param manifest A manifest, as from
#' [make_manifest()] and
#' [record()].
#' @param data The data the statistics are computed from.
#' @param statistics Named list of functions of
#' `data`. Names must match the recorded result names.
#' @param tol Optional numeric tolerance overriding each
#' result's own recorded `tol`. Supply it to check more strictly than
#' the original run did.
#' @return A list of class `bricklayer_recompute`: `ok`, a
#' `results` data frame with one row per recomputed statistic (
#' `name`, `recorded`, `recomputed`, `delta`,
#' `tol`, `status`) , and `unchecked`, the names recorded
#' but not recomputed.
#' @seealso
#' [verify_capsule()],
#' [capsule_falsify()],
#' [record()].
#' @examples
#' d <- data.frame(x = 1:10)
#' m <- make_manifest(list(dataset = "demo"), environment = FALSE)
#' m <- record(m, "mean_x", observed = mean(d$x), expected = 5.5)
#' m <- record(m, "n", observed = nrow(d), expected = 10)
#'
#' # recomputing both reproduces them
#' res <- manifest_recompute(m, d, list(mean_x = function(z) mean(z$x),
#'                                      n = function(z) nrow(z)))
#' res$ok
#' res$results[, c("name", "recorded", "recomputed", "status")]
#'
#' # recomputing one leaves the other reported as unchecked
#' manifest_recompute(m, d, list(n = function(z) nrow(z)))$unchecked
#'
#' # and data that no longer matches the record is caught
#' manifest_recompute(m, data.frame(x = 1:11),
#'                    list(n = function(z) nrow(z)))$ok
#' @export
manifest_recompute <- function(manifest, data, statistics, tol = NULL) {
  if (!is.list(manifest) || is.null(manifest$results)) {
    stop("`manifest` must be a manifest with recorded results",
         call. = FALSE)
  }
  if (!is.list(statistics) || !length(statistics) ||
      is.null(names(statistics)) || any(!nzchar(names(statistics)))) {
    stop("`statistics` must be a non-empty named list of functions",
         call. = FALSE)
  }
  if (!all(vapply(statistics, is.function, logical(1)))) {
    stop("every element of `statistics` must be a function", call. = FALSE)
  }
  rows <- lapply(names(statistics), function(nm) {
    rec <- manifest$results[[nm]]
    got <- tryCatch(statistics[[nm]](data), error = function(e) e)
    if (inherits(got, "error")) {
      return(data.frame(name = nm, recorded = NA_real_,
                        recomputed = NA_real_, delta = NA_real_,
                        tol = NA_real_, status = "ERROR",
                        detail = conditionMessage(got),
                        stringsAsFactors = FALSE))
    }
    if (is.null(rec)) {
      return(data.frame(name = nm, recorded = NA_real_,
                        recomputed = .rmbl_num_or_na(got),
                        delta = NA_real_, tol = NA_real_,
                        status = "NOT_RECORDED",
                        detail = "the manifest has no result of this name",
                        stringsAsFactors = FALSE))
    }
    use_tol <- if (!is.null(tol)) as.numeric(tol)[1L] else
      if (is.null(rec$tol)) 0 else as.numeric(rec$tol)[1L]
    # A non-numeric result is compared by identity: a recorded label
    # that changed is as much a discrepancy as a number that moved.
    if (!is.numeric(rec$observed) || !is.numeric(got)) {
      same <- identical(as.character(rec$observed)[1L],
                        as.character(got)[1L])
      return(data.frame(name = nm,
                        recorded = .rmbl_num_or_na(rec$observed),
                        recomputed = .rmbl_num_or_na(got),
                        delta = NA_real_, tol = use_tol,
                        status = if (same) "MATCH" else "DIFFER",
                        detail = sprintf("recorded '%s', recomputed '%s'",
                                         as.character(rec$observed)[1L],
                                         as.character(got)[1L]),
                        stringsAsFactors = FALSE))
    }
    d <- abs(as.numeric(rec$observed)[1L] - as.numeric(got)[1L])
    data.frame(name = nm, recorded = as.numeric(rec$observed)[1L],
               recomputed = as.numeric(got)[1L], delta = d,
               tol = use_tol,
               status = if (d <= use_tol) "MATCH" else "DIFFER",
               detail = sprintf("|recorded - recomputed| = %.17g", d),
               stringsAsFactors = FALSE)
  })
  df <- do.call(rbind, rows)
  rownames(df) <- NULL
  unchecked <- setdiff(names(manifest$results), names(statistics))
  out <- list(ok = all(df$status == "MATCH") && length(unchecked) == 0L,
              results = df, unchecked = unchecked)
  class(out) <- c("bricklayer_recompute", "list")
  out
}

#' @export
format.bricklayer_recompute <- function(x, ...) {
  c(.rmbl_rule(sprintf("Recomputation: %s",
                       if (x$ok) "everything checked and matched" else
                         "see below")),
    sprintf("  %-24s %-10s %s", x$results$name, x$results$status,
            substring(x$results$detail, 1L, 40L)),
    if (length(x$unchecked))
      c(.rmbl_rule(),
        sprintf("  %d recorded result(s) NOT recomputed: %s",
                length(x$unchecked),
                paste(utils::head(x$unchecked, 8L), collapse = ", "))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_recompute <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

.rmbl_num_or_na <- function(x) {
  v <- suppressWarnings(as.numeric(x)[1L])
  if (length(v) != 1L) NA_real_ else v
}

#' Record and restore the random number generator state
#'
#' `manifest_record_seed()` stores the generator's kind and its full
#' state in the manifest; `manifest_restore_seed()` puts both back.
#' Together they let a run that used randomness be repeated exactly.
#'
#' Why the state and not just a seed. `set.seed(1)` is reproducible
#' only if everything before it is too: a single extra draw anywhere
#' upstream shifts every subsequent value. Recording `.Random.seed` as
#' it stood pins the actual position in the stream, and recording
#' `RNGkind()` alongside it pins what that position means -- R has
#' changed its default `sample()` algorithm before, and a seed
#' replayed under a different kind gives different numbers with no warning.
#'
#' This is opt-in because the state is 626 integers, which is a lot of
#' manifest for an analysis with no randomness in it.
#'
#' @param manifest A manifest, as from
#' [make_manifest()].
#' @return `manifest_record_seed()` the manifest with an `rng`
#' element; `manifest_restore_seed()` the manifest, invisibly, having
#' set the generator.
#' @seealso
#' [capture_environment()],
#' [capsule_falsify()].
#' @examples
#' set.seed(42)
#' m <- manifest_record_seed(make_manifest(list(a = 1),
#'                                         environment = FALSE))
#' first <- runif(3)
#'
#' # any amount of other work can happen in between
#' invisible(runif(1000))
#'
#' manifest_restore_seed(m)
#' identical(runif(3), first)
#' @export
manifest_record_seed <- function(manifest) {
  if (!is.list(manifest)) {
    stop("`manifest` must be a manifest from make_manifest()",
         call. = FALSE)
  }
  has <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (!has) {
    # Drawing once is what creates the state; without this the record
    # would say "no seed" and a later restore would have nothing to
    # restore to.
    stats::runif(1L)
  }
  manifest$rng <- list(
    kind = RNGkind(),
    state = as.integer(get(".Random.seed", envir = globalenv())),
    was_initialised = has
  )
  manifest
}

#' @rdname manifest_record_seed
#' @export
manifest_restore_seed <- function(manifest) {
  rng <- manifest[["rng"]]
  if (is.null(rng) || is.null(rng$state) || is.null(rng$kind)) {
    stop("this manifest carries no recorded generator state; ",
         "manifest_record_seed() adds one", call. = FALSE)
  }
  kind <- as.character(unlist(rng$kind))
  if (length(kind) < 3L) kind <- c(kind, rep(NA_character_, 3L))[1:3]
  suppressWarnings(RNGkind(kind[1], kind[2], kind[3]))
  assign(".Random.seed", as.integer(unlist(rng$state)),
         envir = globalenv())
  invisible(manifest)
}

#' Where each loaded package came from
#'
#' Records, for every package named, its version and enough about its
#' provenance to find the same one again: the library it was loaded from,
#' the repository it was installed from, and -- for a package installed
#' from a remote -- the remote's URL and commit.
#'
#' Why versions alone are not enough. Two installations can report the same
#' version and differ: one built from CRAN, one from a fork, one from a
#' local `R CMD INSTALL` of a working tree with uncommitted changes. A
#' version number identifies an intention; the repository and commit
#' identify what was actually loaded.
#'
#' @param packages Character vector of package names.
#' Defaults to the namespaces currently loaded.
#' @return A data frame with one row per package: `package`,
#' `version`, `library`, `repository`, `remote_url`,
#' `remote_sha`, `built`. Unavailable fields are `NA` rather
#' than omitted, so a reader can see that the information was absent rather
#' than forgotten.
#' @seealso
#' [capture_environment()],
#' [environment_diff()].
#' @examples
#' deps <- capture_dependencies(c("stats", "utils"))
#' deps[, c("package", "version")]
#'
#' # a package with no repository field records that fact
#' is.na(capture_dependencies("stats")$repository)
#' @export
capture_dependencies <- function(packages = loadedNamespaces()) {
  packages <- sort(unique(as.character(packages)))
  field <- function(d, nm) {
    if (is.null(d) || !nm %in% names(d)) return(NA_character_)
    v <- d[[nm]]
    if (is.null(v) || !nzchar(as.character(v)[1L])) return(NA_character_)
    as.character(v)[1L]
  }
  rows <- lapply(packages, function(p) {
    d <- tryCatch(utils::packageDescription(p), error = function(e) NULL)
    if (inherits(d, "try-error") || !is.list(d)) d <- NULL
    data.frame(
      package    = p,
      version    = tryCatch(as.character(utils::packageVersion(p)),
                            error = function(e) NA_character_),
      library    = tryCatch(dirname(dirname(system.file(package = p))),
                            error = function(e) NA_character_),
      repository = field(d, "Repository"),
      remote_url = field(d, "RemoteUrl"),
      remote_sha = field(d, "RemoteSha"),
      built      = field(d, "Built"),
      stringsAsFactors = FALSE)
  })
  if (!length(rows)) {
    # An empty request returns an empty FRAME, not NULL: a caller that
    # rbinds or indexes the result should not have to special-case the
    # zero-package case.
    return(data.frame(package = character(0), version = character(0),
                      library = character(0), repository = character(0),
                      remote_url = character(0), remote_sha = character(0),
                      built = character(0), stringsAsFactors = FALSE))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}
