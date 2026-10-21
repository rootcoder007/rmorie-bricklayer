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

#' Wraps text in typographic single quotes.
#' @param v A character vector.
#' @return `v` with each element in curly single quotes.
#' @noRd
.rmbl_squote <- function(v) paste0("\u2018", v, "\u2019")

#' Lists every ordering of a set of labels.
#' @param v The labels.
#' @return A list of character vectors, one per permutation of `v`.
#' @noRd
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
#' \code{vlabs}. The lookup itself is done by
#' \code{\link{grdrcd}}, so the result carries the same
#' \code{recode_audit} attribute, including a SHA-256 of the dictionary.
#'
#' Errors:
#' \itemize{
#'   \item \code{vlabs} not a character vector with non-empty names;
#'   \item a code in \code{x} that is not a name of \code{vlabs}
#'     (the message lists the unmapped codes);
#'   \item any \code{NA} in \code{x} when \code{keepna = FALSE}.
#' }
#' For a haven-style labelled vector, which carries its dictionary as a
#' \code{labels} attribute, use \code{\link{declbld}}, which returns a
#' factor with the levels in code order.
#'
#' @param x Vector of codes: numeric, integer, character or factor. A factor
#'   is read through its labels, not its integer codes; an ordered factor is
#'   treated the same as an unordered one (its level order is not used).
#' @param vlabs Named character vector, code = label, for example
#'   \code{c("1" = "White", "2" = "Black")}. The names are the codes as they
#'   print with \code{as.character()}; the values are the labels. Codes in the
#'   dictionary that do not occur in \code{x} are allowed.
#' @param keepna Logical, default \code{TRUE}: \code{NA} codes stay
#'   \code{NA} in the result. \code{FALSE} makes any \code{NA} code an error,
#'   for columns where missingness should not occur.
#' @return A character vector of labels, the same length as \code{x}, with
#'   \code{NA} where \code{x} is \code{NA}. It carries a \code{recode_audit}
#'   attribute: a list with \code{mapping} (the dictionary), \code{kept}
#'   (\code{character(0)}) and \code{checksum} (64-character hexadecimal
#'   SHA-256 of the \code{code=label} pairs).
#' @seealso \code{\link{declbld}}, \code{\link{grdrcd}},
#'   \code{\link{audcats}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # codes from a survey file with their code book
#' race <- c(1, 2, 2, 3, NA)
#' book <- c("1" = "White", "2" = "Black", "3" = "Indigenous")
#' deccodes(race, book)
#'
#' # the dictionary that was applied is kept on the result
#' attr(deccodes(race, book), "recode_audit")$checksum
#'
#' # a code with no label is refused, never passed through
#' try(deccodes(c(1, 2, 9), book))
#'
#' # missing codes can be refused too
#' try(deccodes(race, book, keepna = FALSE))
#' @export
#' @srrstats {G2.4c} Codes are converted with as.character(x) before lookup, not paste().
#' @srrstats {G2.14} keepna sets the NA policy: keep NA (default) or error; G2.14a-c give the detail.
#' @srrstats {G2.14a} keepna = FALSE turns any NA code into an error (documented, and shown in the examples).
#' @srrstats {G2.5} The x docs of deccodes, grdrcd and declbld say how ordered factors are read: like unordered
#'   ones, by label (deccodes, grdrcd) or by integer code (declbld).
deccodes <- function(x, vlabs, keepna = TRUE) {
  .rmbl_no_fn(x = x)
  if (is.factor(x)) x <- as.character(x)
  codes <- as.character(x)
  if (!is.character(vlabs) || is.null(names(vlabs)) ||
        !all(nzchar(names(vlabs)))) {
    stop("deccodes: `vlabs` must be a named character vector ",
      "with the codes as names",
      call. = FALSE
    )
  }
  keepna <- .rmbl_flag1(keepna, "keepna")
  if (!keepna && anyNA(codes)) {
    stop("deccodes: `x` has missing codes and keep_na = FALSE",
      call. = FALSE
    )
  }
  grdrcd(codes, vlabs)
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
#' The checksum is \code{\link{csha256}} of the string
#' \code{"old1=new1;old2=new2;..."} built from the mapping in its given order,
#' so the same mapping written in a different order has a different checksum.
#'
#' Errors: \code{map} not a character vector with non-empty names; any
#' observed value that is neither mapped nor kept (the message lists them).
#'
#' \code{\link{relbl}} is the same check but returns a factor;
#' \code{\link{vrfrcd}} proves the result against the declared mapping;
#' \code{\link{rcdmnf}} records it.
#'
#' @param x A factor or character vector. Other atomic vectors are compared
#'   by matching the values that \code{as.character()} gives. Ordered and
#'   unordered factors are treated the same: both are read through their labels,
#'   and the result is character either way.
#' @param map Named character vector, \code{c(old_label = "new_label", ...)}.
#'   Every name must be non-empty.
#' @param keep Character vector, default empty. Labels allowed to pass
#'   through unchanged.
#' @return A character vector the same length as \code{x}, with a
#'   \code{recode_audit} attribute: a list with \code{mapping} (the mapping as
#'   given), \code{kept} (the \code{keep} vector) and \code{checksum}
#'   (hexadecimal SHA-256 of the mapping).
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # rename three codes
#' x <- c("W", "B", "O", "W", NA)
#' grdrcd(x, c(W = "White", B = "Black", O = "Other"))
#'
#' # collapse two categories and let one pass through unchanged
#' off <- c("assault", "robbery", "theft", "fraud")
#' grdrcd(off, c(assault = "violent", robbery = "violent",
#'                     theft = "property"), keep = "fraud")
#'
#' # a value with no mapping is an error
#' try(grdrcd(x, c(W = "White", B = "Black")))
#' @seealso \code{\link{vrfrcd}} to prove the recode,
#'   \code{\link{grdlvls}} to fix the levels,
#'   \code{\link{rcdmnf}} to record the chain.
#' @export
#' @srrstats {G2.4e} A factor is converted with as.character() and read by its labels, not its codes;
#'   test-categorical-guard.R grdrcd(factor(...)).
grdrcd <- function(x, map, keep = character()) {
  .rmbl_no_fn(x = x)
  if (is.factor(x)) x <- as.character(x)
  if (!is.character(map) || is.null(names(map)) ||
        !all(nzchar(names(map)))) {
    stop("grdrcd: `map` must be a named character vector",
      call. = FALSE
    )
  }
  seen <- unique(x[!is.na(x)])
  unmapped <- setdiff(seen, c(names(map), keep))
  if (length(unmapped)) {
    stop("grdrcd: values with NO mapping: ",
      paste(.rmbl_squote(unmapped), collapse = ", "),
      ". Every observed category must be mapped by name (or listed in ",
      "`keep`); silent pass-through is how group labels get corrupted.",
      call. = FALSE
    )
  }
  out <- ifelse(is.na(x), NA_character_,
    ifelse(x %in% names(map), unname(map[x]), x)
  )
  attr(out, "recode_audit") <- list(
    mapping = map, kept = keep,
    checksum = csha256(charToRaw(
      paste(names(map), map, sep = "=", collapse = ";")
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
#' reference so that a later edit to \code{lvls} cannot change it unnoticed.
#'
#' @details
#' The function checks that every non-missing value of \code{x} is in
#' \code{lvls}, then returns \code{factor(x, levels = levels)}. Declared
#' levels that do not occur are kept as empty levels (they still appear in
#' tables with a count of zero).
#'
#' Errors:
#' \itemize{
#'   \item \code{lvls} not a non-empty character vector, or containing \code{NA};
#'   \item a value of \code{x} not in \code{lvls} (listed in the message);
#'   \item \code{ref} given and not identical to \code{levels[1]}.
#' }
#'
#' @param x Character or factor vector. A factor is read through its labels.
#' @param lvls Character vector of every allowed level, in the intended
#'   order. The first element is the reference category.
#' @param ref Optional character string, default \code{NULL} (no
#'   check). When given it must equal \code{levels[1]}; use it to state the
#'   intended baseline next to the code that fits the model.
#' @return A factor with exactly the levels in \code{levels}, in that order.
#' @seealso \code{\link{grdrcd}}, \code{\link{audcats}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # reference category chosen on purpose, not by alphabet
#' g <- grdlvls(c("White", "Black", "White"), c("White", "Black"), "White")
#' levels(g)
#'
#' # a declared level that does not occur is kept, with a zero count
#' table(grdlvls(c("a", "a"), c("a", "b")))
#'
#' # a stray value, or a reference that is not first, is refused
#' try(grdlvls(c("White", "Blak"), c("White", "Black")))
#' try(grdlvls(c("White", "Black"), c("White", "Black"), ref = "Black"))
#' @export
grdlvls <- function(x, lvls, ref = NULL) {
  .rmbl_no_fn(x = x, reference = ref)
  if (!is.character(lvls) || !length(lvls) || any(is.na(lvls))) {
    stop("`lvls` must be a non-empty character vector", call. = FALSE)
  }
  if (is.factor(x)) x <- as.character(x)
  stray <- setdiff(unique(x[!is.na(x)]), lvls)
  if (length(stray)) {
    stop("grdlvls: values outside the declared levels: ",
      paste(.rmbl_squote(stray), collapse = ", "),
      call. = FALSE
    )
  }
  if (!is.null(ref) && !identical(ref, lvls[1L])) {
    stop("grdlvls: declared reference ", .rmbl_squote(ref),
      " is not levels[1] (", .rmbl_squote(lvls[1L]), "); reorder ",
      "`lvls` so the reference is explicit and first.",
      call. = FALSE
    )
  }
  factor(x, levels = lvls)
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
#'     and must be decoded with \code{\link{deccodes}} or
#'     \code{\link{declbld}});
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
#' @seealso \code{\link{deccodes}}, \code{\link{grdlvls}},
#'   \code{\link{xfrvrf}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # codes without labels, and a case-variant city name
#' a <- audcats(data.frame(
#'   race = factor(c("1", "2", "2", "3")),
#'   city = c("Toronto", "toronto", "Ottawa")[c(1, 2, 3, 3)]
#' ))
#' a
#' attr(a, "clean")
#'
#' # padded, empty and sentinel labels, and an unused level
#' audcats(data.frame(
#'   g = factor(c(" A", "A", "NA", ""), levels = c("", " A", "A", "NA", "B"))
#' ))
#'
#' # a clean frame; non-categorical columns are skipped by default
#' audcats(data.frame(sex = c("F", "M", "F"), age = c(31, 45, 27)))
#'
#' try(audcats(1:3))
#' @export
#' @srrstats {G2.11} Columns with non-standard classes are processed: test-categorical-guard.R:238 audits a
#'   haven_labelled I() column; a yoy Date period keeps its class (test-yoy.R:203).
audcats <- function(data, cols = NULL) {
  if (!is.data.frame(data)) {
    stop("audcats: `data` must be a data frame", call. = FALSE)
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
        "with deccodes() BEFORE analysis (the ",
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
        "the groups. Decode by code (deccodes / relabel), never by position"
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
#'   \item \code{orig} and \code{recd} are atomic and the same length;
#'   \item \code{is.na(original)} equals \code{is.na(recoded)} element by element;
#'   \item in the table of non-missing pairs, no original value has more than
#'     one recoded value (the recode is a function of the label);
#'   \item each original value's recoded value equals \code{declared[old]};
#'     an original value that is not a name of \code{decl} must be
#'     unchanged (identity).
#' }
#' The first failed check is an error naming the offending categories.
#'
#' @param orig,recd Atomic vectors of the same length: the values
#'   before and after the recode, row for row.
#' @param decl Named character vector, old = new: the mapping the analyst
#'   says was applied. Old values not listed are expected to be unchanged.
#' @return Invisibly, when every check passes, the cross-tabulation as a data
#'   frame with columns \code{original}, \code{recoded} (factors) and
#'   \code{Freq} (integer), including the zero cells of the full table.
#'   Otherwise an error.
#' @seealso \code{\link{grdrcd}}, \code{\link{rcdmnf}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' before <- c("W", "B", "W", NA)
#' after <- c("White", "Black", "White", NA)
#' tab <- vrfrcd(before, after, c(W = "White", B = "Black"))
#' tab[tab$Freq > 0, ]
#'
#' # a value not in the declared mapping must be unchanged
#' vrfrcd(c("W", "X"), c("White", "X"), c(W = "White"))
#'
#' # swapped groups are caught
#' try(vrfrcd(c("W", "B"), c("Black", "White"), c(W = "White", B = "Black")))
#'
#' # a value that became NA is caught
#' try(vrfrcd(c("W", "B"), c("White", NA), c(W = "White", B = "Black")))
#' @export
vrfrcd <- function(orig, recd, decl) {
  if (!is.atomic(orig) || is.null(orig) ||
        !is.atomic(recd) || is.null(recd)) {
    stop("`orig` and `recd` must be atomic vectors", call. = FALSE)
  }
  if (is.factor(orig)) orig <- as.character(orig)
  if (is.factor(recd)) recd <- as.character(recd)
  if (length(orig) != length(recd)) {
    stop("vrfrcd: length mismatch (", length(orig), " vs ",
      length(recd), "): rows were lost or duplicated during the recode.",
      call. = FALSE
    )
  }
  if (!identical(is.na(orig), is.na(recd))) {
    stop("vrfrcd: missingness changed during the recode (values ",
      "silently became NA, or NAs were filled).",
      call. = FALSE
    )
  }
  ok <- !is.na(orig)
  tab <- table(original = orig[ok], recoded = recd[ok])
  fan_out <- rowSums(tab > 0)
  if (any(fan_out > 1L)) {
    stop("vrfrcd: original category mapped to MULTIPLE new categories: ",
      paste(.rmbl_squote(names(fan_out)[fan_out > 1L]), collapse = ", "),
      ". The recode is not a function of the category label.",
      call. = FALSE
    )
  }
  realized <- apply(tab, 1L, function(r) colnames(tab)[which(r > 0)])
  for (old in names(realized)) {
    expected <- if (old %in% names(decl)) unname(decl[old]) else old
    if (!identical(realized[[old]], expected)) {
      stop("vrfrcd: ", .rmbl_squote(old), " was mapped to ",
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
#' when \eqn{|n_l - p_l| \le} \code{tol} for every label.
#'
#' On a mismatch, and when there are at most 7 labels, the function searches
#' the \eqn{k!} permutations of the labels (5040 at \eqn{k = 7}) for the
#' first non-identity one under which the observed counts match the
#' published counts, and names it in the message. With more than 7 labels no
#' search is done and \code{permutation} is \code{NULL}. Several
#' permutations can match when counts are tied; only the first is reported.
#'
#' A label that occurs in \code{x} but not in \code{pub} is always a
#' failure (no permutation search). \code{pub} must be a named numeric
#' vector, otherwise an error.
#'
#' @param x A character or factor vector after recoding.
#' @param pub Named numeric vector, label = published count.
#' @param tol Non-negative number, default \code{0}. The absolute
#'   difference in counts allowed per label, for releases that round or
#'   suppress small counts.
#' @param strict Logical, default \code{TRUE}: a mismatch is an error, so a
#'   pipeline stops. \code{FALSE} returns the result with \code{ok = FALSE},
#'   the \code{permutation} that would explain the counts and the
#'   \code{message} the error would have carried, for callers that want to
#'   report it or pass the permutation to \code{\link{rlblfrns}}.
#' @return A list with elements \code{counts} (named numeric, observed count
#'   per published label), \code{published} (named numeric), \code{ok}
#'   (logical), \code{permutation} (named character, true label = label it
#'   would have to be read as, or \code{NULL}) and \code{message}
#'   (character, or \code{NULL} when \code{ok}). It is returned invisibly
#'   when the counts match and visibly when \code{strict = FALSE} and they do
#'   not. With \code{strict = TRUE} a mismatch is an error instead.
#' @seealso \code{\link{xfrvrf}}, \code{\link{rlblfrns}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' x <- c("White", "White", "Black", "Indigenous", "White", "Black")
#' vrfmrg(x, c(White = 3, Black = 2, Indigenous = 1))$ok
#'
#' # swapped labels: the permutation that explains the counts is named
#' r <- vrfmrg(x, c(White = 2, Black = 3, Indigenous = 1),
#'                       strict = FALSE)
#' r$permutation
#'
#' # a release that rounds counts to the nearest 5
#' vrfmrg(rep(c("A", "B"), c(48, 21)), c(A = 50, B = 20),
#'                  tol = 2)$ok
#'
#' # the default is to stop
#' try(vrfmrg(x, c(White = 2, Black = 3, Indigenous = 1)))
#' @export
vrfmrg <- function(x, pub, tol = 0, strict = TRUE) {
  .rmbl_no_fn(x = x)
  strict <- .rmbl_flag1(strict, "strict")
  # labels are compared as text: a date column was compared through charToDate() and failed on a label
  if (is.factor(x) || inherits(x, c("Date", "POSIXt"))) x <- as.character(x)
  tol <- .rmbl_scalar(tol, "tol", 0)
  if (!is.numeric(pub) || is.null(names(pub)) ||
        !all(nzchar(names(pub)))) {
    stop("vrfmrg: `pub` must be a named numeric vector",
      call. = FALSE
    )
  }
  labs <- names(pub)
  obs <- vapply(labs, function(l) sum(!is.na(x) & x == l), numeric(1))
  extra <- setdiff(unique(x[!is.na(x)]), labs)
  if (length(extra)) {
    msg <- paste0(
      "vrfmrg: labels present in the data but not in the ",
      "published counts: ", paste(.rmbl_squote(extra), collapse = ", ")
    )
    if (strict) stop(msg, call. = FALSE)
    return(list(
      counts = obs, published = pub[labs], ok = FALSE,
      permutation = NULL, message = msg
    ))
  }
  ok <- all(abs(obs - pub[labs]) <= tol)
  perm <- NULL
  if (!ok && length(labs) <= 7L) {
    for (p in .rmbl_label_perms(labs)) {
      relabelled <- stats::setNames(obs, p)[labs]
      if (!identical(p, labs) &&
            all(abs(relabelled - pub[labs]) <= tol)) {
        perm <- stats::setNames(p, labs)
        break
      }
    }
  }
  out <- list(
    counts = obs, published = pub[labs], ok = ok, permutation = perm,
    message = NULL
  )
  if (!ok) {
    detail <- paste(
      sprintf("%s: observed %s, published %s", labs, obs, pub[labs]),
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
      "vrfmrg: recoded counts do not match the published counts. ",
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
#' \code{tol} \eqn{\times |\widehat{OR}_r|} for every non-reference
#' group, and all values are finite. The search covers all \eqn{k!}
#' permutations of the row labels, each with and without the outcome columns
#' swapped (the identity without a swap is the \dQuote{as labelled} check), and is
#' only run for \eqn{k \le 7} groups. A zero cell gives an infinite or
#' undefined odds ratio, which never matches.
#'
#' Errors: \code{cnts} not a matrix, data frame or table with two columns
#' and row names; \code{ref} not a row name; \code{rptd} not named
#' by every non-reference row.
#'
#' @param cnts Numeric matrix, data frame or table of counts with row names
#'   (the groups) and exactly two columns: outcome absent, then outcome
#'   present.
#' @param ref Character string: the row name of the reference group.
#' @param rptd Named numeric vector of the odds ratios the report states,
#'   one per non-reference group, named by group. Extra names are ignored.
#' @param tol Number, default \code{0.05}: the relative tolerance for a
#'   match (5 percent), to allow for rounding in the report.
#' @return A list with elements \code{computed} (named numeric odds ratios
#'   from the table as labelled), \code{reported} (the reported values, in
#'   the same order), \code{consistent} (logical), \code{matches} (a data frame
#'   with character \code{relabelling}, for example \code{"B -> C, C -> B"},
#'   and logical \code{outcome_columns_swapped}, one row per relabelling that
#'   reproduces the reported values) and \code{verdict} (a one-sentence
#'   character summary).
#' @seealso \code{\link{vrfmrg}}, \code{\link{rlblfrns}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' tab <- matrix(c(900, 100, 700, 300, 400, 600),
#'   ncol = 2, byrow = TRUE,
#'   dimnames = list(c("A", "B", "C"), c("no", "yes"))
#' )
#' # the odds ratios as labelled: B 3.86, C 13.5
#' orchk(tab, "A", c(B = 3.857, C = 13.5))$consistent
#'
#' # a report that swapped B and C
#' chk <- orchk(tab, "A", c(B = 13.5, C = 3.857))
#' chk$matches
#' chk$verdict
#'
#' # every non-reference group needs a reported value
#' try(orchk(tab, "A", c(B = 3.857)))
#' @export
orchk <- function(cnts, ref, rptd, tol = 0.05) {
  if (!missing(ref) && (!is.atomic(ref) || length(ref) != 1L || is.na(ref))) {
    stop("`ref` must be one group label (a row name of `cnts`)", call. = FALSE)
  }
  tol <- .rmbl_scalar(tol, "tol", 0)
  if (is.null(cnts) || !(is.matrix(cnts) || is.data.frame(cnts) || is.table(cnts))) {
    stop("`cnts` must be a 2-column matrix or table of counts (rows named)", call. = FALSE)
  }
  cnts <- as.matrix(cnts)
  if (ncol(cnts) != 2L || is.null(rownames(cnts))) {
    stop("orchk: `cnts` must be a k-by-2 matrix with row names ",
      "(groups) and columns outcome-absent, outcome-present.",
      call. = FALSE
    )
  }
  labs <- rownames(cnts)
  if (!ref %in% labs) {
    stop("orchk: reference ", .rmbl_squote(ref),
      " is not a row of `cnts`.",
      call. = FALSE
    )
  }
  others <- setdiff(labs, ref)
  if (is.null(names(rptd)) || !all(others %in% names(rptd))) {
    stop("orchk: `rptd` must be named by every ",
      "non-reference row: ",
      paste(.rmbl_squote(others), collapse = ", "),
      call. = FALSE
    )
  }
  rptd <- rptd[others]
  or_of <- function(m) {
    ref_odds <- m[ref, 2L] / m[ref, 1L]
    vapply(others, function(r) (m[r, 2L] / m[r, 1L]) / ref_odds, numeric(1))
  }
  close_to <- function(a, b) {
    all(is.finite(a) & is.finite(b)) &&
      all(abs(a - b) <= tol * pmax(abs(b), .Machine$double.eps))
  }
  computed <- or_of(cnts)
  consistent <- close_to(computed, rptd)
  rows <- list()
  if (length(labs) <= 7L) {
    for (p in .rmbl_label_perms(labs)) {
      for (swap_cols in c(FALSE, TRUE)) {
        if (identical(p, labs) && !swap_cols) next
        m <- cnts
        if (swap_cols) m <- m[, 2:1, drop = FALSE]
        rownames(m) <- p
        m <- m[labs, , drop = FALSE]
        if (close_to(or_of(m), rptd)) {
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
    computed = computed, reported = rptd, consistent = consistent,
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
#' @seealso \code{\link{grdrcd}} to build an explicit indicator.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' grdbin(c(0, 1, 1, 0, NA), "treated")
#' grdbin(c(TRUE, FALSE), "arrested")
#'
#' # a factor is refused rather than coerced
#' try(grdbin(factor(c("control", "treated")), "treated"))
#'
#' # so is a numeric column with other values
#' try(grdbin(c(0, 1, 2), "treated"))
#' @export
grdbin <- function(x, col) {
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
      "grdrcd() + as.integer(x == \"treated_label\").",
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
#' whole record. Write it to disk with \code{\link{wrrcdmnf}}
#' and re-check it with \code{\link{vrfrcdmnf}}, so anyone can
#' confirm which labels went where and that nothing was changed afterwards.
#'
#' @details
#' The function first runs \code{\link{vrfrcd}}, as
#' \code{vrfrcd(original, recoded, mapping)}. When \code{pub} is given it then
#' runs \code{\link{vrfmrg}}, as \code{vrfmrg(recoded, published)}, with the
#' default \code{strict = TRUE}. Either check failing is an error, so a manifest is
#' only produced for a recode that passed. For that reason
#' \code{checks$matches_published} is \code{TRUE} or \code{NA} (no published counts), never
#' \code{FALSE}.
#'
#' \code{body_sha256} is \code{\link{csha256}} of the canonical JSON of
#' every other field. With a \code{key}, \code{\link{cpssign}} signs that
#' hash and the manifest also stores the public key: a
#' \code{bricklayer_signing_key} from \code{\link{pqckg}} (XMSS, which
#' consumes one one-time leaf per signature) or a key from
#' \code{\link{fipskg}} (ML-DSA or SLH-DSA). Nothing is written to disk.
#'
#' @param orig,recd Vectors of the same length: the values before and
#'   after the recode.
#' @param map Named character vector, old = new: the mapping that was
#'   applied.
#' @param pub Optional named numeric vector of published counts per
#'   recoded label, default \code{NULL} (no check).
#' @param key Optional signing key, default \code{NULL} (unsigned): a key from
#'   \code{\link{pqckg}} or \code{\link{fipskg}}. When given the
#'   manifest carries a signature and the public key.
#' @param ctx Optional character string, default \code{NULL}: free text
#'   such as the dataset, table and analyst. Only the first element is kept.
#' @return A list of class \code{bricklayer_recode_manifest} with these elements:
#'   \itemize{
#'     \item \code{context};
#'     \item \code{created} (ISO 8601 UTC time);
#'     \item \code{mapping} (list) and \code{mapping_sha256};
#'     \item \code{n} (number of rows) and \code{n_missing};
#'     \item \code{counts_before} and \code{counts_after} (named lists of counts);
#'     \item \code{checks}, a list: \code{crosstab_is_function},
#'       \code{missingness_unchanged} and \code{matches_published};
#'     \item \code{published} (list or \code{NULL});
#'     \item \code{body_sha256};
#'     \item with a key, \code{signature} and \code{public_key}.
#'   }
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' x <- c("W", "B", "W", "I")
#' map <- c(W = "White", B = "Black", I = "Indigenous")
#' y <- grdrcd(x, map)
#' m <- rcdmnf(x, y, map,
#'   pub = c(White = 2, Black = 1, Indigenous = 1),
#'   ctx = "example survey, race item"
#' )
#' m$checks
#' m$counts_after
#'
#' # signed with an ML-DSA key
#' k <- fipskg(seed = as.raw(1:32))
#' ms <- rcdmnf(x, y, map, key = k)
#' names(ms)
#'
#' # a recode that does not match the published counts is refused
#' try(rcdmnf(x, y, map, pub = c(White = 1, Black = 2, Indigenous = 1)))
#' @export
rcdmnf <- function(orig, recd, map, pub = NULL,
                            key = NULL, ctx = NULL) {
  .rmbl_no_fn(context = ctx)
  vrfrcd(orig, recd, map)
  marg <- if (!is.null(pub)) {
    vrfmrg(recd, pub)
  } else {
    NULL
  }
  before <- table(as.character(orig), useNA = "no")
  after <- table(as.character(recd), useNA = "no")
  body <- list(
    context = if (is.null(ctx)) "" else as.character(ctx)[1L],
    created = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    mapping = as.list(map),
    mapping_sha256 = csha256(charToRaw(
      paste(names(map), map, sep = "=", collapse = ";")
    )),
    n = length(orig), n_missing = sum(is.na(orig)),
    counts_before = as.list(stats::setNames(as.numeric(before), names(before))),
    counts_after = as.list(stats::setNames(as.numeric(after), names(after))),
    checks = list(
      crosstab_is_function = TRUE, missingness_unchanged = TRUE,
      matches_published = if (is.null(marg)) NA else isTRUE(marg$ok)
    ),
    published = if (is.null(pub)) NULL else as.list(pub)
  )
  body$body_sha256 <- csha256(charToRaw(tojs(body)))
  if (!is.null(key)) {
    sig <- cpssign(body$body_sha256, key)
    body$signature <- unclass(sig)
    body$public_key <- unclass(if (inherits(key, "bricklayer_signing_key")) {
      signpubkey(key)
    } else {
      fipspubkey(key)
    })
  }
  class(body) <- c("bricklayer_recode_manifest", "list")
  body
}

#' Write and verify a recode manifest
#'
#' @description
#' \code{wrrcdmnf()} saves a manifest from
#' \code{\link{rcdmnf}} as a JSON file. \code{vrfrcdmnf()}
#' reads such a file back and checks it against the data: that the mapping
#' and the manifest body are unchanged since they were written, that the
#' recode in the data still matches the recorded mapping, that the recoded
#' counts are the recorded counts, and, for a signed manifest, that the
#' signature verifies. Use the pair to hand a recode to a reviewer or to
#' re-check it before a later analysis.
#'
#' @details
#' \code{vrfrcdmnf()} collects every failure in \code{reasons}
#' instead of stopping at the first:
#' \itemize{
#'   \item the SHA-256 of the stored mapping differs from \code{mapping_sha256};
#'   \item the SHA-256 of the body (all fields except \code{body_sha256},
#'     \code{signature} and \code{public_key}) differs from \code{body_sha256},
#'     meaning the file was edited after it was written;
#'   \item \code{\link{vrfrcd}(original, recoded, mapping)} fails;
#'   \item the counts of \code{recoded} differ from \code{counts_after}.
#' }
#' The signature, when present, is checked with \code{\link{cpsvrf}}
#' over the stored \code{body_sha256}. It therefore proves who wrote that
#' hash; the body check above proves the body still matches it. Both are
#' needed for \code{ok = TRUE}.
#'
#' \code{wrrcdmnf()} errors when \code{man} is not a
#' \code{bricklayer_recode_manifest}; it overwrites \code{path}.
#'
#' @param man A manifest returned by \code{\link{rcdmnf}}.
#' @param path Character string: the JSON file to write
#'   (\code{wrrcdmnf()}) or read (\code{vrfrcdmnf()}).
#' @return \code{wrrcdmnf()} returns \code{path} invisibly.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' x <- c("W", "B", "W")
#' y <- grdrcd(x, c(W = "White", B = "Black"))
#' m <- rcdmnf(x, y, c(W = "White", B = "Black"))
#' p <- wrrcdmnf(m, tempfile(fileext = ".json"))
#' vrfrcdmnf(p, x, y)$ok
#'
#' # the data changed after the manifest was written
#' y2 <- y
#' y2[2] <- "White"
#' vrfrcdmnf(p, x, y2)$reasons
#'
#' # only manifests can be written
#' try(wrrcdmnf(list(a = 1), tempfile()))
#' @export
wrrcdmnf <- function(man, path) {
  if (!inherits(man, "bricklayer_recode_manifest")) {
    stop("wrrcdmnf: `man` must come from rcdmnf()",
      call. = FALSE
    )
  }
  if (is.null(path)) stop("`path` must be a file path or a connection", call. = FALSE)
  path <- .rmbl_out_file(path, "path")
  writeLines(tojs(unclass(man)), path)
  invisible(path)
}

#' @rdname wrrcdmnf
#' @param orig,recd The vectors before and after the recode, to check
#'   the manifest against.
#' @return \code{vrfrcdmnf()} returns a list with \code{ok}
#'   (logical), \code{reasons} (character; empty, \code{character(0)}, when
#'   \code{ok}), \code{signature_ok} (logical, \code{NA} when the manifest is
#'   unsigned) and \code{manifest} (the parsed JSON as a list).
#' @export
vrfrcdmnf <- function(path, orig, recd) {
  .rmbl_no_fn(recoded = recd)
  path <- .rmbl_file1(path, "path")
  m <- .rmbl_json_text(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
  reasons <- character(0)
  mapping <- unlist(m$mapping)
  sha <- csha256(charToRaw(
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
  body_sha <- csha256(charToRaw(tojs(check)))
  if (!identical(body_sha, m$body_sha256)) {
    reasons <- c(reasons, "manifest body was altered after it was written")
  }
  r <- tryCatch(
    {
      vrfrcd(orig, recd, mapping)
      TRUE
    },
    error = function(e) conditionMessage(e)
  )
  if (!isTRUE(r)) reasons <- c(reasons, r)
  after <- table(as.character(recd), useNA = "no")
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
    sig_ok <- isTRUE(cpsvrf(m$body_sha256, sig, pk))
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
#' values otherwise; all of them must be names of \code{map} or members
#' of \code{keep}, so for a factor even an unused level must be mapped. The
#' recode itself is \code{\link{grdrcd}}. The levels of the result are
#' the distinct values of \code{map} in the order given, followed by the
#' \code{keep} labels that occur in the data.
#'
#' Errors: \code{map} without names (including a plain vector of new
#' labels); a level with no mapping.
#'
#' @param x A factor or character vector.
#' @param map Named character vector, old label = new label. Every level
#'   of \code{x} must appear as a name unless listed in \code{keep}. Several
#'   old labels may map to one new label.
#' @param keep Character vector, default empty: levels allowed to pass
#'   through unchanged.
#' @return A factor with the new labels, levels in the order of
#'   \code{mapping}, carrying a \code{recode_audit} attribute (see
#'   \code{\link{grdrcd}}).
#' @seealso \code{\link{grdrcd}}, \code{\link{rlblfrns}},
#'   \code{\link{declbld}}
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' f <- factor(c("W", "B", "O", "W"))
#' relbl(f, c(W = "White", B = "Black", O = "Other"))
#'
#' # the level order follows the mapping, not the alphabet
#' levels(relbl(f, c(W = "White", O = "Other", B = "Black")))
#'
#' # a kept label passes through
#' relbl(c("W", "B", "X"), c(W = "White", B = "Black"), keep = "X")
#'
#' # positional labels are refused
#' try(relbl(f, c("Black", "Other", "White")))
#' @export
relbl <- function(x, map, keep = character()) {
  if (is.null(x) || !is.atomic(x) || is.complex(x) || is.raw(x)) {
    stop("`x` must be a vector of labels (character, factor or numbers)", call. = FALSE)
  }
  if (is.null(names(map)) || !all(nzchar(names(map)))) {
    stop("relabel: `map` must be NAMED (old label = new label). ",
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
  unmapped <- setdiff(old, c(names(map), keep))
  if (length(unmapped)) {
    stop("relabel: level(s) with NO mapping: ",
      paste(.rmbl_squote(unmapped), collapse = ", "),
      ". Name every level or list it in `keep`.",
      call. = FALSE
    )
  }
  out <- grdrcd(as.character(x), map, keep = keep)
  lev <- unique(c(unname(map), keep))
  keep_lev <- lev %in% as.character(out) | lev %in% unname(map)
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
#' it is used and \code{vlabs} is ignored; otherwise
#' \code{vlabs} (code = label) is required. Decoding is done by
#' \code{\link{deccodes}}. The levels are the labels ordered by their
#' numeric code (codes that are not numbers are ordered after the numeric
#' ones, by string), and include labels of codes that do not occur.
#'
#' Errors: a \code{labels} attribute without names; no attribute and no
#' \code{vlabs}; a code with no label.
#'
#' @param x A vector with a \code{labels} attribute (as produced by haven),
#'   or a plain vector of codes when \code{vlabs} is supplied. A factor,
#'   ordered or not, is read through its integer codes; the result is an
#'   unordered factor whose levels follow the codes.
#' @param vlabs Optional named character vector, code = label, used
#'   only when \code{x} carries no \code{labels} attribute. Default
#'   \code{NULL}.
#' @return A factor whose levels are the labels in code order (not
#'   alphabetical), with a \code{recode_audit} attribute as described in
#'   \code{\link{grdrcd}}.
#' @seealso \code{\link{deccodes}}, \code{\link{relbl}},
#'   \code{\link{xfrvrf}}
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' x <- structure(c(1, 2, 2, 4),
#'                labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
#' declbld(x)
#'
#' # plain codes with a code book; levels follow the codes 1, 2, 10
#' declbld(c(2, 1, 10), vlabs = c("10" = "Ten", "2" = "Two", "1" = "One"))
#'
#' # codes alone are not categories
#' try(declbld(c(1, 2, 2)))
#' @export
#' @srrstats {G2.4d} Builds a factor explicitly, factor(..., levels = labels in code order), from labelled codes.
declbld <- function(x, vlabs = NULL) {
  .rmbl_no_fn(x = x)
  if (!is.atomic(x) && !is.factor(x)) stop("`x` must be a vector of codes", call. = FALSE)
  lab <- attr(x, "labels", exact = TRUE)
  if (!is.null(lab)) {
    if (is.null(names(lab))) {
      stop("declbld: the `labels` attribute has no names",
        call. = FALSE
      )
    }
    vlabs <- stats::setNames(names(lab), as.character(unname(lab)))
  }
  if (is.null(vlabs)) {
    stop("declbld: `x` carries no `labels` attribute and ",
      "`vlabs` was not ",
      "supplied; the codes alone are NOT the categories",
      call. = FALSE
    )
  }
  codes <- as.character(unclass(x))
  out <- deccodes(codes, vlabs)
  code_order <- order(suppressWarnings(as.numeric(names(vlabs))),
                      names(vlabs))
  f <- factor(as.character(out), levels = unname(vlabs[code_order]))
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
#' a sequence \eqn{M_1, \dots, M_k} meaning \dQuote{true group \eqn{L_i} was seen as
#' \eqn{M_i}}. It matches when \eqn{M_i =} \code{observed[L_i]} for all
#' \eqn{i}. There are five fixed mechanisms, \eqn{k - 1} rotations, and two
#' frequency orders with \code{cnts}. When \code{obs} is the identity
#' no mechanism is reported as matching.
#'
#' Errors: either argument unnamed; \code{obs} not a permutation of the
#' labels in \code{vlabs}.
#'
#' @param vlabs Named character vector, code = true label, in code
#'   order (the source program's code book).
#' @param obs Named character vector, true label = label it was seen
#'   under, covering every label once.
#' @param cnts Optional named numeric vector of frequencies per true label,
#'   default \code{NULL}. Enables the two frequency-order mechanisms.
#' @return A data frame of class \code{c("bricklayer_relabel_forensics",
#'   "data.frame")} with one row per mechanism tried and columns
#'   \code{mechanism} (character), \code{permutation} (character,
#'   \code{"A -> B, ..."}) and \code{matches} (logical). The \code{verdict}
#'   attribute is a character summary. The print method shows only the
#'   matching mechanisms and the verdict.
#' @seealso \code{\link{vrfmrg}}, \code{\link{relbl}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # the OHRC 2023 case: alphabetical labels assigned to codes 1-4
#' vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
#' obs <- c(White = "Black", Black = "Other", Other = "Unknown",
#'          Unknown = "White")
#' rlblfrns(vl, obs)
#'
#' # a frequency-ordered relabel needs the counts
#' obs2 <- c(White = "White", Black = "Other", Other = "Black",
#'           Unknown = "Unknown")
#' rf <- rlblfrns(vl, obs2, cnts = c(White = 50, Black = 10,
#'                                              Other = 30, Unknown = 5))
#' rf$mechanism[rf$matches]
#'
#' # observed must be a permutation of the labels
#' try(rlblfrns(vl, c(White = "Black")))
#' @export
rlblfrns <- function(vlabs, obs, cnts = NULL) {
  .rmbl_no_fn(value_labels = vlabs, observed = obs, counts = cnts)
  if (!is.null(cnts)) cnts <- stats::setNames(.rmbl_num(cnts, "cnts"), names(cnts))   # read by label
  if (is.null(names(vlabs)) || is.null(names(obs))) {
    stop("rlblfrns: `vlabs` (code = label) and `obs` ",
      "(true = seen) ",
      "must both be named",
      call. = FALSE
    )
  }
  labs <- unname(vlabs)
  k <- length(labs)
  if (!setequal(names(obs), labs) || !setequal(unname(obs), labs)) {
    stop("rlblfrns: `obs` must be a permutation of the labels ",
      "in `vlabs`",
      call. = FALSE
    )
  }
  .obs <- unname(obs[labs])
  mech <- list(
    "labels sorted alphabetically, assigned by code position" =
      sort(labs, method = "radix"),
    "labels sorted case-insensitively, assigned by code position" =
      labs[order(tolower(labs), method = "radix")],
    "labels sorted in reverse, assigned by code position" =
      rev(sort(labs, method = "radix")),
    "labels reversed" = rev(labs),
    "codes sorted as strings, labels assigned in that order" =
      labs[order(as.character(names(vlabs)), method = "radix")]
  )
  for (r in seq_len(k - 1L)) {
    mech[[sprintf("rotation by %d position(s)", r)]] <-
      labs[((seq_len(k) - 1L + r) %% k) + 1L]
  }
  if (!is.null(cnts)) {
    cnt <- cnts[labs]
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
      matches = identical(perm, .obs), stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (identical(.obs, labs)) {
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
#'     \code{codebook} is given, the two are compared code by code; any
#'     code whose label differs (or that is present in only one) is a
#'     disagreement.
#'   \item The vector is decoded: by its \code{labels} attribute
#'     (\code{\link{declbld}}), else by \code{codebook}, else taken
#'     as already-decoded labels.
#'   \item The decoded labels are checked with
#'     \code{\link{vrfmrg}} against \code{soucnts}.
#' }
#' With \code{strict = TRUE} the first disagreement is an error. With
#' \code{strict = FALSE} both checks run and are reported. A code without a
#' label is an error in either mode (from the decoding step).
#'
#' @param imported The vector as it arrived. It is a haven-style labelled vector,
#'   plain codes given with \code{codebook}, or labels already decoded.
#' @param soucnts Named numeric vector, label = count, as printed by
#'   the source program (SPSS FREQUENCIES, Stata tabulate).
#' @param codebook Optional named character vector, code = label, from the
#'   source program's variable view. Default \code{NULL}. When
#'   \code{imported} carries a \code{labels} attribute the two are compared
#'   and any disagreement fails the check.
#' @param tol Non-negative number, default \code{0}: the absolute
#'   difference in count allowed per label, passed to
#'   \code{\link{vrfmrg}}.
#' @param strict Logical, default \code{TRUE}: any disagreement is an error.
#'   When \code{FALSE} the result comes back with \code{ok = FALSE},
#'   \code{reasons}, and \code{marginals$permutation} ready for
#'   \code{\link{rlblfrns}}.
#' @return A list with \code{ok} (logical), \code{decoded} (a factor; in code
#'   order when decoded from codes), \code{marginals} (the
#'   \code{\link{vrfmrg}} result), \code{code_book_ok} (logical, or
#'   \code{NA} when there was nothing to compare) and \code{reasons}
#'   (character messages, or \code{NULL} when \code{ok}).
#' @seealso \code{\link{declbld}}, \code{\link{vrfmrg}},
#'   \code{\link{rlblfrns}}
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' x <- structure(c(1, 1, 2, 4, 1),
#'                labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
#' xfrvrf(x, c(White = 3, Black = 1, Unknown = 1))$ok
#'
#' # counts that only match under swapped labels, reported without stopping
#' r <- xfrvrf(x, c(White = 1, Black = 3, Unknown = 1), strict = FALSE)
#' r$ok
#' r$marginals$permutation
#'
#' # value labels that disagree with the source code book
#' try(xfrvrf(x, c(White = 3, Black = 1, Unknown = 1),
#'   codebook = c("1" = "White", "2" = "Other", "3" = "Black", "4" = "Unknown")))
#' @export
xfrvrf <- function(imported, soucnts, codebook = NULL,
                            tol = 0, strict = TRUE) {
  .rmbl_no_fn(imported = imported, code_book = codebook)
  strict <- .rmbl_flag1(strict, "strict")
  if (!is.null(codebook) &&
        (!is.atomic(codebook) || is.null(names(codebook)) || inherits(codebook, c("Date", "POSIXt")))) {
    stop("`codebook` must be a named vector (code = label), or NULL", call. = FALSE)
  }
  tol <- .rmbl_scalar(tol, "tol", 0)
  lab <- attr(imported, "labels", exact = TRUE)
  code_book_ok <- NA
  if (!is.null(lab) && !is.null(codebook)) {
    got <- stats::setNames(names(lab), as.character(unname(lab)))
    want <- stats::setNames(unname(codebook), as.character(names(codebook)))
    bad <- setdiff(
      union(names(got), names(want)),
      names(got)[names(got) %in% names(want) & got == want[names(got)]]
    )
    code_book_ok <- !length(bad)
    if (!code_book_ok && strict) {
      stop("xfrvrf: the value labels that arrived disagree with the ",
        "source code ",
        "book at code(s) ", paste(bad, collapse = ", "), ": arrived ",
        paste(paste0(bad, "=", got[bad]), collapse = ", "), "; source ",
        paste(paste0(bad, "=", want[bad]), collapse = ", "),
        call. = FALSE
      )
    }
  }
  decoded <- if (!is.null(lab)) {
    declbld(imported)
  } else if (!is.null(codebook)) {
    declbld(imported, vlabs = codebook)
  } else {
    # keep every label that arrived: one absent from the source counts must
    # be reported by the marginals check, never dropped as NA
    lab_all <- as.character(imported)
    seen <- lab_all[!is.na(lab_all)]
    factor(lab_all, levels = unique(c(names(soucnts), seen)))
  }
  m <- vrfmrg(as.character(decoded), soucnts,
    tol = tol, strict = strict
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
