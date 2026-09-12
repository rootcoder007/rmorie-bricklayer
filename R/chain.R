# SPDX-License-Identifier: AGPL-3.0-or-later
#
# A single signed manifest proves one run. It does not prove the RUN
# HISTORY: someone can delete an inconvenient run, or insert one, and
# every remaining manifest still verifies on its own. Linking each entry
# to the digest of the one before makes the sequence itself tamper-
# evident -- removing, reordering or editing any entry breaks every
# digest after it.

#' Tamper-evident chain of capsule manifests
#'
#' Each entry records the digest of the entry before it, so the chain's
#' integrity covers the ORDER and COMPLETENESS of the history, not merely
#' the contents of each manifest. Deleting an entry, inserting one, or
#' editing one breaks the links from that point onward, and
#' [chain_verify()] reports the first index where the break occurs.
#'
#' This is the structure behind an append-only audit log, and it is what
#' a per-manifest digest alone cannot give you: individually valid
#' manifests say nothing about whether any were removed.
#'
#' # What the head covers, and what it does not
#'
#' `chain_head()` is the STORED digest of the last entry. Deleting an
#' entry from the MIDDLE leaves that value untouched -- the stored
#' digests do not change, only the links between them stop agreeing --
#' so the head alone will not notice. [chain_verify()] will, and names
#' the index.
#'
#' Conversely, truncating from the END leaves a perfectly valid prefix
#' that [chain_verify()] accepts, while the head changes.
#'
#' The two failures are complementary, which is why `chain_seal()`
#' exists: it verifies the links AND folds the entry count and every
#' link digest into one value, so a single signature over the seal
#' detects an edit, a deletion, a reordering, an insertion and a
#' truncation alike. Sign the seal, not the head.
#'
#' Signing is what turns tamper-EVIDENT into tamper-PROOF: without a
#' signature an attacker who rewrites the whole chain leaves it
#' internally consistent, because recomputing every link is cheap.
#'
#' @param chain A chain from `chain_new()` or `chain_append()`.
#' @param entry Any object to record. It is digested through its own
#'   deterministic serialization, so lists and data frames are accepted
#'   as readily as strings.
#' @param label Optional short character label for the entry.
#' @return `chain_new()` and `chain_append()` return an object of class
#'   `bricklayer_chain`. `chain_verify()` returns a list with `valid`,
#'   `n`, `broken_at` (`NA` when intact) and `head`. `chain_head()`
#'   returns the head digest. `chain_seal()` returns a single digest over
#'   the verified chain's length and links, or `NA` if the chain does not
#'   verify.
#' @seealso [capsule_sign()] to sign the head, [merkle_root()] for
#'   pinning the contents of one capsule rather than a history.
#' @examples
#' ch <- chain_new()
#' ch <- chain_append(ch, "manifest for run 1", label = "run-1")
#' ch <- chain_append(ch, "manifest for run 2", label = "run-2")
#' ch <- chain_append(ch, "manifest for run 3", label = "run-3")
#' ch
#'
#' # An intact chain verifies.
#' chain_verify(ch)$valid
#'
#' # Editing an entry breaks it, and names where.
#' edited <- ch
#' edited$entries[[2]]$digest <- core_sha256("something else")
#' chain_verify(edited)$valid
#' chain_verify(edited)$broken_at
#'
#' # So does deleting one, which a per-manifest digest would not catch.
#' dropped <- ch
#' dropped$entries[[2]] <- NULL
#' chain_verify(dropped)$valid
#'
#' # Sign the SEAL, which covers the links and the length together.
#' key <- pqc_keygen(height = 2)
#' sig <- capsule_sign(chain_seal(ch), key)
#' capsule_verify(chain_seal(ch), sig, signing_public_key(key))
#'
#' # Truncating the chain still seals, but to a different value, so the
#' # signature no longer verifies.
#' truncated <- ch
#' truncated$entries[[3]] <- NULL
#' capsule_verify(chain_seal(truncated), sig, signing_public_key(key))
#'
#' # A chain whose links disagree has no seal to present at all.
#' chain_seal(dropped)
#' @name rmbl_chain
#' @export
chain_new <- function() {
  out <- list(entries = list(),
              genesis = paste(rep("0", 64L), collapse = ""))
  class(out) <- c("bricklayer_chain", "list")
  out
}

#' @rdname rmbl_chain
#' @export
chain_append <- function(chain, entry, label = NA_character_) {
  if (!inherits(chain, "bricklayer_chain")) {
    stop("`chain` must come from chain_new()", call. = FALSE)
  }
  prev <- chain_head(chain)
  payload <- .rmbl_entry_digest(entry)
  rec <- list(
    label = as.character(label)[1L],
    payload = payload,
    prev = prev,
    # The link digest covers the payload AND the previous link, which is
    # what ties the entry to its position in the history.
    digest = core_sha256(paste0(prev, ":", payload))
  )
  chain$entries[[length(chain$entries) + 1L]] <- rec
  chain
}

#' @rdname rmbl_chain
#' @export
chain_head <- function(chain) {
  if (!inherits(chain, "bricklayer_chain")) {
    stop("`chain` must come from chain_new()", call. = FALSE)
  }
  n <- length(chain$entries)
  if (n == 0L) return(chain$genesis)
  chain$entries[[n]]$digest
}

#' @rdname rmbl_chain
#' @export
chain_seal <- function(chain) {
  chk <- chain_verify(chain)
  if (!isTRUE(chk$valid)) return(NA_character_)
  # Fold the LENGTH in as well as every link digest: without the count, a
  # truncated chain would seal to a prefix of the same material.
  parts <- c(as.character(chk$n),
             vapply(chain$entries, function(e) e$digest, character(1)))
  core_sha256(paste(parts, collapse = "|"))
}

#' @rdname rmbl_chain
#' @export
chain_verify <- function(chain) {
  if (!inherits(chain, "bricklayer_chain")) {
    stop("`chain` must come from chain_new()", call. = FALSE)
  }
  n <- length(chain$entries)
  prev <- chain$genesis
  broken <- NA_integer_
  for (i in seq_len(n)) {
    e <- chain$entries[[i]]
    ok <- is.character(e$prev) && identical(e$prev, prev) &&
      core_digest_equal(e$digest, core_sha256(paste0(prev, ":", e$payload)))
    if (!isTRUE(ok)) {
      broken <- i
      break
    }
    prev <- e$digest
  }
  out <- list(valid = is.na(broken), n = n, broken_at = broken,
              head = chain_head(chain))
  class(out) <- c("bricklayer_chain_check", "list")
  out
}

# Deterministic digest of an arbitrary object. serialize() with a fixed
# version and no native encoding gives the same bytes on every platform,
# which a printed representation would not.
.rmbl_entry_digest <- function(entry) {
  if (is.character(entry) && length(entry) == 1L && !is.na(entry)) {
    return(core_sha256(entry))
  }
  core_sha256(serialize(entry, NULL, version = 2L, xdr = TRUE))
}

#' @export
format.bricklayer_chain <- function(x, ...) {
  chk <- chain_verify(x)
  g <- .rmbl_glyphs()
  head_lines <- c(
    .rmbl_rule("Manifest chain"),
    paste0("  ", if (chk$valid) paste0(g$ok, " chain intact") else
      paste0(g$bad, " chain BROKEN at entry ", chk$broken_at)),
    "",
    .rmbl_kv(list(entries = chk$n, head = chk$head,
                  seal = if (chk$valid) chain_seal(x) else
                    paste0(g$dash, " (chain broken)"))),
    "")
  if (chk$n == 0L) return(c(head_lines, "  (empty)", .rmbl_rule()))
  rows <- vapply(seq_len(chk$n), function(i) {
    e <- x$entries[[i]]
    sprintf("  %3d  %-16s %s", i,
            if (is.na(e$label)) paste0(g$dash, " ") else e$label,
            substring(e$digest, 1L, 24L))
  }, character(1))
  c(head_lines, rows, .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_chain <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
print.bricklayer_chain_check <- function(x, ...) {
  g <- .rmbl_glyphs()
  if (isTRUE(x$valid)) {
    cat(sprintf("%s chain intact (%d entries)\n", g$ok, x$n))
  } else {
    cat(sprintf("%s chain broken at entry %d of %d\n", g$bad, x$broken_at,
                x$n))
  }
  invisible(x)
}
