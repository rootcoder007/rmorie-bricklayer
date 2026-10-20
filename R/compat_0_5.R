#' Old names kept for rmoriedata 0.3.x
#'
#' rmoriedata 0.3.x on CRAN calls eleven functions by their 0.5.x names. These wrappers keep
#' that release installing and checking against rmoriebricklayer 1.0.0. Each one forwards to
#' the function named in its body, translating the old argument names; new code should call
#' the new names directly, and these wrappers go when every released rmoriedata uses them.
#'
#' @param message,signature,key,scheme,context,deterministic,prehash,masked As `msg`, `sig`,
#'   `key`, `scheme`, `ctx`, `determ`, `prehash` and `masked` of [cpssign()] and [cpsvrf()].
#' @param height,sk_seed,pub_seed,sk_prf As `height`, `skseed`, `pubseed` and `skprf` of
#'   [pqckg()].
#' @param url,dest,wayback,timeout As `url`, `dest`, `wb` and `tmout` of [blfetch()].
#' @param timestamp As `ts` of [wbsnpurl()].
#' @param x,path,txt,... Passed through to [csha256()], [cmn()], [sha256file()], [tojs()] and
#'   [fromjs()].
#' @return What the forwarded function returns.
#' @keywords internal
#' @name rmbl-compat
#' @examples
#' k <- pqc_keygen(height = 2)
#' s <- capsule_sign(core_sha256("manifest"), k)
#' capsule_verify(core_sha256("manifest"), s, signing_public_key(k))
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
