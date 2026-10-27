#' Old names kept for rmoriedata 0.3.x
#'
#' rmoriedata 0.3.x on CRAN calls eleven functions by their 0.5.x names. These
#' wrappers keep that release installing and checking against rmoriebricklayer
#' 1.0.0. Each one forwards to the function named in its body, translating the
#' old argument names: [cpssign()], [cpsvrf()],
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # keep this example's
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())
#' # one-time index record out of your configuration directory
#' k <- pqc_keygen(height = 2)
#' s <- capsule_sign(core_sha256("manifest"), k)
#' capsule_verify(core_sha256("manifest"), s, signing_public_key(k))
#' options(op)
NULL

#' @rdname rmbl-compat
#' @export
capsule_sign <- function(
  message,
  key,
  scheme = NULL,
  context = NULL,
  deterministic = FALSE,
  prehash = "none",
  masked = getOption("rmoriebricklayer.masked", TRUE)
) {
  .rmbl_compat_errors(
    cpssign(
      message,
      key,
      scheme = scheme,
      ctx = context,
      determ = deterministic,
      prehash = prehash,
      masked = masked
    ),
    "cpssign",
    "capsule_sign",
    c(msg = "message", ctx = "context", determ = "deterministic")
  )
}

#' @rdname rmbl-compat
#' @export
capsule_verify <- function(
  message,
  signature,
  key,
  context = NULL,
  prehash = NULL
) {
  .rmbl_compat_errors(
    cpsvrf(message, signature, key, ctx = context, prehash = prehash),
    "cpsvrf",
    "capsule_verify",
    c(msg = "message", sig = "signature", ctx = "context")
  )
}

#' @rdname rmbl-compat
#' @export
pqc_keygen <- function(
  height = 10L,
  sk_seed = NULL,
  pub_seed = NULL,
  sk_prf = NULL
) {
  .rmbl_compat_errors(
    pqckg(height, skseed = sk_seed, pubseed = pub_seed, skprf = sk_prf),
    "pqckg",
    "pqc_keygen",
    c(skseed = "sk_seed", pubseed = "pub_seed", skprf = "sk_prf")
  )
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
  .rmbl_compat_errors(
    blfetch(url, dest, wb = wayback, tmout = timeout),
    "blfetch",
    "bricklayer_fetch",
    c(wb = "wayback", tmout = "timeout")
  )
}

#' @rdname rmbl-compat
#' @export
wayback_snapshot_url <- function(url, timestamp = NULL) {
  .rmbl_compat_errors(
    wbsnpurl(url, ts = timestamp),
    "wbsnpurl",
    "wayback_snapshot_url",
    c(ts = "timestamp")
  )
}

#' Rewrites a forwarded function's errors in the 0.5.x alias's own words.
#'
#' An error from the new function named the new arguments (`skseed` for
#' pqc_keygen()'s `sk_seed`); the alias's caller only knows its own names.
#' An error that names none of them is passed on unchanged.
#' @param expr The forwarded call.
#' @param fn The new function's name, as an error's prefix gives it.
#' @param alias The alias's name.
#' @param map The alias's argument names, named by the new ones.
#' @return The value of `expr`.
#' @noRd
.rmbl_compat_errors <- function(expr, fn, alias, map) {
  tryCatch(expr, error = function(e) {
    m <- conditionMessage(e)
    new <- sub(paste0("^", fn, ": "), paste0(alias, ": "), m)
    for (k in names(map)) {
      new <- gsub(
        sprintf("`%s`", k),
        sprintf("`%s`", map[[k]]),
        new,
        fixed = TRUE
      )
    }
    if (identical(new, m)) {
      stop(e)
    }
    stop(new, call. = FALSE)
  })
}
