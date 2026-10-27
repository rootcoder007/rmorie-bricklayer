# SPDX-License-Identifier: AGPL-3.0-or-later
## =====================================================================
## lib_synthetic.R -- schema-driven synthetic data generation
##
## Part of rmorie-bricklayer. The generic primitives here let you build a
## synthetic CSV from a schema definition without writing project-
## specific generator code. Falls back gracefully when the schema is
## under-specified.
##
## Provides:
##   mksyncsv: a schema to a CSV of n rows under a seed
##   mksyncol: one column from its spec
##
## Schema format (from data_provenance.json schema.synthetic_recipe):
##   {
##     "nrows": 75000,                       # target rows
##     "seed":   91735246,                    # reproducible seed
##     "columns": {
##       "EndFiscalYear": {
##         "type":     "sample",
##         "values":   [2023, 2024, 2025],
##         "weights":  [0.33, 0.33, 0.34]     # optional
##       },
##       "Gender": {
##         "type":     "sample",
##         "values":   ["Male", "Female"],
##         "weights":  [0.92, 0.08]
##       },
##       "MentalHealth_Alert": {
##         "type":            "bernoulli",
##         "p":               0.18,
##         "p_with_baserate": 0.15,           # add row-level latent variation
##         "labels":          ["Yes", "No"]
##       },
##       "Number_Of_Placements": {
##         "type":   "poisson",
##         "lambda": 25,
##         "min":    1
##       },
##       "UniqueIndividual_ID": {
##         "type":    "id_pattern",
##         pattern, e.g. year-seq-RC with a 5-digit zero-padded seq,
##         "year_col": "EndFiscalYear"
##       }
##     }
##   }
##
## Licence: AGPL-3.0-or-later
## =====================================================================

#' Generate One Synthetic Column From a Spec
#'
#' @description Builds one column of synthetic (made-up) data from a short
#' specification, such as \dQuote{sample these categories with these weights} or
#' \dQuote{Poisson counts with mean 25}. It is the building block of
#' \code{\link{mksyncsv}}, which assembles a whole table from a recipe. Use
#' synthetic columns to develop and test an analysis pipeline before, or instead
#' of, touching restricted data.
#'
#' @details The supported \code{spec$type}s and the fields each reads (defaults
#' in parentheses): \describe{ \item{\code{"sample"} (the default
#' type)}{\code{values}, a vector or list of categories; \code{weights} (default
#' equal), their probabilities. Drawn with replacement.}
#' \item{\code{"bernoulli"}}{\code{p} (default 0.1), the probability of the
#' first label; \code{labels} (default \code{c("Yes", "No")});
#' \code{p_with_baserate} (default 0), added as \code{p_with_baserate * basep}
#' to give row-level variation when \code{basep} is supplied. A per-row
#' probability above 1 behaves as 1.} \item{\code{"poisson"}}{\code{lambda}
#' (default 1); \code{min} (default 0), a floor: draws below it are raised to it
#' (so the result is not Poisson below the floor).}
#' \item{\code{"id_pattern"}}{\code{pattern} (default \code{"id-\{seq:05d\}"}),
#' in which \code{\{seq:05d\}} becomes a five-digit zero-padded sequence number
#' and \code{\{year\}} the year; \code{year_col}, the name of a column in
#' \code{ctx} whose values supply \code{\{year\}} and restart the sequence
#' within each year. With \code{year_col}, that column must have \code{n}
#' values. No other tokens are recognised.} \item{\code{"sequence"}}{\code{from}
#' (default 1): \code{from, from + 1, ...}.} \item{\code{"fitted"}}{\code{fit},
#' a \code{\link{dstfit}} result, and \code{family} (default the first-ranked
#' converged fit): draws from that fitted distribution.} } Random draws use R's
#' random number generator, so call \code{set.seed()} first for a reproducible
#' column. Errors: \code{spec} not a list; an unknown \code{type}; errors from
#' \code{sample()} or \code{rpois()} on invalid weights or rates.
#'
#' @param spec A list describing the column: \code{type} and the fields
#'   listed in Details. Lists as parsed from JSON (for example
#'   \code{values = list("a", "b")}) are accepted.
#' @param n Whole number: how many values to generate.
#' @param ctx Named list of already-generated columns. Later columns can then
#'   reference earlier ones, as \code{id_pattern} does with a \code{year_col}.
#'   Defaults to an empty list.
#' @param basep Optional numeric vector of per-row latent propensities in
#'   \eqn{[0, 1]}, length \code{n}, used by the \code{"bernoulli"} type to add
#'   row-level variation. Default \code{NULL}.
#' @return A vector for the requested column type: character for
#'   \code{"sample"} of strings, \code{"bernoulli"} and \code{"id_pattern"},
#'   numeric or integer for \code{"poisson"} and \code{"sequence"} (and for
#'   \code{"sample"} of numbers). Its length is \code{n}, except for
#'   \code{"id_pattern"} with a \code{year_col}.
#' @seealso \code{\link{mksyncsv}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' # "sample": categorical draw, optionally weighted.
#' mksyncol(list(
#'   type = "sample", values = list("a", "b"),
#'   weights = list(0.7, 0.3)
#' ), 5)
#'
#' # "bernoulli": two-label draw at probability p.
#' mksyncol(list(
#'   type = "bernoulli", p = 0.5,
#'   labels = list("Yes", "No")
#' ), 5)
#'
#' # "poisson": counts with a floor via min.
#' mksyncol(list(type = "poisson", lambda = 3, min = 1), 5)
#'
#' # "id_pattern": templated IDs (the {seq:05d} token is zero-padded).
#' mksyncol(list(
#'   type = "id_pattern",
#'   pattern = "case-{seq:05d}"
#' ), 3)
#'
#' # ... numbered within each year of an earlier column
#' yrs <- c(2024, 2024, 2025)
#' unname(mksyncol(list(type = "id_pattern",
#'   pattern = "{year}-{seq:05d}", year_col = "year"), 3,
#'   ctx = list(year = yrs)))
#'
#' # "fitted": draws from a distribution fitted by dstfit()
#' f <- dstfit(stats::rexp(100, 2), fams = "exponential", nboot = 0)
#' mksyncol(list(type = "fitted", fit = f), 4)
#'
#' # "sequence": a running integer sequence from from.
#' mksyncol(list(type = "sequence", from = 100), 4)
#'
#' # An unknown type errors.
#' try(mksyncol(list(type = "nope"), 3))
#' @export
mksyncol <- function(spec, n, ctx = list(), basep = NULL) {
  if (!is.list(spec)) {
    stop(
      "mksyncol: `spec` must be a column spec list (type = ..., ...)",
      call. = FALSE
    )
  }
  type <- spec$type %||% "sample"
  if (is.data.frame(spec) || (length(spec) && is.null(names(spec)))) {
    stop(
      "mksyncol: `spec` must be a column spec list (type = ..., ...)",
      call. = FALSE
    )
  }
  n <- .syn_check_col(spec, n, type, basep)
  if (!is.null(basep)) {
    basep <- .rmbl_num(basep, "basep")
  }
  switch(
    type,
    sample = {
      vals <- unlist(spec$values)
      w <- if (!is.null(spec$weights)) unlist(spec$weights) else NULL
      sample(vals, n, replace = TRUE, prob = w)
    },
    bernoulli = .syn_bernoulli(spec, n, basep),
    poisson = {
      lambda <- spec$lambda %||% 1
      out <- stats::rpois(n, lambda = lambda)
      mn <- spec$min %||% 0
      pmax(out, mn)
    },
    id_pattern = .syn_id_pattern(spec, n, ctx),
    fitted = .syn_fitted(spec, n),
    sequence = {
      from <- spec$from %||% 1L
      seq.int(from, length.out = n)
    },
    stop("Unknown synthetic column type: ", type)
  )
}

#' Generate a Synthetic CSV From a Schema Recipe
#'
#' @description
#' Generates a reproducible synthetic data set from a recipe (the
#' \code{schema$synthetic_recipe} block of a provenance object, or a list
#' written by hand) and writes it to a CSV file. Each column is described as
#' in \code{\link{mksyncol}}. Next to the CSV it writes a
#' \code{.synthetic} marker file, so the generated rows can never be
#' mistaken for real data later. Use it to share a runnable version of an
#' analysis without sharing restricted records.
#'
#' @details
#' Columns are produced in declaration order so later columns can reference
#' earlier ones. A shared per-person latent propensity, uniform on
#' \eqn{[0, 1]}, drives every \code{"bernoulli"} column through the column's
#' \code{p_with_baserate} field, so those columns are correlated with each
#' other. An optional \code{row_replication} block (\code{values} and
#' \code{weights}) draws how many rows each person gets: person-level
#' columns are drawn once per person and repeated, while \code{"bernoulli"}
#' columns are drawn once per row. With replication the file therefore has
#' more than \code{nrows} rows.
#'
#' The data are drawn under \code{seed} and the caller's random number
#' stream is restored afterwards, so the same recipe and seed give the same
#' file and the surrounding analysis is not disturbed.
#'
#' Side effects: writes \code{outpath} (overwriting it) and
#' \code{paste0(outpath, ".synthetic")}, a small JSON file with
#' \code{synthetic: true}, the row count, the seed, the recipe's SHA-256 and
#' the time; and marks the R session as having made synthetic data, so a
#' manifest built later in the same session is labelled synthetic. A
#' progress bar is shown in an interactive session.
#'
#' Errors: \code{schema} not a list; any error from
#' \code{\link{mksyncol}}; an unwritable \code{outpath}.
#'
#' @param schema The synthetic recipe: a list with \code{columns} (a named
#'   list of column specs), and optional \code{nrows}, \code{seed} and
#'   \code{row_replication}.
#' @param outpath Character string: the path of the CSV to write.
#' @param nrows Whole number: the number of rows (persons, if replicating)
#'   to generate, from 1 to 100 million (the table is built in memory).
#'   Defaults to \code{schema$nrows}, then 50000.
#' @param seed Random seed for reproducibility. Defaults to
#'   \code{schema$seed}, then 91735246.
#' @return Invisibly, a list of class \code{bricklayer_synthetic} with
#'   \code{path}, \code{sidecar} (the \code{<path>.synthetic} marker file;
#'   \code{\link{vrfcps}} treats its presence as a failed check),
#'   \code{rows} (rows written), \code{seed} (the seed used) and
#'   \code{recipe_sha256} (the recipe's digest, \code{NA} when it could not
#'   be computed). Its print method labels the file as synthetic.
#' @seealso \code{\link{mksyncol}}, \code{\link{vrfcps}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' recipe <- list(
#'   n_rows = 20, seed = 42,
#'   columns = list(
#'     year   = list(type = "sample", values = list(2024, 2025)),
#'     alert  = list(type = "bernoulli", p = 0.2),
#'     visits = list(type = "poisson", lambda = 3, min = 1),
#'     id     = list(type = "id_pattern", pattern = "p-{seq:05d}")
#'   )
#' )
#' out <- tempfile(fileext = ".csv")
#' res <- mksyncsv(recipe, out)
#' res$rows # 20
#' res$seed # 42 (reproducible)
#'
#' # The written CSV round-trips and has the declared columns.
#' df <- utils::read.csv(out)
#' dim(df)
#' names(df)
#'
#' # and the marker file says it is synthetic
#' file.exists(res$sidecar)
#'
#' # nrows overrides the recipe's own row count.
#' mksyncsv(recipe, tempfile(fileext = ".csv"), nrows = 5)$rows
#'
#' # one to three rows per person
#' recipe$row_replication <- list(values = list(1, 2, 3))
#' mksyncsv(recipe, tempfile(fileext = ".csv"), nrows = 5)$rows
#'
#' try(mksyncsv("not a recipe", tempfile()))
#' @export
mksyncsv <- function(schema, outpath, nrows = NULL, seed = NULL) {
  outpath <- .rmbl_string1(outpath, "outpath")
  if (!is.list(schema)) {
    stop("`schema` must be a schema list (columns = ..., ...)", call. = FALSE)
  }
  seed <- seed %||% schema$seed %||% 91735246L
  nrows <- nrows %||% schema$n_rows %||% 50000L
  .syn_check_nrows(nrows)
  # CRAN policy: restore the caller's RNG state on exit.
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    old_seed <- get(".Random.seed", envir = globalenv())
    on.exit(assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  }
  .rmbl_local_seed(seed)

  # base R only when sourced standalone in a bundle: the bar only when the
  # package is there
  pg <- if (exists("blprog", mode = "function")) {
    blprog("synthetic data", length(schema$columns) + 1L)
  }
  if (!is.null(pg)) {
    on.exit(pg$done(), add = TRUE)
  }
  out_df <- .syn_draw(schema, nrows, pg)
  utils::write.csv(out_df, outpath, row.names = FALSE)
  # The CSV stays a plain CSV so every reader opens it; the sidecar beside
  # it is what says the rows were generated (seed, recipe digest), and
  # vrfcps() refuses a capsule whose data file has one. Read back
  # with read.csv() alone the file was indistinguishable from real data.
  recipe_sha256 <- .syn_recipe_sha(schema)
  .rmbl_synth_state$made <- TRUE
  sidecar <- .syn_sidecar(outpath, nrow(out_df), seed, recipe_sha256)
  invisible(structure(
    list(
      path = outpath,
      sidecar = sidecar,
      rows = nrow(out_df),
      seed = seed,
      recipe_sha256 = recipe_sha256
    ),
    class = c("bricklayer_synthetic", "list")
  ))
}

#' @export
format.bricklayer_synthetic <- function(x, ...) {
  title <- "SYNTHETIC data (generated from a recipe, not fetched)"
  # sourced on its own in a capsule bundle the package's block is absent
  if (!exists(".rmbl_res_block", mode = "function")) {
    return(c(
      title,
      sprintf("  file    %s", x$path),
      sprintf("  sidecar %s", x$sidecar),
      sprintf(
        "  rows %d, seed %s, recipe sha256 %s",
        x$rows,
        format(x$seed),
        substr(x$recipe_sha256, 1L, 16L)
      )
    ))
  }
  .rmbl_res_block(
    title,
    facts = list(
      File = x$path,
      Sidecar = x$sidecar,
      Rows = x$rows,
      Seed = format(x$seed),
      `Recipe sha256` = substr(x$recipe_sha256, 1L, 16L)
    ),
    reading = paste(
      "These rows were drawn from a recipe, not fetched from a source. The",
      "sidecar beside the file says so, and vrfcps() refuses a capsule",
      "built on them as real data."
    )
  )
}

#' @export
#' @method print bricklayer_synthetic
print.bricklayer_synthetic <- function(x, ...) {
  if (exists(".rmbl_cat", mode = "function")) {
    .rmbl_cat(format(x, ...), x)
  } else {
    cat(format(x, ...), sep = "\n")
  }
  invisible(x)
}

#' mksyncol()'s row count, base propensities and sample values, checked.
#' @param spec,n,basep As for mksyncol().
#' @param type The column type.
#' @return The row count, a whole number.
#' @noRd
.syn_check_col <- function(spec, n, type, basep) {
  n <- .rmbl_num(n, "n", integer = TRUE)
  if (length(n) != 1L || is.na(n) || n < 0L) {
    stop(
      "mksyncol: `n` must be a single non-negative whole number",
      call. = FALSE
    )
  }
  if (!is.null(basep)) {
    basep <- .rmbl_num(basep, "basep")
    if (anyNA(basep) || any(basep < 0 | basep > 1)) {
      stop("`basep` must be probabilities between 0 and 1", call. = FALSE)
    }
  }
  if (identical(type, "sample") && !length(unlist(spec$values))) {
    stop("a \"sample\" column spec needs `values` to draw from", call. = FALSE)
  }
  n
}

#' An id_pattern column: `{seq:05d}` numbered, within each year when the
#' spec names a year column of `ctx`.
#' @param spec,n,ctx As for mksyncol().
#' @return The ids.
#' @noRd
.syn_id_pattern <- function(spec, n, ctx) {
  pattern <- spec$pattern %||% "id-{seq:05d}"
  year_col <- spec$year_col %||% NULL
  if (!is.null(year_col) && year_col %in% names(ctx)) {
    years <- ctx[[year_col]]
    if (length(years) != n) {
      stop(
        sprintf(
          "`ctx$%s` has %d values but n = %d",
          year_col,
          length(years),
          n
        ),
        call. = FALSE
      )
    }
    seq_per_yr <- stats::ave(seq_along(years), years, FUN = seq_along)
    ids <- mapply(
      function(y, s) {
        out <- gsub("{year}", as.character(y), pattern, fixed = TRUE)
        gsub("{seq:05d}", sprintf("%05d", s), out, fixed = TRUE)
      },
      years,
      seq_per_yr,
      USE.NAMES = FALSE
    )
    return(ids)
  }
  # vapply: gsub vectorises over x, not replacement -- a bare gsub here
  # returned a single id regardless of n.
  vapply(
    seq_len(n),
    function(s) {
      gsub("{seq:05d}", sprintf("%05d", s), pattern, fixed = TRUE)
    },
    character(1)
  )
}

## ----- Main generator -----
## `schema` is the synthetic_recipe sub-block of provenance.
## `outpath` is where to write the CSV.

#' mksyncsv()'s row count, checked: whole, at least one, at most 100 million.
#' @param nrows As for mksyncsv().
#' @noRd
.syn_check_nrows <- function(nrows) {
  # built in memory: a count of rows, and one a machine can hold (2^31 was a
  # process killed for memory; CRAN stress test of 0.5.14). Base R only: a
  # staged bundle sources this file on its own.
  if (
    !is.numeric(nrows) ||
      length(nrows) != 1L ||
      !is.finite(nrows) ||
      nrows < 1 ||
      nrows != round(nrows) ||
      inherits(nrows, c("Date", "POSIXt", "difftime"))
  ) {
    stop("`nrows` must be one whole number of rows, at least 1", call. = FALSE)
  }
  if (nrows > 1e8) {
    stop(
      "`nrows` above 100 million is refused: the synthetic table is ",
      "built in memory",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Rows per person: a draw of the schema's replication values, and the
#' function that repeats a person's values over their rows.
#' @param reps_spec The schema's row_replication, or NULL.
#' @param nrows The persons.
#' @return A list: expand and n_total.
#' @noRd
.syn_replication <- function(reps_spec, nrows) {
  ## Optional: replicate rows per "person" if a multiplier is specified
  if (is.null(reps_spec)) {
    return(list(expand = identity, n_total = nrows))
  }
  n_persons <- nrows
  # index-sample the values: sample(x) with a scalar integer x would
  # expand to 1:x (base R gotcha) and break single-value replication.
  rep_vals <- unlist(reps_spec$values)
  rows_per <- rep_vals[sample.int(
    length(rep_vals),
    n_persons,
    replace = TRUE,
    prob = unlist(reps_spec$weights)
  )]
  expand <- function(x) rep(x, rows_per)
  n_total <- sum(rows_per)
  list(expand = expand, n_total = n_total)
}

#' mksyncsv()'s columns, in declaration order: person-level ones drawn once
#' per person and repeated, bernoulli ones drawn per row.
#' @param schema,nrows As for mksyncsv().
#' @param n_total The rows.
#' @param expand Repeats a person's values over their rows.
#' @param base_p The per-row baseline propensity.
#' @param pg The progress bar, or NULL.
#' @return The columns, a named list.
#' @noRd
.syn_columns <- function(schema, nrows, n_total, expand, base_p, pg) {
  out <- list()
  ctx <- list() # one entry per row
  ctx_person <- list() # one entry per person, before replication
  for (col_name in names(schema$columns)) {
    if (!is.null(pg)) {
      pg$tick(0, sprintf("column %s", col_name))
    }
    spec <- schema$columns[[col_name]]
    type <- spec$type %||% "sample"
    if (identical(type, "bernoulli")) {
      ## one draw per row, not one per person copied across rows
      vals <- mksyncol(spec, n_total, ctx, base_p)
    } else {
      ## person-level columns (ids, demographics, regions): drawn once per
      ## person from the person-level context, then repeated over rows
      vals <- mksyncol(spec, nrows, ctx_person)
      ctx_person[[col_name]] <- vals
      vals <- expand(vals)
    }
    ctx[[col_name]] <- vals
    out[[col_name]] <- vals
    if (!is.null(pg)) pg$tick()
  }
  out
}

#' The `.synthetic` sidecar beside a synthetic CSV: rows, seed, recipe digest
#' and time.
#' @param outpath The CSV.
#' @param rows Its rows.
#' @param seed The seed recorded in the sidecar file.
#' @param recipe_sha256 The schema's digest, or NA.
#' @return The sidecar's path.
#' @noRd
.syn_sidecar <- function(outpath, rows, seed, recipe_sha256) {
  sidecar <- paste0(outpath, ".synthetic")
  jstr <- function(x) {
    paste0("\"", gsub("\"", "\\\"", as.character(x), fixed = TRUE), "\"")
  }
  writeLines(
    c(
      "{",
      "  \"synthetic\": true,",
      sprintf("  \"rows\": %d,", rows),
      sprintf("  \"seed\": %s,", format(seed)),
      sprintf(
        "  \"recipe_sha256\": %s,",
        if (is.na(recipe_sha256)) "null" else jstr(recipe_sha256)
      ),
      sprintf(
        "  \"generated_utc\": %s",
        jstr(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
      ),
      "}"
    ),
    sidecar
  )
  sidecar
}

#' A "bernoulli" column of mksyncol(): two labels, the first with
#' probability `p` plus `p_with_baserate` times the row's propensity.
#' @param spec The column spec.
#' @param n The number of synthetic rows to draw.
#' @param basep The per-row propensity, or NULL.
#' @return A vector of `n` labels.
#' @noRd
.syn_bernoulli <- function(spec, n, basep) {
  p_base <- spec$p %||% 0.1
  p_extra <- spec$p_with_baserate %||% 0
  p_per_row <- if (!is.null(basep)) p_base + p_extra * basep else p_base
  # unlist: schemas parsed from provenance JSON deliver list("Yes","No")
  labels <- unlist(spec$labels %||% c("Yes", "No"))
  ifelse(stats::runif(n) < p_per_row, labels[1], labels[2])
}

#' A "fitted" column of mksyncol(): draws from a dstfit() family.
#' @param spec The column spec.
#' @param n The number of rows drawn from the fitted family.
#' @return A numeric vector of `n` draws.
#' @noRd
.syn_fitted <- function(spec, n) {
  fit <- spec$fit
  if (!inherits(fit, "rmbl_dstfit") || !length(fit$fits)) {
    stop(
      "mksyncol: a \"fitted\" column spec needs `fit`, a dstfit() ",
      "result with a converged fit",
      call. = FALSE
    )
  }
  fam <- spec$family %||% names(fit$fits)[[1L]]
  if (!fam %in% names(fit$fits)) {
    stop(
      sprintf("mksyncol: the fit has no converged %s family", fam),
      call. = FALSE
    )
  }
  .dst_fams()[[fam]]$r(n, fit$fits[[fam]])
}

#' The digest of a synthetic recipe, when mnfdgst() is there to make it.
#' @param schema The recipe.
#' @return A SHA-256 hex string, or NA.
#' @noRd
.syn_recipe_sha <- function(schema) {
  # This file is also sourced standalone inside a staged bundle, where only
  # lib_*.R exist: base R only here (the bundle's lib_manifest.R supplies the
  # digest when it is present; the sidecar is written either way).
  if (exists("mnfdgst", mode = "function")) {
    tryCatch(mnfdgst(schema), error = function(e) NA_character_)
  } else {
    NA_character_
  }
}

#' Draws mksyncsv()'s rows, under the seed already set.
#' @param schema The recipe.
#' @param nrows The number of persons.
#' @param pg The progress bar, or NULL.
#' @return A data frame.
#' @noRd
.syn_draw <- function(schema, nrows, pg) {
  rp <- .syn_replication(schema$row_replication, nrows)
  expand <- rp$expand
  n_total <- rp$n_total

  ## Latent per-person "baseline propensity" -- shared across bernoulli
  ## cols; expanded to one entry per row so replicated rows of a person
  ## share the propensity but draw their own outcome (a person's alert
  ## status can change between placements, which is what the treatment
  ## definition in the analyses rests on).
  base_p <- expand(stats::runif(nrows, 0, 1))

  ## Generate columns in declaration order; later columns can see ctx
  out <- .syn_columns(schema, nrows, n_total, expand, base_p, pg)
  if (!is.null(pg)) {
    pg$tick(0, sprintf("writing %s rows", format(n_total, big.mark = ",")))
  }
  out_df <- as.data.frame(out, stringsAsFactors = FALSE)
  out_df
}
