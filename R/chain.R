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
#' Keeps a history of runs (one manifest per run) as a hash chain: each
#' entry records the digest of the entry before it, so the chain's
#' integrity covers the ORDER and COMPLETENESS of the history, not merely
#' the contents of each manifest. Deleting an entry, inserting one, or
#' editing one breaks the links from that point onward, and
#' [chnvrf()] reports the first index where the break
#' occurs. Use it
#' when the record of which analyses were run, and in what order, has to be
#' auditable.
#'
#' \code{chnnew()} starts an empty chain, \code{chnapp()} adds an
#' entry, \code{chnhead()} returns the last link, \code{chnvrf()}
#' checks every link and \code{chnseal()} returns one digest to sign.
#'
#' @details
#' This is the structure behind an append-only audit log, and it is what a
#' per-manifest digest alone cannot give you: individually valid manifests
#' say nothing about whether any were removed.
#'
#' Each entry stores \code{payload}, the SHA-256 of the entry (of its UTF-8
#' bytes for a single string, otherwise of \code{serialize(entry, version =
#' 2, xdr = TRUE)} with the four bytes that name the writer's R version set
#' to zero), \code{prev}, the previous link (64 zeros for the first),
#' \code{scheme} (2) and \code{digest} = SHA-256 of
#' \code{"v2|<prev>|<payload>|<label>"}, where \code{<label>} is \code{"0"}
#' for a missing label and \code{"1"} followed by the label otherwise. The
#' entry itself is not kept, only its digest; the label is covered, so
#' editing it breaks the link. Zeroing the writer-version bytes makes the
#' payload the same on every R version, for any R object (a canonical JSON
#' encoding would cover only the objects JSON can hold); the rest of a
#' version-2 stream depends only on the object.
#'
#' Entries written by 0.5.12 and earlier carry no \code{scheme}. Their
#' digest is the SHA-256 of the string \code{"<prev>:<payload>"} (the label not covered,
#' and the payload of a non-string entry taken over serialized bytes that
#' include the writer's R version). \code{chnvrf()} and
#' \code{chnseal()} still accept them under those rules, with a warning
#' that they were sealed with the weaker scheme. Appending to such a chain
#' adds scheme-2 entries.
#'
#' \code{chnvrf()} walks the chain from the start: an entry fails when
#' its \code{prev} is not the previous link, its \code{scheme} is neither 2
#' nor absent, or its \code{digest} does not recompute (compared in constant
#' time with [cdgsteq()]).
#'
#' ## What the head covers, and what it does not
#'
#' \code{chnhead()} is the STORED digest of the last entry. Deleting an
#' entry from the MIDDLE leaves that value untouched -- the stored digests
#' do not change, only the links between them stop agreeing -- so the head
#' alone will not notice. [chnvrf()] will,
#' and names the index.
#'
#' Conversely, truncating from the END leaves a perfectly valid prefix that
#' [chnvrf()] accepts, while the head
#' changes.
#'
#' The two failures are complementary, which is why \code{chnseal()}
#' exists: it verifies the links AND folds the entry count and every link
#' digest into one value (SHA-256 of the count and the links joined by
#' \code{"|"}), so a single signature over the seal detects an edit, a
#' deletion, a reordering, an insertion and a truncation alike. Sign the
#' seal, not the head.
#'
#' Signing is what turns tamper-EVIDENT into tamper-PROOF: without a
#' signature an attacker who rewrites the whole chain leaves it internally
#' consistent, because recomputing every link is cheap.
#'
#' Error: a \code{chain} that does not come from \code{chnnew()} (for
#' \code{chnapp()}, \code{chnhead()} and \code{chnvrf()}).
#'
#' @param chain A chain from \code{chnnew()} or \code{chnapp()}.
#' @param entry Any object to record. It is digested through
#'   its own deterministic serialization, so lists and data frames are
#'   accepted as readily as strings.
#' @param label Optional short label for the entry (the first element of
#'   \code{as.character(label)} is kept); \code{NA} by default. Covered by
#'   the entry's digest.
#' @return \code{chnnew()} and \code{chnapp()} return an object of
#'   class \code{c("bricklayer_chain", "list")} with \code{entries} (a list of
#'   entries, each with \code{label}, \code{payload}, \code{prev},
#'   \code{scheme} and \code{digest}) and \code{genesis} (64 zeros).
#'   \code{chnvrf()} returns a
#'   list of class \code{bricklayer_chain_check} with \code{valid} (logical),
#'   \code{n} (integer, entries), \code{broken_at} (integer index of the first
#'   bad entry, \code{NA} when intact) and \code{head}. \code{chnhead()}
#'   returns the head digest (64 hex characters; the genesis value for an
#'   empty chain). \code{chnseal()} returns a single digest over the verified
#'   chain's length and links, or \code{NA} if the chain does not verify.
#' @seealso
#' [cpssign()] to sign the seal,
#' [mrkroot()] for pinning the contents of
#' one capsule rather than a history.
#' @examples
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' ch <- chnnew()
#' ch <- chnapp(ch, "manifest for run 1", label = "run-1")
#' ch <- chnapp(ch, "manifest for run 2", label = "run-2")
#' ch <- chnapp(ch, "manifest for run 3", label = "run-3")
#' ch
#'
#' # An intact chain verifies.
#' chnvrf(ch)$valid
#'
#' # Editing an entry breaks it, and names where.
#' edited <- ch
#' edited$entries[[2]]$digest <- csha256("something else")
#' chnvrf(edited)$valid
#' chnvrf(edited)$broken_at
#'
#' # So does deleting one, which a per-manifest digest would not catch.
#' dropped <- ch
#' dropped$entries[[2]] <- NULL
#' chnvrf(dropped)$valid
#'
#' # Sign the SEAL, which covers the links and the length together.
#' key <- pqckg(height = 2)
#' sig <- cpssign(chnseal(ch), key)
#' cpsvrf(chnseal(ch), sig, signpubkey(key))
#'
#' # Truncating the chain still seals, but to a different value, so the
#' # signature no longer verifies.
#' truncated <- ch
#' truncated$entries[[3]] <- NULL
#' cpsvrf(chnseal(truncated), sig, signpubkey(key))
#'
#' # A chain whose links disagree has no seal to present at all.
#' chnseal(dropped)
#'
#' # any object can be an entry, such as a whole manifest list
#' ch2 <- chnapp(chnnew(), list(run = 1, mean = 2.5), label = "list entry")
#' chnhead(ch2)
#'
#' # only chains are accepted
#' try(chnvrf(list(entries = list())))
#' options(op)
#' @name chn
#' @export
chnnew <- function() {
  out <- list(entries = list(),
              genesis = paste(rep("0", 64L), collapse = ""))
  class(out) <- c("bricklayer_chain", "list")
  out
}

#' @rdname chn
#' @export
chnapp <- function(chain, entry, label = NA_character_) {
  .rmbl_no_fn(label = label)
  if (!inherits(chain, "bricklayer_chain")) {
    stop("chnapp: `chain` must come from chnnew()", call. = FALSE)
  }
  prev <- chnhead(chain)
  payload <- .rmbl_entry_digest(entry)
  label <- as.character(label)[1L]
  rec <- list(
    label = label,
    payload = payload,
    prev = prev,
    scheme = 2L,
    # The link digest covers the payload, the label AND the previous link,
    # which is what ties the entry to its position in the history.
    digest = .rmbl_link_digest(prev, payload, label, 2L)
  )
  chain$entries[[length(chain$entries) + 1L]] <- rec
  chain
}

#' @rdname chn
#' @export
chnhead <- function(chain) {
  if (!inherits(chain, "bricklayer_chain")) {
    stop("chnhead: `chain` must come from chnnew()", call. = FALSE)
  }
  n <- length(chain$entries)
  if (n == 0L) return(chain$genesis)
  chain$entries[[n]]$digest
}

#' @rdname chn
#' @export
chnseal <- function(chain) {
  chk <- .rmbl_chain_check(chain, warn = TRUE)
  if (!isTRUE(chk$valid)) return(NA_character_)
  # Fold the LENGTH in as well as every link digest: without the count, a
  # truncated chain would seal to a prefix of the same material.
  parts <- c(as.character(chk$n),
             vapply(chain$entries, function(e) e$digest, character(1)))
  csha256(paste(parts, collapse = "|"))
}

#' @rdname chn
#' @export
chnvrf <- function(chain) {
  .rmbl_chain_check(chain, warn = TRUE)
}

#' Walks a chain and finds the first entry whose link does not verify.
#'
#' The walk behind chnvrf(), chnseal() and format(): `warn` says
#' whether entries sealed under scheme 1 (0.5.12 and earlier) are reported.
#' @param chain A chain made by chnnew().
#' @param warn Whether entries sealed under scheme 1 are reported in a warning.
#' @return A `bricklayer_chain_check` list: `valid`, `n`, `broken_at` (NA when none) and `head`.
#' @noRd
.rmbl_chain_check <- function(chain, warn) {
  if (!inherits(chain, "bricklayer_chain")) {
    stop(.rmbl_fn(), "`chain` must come from chnnew()", call. = FALSE)
  }
  n <- length(chain$entries)
  prev <- chain$genesis
  broken <- NA_integer_
  legacy <- integer(0)
  for (i in seq_len(n)) {
    e <- chain$entries[[i]]
    sc <- e[["scheme"]]
    if (is.null(sc)) legacy <- c(legacy, i)
    ok <- is.character(e$prev) && identical(e$prev, prev) && is.character(e$payload) &&
      length(e$payload) == 1L && (is.null(sc) || (is.numeric(sc) && length(sc) == 1L && isTRUE(sc == 2))) &&
      cdgsteq(e$digest, .rmbl_link_digest(prev, e$payload, e$label, if (is.null(sc)) 1L else 2L))
    if (!isTRUE(ok)) {
      broken <- i
      break
    }
    prev <- e$digest
  }
  if (warn && length(legacy)) {
    warning(sprintf(paste0("chain entr%s %s %s sealed by rmoriebricklayer 0.5.12 or earlier with the ",
                           "weaker scheme 1: %s label%s not covered by the digests"),
                    if (length(legacy) == 1L) "y" else "ies", paste(legacy, collapse = ", "),
                    if (length(legacy) == 1L) "was" else "were",
                    if (length(legacy) == 1L) "its" else "their", if (length(legacy) == 1L) " is" else "s are"),
            call. = FALSE)
  }
  out <- list(valid = is.na(broken), n = n, broken_at = broken,
              head = chnhead(chain))
  class(out) <- c("bricklayer_chain_check", "list")
  out
}

#' Computes the digest of one chain link.
#'
#' One link's digest. Scheme 2 covers the label: "0" for a missing label and
#' "1" + the label otherwise, after the fixed-width prev and payload, so no
#' two (prev, payload, label) triples share a preimage. Scheme 1 (0.5.12 and
#' earlier) is "<prev>:<payload>" and is only ever recomputed, never written.
#' @param prev The previous link digest (the genesis digest for the first entry).
#' @param payload The entry digest.
#' @param label The entry label, or NULL or NA when it has none.
#' @param scheme The sealing scheme, 1 or 2.
#' @return The link digest as hex text.
#' @noRd
.rmbl_link_digest <- function(prev, payload, label, scheme) {
  if (scheme == 1L) return(csha256(paste0(prev, ":", payload)))
  lab <- if (length(label) != 1L || is.na(label)) "0" else paste0("1", enc2utf8(as.character(label)))
  csha256(paste0("v2|", prev, "|", payload, "|", lab))
}

#' Computes a deterministic SHA-256 digest of an R object.
#'
#' Deterministic digest of an arbitrary object. serialize() with a fixed
#' version and no native encoding gives the same bytes on every platform,
#' which a printed representation would not -- except bytes 7 to 10 of the
#' header, the version of R that wrote the stream. Those are zeroed, so the
#' digest is the same on every R version; the rest of a version-2 stream is
#' fixed by the object (format version 2, reader version 2.3.0).
#' @param entry The object; a single string is digested as its text.
#' @return The digest as hex text.
#' @noRd
.rmbl_entry_digest <- function(entry) {
  if (is.character(entry) && length(entry) == 1L && !is.na(entry)) {
    return(csha256(entry))
  }
  b <- serialize(entry, NULL, version = 2L, xdr = TRUE)
  b[7:10] <- as.raw(0L)
  csha256(b)
}

#' @export
format.bricklayer_chain <- function(x, ...) {
  chk <- .rmbl_chain_check(x, warn = FALSE)
  g <- .rmbl_glyphs()
  head_lines <- c(
    .rmbl_rule("Manifest chain"),
    paste0("  ", if (chk$valid) paste0(g$ok, " chain intact") else
      paste0(g$bad, " chain BROKEN at entry ", chk$broken_at)),
    "",
    .rmbl_kv(list(entries = chk$n, head = chk$head,
                  seal = if (chk$valid) suppressWarnings(chnseal(x)) else
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

#' @rdname printmeth
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
