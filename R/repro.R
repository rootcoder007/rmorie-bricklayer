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
#' Re-evaluates named statistics against \code{data} and compares each to
#' what the manifest recorded. This is the check
#' [verify_capsule()] cannot
#' make: that one confirms the record is internally consistent, which an
#' edited-at-the-time manifest also is. Use it when receiving a capsule, or
#' after a data refresh, to confirm that the numbers in the record still
#' come out of the data.
#'
#' @details
#' Every recorded result that was NOT recomputed is reported too, as
#' \code{unchecked}. An analysis that recorded twenty statistics and
#' re-derives three has seventeen it has not re-derived, and a report that
#' quietly omitted them would read as a clean bill of health.
#'
#' For each function in \code{statistics}, its value on \code{data} is
#' compared with the \code{observed} value recorded under the same name.
#' Numeric results match when they are identical (so the same \code{NA},
#' \code{NaN} or infinite value on both sides matches) or when
#' \eqn{|recorded - recomputed| \le tol}, with
#' \code{tol} the argument if given, else the result's recorded \code{tol},
#' else 0 (exact); any other pair with a missing or non-finite value is
#' \code{"DIFFER"}. A non-numeric result (a label, a verdict) is compared as
#' text and must be identical. A function that errors gives the status
#' \code{"ERROR"} with the message; a name the manifest does not have gives
#' \code{"NOT_RECORDED"}. \code{ok} is \code{TRUE} only when every row is
#' \code{"MATCH"} and nothing recorded was left unchecked. The functions are
#' run as given, so they can read files or draw random numbers; nothing else
#' is changed.
#'
#' Errors: \code{manifest} not a list with \code{results}; \code{statistics}
#' not a non-empty fully named list, or with an element that is not a
#' function.
#'
#' @param manifest A manifest, as from [make_manifest()]
#'   and [record()].
#' @param data The data the statistics are computed from (usually a data
#'   frame); passed unchanged to each function.
#' @param statistics Named list of functions of \code{data}, each returning
#'   one value. Names must match the recorded result names.
#' @param tol Optional numeric tolerance (absolute) overriding each
#'   result's own recorded \code{tol}. Supply it to check more strictly than
#'   the original run did. \code{NULL} (the default) uses the recorded one.
#' @return A list of class \code{c("bricklayer_recompute", "list")}:
#'   \describe{
#'     \item{\code{ok}}{logical, every statistic matched and none was left unchecked.}
#'     \item{\code{results}}{data frame, one row per recomputed statistic, with
#'       \code{name} (character), \code{recorded} and \code{recomputed} (numeric,
#'       \code{NA} for non-numeric values), \code{delta} (numeric absolute
#'       difference), \code{tol} (numeric), \code{status} (\code{"MATCH"},
#'       \code{"DIFFER"}, \code{"NOT_RECORDED"} or \code{"ERROR"}) and \code{detail}
#'       (character explanation).}
#'     \item{\code{unchecked}}{character, the names recorded but not recomputed.}
#'   }
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
#'
#' # a stricter tolerance than the recorded one
#' manifest_recompute(m, d, list(mean_x = function(z) mean(z$x) + 1e-9,
#'                               n = nrow), tol = 0)$results$status
#'
#' # a function that fails is reported, not thrown
#' manifest_recompute(m, d, list(mean_x = function(z) stop("column y is gone"),
#'                               n = nrow))$results[, c("name", "status")]
#'
#' # statistics must be named
#' try(manifest_recompute(m, d, list(function(z) nrow(z))))
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
    r <- as.numeric(rec$observed)[1L]
    g <- as.numeric(got)[1L]
    d <- abs(r - g)
    # identical() first: NA, NaN and Inf recorded and recomputed alike are a
    # match, and a delta of NA (one side missing) is a difference, not a
    # crash of `d <= use_tol`
    same <- identical(r, g) || (!is.na(d) && d <= use_tol)
    data.frame(name = nm, recorded = r,
               recomputed = g, delta = d,
               tol = use_tol,
               status = if (same) "MATCH" else "DIFFER",
               detail = if (is.finite(d)) sprintf("|recorded - recomputed| = %.17g", d) else
                 sprintf("recorded %s, recomputed %s", format(r), format(g)),
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
#' \code{manifest_record_seed()} stores the generator's kind and its full
#' state in the manifest; \code{manifest_restore_seed()} puts both back.
#' Together they let a run that used randomness (a bootstrap, a permutation
#' test, a simulation, a random split) be repeated exactly, even without
#' knowing what seed was set or how many draws came before.
#'
#' @details
#' Why the state and not just a seed. \code{set.seed(1)} is reproducible
#' only if everything before it is too: a single extra draw anywhere
#' upstream shifts every subsequent value. Recording \code{.Random.seed} as
#' it stood pins the actual position in the stream, and recording
#' \code{RNGkind()} alongside it pins what that position means -- R has
#' changed its default \code{sample()} algorithm before, and a seed
#' replayed under a different kind gives different numbers with no warning.
#'
#' This is opt-in because the state is 626 integers for R's default
#' Mersenne-Twister generator, which is a lot of manifest for an analysis
#' with no randomness in it.
#'
#' Side effects: if no generator state exists yet (\code{.Random.seed} is
#' absent from the global environment), \code{manifest_record_seed()} draws
#' one uniform number to create it, and records \code{was_initialised =
#' FALSE}. \code{manifest_restore_seed()} calls \code{RNGkind()} with the
#' recorded kinds and assigns \code{.Random.seed} in the global environment,
#' replacing the current state.
#'
#' Errors: \code{manifest} that is not a list (or is a data frame); for
#' \code{manifest_restore_seed()}, a manifest without a recorded state or with
#' an empty kind.
#'
#' @param manifest A manifest, as from [make_manifest()] (a
#'   list).
#' @return \code{manifest_record_seed()}: the manifest with an \code{rng}
#'   element, a list of \code{kind} (character, the three \code{RNGkind()}
#'   values), \code{state} (integer, the \code{.Random.seed} vector) and
#'   \code{was_initialised} (logical, whether a state existed before the
#'   call). \code{manifest_restore_seed()}: the manifest, invisibly, having
#'   set the generator.
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
#'
#' # what is stored
#' m$rng$kind
#' length(m$rng$state)
#'
#' # a manifest without a recorded state cannot restore one
#' try(manifest_restore_seed(make_manifest(list(a = 1), environment = FALSE)))
#' @export
manifest_record_seed <- function(manifest) {
  if (!is.list(manifest) || is.data.frame(manifest)) {
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
  if (!is.list(manifest) || is.data.frame(manifest)) {
    stop("`manifest` must be a manifest from make_manifest()", call. = FALSE)
  }
  rng <- manifest[["rng"]]
  if (is.null(rng) || is.null(rng$state) || is.null(rng$kind)) {
    stop("this manifest carries no recorded generator state; ",
         "manifest_record_seed() adds one", call. = FALSE)
  }
  # RNGkind() takes up to three names; a record with fewer leaves the
  # rest of the generator settings as they are (NA is not a valid name)
  kind <- as.character(unlist(rng$kind))
  kind <- kind[!is.na(kind) & nzchar(kind)]
  if (!length(kind)) {
    stop("the recorded generator kind is empty", call. = FALSE)
  }
  suppressWarnings(do.call(RNGkind, as.list(kind[seq_len(min(3L, length(kind)))])))
  assign(".Random.seed", as.integer(unlist(rng$state)),
         envir = globalenv())
  invisible(manifest)
}

#' Where each loaded package came from
#'
#' Records, for every package named, its version and enough about its
#' provenance to find the same one again: the library it was loaded from,
#' the repository it was installed from, and -- for a package installed
#' from a remote -- the remote's URL and commit. Store it in a manifest next
#' to [capture_environment()] when an analysis depends
#' on packages installed
#' from GitHub or a local build.
#'
#' @details
#' Why versions alone are not enough. Two installations can report the same
#' version and differ: one built from CRAN, one from a fork, one from a
#' local \code{R CMD INSTALL} of a working tree with uncommitted changes. A
#' version number identifies an intention; the repository and commit
#' identify what was actually loaded.
#'
#' The fields are read from each package's installed DESCRIPTION
#' (\code{utils::packageDescription()}): \code{Repository} (for example
#' \code{"CRAN"}), \code{RemoteUrl} and \code{RemoteSha} (written by
#' remotes, pak and devtools for packages installed from a Git host) and
#' \code{Built}. Packages are sorted and de-duplicated. A progress bar is
#' drawn on stderr for many packages unless \code{options(morie.quiet =
#' TRUE)}. Nothing is written. Error: \code{packages} that is not a character
#' vector.
#'
#' @param packages Character vector of package names.
#'   Defaults to the namespaces currently loaded.
#' @return A data frame with one row per package and character columns
#'   \code{package}, \code{version}, \code{library} (the library directory),
#'   \code{repository}, \code{remote_url}, \code{remote_sha} and \code{built}
#'   (R version, platform and time of the build). Unavailable fields are
#'   \code{NA} rather than omitted, so a reader can see that the information
#'   was absent rather than forgotten; for a package that is not installed,
#'   every field except \code{package} is \code{NA}. An empty \code{packages} gives a
#'   data frame with no
#'   rows and the same columns.
#' @seealso
#' [capture_environment()],
#' [environment_diff()].
#' @examples
#' deps <- capture_dependencies(c("stats", "utils"))
#' deps[, c("package", "version")]
#'
#' # a package with no repository field records that fact
#' is.na(capture_dependencies("stats")$repository)
#'
#' # a package that is not installed is a row of NAs, not an error
#' capture_dependencies("notapackage123")[, c("package", "version")]
#'
#' # names must be character
#' try(capture_dependencies(1))
#' @export
capture_dependencies <- function(packages = loadedNamespaces()) {
  if (!is.null(packages) && !is.character(packages)) {
    stop("`packages` must be a character vector of package names",
         call. = FALSE)
  }
  packages <- sort(unique(as.character(packages)))
  field <- function(d, nm) {
    if (is.null(d) || !nm %in% names(d)) return(NA_character_)
    v <- d[[nm]]
    if (is.null(v) || !nzchar(as.character(v)[1L])) return(NA_character_)
    as.character(v)[1L]
  }
  pg <- bricklayer_progress("reading package descriptions", length(packages))
  on.exit(pg$done(), add = TRUE)
  rows <- lapply(packages, function(p) {
    pg$tick(info = p)
    d <- suppressWarnings(tryCatch(utils::packageDescription(p), error = function(e) NULL))  # absent: an NA row
    if (inherits(d, "try-error") || !is.list(d)) d <- NULL
    data.frame(
      package    = p,
      version    = tryCatch(as.character(utils::packageVersion(p)),
                            error = function(e) NA_character_),
      # system.file() is "" for a package that is not installed, and dirname(dirname("")) is ""
      library    = tryCatch({
        sf <- system.file(package = p)
        if (nzchar(sf)) dirname(sf) else NA_character_
      }, error = function(e) NA_character_),
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
