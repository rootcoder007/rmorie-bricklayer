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
#' @description
#' Turns a vector of category codes (for example \code{1}, \code{2}, \code{3}
#' from an SPSS, Stata or SAS file) into the category labels they stand for,
#' using a code-to-label dictionary that you write out. Every code that occurs
#' in the data must be in the dictionary; a code without a label is an error
#' rather than a silent \code{NA} or a pass-through. Use it whenever a column
#' arrives as numbers that are really categories, before any table or model,
#' so that a group can never be renumbered by treating codes (or
#' \code{as.numeric()} on a factor of them) as the categories.
#'
#' @details
#' \code{x} is converted to character (a factor by its labels, a number by
#' \code{as.character()}, so \code{1} and \code{1.0} both become \code{"1"})
#' and every distinct non-missing code is looked up by name in
#' \code{value_labels}. The lookup itself is done by
#' \code{\link{guard_recode}}, so the result carries the same
#' \code{recode_audit} attribute, including a SHA-256 of the dictionary.
#'
#' Errors:
#' \itemize{
#'   \item \code{value_labels} not a character vector with non-empty names;
#'   \item a code in \code{x} that is not a name of \code{value_labels}
#'     (the message lists the unmapped codes);
#'   \item any \code{NA} in \code{x} when \code{keep_na = FALSE}.
#' }
#' For a haven-style labelled vector, which carries its dictionary as a
#' \code{labels} attribute, use \code{\link{decode_labelled}}, which returns a
#' factor with the levels in code order.
#'
#' @param x Vector of codes: numeric, integer, character or factor. A factor
#'   is read through its labels, not its integer codes.
#' @param value_labels Named character vector, code = label, for example
#'   \code{c("1" = "White", "2" = "Black")}. The names are the codes as they
#'   print with \code{as.character()}; the values are the labels. Codes in the
#'   dictionary that do not occur in \code{x} are allowed.
#' @param keep_na Logical, default \code{TRUE}: \code{NA} codes stay
#'   \code{NA} in the result. \code{FALSE} makes any \code{NA} code an error,
#'   for columns where missingness should not occur.
#' @return A character vector of labels, the same length as \code{x}, with
#'   \code{NA} where \code{x} is \code{NA}. It carries a \code{recode_audit}
#'   attribute: a list with \code{mapping} (the dictionary), \code{kept}
#'   (\code{character(0)}) and \code{checksum} (64-character hexadecimal
#'   SHA-256 of the \code{code=label} pairs).
#' @seealso \code{\link{decode_labelled}}, \code{\link{guard_recode}},
#'   \code{\link{audit_categories}}.
#' @examples
#' # codes from a survey file with their code book
#' race <- c(1, 2, 2, 3, NA)
#' book <- c("1" = "White", "2" = "Black", "3" = "Indigenous")
#' decode_codes(race, book)
#'
#' # the dictionary that was applied is kept on the result
#' attr(decode_codes(race, book), "recode_audit")$checksum
#'
#' # a code with no label is refused, never passed through
#' try(decode_codes(c(1, 2, 9), book))
#'
#' # missing codes can be refused too
#' try(decode_codes(race, book, keep_na = FALSE))
#' @export
decode_codes <- function(x, value_labels, keep_na = TRUE) {
  .rmbl_no_fn(x = x)
  if (is.factor(x)) x <- as.character(x)
  codes <- as.character(x)
  if (!is.character(value_labels) || is.null(names(value_labels)) ||
        !all(nzchar(names(value_labels)))) {
    stop("decode_codes: `value_labels` must be a named character vector ",
      "with the codes as names",
      call. = FALSE
    )
  }
  keep_na <- .rmbl_flag1(keep_na, "keep_na")
  if (!keep_na && anyNA(codes)) {
    stop("decode_codes: `x` has missing codes and keep_na = FALSE",
      call. = FALSE
    )
  }
  guard_recode(codes, value_labels)
}

#' Recode a categorical column by explicit name-to-name mapping
#'
#' @description
#' Recodes a categorical variable with a mapping written out by name,
#' \code{old_label = "new_label"}, so that the recode cannot depend on the
#' order of the levels. Any value that the mapping does not cover is an error
#' unless you list it in \code{keep}; nothing is silently set to \code{NA} or
#' passed through. The result records the mapping and its SHA-256, so the
#' recode that was applied can be shown later. Use it for collapsing or
#' renaming categories (race, offence type, region) before analysis.
#'
#' @details
#' Let \eqn{S} be the set of distinct non-missing values of \code{x}. The
#' function refuses unless \eqn{S \subseteq} \code{names(mapping)} \eqn{\cup}
#' \code{keep}. Each value found in \code{names(mapping)} is replaced by its
#' mapped label; values in \code{keep} are returned unchanged; \code{NA}
#' stays \code{NA}. Several old labels may map to the same new label (a
#' collapse). Matching is exact: case and whitespace count.
#'
#' The checksum is \code{\link{core_sha256}} of the string
#' \code{"old1=new1;old2=new2;..."} built from the mapping in its given order,
#' so the same mapping written in a different order has a different checksum.
#'
#' Errors: \code{mapping} not a character vector with non-empty names; any
#' observed value that is neither mapped nor kept (the message lists them).
#'
#' \code{\link{relabel}} is the same check but returns a factor;
#' \code{\link{verify_recode}} proves the result against the declared mapping;
#' \code{\link{recode_manifest}} records it.
#'
#' @param x A factor or character vector (other atomic vectors are compared
#'   through \code{as.character()} matching of their values).
#' @param mapping Named character vector, \code{c(old_label = "new_label", ...)}.
#'   Every name must be non-empty.
#' @param keep Character vector, default empty. Labels allowed to pass
#'   through unchanged.
#' @return A character vector the same length as \code{x}, with a
#'   \code{recode_audit} attribute: a list with \code{mapping} (the mapping as
#'   given), \code{kept} (the \code{keep} vector) and \code{checksum}
#'   (hexadecimal SHA-256 of the mapping).
#' @examples
#' # rename three codes
#' x <- c("W", "B", "O", "W", NA)
#' guard_recode(x, c(W = "White", B = "Black", O = "Other"))
#'
#' # collapse two categories and let one pass through unchanged
#' off <- c("assault", "robbery", "theft", "fraud")
#' guard_recode(off, c(assault = "violent", robbery = "violent",
#'                     theft = "property"), keep = "fraud")
#'
#' # a value with no mapping is an error
#' try(guard_recode(x, c(W = "White", B = "Black")))
#' @seealso \code{\link{verify_recode}} to prove the recode,
#'   \code{\link{guard_levels}} to fix the levels,
#'   \code{\link{recode_manifest}} to record the chain.
#' @export
guard_recode <- function(x, mapping, keep = character()) {
  .rmbl_no_fn(x = x)
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
#' @description
#' Creates a factor whose levels you write out in full and in order, instead
#' of letting \code{factor()} sort them alphabetically. The first level is
#' the reference category of every regression fitted on the factor, so
#' writing the levels out decides the baseline on purpose. Values outside the
#' declared levels are an error, and you can assert which level is the
#' reference so that a later edit to \code{levels} cannot change it unnoticed.
#'
#' @details
#' The function checks that every non-missing value of \code{x} is in
#' \code{levels}, then returns \code{factor(x, levels = levels)}. Declared
#' levels that do not occur are kept as empty levels (they still appear in
#' tables with a count of zero).
#'
#' Errors:
#' \itemize{
#'   \item \code{levels} not a non-empty character vector, or containing \code{NA};
#'   \item a value of \code{x} not in \code{levels} (listed in the message);
#'   \item \code{reference} given and not identical to \code{levels[1]}.
#' }
#'
#' @param x Character or factor vector. A factor is read through its labels.
#' @param levels Character vector of every allowed level, in the intended
#'   order. The first element is the reference category.
#' @param reference Optional character string, default \code{NULL} (no
#'   check). When given it must equal \code{levels[1]}; use it to state the
#'   intended baseline next to the code that fits the model.
#' @return A factor with exactly the levels in \code{levels}, in that order.
#' @seealso \code{\link{guard_recode}}, \code{\link{audit_categories}}.
#' @examples
#' # reference category chosen on purpose, not by alphabet
#' g <- guard_levels(c("White", "Black", "White"), c("White", "Black"), "White")
#' levels(g)
#'
#' # a declared level that does not occur is kept, with a zero count
#' table(guard_levels(c("a", "a"), c("a", "b")))
#'
#' # a stray value, or a reference that is not first, is refused
#' try(guard_levels(c("White", "Blak"), c("White", "Black")))
#' try(guard_levels(c("White", "Black"), c("White", "Black"), reference = "Black"))
#' @export
guard_levels <- function(x, levels, reference = NULL) {
  .rmbl_no_fn(x = x, reference = reference)
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
#' @description
#' Checks every categorical column of a data frame for the coding problems
#' that silently change results: numbers that are really category codes
#' whose labels were lost, labels still in foreign value-label form, labels
#' that differ only by case or by an invisible space, empty strings or
#' \code{"NA"} stored as a category, unused levels, and identifiers mistaken
#' for categories. Run it once after every import, before any model. It also
#' reports which level R will use as the reference category.
#'
#' @details
#' For each column the levels are \code{levels(x)} for a factor and the
#' sorted distinct values (radix sort, as \code{factor()} would order them)
#' otherwise. A hazard is reported when:
#' \itemize{
#'   \item the column is haven \code{labelled} (it still carries value labels
#'     and must be decoded with \code{\link{decode_codes}} or
#'     \code{\link{decode_labelled}});
#'   \item every level looks like a number (\code{^[0-9.]+$});
#'   \item every level starts with a code prefix such as \code{"1. White"};
#'   \item a level has leading or trailing whitespace, including non-breaking
#'     and other Unicode spaces, or two levels are equal once trimmed;
#'   \item a level is empty, or is a missing-value sentinel (\code{NA},
#'     \code{N/A}, \code{NAN}, \code{NULL}, \code{NONE}, \code{.}, \code{-},
#'     \code{?}, compared case-insensitively);
#'   \item the reference (first) level is empty, a sentinel, or padded;
#'   \item two different trimmed levels agree once lower-cased;
#'   \item a factor has levels that never occur;
#'   \item there are more than 50 levels.
#' }
#' The function only reports; it never changes \code{data}. It errors when
#' \code{data} is not a data frame.
#'
#' @param data A data frame.
#' @param cols Character vector of column names to audit, default
#'   \code{NULL}: every factor, character or haven-labelled column. Columns of
#'   other types can be named explicitly and are audited by their distinct
#'   values.
#' @return A data frame of class \code{c("bricklayer_category_audit",
#'   "data.frame")}, one row per audited column, with character columns
#'   \code{column}, \code{storage} (the column's class), \code{levels} (up to
#'   eight levels joined with \code{"|"}), \code{reference} (the first level)
#'   and \code{hazards} (all hazards joined with \code{" ;; "}, or \code{""}),
#'   and integer \code{n_levels}. The attribute \code{clean} is \code{TRUE}
#'   when no hazard was found. The print method lists each column and its
#'   hazards.
#' @seealso \code{\link{decode_codes}}, \code{\link{guard_levels}},
#'   \code{\link{transfer_verify}}.
#' @examples
#' # codes without labels, and a case-variant city name
#' a <- audit_categories(data.frame(
#'   race = factor(c("1", "2", "2", "3")),
#'   city = c("Toronto", "toronto", "Ottawa")[c(1, 2, 3, 3)]
#' ))
#' a
#' attr(a, "clean")
#'
#' # padded, empty and sentinel labels, and an unused level
#' audit_categories(data.frame(
#'   g = factor(c(" A", "A", "NA", ""), levels = c("", " A", "A", "NA", "B"))
#' ))
#'
#' # a clean frame; non-categorical columns are skipped by default
#' audit_categories(data.frame(sex = c("F", "M", "F"), age = c(31, 45, 27)))
#'
#' try(audit_categories(1:3))
#' @export
audit_categories <- function(data, cols = NULL) {
  if (!is.data.frame(data)) {
    stop("audit_categories: `data` must be a data frame", call. = FALSE)
  }
  is_cat <- function(v) {
    is.factor(v) || is.character(v) ||
      inherits(v, c("haven_labelled", "labelled"))
  }
  if (!is.null(cols) && (!is.character(cols) || anyNA(cols))) {
    stop("`cols` must be column names (a character vector), or NULL for every categorical column", call. = FALSE)
  }
  if (is.null(cols)) cols <- names(data)[vapply(data, is_cat, logical(1))]
  gone <- setdiff(cols, names(data))
  if (length(gone)) stop(sprintf("`cols` names no column of `data`: %s", paste(gone, collapse = ", ")), call. = FALSE)
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
#' @description
#' Checks, after the fact, that a recode did what you said it did. It
#' cross-tabulates the original values against the recoded ones and stops
#' with an error unless each original category went to exactly one new
#' category, that category is the one in your declared mapping, no rows were
#' lost or added, and no value became missing (or was filled in). Use it
#' directly after any recode, including recodes done by other code or other
#' software, to catch swapped groups before a model runs.
#'
#' @details
#' Factors are compared through their labels. The checks, in order:
#' \enumerate{
#'   \item \code{original} and \code{recoded} are atomic and the same length;
#'   \item \code{is.na(original)} equals \code{is.na(recoded)} element by element;
#'   \item in the table of non-missing pairs, no original value has more than
#'     one recoded value (the recode is a function of the label);
#'   \item each original value's recoded value equals \code{declared[old]};
#'     an original value that is not a name of \code{declared} must be
#'     unchanged (identity).
#' }
#' The first failed check is an error naming the offending categories.
#'
#' @param original,recoded Atomic vectors of the same length: the values
#'   before and after the recode, row for row.
#' @param declared Named character vector, old = new: the mapping the analyst
#'   says was applied. Old values not listed are expected to be unchanged.
#' @return Invisibly, when every check passes, the cross-tabulation as a data
#'   frame with columns \code{original}, \code{recoded} (factors) and
#'   \code{Freq} (integer), including the zero cells of the full table.
#'   Otherwise an error.
#' @seealso \code{\link{guard_recode}}, \code{\link{recode_manifest}}.
#' @examples
#' before <- c("W", "B", "W", NA)
#' after <- c("White", "Black", "White", NA)
#' tab <- verify_recode(before, after, c(W = "White", B = "Black"))
#' tab[tab$Freq > 0, ]
#'
#' # a value not in the declared mapping must be unchanged
#' verify_recode(c("W", "X"), c("White", "X"), c(W = "White"))
#'
#' # swapped groups are caught
#' try(verify_recode(c("W", "B"), c("Black", "White"), c(W = "White", B = "Black")))
#'
#' # a value that became NA is caught
#' try(verify_recode(c("W", "B"), c("White", NA), c(W = "White", B = "Black")))
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
#' @description
#' Compares the number of rows per category after a recode with the counts
#' the data source published for those categories (for example the
#' frequency table in a codebook or a statistical release). If they disagree,
#' it tries every reordering of the labels and names the one under which the
#' observed counts would match, which is the signature of labels attached to
#' the wrong groups. Use it after decoding or recoding a column whenever
#' published totals exist.
#'
#' @details
#' For each label \eqn{l} in \code{names(published)} the observed count is
#' \eqn{n_l = \sum_i 1[x_i = l]} (missing values excluded). The counts match
#' when \eqn{|n_l - p_l| \le} \code{tolerance} for every label.
#'
#' On a mismatch, and when there are at most 7 labels, the function searches
#' the \eqn{k!} permutations of the labels (5040 at \eqn{k = 7}) for the
#' first non-identity one under which the observed counts match the
#' published counts, and names it in the message. With more than 7 labels no
#' search is done and \code{permutation} is \code{NULL}. Several
#' permutations can match when counts are tied; only the first is reported.
#'
#' A label that occurs in \code{x} but not in \code{published} is always a
#' failure (no permutation search). \code{published} must be a named numeric
#' vector, otherwise an error.
#'
#' @param x A character or factor vector after recoding.
#' @param published Named numeric vector, label = published count.
#' @param tolerance Non-negative number, default \code{0}. The absolute
#'   difference in counts allowed per label, for releases that round or
#'   suppress small counts.
#' @param strict Logical, default \code{TRUE}: a mismatch is an error, so a
#'   pipeline stops. \code{FALSE} returns the result with \code{ok = FALSE},
#'   the \code{permutation} that would explain the counts and the
#'   \code{message} the error would have carried, for callers that want to
#'   report it or pass the permutation to \code{\link{relabel_forensics}}.
#' @return A list with elements \code{counts} (named numeric, observed count
#'   per published label), \code{published} (named numeric), \code{ok}
#'   (logical), \code{permutation} (named character, true label = label it
#'   would have to be read as, or \code{NULL}) and \code{message}
#'   (character, or \code{NULL} when \code{ok}). It is returned invisibly
#'   when the counts match and visibly when \code{strict = FALSE} and they do
#'   not. With \code{strict = TRUE} a mismatch is an error instead.
#' @seealso \code{\link{transfer_verify}}, \code{\link{relabel_forensics}}.
#' @examples
#' x <- c("White", "White", "Black", "Indigenous", "White", "Black")
#' verify_marginals(x, c(White = 3, Black = 2, Indigenous = 1))$ok
#'
#' # swapped labels: the permutation that explains the counts is named
#' r <- verify_marginals(x, c(White = 2, Black = 3, Indigenous = 1),
#'                       strict = FALSE)
#' r$permutation
#'
#' # a release that rounds counts to the nearest 5
#' verify_marginals(rep(c("A", "B"), c(48, 21)), c(A = 50, B = 20),
#'                  tolerance = 2)$ok
#'
#' # the default is to stop
#' try(verify_marginals(x, c(White = 2, Black = 3, Indigenous = 1)))
#' @export
verify_marginals <- function(x, published, tolerance = 0, strict = TRUE) {
  .rmbl_no_fn(x = x)
  # labels are compared as text: a date column was compared through charToDate() and failed on a label
  if (is.factor(x) || inherits(x, c("Date", "POSIXt"))) x <- as.character(x)
  tolerance <- .rmbl_scalar(tolerance, "tolerance", 0)
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
#' @description
#' Recomputes the odds ratios a report gives for each group from the
#' underlying table of counts, and says whether the reported values follow
#' from the table as it is labelled. If they do not, it tries every
#' reassignment of the group labels (and the two outcome columns swapped) and
#' lists the relabellings that do reproduce the reported values. Use it when
#' a published odds ratio looks implausible: a four-fold ratio reported as
#' thirty-six-fold is typically reproduced exactly by one such relabelling,
#' which shows the groups were mislabelled rather than the arithmetic wrong.
#'
#' @details
#' With row \eqn{r} holding \eqn{a_r} (outcome absent) and \eqn{b_r}
#' (outcome present), the odds ratio of group \eqn{r} against the reference
#' \eqn{0} is
#' \deqn{OR_r = \frac{b_r / a_r}{b_0 / a_0}.}
#' A reported value matches when \eqn{|OR_r - \widehat{OR}_r| \le}
#' \code{tolerance} \eqn{\times |\widehat{OR}_r|} for every non-reference
#' group, and all values are finite. The search covers all \eqn{k!}
#' permutations of the row labels, each with and without the outcome columns
#' swapped (the identity without a swap is the "as labelled" check), and is
#' only run for \eqn{k \le 7} groups. A zero cell gives an infinite or
#' undefined odds ratio, which never matches.
#'
#' Errors: \code{counts} not a matrix, data frame or table with two columns
#' and row names; \code{reference} not a row name; \code{reported} not named
#' by every non-reference row.
#'
#' @param counts Numeric matrix, data frame or table of counts with row names
#'   (the groups) and exactly two columns: outcome absent, then outcome
#'   present.
#' @param reference Character string: the row name of the reference group.
#' @param reported Named numeric vector of the odds ratios the report states,
#'   one per non-reference group, named by group. Extra names are ignored.
#' @param tolerance Number, default \code{0.05}: the relative tolerance for a
#'   match (5 percent), to allow for rounding in the report.
#' @return A list with elements \code{computed} (named numeric odds ratios
#'   from the table as labelled), \code{reported} (the reported values, in
#'   the same order), \code{consistent} (logical), \code{matches} (a data frame
#'   with character \code{relabelling}, for example \code{"B -> C, C -> B"},
#'   and logical \code{outcome_columns_swapped}, one row per relabelling that
#'   reproduces the reported values) and \code{verdict} (a one-sentence
#'   character summary).
#' @seealso \code{\link{verify_marginals}}, \code{\link{relabel_forensics}}.
#' @examples
#' tab <- matrix(c(900, 100, 700, 300, 400, 600),
#'   ncol = 2, byrow = TRUE,
#'   dimnames = list(c("A", "B", "C"), c("no", "yes"))
#' )
#' # the odds ratios as labelled: B 3.86, C 13.5
#' odds_ratio_check(tab, "A", c(B = 3.857, C = 13.5))$consistent
#'
#' # a report that swapped B and C
#' chk <- odds_ratio_check(tab, "A", c(B = 13.5, C = 3.857))
#' chk$matches
#' chk$verdict
#'
#' # every non-reference group needs a reported value
#' try(odds_ratio_check(tab, "A", c(B = 3.857)))
#' @export
odds_ratio_check <- function(counts, reference, reported, tolerance = 0.05) {
  if (!missing(reference) && (!is.atomic(reference) || length(reference) != 1L || is.na(reference))) {
    stop("`reference` must be one group label (a row name of `counts`)", call. = FALSE)
  }
  tolerance <- .rmbl_scalar(tolerance, "tolerance", 0)
  if (is.null(counts) || !(is.matrix(counts) || is.data.frame(counts) || is.table(counts))) {
    stop("`counts` must be a 2-column matrix or table of counts (rows named)", call. = FALSE)
  }
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
#' @description
#' Checks that a column meant as a binary treatment or outcome indicator is
#' numeric 0/1 and not a factor or character column. Coercing a factor with
#' \code{as.numeric()} returns the level indices (1, 2, ...) rather than the
#' data, and a mis-ordered level silently flips every observation; this guard
#' stops before that happens. Call it at the top of any function that needs a
#' 0/1 column.
#'
#' @details
#' The checks are: \code{x} is an atomic vector; it is not a factor or
#' character vector; its distinct non-missing values are all \code{0} or
#' \code{1}. Logical vectors pass, because \code{TRUE} and \code{FALSE}
#' compare equal to \code{1} and \code{0}. Missing values are ignored. Each
#' failure is an error that names the column.
#'
#' @param x The column to check.
#' @param col Character string: the column's name, used only in the error
#'   message.
#' @return \code{TRUE}, invisibly, when the column is a 0/1 indicator;
#'   otherwise an error.
#' @seealso \code{\link{guard_recode}} to build an explicit indicator.
#' @examples
#' guard_binary(c(0, 1, 1, 0, NA), "treated")
#' guard_binary(c(TRUE, FALSE), "arrested")
#'
#' # a factor is refused rather than coerced
#' try(guard_binary(factor(c("control", "treated")), "treated"))
#'
#' # so is a numeric column with other values
#' try(guard_binary(c(0, 1, 2), "treated"))
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
#' @description
#' Builds a record of a recode that a later reader can check: the mapping
#' and its SHA-256, the counts per label before and after, the results of the
#' before/after cross-tabulation check and (when given) of the match against
#' published counts, a UTC timestamp, and, with a key, a signature over the
#' whole record. Write it to disk with \code{\link{write_recode_manifest}}
#' and re-check it with \code{\link{verify_recode_manifest}}, so anyone can
#' confirm which labels went where and that nothing was changed afterwards.
#'
#' @details
#' The function first runs \code{\link{verify_recode}(original, recoded,
#' mapping)} and, when \code{published} is given,
#' \code{\link{verify_marginals}(recoded, published)} with the default
#' \code{strict = TRUE}. Either check failing is an error, so a manifest is
#' only produced for a recode that passed; \code{checks$matches_published} is
#' therefore \code{TRUE} or \code{NA} (no published counts), never
#' \code{FALSE}.
#'
#' \code{body_sha256} is \code{\link{core_sha256}} of the canonical JSON of
#' every other field. With a \code{key}, \code{\link{capsule_sign}} signs that
#' hash and the manifest also stores the public key: a
#' \code{bricklayer_signing_key} from \code{\link{pqc_keygen}} (XMSS, which
#' consumes one one-time leaf per signature) or a key from
#' \code{\link{fips_keygen}} (ML-DSA or SLH-DSA). Nothing is written to disk.
#'
#' @param original,recoded Vectors of the same length: the values before and
#'   after the recode.
#' @param mapping Named character vector, old = new: the mapping that was
#'   applied.
#' @param published Optional named numeric vector of published counts per
#'   recoded label, default \code{NULL} (no check).
#' @param key Optional signing key, default \code{NULL} (unsigned): a key from
#'   \code{\link{pqc_keygen}} or \code{\link{fips_keygen}}. When given the
#'   manifest carries a signature and the public key.
#' @param context Optional character string, default \code{NULL}: free text
#'   such as the dataset, table and analyst. Only the first element is kept.
#' @return A list of class \code{c("bricklayer_recode_manifest", "list")}
#'   with elements \code{context}, \code{created} (ISO 8601 UTC time),
#'   \code{mapping} (list), \code{mapping_sha256}, \code{n} (number of rows),
#'   \code{n_missing}, \code{counts_before} and \code{counts_after} (named
#'   lists of counts), \code{checks} (list of \code{crosstab_is_function},
#'   \code{missingness_unchanged}, \code{matches_published}),
#'   \code{published} (list or \code{NULL}), \code{body_sha256}, and with a
#'   key \code{signature} and \code{public_key}.
#' @examples
#' x <- c("W", "B", "W", "I")
#' map <- c(W = "White", B = "Black", I = "Indigenous")
#' y <- guard_recode(x, map)
#' m <- recode_manifest(x, y, map,
#'   published = c(White = 2, Black = 1, Indigenous = 1),
#'   context = "example survey, race item"
#' )
#' m$checks
#' m$counts_after
#'
#' # signed with an ML-DSA key
#' k <- fips_keygen(seed = as.raw(1:32))
#' ms <- recode_manifest(x, y, map, key = k)
#' names(ms)
#'
#' # a recode that does not match the published counts is refused
#' try(recode_manifest(x, y, map, published = c(White = 1, Black = 2, Indigenous = 1)))
#' @export
recode_manifest <- function(original, recoded, mapping, published = NULL,
                            key = NULL, context = NULL) {
  .rmbl_no_fn(context = context)
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
#' @description
#' \code{write_recode_manifest()} saves a manifest from
#' \code{\link{recode_manifest}} as a JSON file. \code{verify_recode_manifest()}
#' reads such a file back and checks it against the data: that the mapping
#' and the manifest body are unchanged since they were written, that the
#' recode in the data still matches the recorded mapping, that the recoded
#' counts are the recorded counts, and, for a signed manifest, that the
#' signature verifies. Use the pair to hand a recode to a reviewer or to
#' re-check it before a later analysis.
#'
#' @details
#' \code{verify_recode_manifest()} collects every failure in \code{reasons}
#' instead of stopping at the first:
#' \itemize{
#'   \item the SHA-256 of the stored mapping differs from \code{mapping_sha256};
#'   \item the SHA-256 of the body (all fields except \code{body_sha256},
#'     \code{signature} and \code{public_key}) differs from \code{body_sha256},
#'     meaning the file was edited after it was written;
#'   \item \code{\link{verify_recode}(original, recoded, mapping)} fails;
#'   \item the counts of \code{recoded} differ from \code{counts_after}.
#' }
#' The signature, when present, is checked with \code{\link{capsule_verify}}
#' over the stored \code{body_sha256}. It therefore proves who wrote that
#' hash; the body check above proves the body still matches it. Both are
#' needed for \code{ok = TRUE}.
#'
#' \code{write_recode_manifest()} errors when \code{manifest} is not a
#' \code{bricklayer_recode_manifest}; it overwrites \code{path}.
#'
#' @param manifest A manifest returned by \code{\link{recode_manifest}}.
#' @param path Character string: the JSON file to write
#'   (\code{write_recode_manifest()}) or read (\code{verify_recode_manifest()}).
#' @return \code{write_recode_manifest()} returns \code{path} invisibly.
#' @examples
#' x <- c("W", "B", "W")
#' y <- guard_recode(x, c(W = "White", B = "Black"))
#' m <- recode_manifest(x, y, c(W = "White", B = "Black"))
#' p <- write_recode_manifest(m, tempfile(fileext = ".json"))
#' verify_recode_manifest(p, x, y)$ok
#'
#' # the data changed after the manifest was written
#' y2 <- y
#' y2[2] <- "White"
#' verify_recode_manifest(p, x, y2)$reasons
#'
#' # only manifests can be written
#' try(write_recode_manifest(list(a = 1), tempfile()))
#' @export
write_recode_manifest <- function(manifest, path) {
  if (!inherits(manifest, "bricklayer_recode_manifest")) {
    stop("write_recode_manifest: `manifest` must come from recode_manifest()",
      call. = FALSE
    )
  }
  if (is.null(path)) stop("`path` must be a file path or a connection", call. = FALSE)
  path <- .rmbl_out_file(path, "path")
  writeLines(bricklayer_json_to_json(unclass(manifest)), path)
  invisible(path)
}

#' @rdname write_recode_manifest
#' @param original,recoded The vectors before and after the recode, to check
#'   the manifest against.
#' @return \code{verify_recode_manifest()} returns a list with \code{ok}
#'   (logical), \code{reasons} (character, \code{character(0)} when
#'   \code{ok}), \code{signature_ok} (logical, \code{NA} when the manifest is
#'   unsigned) and \code{manifest} (the parsed JSON as a list).
#' @export
verify_recode_manifest <- function(path, original, recoded) {
  .rmbl_no_fn(recoded = recoded)
  path <- .rmbl_file1(path, "path")
  m <- .rmbl_json_text(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
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
#' @description
#' Gives a factor or character vector new labels with a mapping written by
#' name, old label = new label, and returns a factor. Assigning a vector of
#' labels by position (the \code{levels(x) <- ...} idiom, or
#' \code{factor(x, labels = ...)} with labels in a different order from the
#' codes) is how the four race categories were rotated in the analysis that
#' the Ontario Human Rights Commission corrected on 26 January 2023; this
#' function refuses unnamed mappings outright, and refuses levels that the
#' mapping does not cover.
#'
#' @details
#' The old levels are \code{levels(x)} for a factor and the sorted distinct
#' values otherwise; all of them must be names of \code{mapping} or members
#' of \code{keep}, so for a factor even an unused level must be mapped. The
#' recode itself is \code{\link{guard_recode}}. The levels of the result are
#' the distinct values of \code{mapping} in the order given, followed by the
#' \code{keep} labels that occur in the data.
#'
#' Errors: \code{mapping} without names (including a plain vector of new
#' labels); a level with no mapping.
#'
#' @param x A factor or character vector.
#' @param mapping Named character vector, old label = new label. Every level
#'   of \code{x} must appear as a name unless listed in \code{keep}. Several
#'   old labels may map to one new label.
#' @param keep Character vector, default empty: levels allowed to pass
#'   through unchanged.
#' @return A factor with the new labels, levels in the order of
#'   \code{mapping}, carrying a \code{recode_audit} attribute (see
#'   \code{\link{guard_recode}}).
#' @seealso \code{\link{guard_recode}}, \code{\link{relabel_forensics}},
#'   \code{\link{decode_labelled}}
#' @examples
#' f <- factor(c("W", "B", "O", "W"))
#' relabel(f, c(W = "White", B = "Black", O = "Other"))
#'
#' # the level order follows the mapping, not the alphabet
#' levels(relabel(f, c(W = "White", O = "Other", B = "Black")))
#'
#' # a kept label passes through
#' relabel(c("W", "B", "X"), c(W = "White", B = "Black"), keep = "X")
#'
#' # positional labels are refused
#' try(relabel(f, c("Black", "Other", "White")))
#' @export
relabel <- function(x, mapping, keep = character()) {
  if (is.null(x) || !is.atomic(x) || is.complex(x) || is.raw(x)) {
    stop("`x` must be a vector of labels (character, factor or numbers)", call. = FALSE)
  }
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
#' @description
#' Converts a vector read from SPSS, Stata or SAS (for example by
#' \code{haven::read_sav()}), which stores categories as numeric codes with a
#' \code{labels} attribute, into a factor of the labels. Each code is looked
#' up by its value, so neither the order of the codes nor the alphabetical
#' order of the labels can affect which label a row gets. Codes with no label
#' are refused. The factor's levels are in code order, which keeps the
#' source program's reference category.
#'
#' @details
#' When \code{x} has a \code{labels} attribute (a named vector, label = code)
#' it is used and \code{value_labels} is ignored; otherwise
#' \code{value_labels} (code = label) is required. Decoding is done by
#' \code{\link{decode_codes}}. The levels are the labels ordered by their
#' numeric code (codes that are not numbers are ordered after the numeric
#' ones, by string), and include labels of codes that do not occur.
#'
#' Errors: a \code{labels} attribute without names; no attribute and no
#' \code{value_labels}; a code with no label.
#'
#' @param x A vector with a \code{labels} attribute (as produced by haven),
#'   or a plain vector of codes when \code{value_labels} is supplied.
#' @param value_labels Optional named character vector, code = label, used
#'   only when \code{x} carries no \code{labels} attribute. Default
#'   \code{NULL}.
#' @return A factor whose levels are the labels in code order (not
#'   alphabetical), with a \code{recode_audit} attribute as described in
#'   \code{\link{guard_recode}}.
#' @seealso \code{\link{decode_codes}}, \code{\link{relabel}},
#'   \code{\link{transfer_verify}}
#' @examples
#' x <- structure(c(1, 2, 2, 4),
#'                labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
#' decode_labelled(x)
#'
#' # plain codes with a code book; levels follow the codes 1, 2, 10
#' decode_labelled(c(2, 1, 10), value_labels = c("10" = "Ten", "2" = "Two", "1" = "One"))
#'
#' # codes alone are not categories
#' try(decode_labelled(c(1, 2, 2)))
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
#' @description
#' When categories come out permuted (each true group reported under another
#' group's label), this function asks which deterministic step, applied to
#' the code book, produces exactly that permutation. It tries the known
#' mechanisms: labels sorted alphabetically (also reversed or
#' case-insensitive) and assigned by code position, labels reversed, every
#' rotation, codes sorted as strings, and, when counts are given, labels
#' ordered by frequency. A match is a reconstruction, not proof of intent;
#' but a file transfer has no reason to pick the sort order of the labels, so
#' a match on a sort-based mechanism points to a positional relabel in the
#' analysis rather than to the software.
#'
#' @details
#' With labels \eqn{L_1, \dots, L_k} in code order, each mechanism produces
#' a sequence \eqn{M_1, \dots, M_k} meaning "true group \eqn{L_i} was seen as
#' \eqn{M_i}". It matches when \eqn{M_i =} \code{observed[L_i]} for all
#' \eqn{i}. There are five fixed mechanisms, \eqn{k - 1} rotations, and two
#' frequency orders with \code{counts}. When \code{observed} is the identity
#' no mechanism is reported as matching.
#'
#' Errors: either argument unnamed; \code{observed} not a permutation of the
#' labels in \code{value_labels}.
#'
#' @param value_labels Named character vector, code = true label, in code
#'   order (the source program's code book).
#' @param observed Named character vector, true label = label it was seen
#'   under, covering every label once.
#' @param counts Optional named numeric vector of frequencies per true label,
#'   default \code{NULL}. Enables the two frequency-order mechanisms.
#' @return A data frame of class \code{c("bricklayer_relabel_forensics",
#'   "data.frame")} with one row per mechanism tried and columns
#'   \code{mechanism} (character), \code{permutation} (character,
#'   \code{"A -> B, ..."}) and \code{matches} (logical). The \code{verdict}
#'   attribute is a character summary. The print method shows only the
#'   matching mechanisms and the verdict.
#' @seealso \code{\link{verify_marginals}}, \code{\link{relabel}}.
#' @examples
#' # the OHRC 2023 case: alphabetical labels assigned to codes 1-4
#' vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
#' obs <- c(White = "Black", Black = "Other", Other = "Unknown",
#'          Unknown = "White")
#' relabel_forensics(vl, obs)
#'
#' # a frequency-ordered relabel needs the counts
#' obs2 <- c(White = "White", Black = "Other", Other = "Black",
#'           Unknown = "Unknown")
#' rf <- relabel_forensics(vl, obs2, counts = c(White = 50, Black = 10,
#'                                              Other = 30, Unknown = 5))
#' rf$mechanism[rf$matches]
#'
#' # observed must be a permutation of the labels
#' try(relabel_forensics(vl, c(White = "Black")))
#' @export
relabel_forensics <- function(value_labels, observed, counts = NULL) {
  .rmbl_no_fn(value_labels = value_labels, observed = observed, counts = counts)
  if (!is.null(counts)) counts <- stats::setNames(.rmbl_num(counts, "counts"), names(counts))   # read by label
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
#' @description
#' Checks a categorical variable that was moved from SPSS, Stata or SAS into
#' R against what the source program reported for it. You give the frequency
#' table the source program printed (label = count) and, optionally, its code
#' book (code = label); the function decodes the imported vector and refuses
#' to continue unless it reproduces those counts exactly and its value labels
#' agree with the code book. Rotated, swapped or positionally relabelled
#' groups fail at import, with the permutation named.
#'
#' @details
#' Steps:
#' \enumerate{
#'   \item When \code{imported} has a \code{labels} attribute and
#'     \code{code_book} is given, the two are compared code by code; any
#'     code whose label differs (or that is present in only one) is a
#'     disagreement.
#'   \item The vector is decoded: by its \code{labels} attribute
#'     (\code{\link{decode_labelled}}), else by \code{code_book}, else taken
#'     as already-decoded labels.
#'   \item The decoded labels are checked with
#'     \code{\link{verify_marginals}} against \code{source_counts}.
#' }
#' With \code{strict = TRUE} the first disagreement is an error. With
#' \code{strict = FALSE} both checks run and are reported. A code without a
#' label is an error in either mode (from the decoding step).
#'
#' @param imported The vector as it arrived: a haven-style labelled vector,
#'   plain codes (with \code{code_book}), or already-decoded labels.
#' @param source_counts Named numeric vector, label = count, as printed by
#'   the source program (SPSS FREQUENCIES, Stata tabulate).
#' @param code_book Optional named character vector, code = label, from the
#'   source program's variable view. Default \code{NULL}. When
#'   \code{imported} carries a \code{labels} attribute the two are compared
#'   and any disagreement fails the check.
#' @param tolerance Non-negative number, default \code{0}: the absolute
#'   difference in count allowed per label, passed to
#'   \code{\link{verify_marginals}}.
#' @param strict Logical, default \code{TRUE}: any disagreement is an error.
#'   When \code{FALSE} the result comes back with \code{ok = FALSE},
#'   \code{reasons}, and \code{marginals$permutation} ready for
#'   \code{\link{relabel_forensics}}.
#' @return A list with \code{ok} (logical), \code{decoded} (a factor; in code
#'   order when decoded from codes), \code{marginals} (the
#'   \code{\link{verify_marginals}} result), \code{code_book_ok} (logical, or
#'   \code{NA} when there was nothing to compare) and \code{reasons}
#'   (character messages, or \code{NULL} when \code{ok}).
#' @seealso \code{\link{decode_labelled}}, \code{\link{verify_marginals}},
#'   \code{\link{relabel_forensics}}
#' @examples
#' x <- structure(c(1, 1, 2, 4, 1),
#'                labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
#' transfer_verify(x, c(White = 3, Black = 1, Unknown = 1))$ok
#'
#' # counts that only match under swapped labels, reported without stopping
#' r <- transfer_verify(x, c(White = 1, Black = 3, Unknown = 1), strict = FALSE)
#' r$ok
#' r$marginals$permutation
#'
#' # value labels that disagree with the source code book
#' try(transfer_verify(x, c(White = 3, Black = 1, Unknown = 1),
#'   code_book = c("1" = "White", "2" = "Other", "3" = "Black", "4" = "Unknown")))
#' @export
transfer_verify <- function(imported, source_counts, code_book = NULL,
                            tolerance = 0, strict = TRUE) {
  .rmbl_no_fn(imported = imported, code_book = code_book)
  if (!is.null(code_book) &&
        (!is.atomic(code_book) || is.null(names(code_book)) || inherits(code_book, c("Date", "POSIXt")))) {
    stop("`code_book` must be a named vector (code = label), or NULL", call. = FALSE)
  }
  tolerance <- .rmbl_scalar(tolerance, "tolerance", 0)
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
