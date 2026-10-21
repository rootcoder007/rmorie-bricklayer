# The XMSS key file as the key's state, for `rmbl sign --scheme xmss-sha256`, and the index
# sightings that verify and sign read (RFC 10033, "Hash-Based Signatures: State and Backup
# Management"; NIST SP 800-208). The interactive session's record (R_user_dir) is not used here:
# the command line writes only the files it is pointed at.

# the reserved block of indices of each key while `rmbl sign` signs from it, by record id
.rmbl_xmss_block <- new.env(parent = emptyenv())

#' A key fingerprint: the first 16 hex characters of SHA-256 over the public key, root || pubseed.
#' @param public The public key as hex, as an attestation records it.
#' @return 16 hex characters.
#' @noRd
.rmbl_xmss_fpr <- function(public) substr(tolower(csha256(charToRaw(tolower(public)))), 1L, 16L)

#' A digest of one XMSS signature (its wire form), to tell two signatures at one index apart.
#' @param wire The signature's wire hex.
#' @return 16 hex characters.
#' @noRd
.rmbl_xmss_sigd <- function(wire) substr(tolower(csha256(charToRaw(tolower(wire)))), 1L, 16L)

#' The host fingerprint of a state's writer: SHA-256 of the host name and the boot id, no personal data.
#' @return 16 hex characters.
#' @noRd
.rmbl_xmss_writer <- function() {
  b <- tryCatch(readLines("/proc/sys/kernel/random/boot_id", n = 1L, warn = FALSE), error = function(e) "",
                warning = function(w) "")
  substr(tolower(csha256(charToRaw(paste0("rmoriebricklayer xmss writer\n", Sys.info()[["nodename"]], "\n",
                                          paste(b, collapse = ""))))), 1L, 16L)
}

#' Reads an XMSS key from the JSON pqckg() keys are saved as (with the state in `used`, if any).
#' @param txt The JSON text.
#' @param what What to call it in a refusal.
#' @return A list: `key` (a bricklayer_signing_key) and `used` (the state it carries, or NULL).
#' @noRd
.rmbl_xmss_key_json <- function(txt, what) {
  j <- tryCatch(.rmbl_json_text(txt, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(j) || !identical(j$scheme, "xmss-sha256")) {
    stop(sprintf("%s is not an xmss-sha256 key: give the JSON of a pqckg() key (tojs(unclass(key), auto_unbox = TRUE))",
                 what), call. = FALSE)
  }
  whole <- function(v, lo, hi) is.numeric(v) && length(v) == 1L && !is.na(v) && v == floor(v) && v >= lo && v <= hi
  if (!whole(j$height, 1, 16) || !whole(j$next_index, 0, 2^j$height)) {
    stop(sprintf(paste("%s: `height` or `next_index` is not a whole number in range: the key state is damaged;",
                       "do not hand-edit it"), what), call. = FALSE)
  }
  key <- j[setdiff(names(j), "used")]
  key$height <- as.integer(j$height)
  key$next_index <- as.integer(j$next_index)
  key$capacity <- bitwShiftL(1L, key$height)
  class(key) <- c("bricklayer_signing_key", "list")
  tryCatch({
    .rmbl_xmss_ids(key)
    .rmbl_check_seed(.rmbl_xkey(key, "skprf"), "skprf")
  }, error = function(e) stop(sprintf("%s: %s", what, conditionMessage(e)), call. = FALSE))
  list(key = key, used = j$used)
}

#' Checks a key's XMSS state and gives it back with whole numbers as integers.
#' @param st The state, as read from JSON.
#' @param fpr The key's fingerprint, which the state must name.
#' @param what The file it came from, for the refusal.
#' @return The state.
#' @noRd
.rmbl_xmss_state_check <- function(st, fpr, what) {
  w <- function(v, lo = -1) is.numeric(v) && length(v) == 1L && !is.na(v) && v == floor(v) && v >= lo && v < 2^31
  sc <- if (is.list(st)) st$sectors
  ok <- is.list(st) && identical(st$format, "rmbl-xmss-state/1") && identical(st$key, fpr) && w(st$highest) &&
    w(st$generation, 0) && (is.null(sc) || (is.list(sc) && w(sc$count, 2) && w(sc$base) && is.list(sc$highest) &&
                                              all(vapply(sc$highest, w, NA))))
  if (!ok) {
    stop(sprintf(paste("%s does not hold the XMSS state of this key (format rmbl-xmss-state/1, key %s): a state",
                       "that cannot be read cannot be trusted, so no signature is made"), what, fpr), call. = FALSE)
  }
  st$highest <- as.integer(st$highest)
  st$generation <- as.integer(st$generation)
  if (!is.null(sc)) {
    st$sectors <- list(count = as.integer(sc$count), base = as.integer(sc$base),
                       highest = stats::setNames(lapply(sc$highest, as.integer), names(sc$highest)))
  }
  st
}

#' Writes a file atomically: a temporary file in the same directory, flushed to the disk, renamed.
#' @param p The file.
#' @param txt Its new text.
#' @return `p`, invisibly.
#' @noRd
.rmbl_xmss_put <- function(p, txt) {
  tmp <- tempfile(pattern = paste0(basename(p), ".xmss-"), tmpdir = dirname(p), fileext = ".tmp")
  why <- .Call(C_rmbl_write_file_checked, tmp, p, charToRaw(enc2utf8(txt)))
  if (!is.null(why)) {
    stop(sprintf("could not write the XMSS state %s (%s): no signature is made", p, why), call. = FALSE)
  }
  invisible(p)
}

#' Reserves a block of indices in the key's durable state, before any signature exists (RFC 10033 section 4).
#'
#' Under the state file's lock: read the key and its state, take the sector's range, refuse a stale copy
#' (an index this key is seen to have signed above the state) and an exhausted range, then write the
#' state with the block marked used, atomically. Only then may the caller sign from the block.
#' @param kf The key file, or NULL when the key came from RMBL_KEY.
#' @param sf The state file, or NULL to keep the state in the key file.
#' @param keytxt The key's JSON when `kf` is NULL.
#' @param sec A list: `count` (--sectors), `index` (--sector-index) and `name` (--sector), each NULL if not given.
#' @param n How many indices to reserve.
#' @param seen The sightings of this key's signatures (xmssidxseen()).
#' @param rec_hi The highest index the used-index record shows, or -1.
#' @return A list: `key`, `fpr`, `from`, `to`, `sector`, `count`, `size`, `left`, `generation`, `prev`,
#'   `writer`, `where`.
#' @noRd
.rmbl_xmss_state_commit <- function(kf, sf, keytxt, sec, n, seen, rec_hi = -1L) {
  where <- sf %||% kf
  .rmbl_xmss_with_lock(where, function() {
    txt <- if (is.null(kf)) keytxt else paste(readLines(kf, warn = FALSE), collapse = "\n")
    kj <- .rmbl_xmss_key_json(txt, "the key")
    key <- kj$key
    fpr <- .rmbl_xmss_fpr(paste0(key$root, .rmbl_xkey(key, "pubseed")))
    fresh <- list(format = "rmbl-xmss-state/1", key = fpr, highest = -1L, generation = 0L)
    st <- if (!is.null(sf) && file.exists(sf) && file.size(sf) > 0) {
      tryCatch(.rmbl_json_text(readLines(sf, warn = FALSE), simplifyVector = FALSE),
               error = function(e) NULL)
    } else {
      kj$used %||% fresh
    }
    st <- .rmbl_xmss_state_check(st, fpr, where)
    cap <- key$capacity
    # what the key file's next_index and the used-index record say was used: never go back from it
    outside <- max(key$next_index - 1L, rec_hi)
    k <- sec$count
    if (!is.null(k) && (bitwAnd(k, k - 1L) != 0L || k > cap %/% 2L)) {
      stop(sprintf("--sectors must be a power of two from 2 to %d (half the %d indices of this key), not %d",
                   cap %/% 2L, cap, k), call. = FALSE)
    }
    if (is.null(st$sectors) && !is.null(k)) {
      # every index up to the highest used so far counts as used in every sector
      st$sectors <- list(count = k, base = max(st$highest, outside), highest = stats::setNames(list(), character()))
    }
    kk <- st$sectors$count %||% 1L
    if (kk > 1L) {
      if (key$next_index - 1L > st$highest) {
        stop(sprintf(paste("the key's next_index (%d) is past the highest index its sector state records (%d): it",
                           "signed outside rmbl sign after its state was split into sectors, so which indices",
                           "are used is not known. Generate a new key"), key$next_index, st$highest), call. = FALSE)
      }
      if (!is.null(k) && k != kk) {
        stop(sprintf("this key's state is split into %d sectors, not %d: give --sectors %d", kk, k, kk), call. = FALSE)
      }
      if (is.null(sec$index) && is.null(sec$name)) {
        stop(sprintf("this key's state is split into %d sectors: give --sector NAME or --sector-index I", kk),
             call. = FALSE)
      }
    } else if (!is.null(sec$index) || !is.null(sec$name)) {
      stop("--sector and --sector-index need --sectors K: this key's state is not split into sectors", call. = FALSE)
    }
    i <- if (kk == 1L) 0L else sec$index %||%
      (strtoi(substr(tolower(csha256(charToRaw(paste0(sec$name, fpr)))), 1L, 7L), 16L) %% kk)
    if (i >= kk) stop(sprintf("--sector-index must be below the %d sectors, not %d", kk, i), call. = FALSE)
    size <- cap %/% kk
    lo <- i * size
    end <- lo + size - 1L
    cur <- if (kk == 1L) max(st$highest, outside) else
      max(min(max(st$sectors$base, lo - 1L), end), st$sectors$highest[[as.character(i)]] %||% -1L)
    kn <- seen$index[seen$key == fpr & seen$index >= lo & seen$index <= end]
    if (length(kn) && max(kn) > cur) {
      stop(sprintf(paste("stale copy of the key: index %d of it was already signed (seen in %s), but this state",
                         "says the highest used in its range is %d. Signing would reuse an index: use the copy that",
                         "made that signature, or generate a new key"), max(kn),
                   seen$where[seen$key == fpr & seen$index == max(kn)][[1L]], cur), call. = FALSE)
    }
    from <- cur + 1L
    to <- from + as.integer(n) - 1L
    if (to > end) {
      stop(sprintf(paste("the key is exhausted in sector %d of %d (indices %d to %d): %d left, and this run needs %d.",
                         "Generate a new key"), i, kk, lo, end, end - cur, n), call. = FALSE)
    }
    st$highest <- max(st$highest, outside, to)
    if (kk > 1L) st$sectors$highest[[as.character(i)]] <- to
    prev <- st$writer %||% ""
    st$generation <- st$generation + 1L
    st$writer <- .rmbl_xmss_writer()
    st$reserved <- list(sector = i, from = from, to = to)
    if (is.null(sf)) {
      key$next_index <- st$highest + 1L
      .rmbl_xmss_put(kf, paste0(tojs(c(unclass(key), list(used = st)), auto_unbox = TRUE, pretty = TRUE,
                                     digits = NA), "\n"))
    } else {
      .rmbl_xmss_put(sf, paste0(tojs(st, auto_unbox = TRUE, pretty = TRUE, digits = NA), "\n"))
    }
    list(key = key, fpr = fpr, from = from, to = to, sector = i, count = kk, size = size, left = end - to,
         generation = st$generation, prev = prev, writer = st$writer, where = where)
  }, what = "the XMSS state")
}

#' Reads an XMSS seen-log: one line per signature, key fingerprint, index, signature digest, where.
#' @param f The log; a file that does not exist yet is an empty log.
#' @return A data frame (key, index, sig, where), or NULL.
#' @noRd
.rmbl_xmss_seen_read <- function(f) {
  if (dir.exists(f)) stop(.rmbl_fn(), "the XMSS seen-log ", .rmbl_printable(f), " is a directory", call. = FALSE)
  if (!file.exists(f)) return(NULL)
  l <- readLines(f, warn = FALSE)
  l <- l[nzchar(l) & !startsWith(l, "#")]
  p <- strsplit(l, "\t", fixed = TRUE)
  ok <- vapply(p, function(x) {
    length(x) == 4L && grepl("^[0-9a-f]{16}$", x[[1L]]) && grepl("^[0-9]{1,9}$", x[[2L]]) &&
      grepl("^[0-9a-f]{16}$", x[[3L]])
  }, NA)
  if (!all(ok)) {
    stop(.rmbl_fn(), sprintf(paste("%s (an XMSS seen-log) has %d malformed line(s): a log that cannot be read",
                                   "cannot be trusted"), .rmbl_printable(f), sum(!ok)), call. = FALSE)
  }
  data.frame(key = vapply(p, `[[`, "", 1L), index = as.integer(vapply(p, `[[`, "", 2L)),
             sig = vapply(p, `[[`, "", 3L), where = vapply(p, `[[`, "", 4L), stringsAsFactors = FALSE)
}

#' Appends signatures to an XMSS seen-log, with its header when the log is new.
#' @param f The log.
#' @param df Sightings (key, index, sig, where).
#' @return `f`, invisibly.
#' @noRd
.rmbl_xmss_seen_append <- function(f, df) {
  if (!file.exists(f)) {
    cat("# rmoriebricklayer xmss seen-log 1: key fingerprint, index, signature digest, where\n", file = f)
  }
  cat(paste0(df$key, "\t", df$index, "\t", df$sig, "\t", gsub("[\t\r\n]", " ", df$where), "\n", collapse = ""),
      file = f, append = TRUE)
  invisible(f)
}

#' Find XMSS signature indices used twice
#'
#' Lists every XMSS signature in the capsule bundles under a directory, and in seen-logs,
#' and marks an index that one key signed with two different signatures. An XMSS index must
#' sign once: two signatures at one index let anyone forge a third message, so a reused
#' index means the key's state was copied or rolled back (RFC 10033, section 4: a verifier
#' that sees all of a signer's signatures can detect reuse, since each carries its index).
#'
#' A seen-log is the text file `rmbl sign --seen-log FILE` appends to: one line per
#' signature it made, with the key fingerprint, the index, a digest of the signature and
#' the bundle it went into, tab-separated; lines starting with `#` are
#' comments. The same
#' signature found twice (one bundle copied to two places, or a bundle and its log line) is
#' not a reuse.
#'
#' @param path A directory (every `capsule_bundle.json` under it) or one bundle file.
#' @param seenlog Seen-log files to read as well, or NULL. A file that does not exist yet
#'   is an empty log; a directory, or a log with a malformed line, is refused.
#' @return A data frame, one row per signature seen: `key` (the key
#'   fingerprint, the first 16 hex characters of SHA-256 over the public
#'   key), `index`, `sig` (a digest of the signature), `where` (the file)
#'   and `reused` (`TRUE` when this key signed this index with another
#'   signature too).
#' @seealso [cpsbndlvrf()] (its `seen` argument),
#'   [blcli()] (`rmbl sign --seen-log`),
#'   [pqckg()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory
#' root <- tempfile("capsules-")
#' d <- file.path(root, "one")
#' dir.create(d, recursive = TRUE)
#' writeLines("x\n1", file.path(d, "data.csv"))
#' key <- pqckg(height = 2)
#' b <- cpsbndl(d, mkmnf(list(), env = FALSE), key)
#' xmssidxseen(root)
#'
#' # the same index signed again from a stale copy of the key: reused
#' e <- file.path(root, "two")
#' dir.create(e)
#' writeLines("x\n2", file.path(e, "data.csv"))
#' invisible(xmssfgt(key))  # forget the record, as a copy on another machine would
#' b2 <- cpsbndl(e, mkmnf(list(), env = FALSE), key)
#' xmssidxseen(root)[, c("index", "reused")]
#'
#' try(xmssidxseen(tempfile()))
#' options(op)
#' @export
xmssidxseen <- function(path = ".", seenlog = NULL) {
  path <- .rmbl_string1(path, "path")
  if (!file.exists(path)) {
    stop(.rmbl_fn(), "`path` is not an existing directory or bundle file: ", .rmbl_printable(path), call. = FALSE)
  }
  if (!is.null(seenlog) && (!is.character(seenlog) || anyNA(seenlog))) {
    stop(.rmbl_fn(), "`seenlog` must be file paths, or NULL", call. = FALSE)
  }
  files <- if (dir.exists(path)) {
    f <- list.files(path, pattern = "^capsule_bundle[.]json$", recursive = TRUE, full.names = TRUE, all.files = TRUE)
    f[!grepl("(^|/)([.]git|[.]rmbl-cache)/", f)]
  } else {
    path
  }
  rows <- lapply(files, function(f) {
    b <- tryCatch(.rmbl_json_text(readLines(f, warn = FALSE), simplifyVector = FALSE),
                  error = function(e) NULL)
    a <- if (is.list(b) && is.list(b$attestation)) b$attestation
    s <- if (is.list(a)) a$signature
    if (!is.list(s) || !identical(a$scheme, "xmss-sha256") || !is.character(a$public) || !is.numeric(s$index) ||
          !is.character(s$wire)) {
      return(NULL)
    }
    data.frame(key = .rmbl_xmss_fpr(a$public), index = as.integer(s$index), sig = .rmbl_xmss_sigd(s$wire), where = f,
               stringsAsFactors = FALSE)
  })
  rows <- c(rows, lapply(seenlog, .rmbl_xmss_seen_read))
  df <- do.call(rbind, c(list(data.frame(key = character(), index = integer(), sig = character(), where = character(),
                                         stringsAsFactors = FALSE)), rows))
  g <- paste(df$key, df$index)
  n <- vapply(split(df$sig, g), function(s) length(unique(s)), 1L)
  df$reused <- unname(n[g] > 1L)
  rownames(df) <- NULL
  df
}
