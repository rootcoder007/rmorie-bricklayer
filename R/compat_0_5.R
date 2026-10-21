#' Old names kept for rmoriedata 0.3.x
#'
#' rmoriedata 0.3.x on CRAN calls eleven functions by their 0.5.x names. These wrappers keep
#' that release installing and checking against rmoriebricklayer 1.0.0. Each one forwards to
#' the function named in its body, translating the old argument names:
#' [cpssign()], [cpsvrf()],
#' [pqckg()], [signpubkey()],
#' [csha256()], [cmn()],
#' [sha256file()], [tojs()],
#' [fromjs()], [blfetch()] and
#' [wbsnpurl()]. New code should call the new names directly; these
#' wrappers go when every released rmoriedata uses them.
#'
#' @param message,signature `msg` and `sig` of the new name.
#' @param key,scheme,prehash,masked As in the new name.
#' @param context `ctx` of the new name.
#' @param deterministic `determ` of `cpssign()`.
#' @param height `height` of `pqckg()`.
#' @param sk_seed `skseed` of `pqckg()`.
#' @param pub_seed `pubseed` of `pqckg()`.
#' @param sk_prf `skprf` of `pqckg()`.
#' @param url,dest As in `blfetch()` and `wbsnpurl()`.
#' @param wayback,timeout `wb` and `tmout` of `blfetch()`.
#' @param timestamp `ts` of `wbsnpurl()`.
#' @param x `x` of `csha256()`, `cmn()` or `tojs()`.
#' @param path `path` of `sha256file()`.
#' @param txt `txt` of `fromjs()`.
#' @param ... Passed through to `tojs()` or `fromjs()`.
#' @return What the forwarded function returns.
#' @keywords internal
#' @name rmbl-compat
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory
#' k <- pqc_keygen(height = 2)
#' s <- capsule_sign(core_sha256("manifest"), k)
#' capsule_verify(core_sha256("manifest"), s, signing_public_key(k))
#' options(op)
NULL

#' @rdname rmbl-compat
#' @export
capsule_sign <- function(message, key, scheme = NULL, context = NULL,
                         deterministic = FALSE, prehash = "none",
                         masked = getOption("rmoriebricklayer.masked", TRUE)) {
  cpssign(message, key, scheme = scheme, ctx = context, determ = deterministic,
          prehash = prehash, masked = masked)
}

#' @rdname rmbl-compat
#' @export
capsule_verify <- function(message, signature, key, context = NULL, prehash = NULL) {
  cpsvrf(message, signature, key, ctx = context, prehash = prehash)
}

#' @rdname rmbl-compat
#' @export
pqc_keygen <- function(height = 10L, sk_seed = NULL, pub_seed = NULL, sk_prf = NULL) {
  pqckg(height, skseed = sk_seed, pubseed = pub_seed, skprf = sk_prf)
}

#' @rdname rmbl-compat
#' @export
signing_public_key <- function(key) signpubkey(key)

#' @rdname rmbl-compat
#' @export
core_sha256 <- function(x) csha256(x)

#' @rdname rmbl-compat
#' @export
core_mean <- function(x) cmn(x)

#' @rdname rmbl-compat
#' @export
sha256_file <- function(path) sha256file(path)

#' @rdname rmbl-compat
#' @export
bricklayer_json_to_json <- function(x, ...) tojs(x, ...)

#' @rdname rmbl-compat
#' @export
bricklayer_json_from_json <- function(txt, ...) fromjs(txt, ...)

#' @rdname rmbl-compat
#' @export
bricklayer_fetch <- function(url, dest, wayback = "", timeout = 120L) {
  blfetch(url, dest, wb = wayback, tmout = timeout)
}

#' @rdname rmbl-compat
#' @export
wayback_snapshot_url <- function(url, timestamp = NULL) wbsnpurl(url, ts = timestamp)
