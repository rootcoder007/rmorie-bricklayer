# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Categorical-integrity guards. Category-mapping errors are among the most
# damaging silent failures in applied statistics: numeric codes imported
# from another package without their value labels, positional recodes
# that reassign groups wholesale, and alphabetical releveling that
# silently changes the reference category. Any of them can relabel entire
# demographic groups and multiply a reported odds ratio severalfold
# without a warning, and the blame then lands on the software that
# carried the data across. These functions make every recode explicit and
# name-based, refuse anything unmapped, audit imported columns for the
# known hazards, prove a recode with a before/after cross-tabulation,
# verify recoded counts against the counts a release published, check
# reported odds ratios against a labelled table under every relabelling,
# and record the whole chain in a manifest that can be signed.

.rmbl_squote <- function(v) paste0("\u2018", v, "\u2019")

.rmbl_label_perms <- function(v) {
  n <- length(v)
  if (n <= 1L) {
    return(list(v))
  }
  out <- list()
  for (i in seq_len(n)) {
    for (rest in .rmbl_label_perms(v[-i])) {
      out[[length(out) + 1L]] <- c(v[i], rest)
    }
  }
  out
}

#' Decode numeric category codes with an explicit code-to-label dictionary
#'
#' The guard for data that arrives from SPSS, Stata or SAS as integer codes:
#' every code observed must be listed in `value_labels`, and the result is
#' the label, never the code. A code without a label is an error, because
#' treating codes as categories (or `as.numeric()` on a factor of them) is
#' how groups get renumbered.
#'
#' @param x Numeric or character vector of codes.
#' @param value_labels Named character vector:
#'   `c("1" = "White", "2" = "Black", ...)`
#'   with the codes as names.
#' @param keep_na Logical; `NA` codes stay `NA` (default) rather than error.
#' @return A character vector of labels with a `recode_audit` attribute.
#' @examples
#' decode_codes(c(1, 2, 2, 3),
#'              c("1" = "White", "2" = "Black", "3" = "Indigenous"))
#' @export
decode_codes <- function(x, value_labels, keep_na = TRUE) {
  if (is.factor(x)) x <- as.character(x)
  codes <- as.character(x)
  if (!is.character(value_labels) || is.null(names(value_labels)) ||
        !all(nzchar(names(value_labels)))) {
    stop("decode_codes: `value_labels` must be a named character vector ",
      "with the codes as names",
      call. = FALSE
    )
  }
  if (!keep_na && anyNA(codes)) {
    stop("decode_codes: `x` has missing codes and keep_na = FALSE",
      call. = FALSE
    )
  }
  guard_recode(codes, value_labels)
}

#' Recode a categorical column by explicit name-to-name mapping
#'
#' Every mapping is written `old_label = "new_label"` by name; positional and
#' index-based recoding are impossible, and any value not covered by the
#' mapping is an error (never a silent `NA` or pass-through) unless listed
#' in `keep`. The result carries a `recode_audit` attribute with the mapping
#' and its SHA-256, so the mapping that was applied is on the record.
#'
#' @param x A factor or character vector.
#' @param mapping Named character vector: `c(old_label = "new_label", ...)`.
#' @param keep Optional character vector of labels allowed to pass through
#'   unchanged.
#' @return A character vector with a `recode_audit` attribute
#'   (`mapping`, `kept`, `checksum`).
#' @examples
#' guard_recode(c("W", "B", "O", "W"), c(W = "White", B = "Black", O = "Other"))
#' @seealso \code{\link{verify_recode}} to prove the recode,
#'   \code{\link{guard_levels}} to fix the levels,
#'   \code{\link{recode_manifest}} to record the chain.
#' @export
guard_recode <- function(x, mapping, keep = character()) {
  if (is.factor(x)) x <- as.character(x)
  if (!is.character(mapping) || is.null(names(mapping)) ||
        !all(nzchar(names(mapping)))) {
    stop("guard_recode: `mapping` must be a named character vector",
      call. = FALSE
    )
  }
  seen <- unique(x[!is.na(x)])
  unmapped <- setdiff(seen, c(names(mapping), keep))
  if (length(unmapped)) {
    stop("guard_recode: values with NO mapping: ",
      paste(.rmbl_squote(unmapped), collapse = ", "),
      ". Every observed category must be mapped by name (or listed in ",
      "`keep`); silent pass-through is how group labels get corrupted.",
      call. = FALSE
    )
  }
  out <- ifelse(is.na(x), NA_character_,
    ifelse(x %in% names(mapping), unname(mapping[x]), x)
  )
  attr(out, "recode_audit") <- list(
    mapping = mapping, kept = keep,
    checksum = core_sha256(charToRaw(
      paste(names(mapping), mapping, sep = "=", collapse = ";")
    ))
  )
  out
}

#' Build a factor with explicit, verified levels
#'
#' `factor(x)` orders levels alphabetically, which silently decides the
#' reference category of every downstream regression. This constructor
#' requires the level set to be written out, errors on values outside it,
#' and asserts the declared reference level.
#'
#' @param x Character (or factor) vector.
#' @param levels Complete character vector of allowed levels, in the intended
#'   order; the first is the reference category.
#' @param reference Optional; assert which level is the reference (must equal
#'   `levels[1]`).
#' @return A factor with exactly the declared levels.
#' @examples
#' guard_levels(c("White", "Black", "White"), c("White", "Black"), "White")
#' @export
guard_levels <- function(x, levels, reference = NULL) {
  if (!is.character(levels) || !length(levels) || any(is.na(levels))) {
    stop("`levels` must be a non-empty character vector", call. = FALSE)
  }
  if (is.factor(x)) x <- as.character(x)
  stray <- setdiff(unique(x[!is.na(x)]), levels)
  if (length(stray)) {
    stop("guard_levels: values outside the declared levels: ",
      paste(.rmbl_squote(stray), collapse = ", "),
      call. = FALSE
    )
  }
  if (!is.null(reference) && !identical(reference, levels[1L])) {
    stop("guard_levels: declared reference ", .rmbl_squote(reference),
      " is not levels[1] (", .rmbl_squote(levels[1L]), "); reorder ",
      "`levels` so the reference is explicit and first.",
      call. = FALSE
    )
  }
  factor(x, levels = levels)
}

#' Audit the categorical columns of a data frame for coding hazards
#'
#' One call after every import, before any model. Reports, per categorical
#' column: storage, levels in order, the reference level R would use, and
#' the known hazards: numeric-looking labels (codes imported without their
#' value labels), still-labelled foreign columns, case-variant duplicate
#' labels, unused levels, and high-cardinality accidents.
#'
#' @param data A data frame.
#' @param cols Columns to audit (default: every factor, character or
#'   labelled column).
#' @return A data frame of class `bricklayer_category_audit` with one row per
#'   column (`column`, `storage`, `n_levels`, `levels`, `reference`,
#'   `hazards`) and a `clean` attribute.
#' @examples
#' audit_categories(data.frame(
#'   race = factor(c("1", "2", "2", "3")),
#'   city = c("Toronto", "toronto", "Ottawa")[c(1, 2, 3, 3)]
#' ))
#' @export
audit_categories <- function(data, cols = NULL) {
  if (!is.data.frame(data)) {
    stop("audit_categories: `data` must be a data frame", call. = FALSE)
  }
  is_cat <- function(v) {
    is.factor(v) || is.character(v) ||
      inherits(v, c("haven_labelled", "labelled"))
  }
  if (is.null(cols)) cols <- names(data)[vapply(data, is_cat, logical(1))]
  rows <- lapply(cols, function(cn) {
    v <- data[[cn]]
    hazards <- character(0)
    if (inherits(v, c("haven_labelled", "labelled"))) {
      hazards <- c(hazards, paste0(
        "still carries foreign value labels: decode ",
        "with decode_codes() BEFORE analysis (the ",
        "numeric codes are NOT the categories)"
      ))
      v <- as.character(v)
    }
    lv <- if (is.factor(v)) {
      levels(v)
    } else {
      as.character(sort(unique(v[!is.na(v)]), method = "radix"))
    }
    obs <- unique(as.character(v[!is.na(v)]))
    if (length(lv) && all(grepl("^[0-9.]+$", lv))) {
      hazards <- c(hazards, paste0(
        "all labels numeric-looking (",
        paste(utils::head(lv, 4), collapse = ","),
        "...): likely imported CODES whose value labels were lost; ",
        "as.numeric() on this column returns level INDICES, not data"
      ))
    }
    if (length(lv) && all(grepl("^[0-9]+[.):]? ?[A-Za-z]", lv))) {
      hazards <- c(hazards, paste0(
        "labels carry code prefixes (",
        paste(utils::head(lv, 3), collapse = ","),
        "...): the code is part of the string, so the level order is the CODE ",
        "order; any positional relabel with labels in another order rotates ",
        "the groups. Decode by code (decode_codes / relabel), never by position"
      ))
    }
    inv <- "[\\s\u00a0\u1680\u2000-\u200b\u2028\u2029\u202f\u205f\u3000\ufeff]"
    padded <- lv[grepl(paste0("^", inv, "|", inv, "$"), lv, perl = TRUE)]
    if (length(padded)) {
      hazards <- c(hazards, paste0(
        "labels with leading/trailing whitespace (incl. non-breaking): ",
        paste(.rmbl_squote(padded), collapse = ", "),
        ": a space splits one category into two"
      ))
    }
    core <- gsub(paste0("^", inv, "+|", inv, "+$"), "", lv, perl = TRUE)
    if (anyDuplicated(core)) {
      hazards <- c(hazards, paste0(
        "whitespace-variant duplicate labels: ",
        paste(.rmbl_squote(lv[core %in% core[duplicated(core)]]),
              collapse = ", ")
      ))
    }
    if (any(!nzchar(core))) {
      hazards <- c(
        hazards,
        "empty-string label \"\": missingness stored as a category"
      )
    }
    sentinels <- c("NA", "N/A", "NAN", "NULL", "NONE", ".", "-", "?")
    sentinel <- lv[toupper(core) %in% sentinels]
    if (length(sentinel)) {
      hazards <- c(hazards, paste0(
        "missing-value sentinel stored as a label: ",
        paste(.rmbl_squote(sentinel), collapse = ", ")
      ))
    }
    if (length(lv) && (!nzchar(core[1]) || lv[1] != core[1] ||
                         lv[1] %in% sentinel)) {
      hazards <- c(hazards, paste0(
        "the REFERENCE level ", .rmbl_squote(lv[1]),
        " is empty, a sentinel, or differs from a real label only by ",
        "invisible characters: every model on this column is baselined on it"
      ))
    }
    lc <- tolower(core)
    # a case-variant pair is two DIFFERENT trimmed labels that agree once
    # lower-cased; a pair that differs only by whitespace was reported above
    case_groups <- split(core, lc)
    is_pair <- vapply(case_groups, function(g) length(unique(g)) > 1L, TRUE)
    case_groups <- case_groups[is_pair]
    if (length(case_groups)) {
      cv <- lv[lc %in% names(case_groups)]
      hazards <- c(hazards, paste0(
        "case-variant duplicate labels: ",
        paste(.rmbl_squote(cv), collapse = ", ")
      ))
    }
    if (is.factor(v) && length(setdiff(lv, obs))) {
      hazards <- c(hazards, paste0(
        "unused levels: ",
        paste(.rmbl_squote(setdiff(lv, obs)), collapse = ", ")
      ))
    }
    if (length(lv) > 50L) {
      hazards <- c(hazards, paste0(
        length(lv), " levels: identifier mistaken for a category?"
      ))
    }
    data.frame(
      column = cn, storage = paste(class(data[[cn]]), collapse = "/"),
      n_levels = length(lv), levels = paste(utils::head(lv, 8), collapse = "|"),
      reference = if (length(lv)) lv[1] else NA_character_,
      hazards = if (length(hazards)) paste(hazards, collapse = " ;; ") else "",
      stringsAsFactors = FALSE
    )
  })
  out <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      column = character(), storage = character(), n_levels = integer(),
      levels = character(), reference = character(), hazards = character(),
      stringsAsFactors = FALSE
    )
  }
  attr(out, "clean") <- !any(nzchar(out$hazards))
  class(out) <- c("bricklayer_category_audit", "data.frame")
  out
}

#' @export
print.bricklayer_category_audit <- function(x, ...) {
  cat("Categorical audit:", nrow(x), "column(s)\n")
  for (i in seq_len(nrow(x))) {
    cat(sprintf(
      "  %-16s %-10s %d level(s), reference %s\n", x$column[i],
      x$storage[i], x$n_levels[i], .rmbl_squote(x$reference[i])
    ))
    if (nzchar(x$hazards[i])) {
      for (h in strsplit(x$hazards[i], " ;; ", fixed = TRUE)[[1]]) {
        cat("    !! HAZARD:", h, "\n")
      }
    }
  }
  if (isTRUE(attr(x, "clean"))) cat("  no hazards detected\n")
  invisible(x)
}

#' Prove a recode with a before/after cross-tabulation
#'
#' Cross-tabulates the original against the recoded values and errors unless
#' the realized mapping is a function (each old category to exactly one new
#' category) that matches the declared mapping, with no rows lost and no
#' change in missingness.
#'
#' @param original,recoded Parallel vectors (before and after).
#' @param declared Named character vector: the mapping the analyst claims was
#'   applied. Identity is assumed for old values absent from `declared`.
#' @return Invisibly, the cross-tabulation as a data frame, if and only if
#'   every check passes.
#' @examples
#' verify_recode(
#'   c("W", "B", "W"), c("White", "Black", "White"),
#'   c(W = "White", B = "Black")
#' )
#' @export
verify_recode <- function(original, recoded, declared) {
  if (!is.atomic(original) || is.null(original) ||
        !is.atomic(recoded) || is.null(recoded)) {
    stop("`original` and `recoded` must be atomic vectors", call. = FALSE)
  }
  if (is.factor(original)) original <- as.character(original)
  if (is.factor(recoded)) recoded <- as.character(recoded)
  if (length(original) != length(recoded)) {
    stop("verify_recode: length mismatch (", length(original), " vs ",
      length(recoded), "): rows were lost or duplicated during the recode.",
      call. = FALSE
    )
  }
  if (!identical(is.na(original), is.na(recoded))) {
    stop("verify_recode: missingness changed during the recode (values ",
      "silently became NA, or NAs were filled).",
      call. = FALSE
    )
  }
  ok <- !is.na(original)
  tab <- table(original = original[ok], recoded = recoded[ok])
  fan_out <- rowSums(tab > 0)
  if (any(fan_out > 1L)) {
    stop("verify_recode: original category mapped to MULTIPLE new categories: ",
      paste(.rmbl_squote(names(fan_out)[fan_out > 1L]), collapse = ", "),
      ". The recode is not a function of the category label.",
      call. = FALSE
    )
  }
  realized <- apply(tab, 1L, function(r) colnames(tab)[which(r > 0)])
  for (old in names(realized)) {
    expected <- if (old %in% names(declared)) unname(declared[old]) else old
    if (!identical(realized[[old]], expected)) {
      stop("verify_recode: ", .rmbl_squote(old), " was mapped to ",
        .rmbl_squote(realized[[old]]), " but the declared mapping says ",
        .rmbl_squote(expected), ". THIS is how groups get swapped; fix the ",
        "recode before any model runs.",
        call. = FALSE
      )
    }
  }
  invisible(as.data.frame(tab))
}

#' Verify recoded category counts against the counts a release published
#'
#' After a recode, the number of rows per label must equal the counts the
#' source published for those labels. If they do not, every permutation of
#' the labels is tried and the one under which the observed counts match the
#' published ones is named: the signature of labels attached to the wrong
#' groups.
#'
#' @param x A character or factor vector after recoding.
#' @param published Named numeric vector: label = published count.
#' @param tolerance Absolute count tolerance per label (default 0).
#' @param strict When `TRUE` (the default) a mismatch is an error, so a
#'   pipeline stops on the day. When `FALSE` the result is returned with
#'   `ok = FALSE`, the `permutation` that would explain the counts, and the
#'   `message` the error would have carried, for callers that want to
#'   report or hand the permutation to [relabel_forensics()].
#' @return Invisibly, a list with `counts`, `published`, `ok`,
#'   `permutation` (the relabelling that matches, or `NULL`) and `message`
#'   (`NULL` when `ok`). Errors when the counts disagree and `strict` is
#'   `TRUE`.
#' @examples
#' x <- c("White", "White", "Black", "Indigenous", "White", "Black")
#' verify_marginals(x, c(White = 3, Black = 2, Indigenous = 1))
#' @export
verify_marginals <- function(x, published, tolerance = 0, strict = TRUE) {
  if (is.factor(x)) x <- as.character(x)
  if (!is.numeric(published) || is.null(names(published)) ||
        !all(nzchar(names(published)))) {
    stop("verify_marginals: `published` must be a named numeric vector",
      call. = FALSE
    )
  }
  labs <- names(published)
  obs <- vapply(labs, function(l) sum(!is.na(x) & x == l), numeric(1))
  extra <- setdiff(unique(x[!is.na(x)]), labs)
  if (length(extra)) {
    msg <- paste0(
      "verify_marginals: labels present in the data but not in the ",
      "published counts: ", paste(.rmbl_squote(extra), collapse = ", ")
    )
    if (strict) stop(msg, call. = FALSE)
    return(list(
      counts = obs, published = published[labs], ok = FALSE,
      permutation = NULL, message = msg
    ))
  }
  ok <- all(abs(obs - published[labs]) <= tolerance)
  perm <- NULL
  if (!ok && length(labs) <= 7L) {
    for (p in .rmbl_label_perms(labs)) {
      relabelled <- stats::setNames(obs, p)[labs]
      if (!identical(p, labs) &&
            all(abs(relabelled - published[labs]) <= tolerance)) {
        perm <- stats::setNames(p, labs)
        break
      }
    }
  }
  out <- list(
    counts = obs, published = published[labs], ok = ok, permutation = perm,
    message = NULL
  )
  if (!ok) {
    detail <- paste(
      sprintf("%s: observed %s, published %s", labs, obs, published[labs]),
      collapse = "; "
    )
    hint <- if (!is.null(perm)) {
      moved <- names(perm)[perm != names(perm)]
      paste0(
        " The observed counts match the published ones if the labels are ",
        "permuted (",
        paste(sprintf("%s -> %s", moved, perm[moved]), collapse = ", "),
        "): the labels are attached to the wrong groups."
      )
    } else {
      ""
    }
    out$message <- paste0(
      "verify_marginals: recoded counts do not match the published counts. ",
      detail, ".", hint
    )
    if (strict) stop(out$message, call. = FALSE)
    return(out)
  }
  invisible(out)
}

#' Check reported odds ratios against a labelled table, under every relabelling
#'
#' Given a k-by-2 table of counts (rows = groups, columns = outcome absent,
#' outcome present), a reference group and the odds ratios a report states
#' for the other groups, this recomputes the odds ratios from the table and
#' then under every permutation of the row labels (and with the outcome
#' columns swapped). It says whether the reported values follow from the
#' table as labelled and, if not, which relabelling reproduces them. A
#' four-fold odds ratio that a report gives as thirty-six-fold is typically
#' reproduced exactly by one such permutation.
#'
#' @param counts Numeric matrix with row names (groups) and two columns
#'   (outcome absent, outcome present), in that order.
#' @param reference Row name of the reference group.
#' @param reported Named numeric vector of the reported odds ratios, one per
#'   non-reference row.
#' @param tolerance Relative tolerance for a match (default 0.05).
#' @return A list: `computed`, `reported`, `consistent`, `matches` (a data
#'   frame of the relabellings that reproduce the reported values) and
#'   `verdict`.
#' @examples
#' tab <- matrix(c(900, 100, 700, 300, 400, 600),
#'   ncol = 2, byrow = TRUE,
#'   dimnames = list(c("A", "B", "C"), c("no", "yes"))
#' )
#' odds_ratio_check(tab, "A", c(B = 13.5, C = 3.857))$verdict
#' @export
odds_ratio_check <- function(counts, reference, reported, tolerance = 0.05) {
  counts <- as.matrix(counts)
  if (ncol(counts) != 2L || is.null(rownames(counts))) {
    stop("odds_ratio_check: `counts` must be a k-by-2 matrix with row names ",
      "(groups) and columns outcome-absent, outcome-present.",
      call. = FALSE
    )
  }
  labs <- rownames(counts)
  if (!reference %in% labs) {
    stop("odds_ratio_check: reference ", .rmbl_squote(reference),
      " is not a row of `counts`.",
      call. = FALSE
    )
  }
  others <- setdiff(labs, reference)
  if (is.null(names(reported)) || !all(others %in% names(reported))) {
    stop("odds_ratio_check: `reported` must be named by every ",
      "non-reference row: ",
      paste(.rmbl_squote(others), collapse = ", "),
      call. = FALSE
    )
  }
  reported <- reported[others]
  or_of <- function(m) {
    ref_odds <- m[reference, 2L] / m[reference, 1L]
    vapply(others, function(r) (m[r, 2L] / m[r, 1L]) / ref_odds, numeric(1))
  }
  close_to <- function(a, b) {
    all(is.finite(a) & is.finite(b)) &&
      all(abs(a - b) <= tolerance * pmax(abs(b), .Machine$double.eps))
  }
  computed <- or_of(counts)
  consistent <- close_to(computed, reported)
  rows <- list()
  if (length(labs) <= 7L) {
    for (p in .rmbl_label_perms(labs)) {
      for (swap_cols in c(FALSE, TRUE)) {
        if (identical(p, labs) && !swap_cols) next
        m <- counts
        if (swap_cols) m <- m[, 2:1, drop = FALSE]
        rownames(m) <- p
        m <- m[labs, , drop = FALSE]
        if (close_to(or_of(m), reported)) {
          moved <- labs[p != labs]
          rows[[length(rows) + 1L]] <- data.frame(
            relabelling = if (length(moved)) {
              paste(sprintf("%s -> %s", moved, p[p != labs]), collapse = ", ")
            } else {
              "none"
            },
            outcome_columns_swapped = swap_cols, stringsAsFactors = FALSE
          )
        }
      }
    }
  }
  matches <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(
      relabelling = character(), outcome_columns_swapped = logical(),
      stringsAsFactors = FALSE
    )
  }
  verdict <- if (consistent) {
    "the reported odds ratios follow from the table as labelled"
  } else if (nrow(matches)) {
    paste0(
      "the reported odds ratios do NOT follow from the table as labelled; ",
      "they are reproduced under a relabelling (", matches$relabelling[1L],
      if (matches$outcome_columns_swapped[1L]) {
        "; outcome columns swapped"
      } else {
        ""
      },
      "): the groups were mislabelled, not the software"
    )
  } else {
    "the reported odds ratios follow from no relabelling of this table"
  }
  list(
    computed = computed, reported = reported, consistent = consistent,
    matches = matches, verdict = verdict
  )
}

#' Refuse a categorical column where a numeric 0/1 treatment is required
#'
#' @param x The column.
#' @param col Its name, for the message.
#' @return `TRUE`, invisibly; errors otherwise.
#' @examples
#' guard_binary(c(0, 1, 1, 0), "treated")
#' @export
guard_binary <- function(x, col) {
  if (is.null(x) || !is.atomic(x)) {
    stop("Column `", col, "` must be an atomic vector", call. = FALSE)
  }
  if (is.factor(x) || is.character(x)) {
    lv <- if (is.factor(x)) levels(x) else unique(as.character(x))
    stop("Column ", .rmbl_squote(col), " is categorical (",
      paste(.rmbl_squote(utils::head(lv, 4)), collapse = ", "),
      "...). Refusing to coerce: as.numeric() on a factor returns level ",
      "INDICES (1, 2, ...), not your data, and a mis-ordered level silently ",
      "relabels every observation. Encode explicitly first, e.g. ",
      "guard_recode() + as.integer(x == \"treated_label\").",
      call. = FALSE
    )
  }
  ux <- unique(x[!is.na(x)])
  if (!all(ux %in% c(0, 1))) {
    stop("Column ", .rmbl_squote(col), " must be binary 0/1 (saw: ",
      paste(utils::head(ux, 5), collapse = ", "), ").",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

#' Record a recode as a manifest that can be signed and verified later
#'
#' The accountable end of the chain: the mapping and its SHA-256, the counts
#' per label before and after, the before/after cross-tabulation check, the
#' match against published counts when given, a timestamp, and (with a key)
#' a signature over the whole record via \code{\link{capsule_sign}}.
#' Written with \code{\link{write_recode_manifest}} and re-checked with
#' \code{\link{verify_recode_manifest}},
#' so a later reader can prove which labels went where and that nothing was
#' changed afterwards.
#'
#' @param original,recoded Parallel vectors (before and after the recode).
#' @param mapping The named mapping that was applied.
#' @param published Optional named numeric vector of published counts per
#'   recoded label.
#' @param key Optional signing key (from \code{\link{pqc_keygen}} or
#'   \code{\link{fips_keygen}});
#'   when given the manifest carries a signature and the public key.
#' @param context Optional free-text context (dataset, table, analyst).
#' @return A list of class `bricklayer_recode_manifest`.
#' @examples
#' x <- c("W", "B", "W", "I")
#' y <- guard_recode(x, c(W = "White", B = "Black", I = "Indigenous"))
#' m <- recode_manifest(x, y, c(W = "White", B = "Black", I = "Indigenous"),
#'   published = c(White = 2, Black = 1, Indigenous = 1)
#' )
#' m$checks
#' @export
recode_manifest <- function(original, recoded, mapping, published = NULL,
                            key = NULL, context = NULL) {
  verify_recode(original, recoded, mapping)
  marg <- if (!is.null(published)) {
    verify_marginals(recoded, published)
  } else {
    NULL
  }
  before <- table(as.character(original), useNA = "no")
  after <- table(as.character(recoded), useNA = "no")
  body <- list(
    context = if (is.null(context)) "" else as.character(context)[1L],
    created = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    mapping = as.list(mapping),
    mapping_sha256 = core_sha256(charToRaw(
      paste(names(mapping), mapping, sep = "=", collapse = ";")
    )),
    n = length(original), n_missing = sum(is.na(original)),
    counts_before = as.list(stats::setNames(as.numeric(before), names(before))),
    counts_after = as.list(stats::setNames(as.numeric(after), names(after))),
    checks = list(
      crosstab_is_function = TRUE, missingness_unchanged = TRUE,
      matches_published = if (is.null(marg)) NA else isTRUE(marg$ok)
    ),
    published = if (is.null(published)) NULL else as.list(published)
  )
  body$body_sha256 <- core_sha256(charToRaw(bricklayer_json_to_json(body)))
  if (!is.null(key)) {
    sig <- capsule_sign(body$body_sha256, key)
    sig$key_state <- NULL
    body$signature <- unclass(sig)
    body$public_key <- unclass(if (inherits(key, "bricklayer_signing_key")) {
      signing_public_key(key)
    } else {
      fips_public_key(key)
    })
  }
  class(body) <- c("bricklayer_recode_manifest", "list")
  body
}

#' Write and verify a recode manifest
#'
#' @param manifest A [recode_manifest()].
#' @param path File to write (JSON).
#' @return `write_recode_manifest()` returns the path invisibly.
#' @examples
#' x <- c("W", "B", "W")
#' y <- guard_recode(x, c(W = "White", B = "Black"))
#' m <- recode_manifest(x, y, c(W = "White", B = "Black"))
#' p <- write_recode_manifest(m, tempfile(fileext = ".json"))
#' verify_recode_manifest(p, x, y)$ok
#' @export
write_recode_manifest <- function(manifest, path) {
  if (!inherits(manifest, "bricklayer_recode_manifest")) {
    stop("write_recode_manifest: `manifest` must come from recode_manifest()",
      call. = FALSE
    )
  }
  writeLines(bricklayer_json_to_json(unclass(manifest)), path)
  invisible(path)
}

#' @rdname write_recode_manifest
#' @param original,recoded The vectors to check the manifest against.
#' @return `verify_recode_manifest()` returns a list with `ok`, `reasons`
#'   (character, empty when ok), `signature_ok` (`NA` when unsigned) and the
#'   manifest.
#' @export
verify_recode_manifest <- function(path, original, recoded) {
  m <- bricklayer_json_from_json(paste(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  ))
  reasons <- character(0)
  mapping <- unlist(m$mapping)
  sha <- core_sha256(charToRaw(
    paste(names(mapping), mapping, sep = "=", collapse = ";")
  ))
  if (!identical(sha, m$mapping_sha256)) {
    reasons <- c(
      reasons,
      "mapping checksum does not match the mapping in the manifest"
    )
  }
  check <- m
  check$body_sha256 <- NULL
  check$signature <- NULL
  check$public_key <- NULL
  body_sha <- core_sha256(charToRaw(bricklayer_json_to_json(check)))
  if (!identical(body_sha, m$body_sha256)) {
    reasons <- c(reasons, "manifest body was altered after it was written")
  }
  r <- tryCatch(
    {
      verify_recode(original, recoded, mapping)
      TRUE
    },
    error = function(e) conditionMessage(e)
  )
  if (!isTRUE(r)) reasons <- c(reasons, r)
  after <- table(as.character(recoded), useNA = "no")
  after_num <- stats::setNames(as.numeric(after), names(after))
  man_num <- vapply(m$counts_after, as.numeric, numeric(1))
  if (!identical(names(after_num), names(man_num)) ||
        !isTRUE(all.equal(unname(after_num), unname(man_num)))) {
    reasons <- c(reasons, "recoded counts differ from the manifest")
  }
  sig_ok <- NA
  if (!is.null(m$signature)) {
    sig <- m$signature
    class(sig) <- c("bricklayer_signature", "list")
    pk <- m$public_key
    class(pk) <- if (!is.null(pk$root)) {
      c("bricklayer_public_key", "list")
    } else {
      c("bricklayer_fips_public_key", "bricklayer_oqs_public_key", "list")
    }
    sig_ok <- isTRUE(capsule_verify(m$body_sha256, sig, pk))
    if (!sig_ok) reasons <- c(reasons, "signature does not verify")
  }
  list(
    ok = !length(reasons), reasons = reasons, signature_ok = sig_ok,
    manifest = m
  )
}

# ---- positional relabels, labelled imports, and forensics ------------------
# The documented case (OHRC, Correction to "A Disparate Impact", 26 January
# 2023): codes 1 = White, 2 = Black, 3 = Other, 4 = Unknown; the labels in
# alphabetical order are Black, Other, Unknown, White; assigning them by
# position gives exactly the reported rotation (White read as Black, Black
# as Other, Other as Unknown, Unknown as White). Nothing in a file transfer
# picks the sort order of your labels. A positional relabel does.

#' Relabel a categorical variable by name, never by position
#'
#' A relabel is only safe when every old level is mapped BY NAME to its new
#' label. Assigning a vector of labels by position (the `levels<-` idiom,
#' or `factor(x, labels = ...)` with labels in a different order from the
#' codes) is the mechanism behind the documented four-way rotation in the
#' OHRC 2023 correction, so this function refuses unnamed mappings outright.
#'
#' @param x A factor or character vector.
#' @param mapping Named character vector, old label to new label. Every
#'   observed level must appear as a name unless listed in `keep`.
#' @param keep Levels allowed to pass through unchanged.
#' @return A factor with the new labels, levels in the order of `mapping`,
#'   carrying a `recode_audit` attribute (see \code{\link{guard_recode}}).
#' @seealso \code{\link{guard_recode}}, \code{\link{relabel_forensics}},
#'   \code{\link{decode_labelled}}
#' @examples
#' f <- factor(c("W", "B", "O", "W"))
#' relabel(f, c(W = "White", B = "Black", O = "Other"))
#' try(relabel(f, c("Black", "Other", "White")))
#' @export
relabel <- function(x, mapping, keep = character()) {
  if (is.null(names(mapping)) || !all(nzchar(names(mapping)))) {
    stop("relabel: `mapping` must be NAMED (old label = new label). ",
      "Assigning labels by POSITION is how four race codes were rotated ",
      "in a published analysis (OHRC correction, 26 January 2023): the ",
      "labels were in alphabetical order, the codes were not.",
      call. = FALSE
    )
  }
  old <- if (is.factor(x)) {
    levels(x)
  } else {
    as.character(sort(unique(x[!is.na(x)]), method = "radix"))
  }
  unmapped <- setdiff(old, c(names(mapping), keep))
  if (length(unmapped)) {
    stop("relabel: level(s) with NO mapping: ",
      paste(.rmbl_squote(unmapped), collapse = ", "),
      ". Name every level or list it in `keep`.",
      call. = FALSE
    )
  }
  out <- guard_recode(as.character(x), mapping, keep = keep)
  lev <- unique(c(unname(mapping), keep))
  keep_lev <- lev %in% as.character(out) | lev %in% unname(mapping)
  f <- factor(as.character(out), levels = lev[keep_lev])
  attr(f, "recode_audit") <- attr(out, "recode_audit")
  f
}

#' Decode a labelled import by its value labels, by code
#'
#' Vectors read from SPSS, Stata or SAS carry their categories as numeric
#' codes with a `labels` attribute (label = code). The categories are the
#' labels looked up BY CODE; the codes themselves, their order, and the
#' alphabetical order of the labels are all irrelevant, and treating any of
#' them as the category is the documented failure. This function looks each
#' code up in the attribute and refuses codes that have no label.
#'
#' @param x A vector with a `labels` attribute (as produced by haven), or a
#'   plain numeric vector with `value_labels` supplied.
#' @param value_labels Optional named vector, code = label, used when `x`
#'   carries no attribute.
#' @return A factor whose levels are the labels in CODE order (not
#'   alphabetical), with a `recode_audit` attribute.
#' @seealso \code{\link{decode_codes}}, \code{\link{relabel}}
#' @examples
#' x <- structure(c(1, 2, 2, 4),
#'                labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
#' decode_labelled(x)
#' @export
decode_labelled <- function(x, value_labels = NULL) {
  lab <- attr(x, "labels", exact = TRUE)
  if (!is.null(lab)) {
    if (is.null(names(lab))) {
      stop("decode_labelled: the `labels` attribute has no names",
        call. = FALSE
      )
    }
    value_labels <- stats::setNames(names(lab), as.character(unname(lab)))
  }
  if (is.null(value_labels)) {
    stop("decode_labelled: `x` carries no `labels` attribute and ",
      "`value_labels` was not ",
      "supplied; the codes alone are NOT the categories",
      call. = FALSE
    )
  }
  codes <- as.character(unclass(x))
  out <- decode_codes(codes, value_labels)
  code_order <- order(suppressWarnings(as.numeric(names(value_labels))),
                      names(value_labels))
  f <- factor(as.character(out), levels = unname(value_labels[code_order]))
  attr(f, "recode_audit") <- attr(out, "recode_audit")
  f
}

#' Name the mechanical step that reproduces a label permutation
#'
#' When categories came out permuted and the transfer between two programs
#' is being blamed, the question is which deterministic step, applied to
#' the code book, yields exactly the observed permutation. This function
#' tries the known ones: labels sorted alphabetically (or reversed, or
#' case-insensitively) and assigned by code position, labels reversed,
#' every rotation, codes sorted as strings, and labels ordered by frequency
#' when counts are supplied. A match is a reconstruction, not a proof of
#' intent; but a transfer fault has no reason to select the sort order of
#' the labels, so a match on a sort-based mechanism exonerates the software.
#'
#' @param value_labels Named character vector, code = true label, in code
#'   order.
#' @param observed Named character vector, true label = label it was seen
#'   under.
#' @param counts Optional named numeric vector of frequencies per true
#'   label, enabling the frequency-order mechanism.
#' @return A data frame with one row per mechanism (`mechanism`,
#'   `permutation`, `matches`) and a `verdict` attribute.
#' @examples
#' vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
#' obs <- c(White = "Black", Black = "Other", Other = "Unknown",
#'          Unknown = "White")
#' attr(relabel_forensics(vl, obs), "verdict")
#' @export
relabel_forensics <- function(value_labels, observed, counts = NULL) {
  if (is.null(names(value_labels)) || is.null(names(observed))) {
    stop("relabel_forensics: `value_labels` (code = label) and `observed` ",
      "(true = seen) ",
      "must both be named",
      call. = FALSE
    )
  }
  labs <- unname(value_labels)
  k <- length(labs)
  if (!setequal(names(observed), labs) || !setequal(unname(observed), labs)) {
    stop("relabel_forensics: `observed` must be a permutation of the labels ",
      "in `value_labels`",
      call. = FALSE
    )
  }
  obs <- unname(observed[labs])
  mech <- list(
    "labels sorted alphabetically, assigned by code position" =
      sort(labs, method = "radix"),
    "labels sorted case-insensitively, assigned by code position" =
      labs[order(tolower(labs), method = "radix")],
    "labels sorted in reverse, assigned by code position" =
      rev(sort(labs, method = "radix")),
    "labels reversed" = rev(labs),
    "codes sorted as strings, labels assigned in that order" =
      labs[order(as.character(names(value_labels)), method = "radix")]
  )
  for (r in seq_len(k - 1L)) {
    mech[[sprintf("rotation by %d position(s)", r)]] <-
      labs[((seq_len(k) - 1L + r) %% k) + 1L]
  }
  if (!is.null(counts)) {
    cnt <- counts[labs]
    dec <- "labels ordered by decreasing frequency, assigned by code position"
    inc <- "labels ordered by increasing frequency, assigned by code position"
    mech[[dec]] <- labs[order(-as.numeric(cnt), method = "radix")]
    mech[[inc]] <- labs[order(as.numeric(cnt), method = "radix")]
  }
  rows <- lapply(names(mech), function(nm) {
    perm <- mech[[nm]]
    data.frame(
      mechanism = nm,
      permutation = paste(paste0(labs, " -> ", perm), collapse = ", "),
      matches = identical(perm, obs), stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (identical(obs, labs)) {
    out$matches[] <- FALSE
    attr(out, "verdict") <- paste0(
      "The labels are in place: every label was seen under itself, so ",
      "there is no permutation to explain."
    )
    class(out) <- c("bricklayer_relabel_forensics", "data.frame")
    return(out)
  }
  hit <- out$mechanism[out$matches]
  attr(out, "verdict") <- if (length(hit)) {
    paste0(
      "The observed permutation is reproduced EXACTLY by: ",
      paste(hit, collapse = "; "),
      ". No import routine (haven, foreign, pandas, ",
      "pyreadstat) reorders value labels; each carries them keyed by code. A ",
      "transfer fault does not select the sort order of the labels. The step ",
      "that did this was a positional relabel in the analysis, and it is ",
      "reproducible from the code book alone."
    )
  } else {
    paste0(
      "No positional or sort-based mechanism reproduces the observed ",
      "permutation. Look at merges/joins on the category column, manual ",
      "edits, and the file ",
      "itself before blaming either program."
    )
  }
  class(out) <- c("bricklayer_relabel_forensics", "data.frame")
  out
}

#' @export
print.bricklayer_relabel_forensics <- function(x, ...) {
  m <- x[x$matches, , drop = FALSE]
  if (nrow(m)) {
    cat("Mechanism(s) reproducing the observed permutation:\n")
    for (i in seq_len(nrow(m))) {
      cat("  * ", m$mechanism[i], "\n      ", m$permutation[i], "\n", sep = "")
    }
  } else {
    cat("No mechanism among ", nrow(x),
        " reproduces the observed permutation.\n",
        sep = "")
  }
  cat("\n", attr(x, "verdict"), "\n", sep = "")
  invisible(x)
}

#' Verify a categorical variable that crossed from one program to another
#'
#' The transfer that matters is SPSS/Stata/SAS to R or Python: the source
#' program stores codes plus value labels, the destination is handed the
#' codes, and the labels are re-attached in the analysis. This function
#' takes what the source program printed for that variable (its frequency
#' table, label = count, and optionally its code book, code = label) and
#' refuses to continue unless the imported vector reproduces it exactly.
#' Rotated, swapped or positionally relabelled groups fail here, on the day
#' of the import, with the permutation named.
#'
#' @param imported The vector as it arrived: a haven-style labelled vector,
#'   plain codes (with `code_book`), or already-decoded labels.
#' @param source_counts Named numeric vector, label = count, as printed by
#'   the source program (SPSS FREQUENCIES, Stata tabulate).
#' @param code_book Optional named character vector, code = label, from the
#'   source program's variable view. When `imported` carries a `labels`
#'   attribute the two are compared and any disagreement is an error.
#' @param tolerance Passed to \code{\link{verify_marginals}}.
#' @param strict When `TRUE` (the default) any disagreement is an error.
#'   When `FALSE` the result comes back with `ok = FALSE`, `reasons`, and
#'   `marginals$permutation` ready for \code{\link{relabel_forensics}}.
#' @return A list with `ok`, `decoded` (a factor in code order), `marginals`
#'   (the \code{\link{verify_marginals}} result), `code_book_ok` and
#'   `reasons` (character, empty when `ok`).
#' @seealso \code{\link{decode_labelled}}, \code{\link{verify_marginals}},
#'   \code{\link{relabel_forensics}}
#' @examples
#' x <- structure(c(1, 1, 2, 4, 1),
#'                labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
#' transfer_verify(x, c(White = 3, Black = 1, Unknown = 1))$ok
#' @export
transfer_verify <- function(imported, source_counts, code_book = NULL,
                            tolerance = 0, strict = TRUE) {
  lab <- attr(imported, "labels", exact = TRUE)
  code_book_ok <- NA
  if (!is.null(lab) && !is.null(code_book)) {
    got <- stats::setNames(names(lab), as.character(unname(lab)))
    want <- stats::setNames(unname(code_book), as.character(names(code_book)))
    bad <- setdiff(
      union(names(got), names(want)),
      names(got)[names(got) %in% names(want) & got == want[names(got)]]
    )
    code_book_ok <- !length(bad)
    if (!code_book_ok && strict) {
      stop("transfer_verify: the value labels that arrived disagree with the ",
        "source code ",
        "book at code(s) ", paste(bad, collapse = ", "), ": arrived ",
        paste(paste0(bad, "=", got[bad]), collapse = ", "), "; source ",
        paste(paste0(bad, "=", want[bad]), collapse = ", "),
        call. = FALSE
      )
    }
  }
  decoded <- if (!is.null(lab)) {
    decode_labelled(imported)
  } else if (!is.null(code_book)) {
    decode_labelled(imported, value_labels = code_book)
  } else {
    # keep every label that arrived: one absent from the source counts must
    # be reported by the marginals check, never dropped as NA
    lab_all <- as.character(imported)
    seen <- lab_all[!is.na(lab_all)]
    factor(lab_all, levels = unique(c(names(source_counts), seen)))
  }
  m <- verify_marginals(as.character(decoded), source_counts,
    tolerance = tolerance, strict = strict
  )
  ok <- isTRUE(m$ok) && !isFALSE(code_book_ok)
  reasons <- c(
    if (isFALSE(code_book_ok)) {
      "value labels disagree with the source code book"
    },
    if (!isTRUE(m$ok)) m$message
  )
  list(
    ok = ok, decoded = decoded, marginals = m, code_book_ok = code_book_ok,
    reasons = reasons
  )
}
