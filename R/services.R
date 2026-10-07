# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The hosted MORIE services (the language-model tier at llm.rmorie.com and
# the curated tables at data.rmorie.com) are described by one document on
# the project site, signed with ML-DSA-44. The packages pin the public key
# and the document's URL and nothing else: an endpoint, a model list or an
# access mode can change on the site without a package release, and a
# hijacked site cannot redirect anyone's key, because the signature fails
# and the package keeps its last good copy.
#
# Resolution order: a fresh cached copy; the live document (fetched through
# the package's own checked transport, verified, newer than the cache); the
# stale cached copy (verified); the copy bundled with the package; and
# finally a document with every mode "off".

.rmbl_services_url <- "https://rmorie.com/.well-known/morie-services.json"
.rmbl_services_context <- "morie-services"
# ML-DSA-44 public key of the document signer (generated 2026-10-06). Rotating
# it is a package release by design; rotating anything the document names is not.
.rmbl_services_pubkey <- function() {
  paste0(
    "ed5aa38192b6ad40e692856549fa2d8977f551d6cfe36c80c5235c19d0762d3a",
    "f4f82b0032cc765d1bee192414d862795b701b6614ea5d5e0bbe3189d0dc656b",
    "f65efc2a2bcc660fb1e90ef66f0349554f2fc14a6e25331bf06116d76ef07a6c",
    "b8b03691ae384f57a1d0ff999551479c22174ae2de427ad896d2729cdecc69e6",
    "e3e97c0e2971aebce530ea7c944dfc15525b431dde0fa3d45c6881cdf1d8dc1f",
    "80cb30195de49d84b4d4fe1c83540917ae95ba315dc05ac0526ca5f21b98d263",
    "af8c6249bc9a97d8d32c0d833a99df87bddc3e8d0ec15a79e0b0f41cadb6256c",
    "fbc94e2458d6b1a7fb4979b1884e5aaa9bd86969b02ac02a98ceae757cea462c",
    "869f1d8a9c264be702db980fa91192949d6f2de7aff823f06aa752443c1703e3",
    "230917adeef7283c2be5ed2b2bfc38957cac9398a44111a7e4376bfce838b51e",
    "285f6ee5a38ac37c5053f3d8b67f08d3f1299c8dabb0cbd588d6176bf08507cd",
    "1299e02abec1fb72c954993b31dbe7a0d7e0a67f78117ee315e9c4ed48178f93",
    "09816fb7e6fd2c3c5d88dcfaee6f4ae5acd9c19f96a841e9b19d80dfb47c424a",
    "0216bc2532767af9f1906ad02fbf61eb957eb899fb83c2486c6aead0268d5ae4",
    "48c46afdb8c58f506b93b2d1ca1124d3346f7995f10ab371bfdb840f6ae31a52",
    "d0121133cc53ba3db24f9a4485fb2e2245cf4d7ee8b1eb7c120973e6df3c2f1f",
    "3828543d541a3ead9630199063921c8e185f90609d3f220e5b5ab616cb8537e2",
    "708cfd319e8bebecda5c32eb832a8921f3f81c266922f1709ef4d34613d39786",
    "444c9dc1defdb7540a912295b58adb8bdb67852006ecbb2033c59a2594aedd83",
    "4a40a17d584e703ffb0f3ffac13b39b3c682abaf48fe6f17591fe51ce095e9dd",
    "dbc3b3a48d413b9a6b950f7b5c2b394a131c0fe494feb11c7f870ebce59f83b6",
    "8c48a86ea83488203c8110d1b8b0c4ad4a8c168fbb584cd9852d04e536093dc6",
    "d693e86bba31e2dcc7af667d382b80c5bbb4bf02b721b9a903e017fbb0c13d67",
    "d42fd31a3673e1709271d5514fb59773d3f8ad171d78b5824da3496665f26147",
    "f9fae8a474e5574c0bf5ee5247dd81cf4d5a5b1c44e71ada02a31dd9cb85e645",
    "330a3db8c40acbc0135efb5630113595c446fd8bf82e4c382aa4686247d8e5e1",
    "05fe8ace027595cd330fde4e7c8f68f42003aed94952d945a87fa658798c2e44",
    "a182f024d3b074a2e90ce5d0050a454a17c3fcfde995eb272e61a8994f6c74dd",
    "60784d02381e9115b9c3dd02a79ff4e02385ced5b2ebba324855cf1b50c384aa",
    "fe6e6fbaf656e326cd9522bc7102bf95c96cb338f7a62da9a3a97cb1b348c853",
    "75bd2afcb915ccb238939229967e2b839c99468bfe7f44219bf6d0b9680dff0a",
    "3f849ceef5954e9c5836c424d7405e16711af9b9b6361257ac1c5303fa92f5d3",
    "178aeb4aa7a28e47ca86ee388b101d8b62f08e8bbe9cd104251ff324382d5018",
    "a67064ec1de0786da7c61a20d3ade9e1cb0c0f44b11627eeee1d9b10b508c459",
    "6c00214f675d046548c42d5e64e567d42e6836195bd215af78468af1ee4ba3bb",
    "6c5d75f0bafaf45b5c863497b6fb4ecbda5e46878a124fbab75ea6f773c8bf58",
    "7843701ef1c0d8fa41abeef91108e540af348558e069d33a125df7d4ec800a53",
    "e1ec04ce0c8d84355c4031598e3ebd18e0b6da42be5e4adbae3bbf5041b4a26f",
    "28c2cc5f9614c6a9dbbb16ad72288f95faaf9cbe2fa9471343c3e78c8e5ac7c7",
    "b3036fa3a8ececbeb1f33c65c5f0cec3be6a85bc3b5691724686ccacdaf9cb0e",
    "0d7b6c0119858a41a5adabfcae656263c835b08d671553ea0aa76034bd9c4f7e"
  )
}

# One verified document per session: the hosted helpers ask for it on every
# call and a signature check per call is waste. Cleared by a live refresh.
.rmbl_services_memo <- new.env(parent = emptyenv())
.rmbl_services_forget <- function() {
  rm(list = ls(.rmbl_services_memo, all.names = TRUE), envir = .rmbl_services_memo)
  invisible(NULL)
}

.rmbl_services_cache_path <- function() {
  dir <- tools::R_user_dir("rmoriebricklayer", "cache")
  file.path(dir, "morie-services.json")
}

# The document every field falls back to: nothing hosted is reachable.
.rmbl_services_off <- function() {
  list(version = 1L, issued = "1970-01-01T00:00:00Z",
       notice = paste0("The hosted MORIE services could not be verified from this machine. ",
                       "Local models and your own API keys keep working."),
       llm = list(mode = "off", base_url = "", auth_url = "", default_model = "",
                  models = character(0), request_access = "https://www.rmorie.com/access"),
       data = list(mode = "off", base_url = "", license = "https://www.rmorie.com/data-license",
                   request_access = "https://www.rmorie.com/access"))
}

# Verify the detached signature over the document's exact bytes. `pubkey`
# is an argument so the tests can sign with a key of their own; every
# exported path pins .rmbl_services_pubkey.
.rmbl_services_verify <- function(doc_bytes, sig_json, pubkey = .rmbl_services_pubkey()) {
  sig <- tryCatch(.rmbl_json_text(sig_json, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(sig) || !identical(sig$scheme, "ML-DSA-44") ||
      !identical(sig$context, .rmbl_services_context) ||
      !is.character(sig$signature) || length(sig$signature) != 1L) {
    return(FALSE)
  }
  obj <- structure(list(scheme = "ML-DSA-44", signature = sig$signature, prehash = "none"),
                   class = c("bricklayer_signature", "list"))
  key <- tryCatch(fips_key("ML-DSA-44", pubkey), error = function(e) NULL)
  if (is.null(key)) return(FALSE)
  isTRUE(tryCatch(capsule_verify(doc_bytes, obj, key, context = .rmbl_services_context),
                  error = function(e) FALSE))
}

# Parse and shape-check a verified document. NULL when it is not a v1 document.
.rmbl_services_parse <- function(doc_bytes) {
  d <- tryCatch(.rmbl_json_text(doc_bytes, simplifyVector = FALSE), error = function(e) NULL)
  if (!is.list(d) || !identical(as.integer(d$version), 1L)) return(NULL)
  mode_ok <- function(m) is.character(m) && length(m) == 1L && m %in% c("off", "key")
  url_ok <- function(u) {
    is.character(u) && length(u) == 1L && (identical(u, "") ||
      !inherits(tryCatch(.rmbl_check_public_url(u, "a service URL"), error = function(e) e), "error"))
  }
  if (!is.list(d$llm) || !is.list(d$data) || !mode_ok(d$llm$mode) || !mode_ok(d$data$mode)) return(NULL)
  if (!is.character(d$issued) || length(d$issued) != 1L ||
      is.na(.rmbl_services_time(d$issued))) return(NULL)
  for (f in c("base_url", "auth_url")) if (!url_ok(d$llm[[f]] %||% "")) return(NULL)
  if (!url_ok(d$data$base_url %||% "")) return(NULL)
  d$llm$models <- as.character(unlist(d$llm$models %||% character(0)))
  d$llm$default_model <- as.character(d$llm$default_model %||% "")[1L]
  d$notice <- as.character(d$notice %||% "")[1L]
  d
}

.rmbl_services_time <- function(s) {
  as.POSIXct(strptime(s, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
}

# Read a document+signature pair from `path` (the cache or the bundled copy):
# verified and parsed, or NULL.
.rmbl_services_read <- function(path, pubkey = .rmbl_services_pubkey()) {
  sig_path <- sub("[.]json$", ".sig", path)
  if (!file.exists(path) || !file.exists(sig_path)) return(NULL)
  bytes <- readBin(path, "raw", file.size(path))
  sig <- paste(readLines(sig_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!.rmbl_services_verify(bytes, sig, pubkey)) return(NULL)
  .rmbl_services_parse(bytes)
}

.rmbl_services_write <- function(path, doc_bytes, sig_json) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  writeBin(doc_bytes, path)
  writeLines(sig_json, sub("[.]json$", ".sig", path))
  invisible(path)
}

#' The hosted MORIE services, as the project site currently describes them
#'
#' Reads \code{https://rmorie.com/.well-known/morie-services.json}, a signed
#' document naming the language-model tier and the curated-data service:
#' their endpoints, whether each is \code{"key"} (reachable with a key
#' requested on the site) or \code{"off"}, the model list, and a notice.
#' The signature (ML-DSA-44, public key pinned in this package) is checked
#' before anything in it is believed, so the endpoints can move or be
#' switched off on the site without a package release, and a document that
#' does not verify is ignored. The result is cached for a day; without a
#' network the cached copy is used, then the copy bundled with the package.
#'
#' Every other MORIE package reads the same document through this function,
#' so one sign-in and one document serve rmorie, rmoriedata and morie alike.
#' The hosted tier is a last resort: a local model or your own API key is
#' always preferred where the caller offers the choice.
#'
#' The environment variable \code{MORIE_SERVICES_URL} points the fetch at a
#' mirror of the document (its signature is fetched from the same place, with
#' the suffix \code{.sig}); the signature check is unchanged, so a mirror can
#' only serve a document the project signed.
#'
#' @param refresh \code{TRUE} to fetch the live document even when the
#'   cached copy is fresh.
#' @param max_age Seconds a cached copy is used without asking the site
#'   (default one day).
#' @param timeout Seconds allowed for the fetch.
#' @param offline \code{TRUE} never fetches: the cached copy, then the
#'   bundled one (what the examples and an offline session get).
#' @return A list with \code{version}, \code{issued}, \code{notice},
#'   \code{llm} (\code{mode}, \code{base_url}, \code{auth_url},
#'   \code{default_model}, \code{models}, \code{request_access}) and
#'   \code{data} (\code{mode}, \code{base_url}, \code{license},
#'   \code{request_access}), with the attribute \code{"source"} set to
#'   \code{"live"}, \code{"cache"}, \code{"bundled"} or \code{"off"}.
#' @examples
#' # Nothing is fetched here: the cached copy if there is one, else the
#' # document bundled with the package.
#' s <- bricklayer_services(offline = TRUE)
#' s$llm$mode
#' attr(s, "source")
#' @export
bricklayer_services <- function(refresh = FALSE, max_age = 86400, timeout = 20,
                                offline = FALSE) {
  .bl_check_flag(refresh, "refresh")
  .bl_check_flag(offline, "offline")
  if (!is.numeric(max_age) || length(max_age) != 1L || is.na(max_age) || max_age < 0) {
    stop("`max_age` must be a single non-negative number of seconds (Inf keeps a cached copy forever)",
         call. = FALSE)
  }
  if (!is.numeric(timeout) || length(timeout) != 1L || !is.finite(timeout) || timeout < 1) {
    stop("`timeout` must be a single number of seconds, at least one", call. = FALSE)
  }
  if (isTRUE(offline) && !isTRUE(refresh) && !is.null(.rmbl_services_memo$doc)) {
    return(.rmbl_services_memo$doc)
  }
  out <- .rmbl_services_resolve(refresh, max_age, timeout, offline)
  .rmbl_services_memo$doc <- out
  out
}

.rmbl_services_resolve <- function(refresh, max_age, timeout, offline) {
  cache <- .rmbl_services_cache_path()
  bundled <- .rmbl_services_read(.rmbl_services_bundled_path())
  cached <- .rmbl_services_read(cache)
  # The floor every accepted document must reach: the copy shipped with the
  # package. A validly signed but OLDER document (any one ever published) in
  # the cache would otherwise pin a retired endpoint forever, and it is the
  # endpoint that receives the user's key (fourth review).
  # A cache earns its place only by being NEWER than the bundled copy: the same
  # date adds nothing, and an older one is deleted.
  if (!is.null(cached) && !is.null(bundled) &&
      .rmbl_services_time(cached$issued) <= .rmbl_services_time(bundled$issued)) {
    if (.rmbl_services_time(cached$issued) < .rmbl_services_time(bundled$issued)) {
      unlink(c(cache, sub("[.]json$", ".sig", cache)))
    }
    cached <- NULL
  }
  floor <- max(c(-Inf, as.numeric(.rmbl_services_time(cached$issued)),
                 as.numeric(.rmbl_services_time(bundled$issued))), na.rm = TRUE)
  fresh <- !is.null(cached) && !isTRUE(refresh) &&
    (as.numeric(Sys.time()) - as.numeric(file.mtime(cache))) < max_age
  if (!is.null(cached) && (fresh || isTRUE(offline))) {
    return(structure(cached, source = "cache"))
  }
  live <- if (isTRUE(offline)) NULL else .rmbl_services_fetch(timeout)
  if (!is.null(live)) {
    # a document older than the one already held, or than the bundled one, is a rollback
    if (as.numeric(.rmbl_services_time(live$doc$issued)) >= floor) {
      .rmbl_services_write(cache, live$bytes, live$sig)
      return(structure(live$doc, source = "live"))
    }
  }
  if (!is.null(cached)) return(structure(cached, source = "cache"))
  if (!is.null(bundled)) return(structure(bundled, source = "bundled"))
  structure(.rmbl_services_off(), source = "off")
}

# Fetch document and signature through the checked transport; a verified,
# parsed pair or NULL. The URL may be overridden for a mirror of the site
# (MORIE_SERVICES_URL), which changes nothing about the signature check.
.rmbl_services_fetch <- function(timeout = 20) {
  url <- Sys.getenv("MORIE_SERVICES_URL", .rmbl_services_url)
  ok <- !inherits(tryCatch(.rmbl_check_public_url(url, "MORIE_SERVICES_URL"),
                           error = function(e) e), "error")
  if (!ok) return(NULL)
  tmp_doc <- tempfile(fileext = ".json")
  tmp_sig <- tempfile(fileext = ".sig")
  on.exit(unlink(c(tmp_doc, tmp_sig)), add = TRUE)
  # no Wayback fallback here: an archived copy of this document is exactly
  # the stale endpoint list the signature and the issue date exist to refuse
  if (!identical(.rmbl_net_download(url, tmp_doc, timeout), 200L) ||
      !file.exists(tmp_doc) || file.size(tmp_doc) == 0) return(NULL)
  if (!identical(.rmbl_net_download(.rmbl_services_sig_url(url), tmp_sig, timeout), 200L) ||
      !file.exists(tmp_sig) || file.size(tmp_sig) == 0) return(NULL)
  bytes <- readBin(tmp_doc, "raw", file.size(tmp_doc))
  sig <- paste(readLines(tmp_sig, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (!.rmbl_services_verify(bytes, sig)) return(NULL)
  doc <- .rmbl_services_parse(bytes)
  if (is.null(doc)) return(NULL)
  list(doc = doc, bytes = bytes, sig = sig)
}

# The download seam (one line, so the tests can serve a document of their own).
.rmbl_net_download <- function(url, tmp, timeout) {
  # 1 MiB is a large document
  res <- .Call(C_rmbl_http_download, url, tmp, as.integer(timeout), NULL, NULL, 1048576, FALSE)
  res$status
}

# The one-line answers the rest of the package asks for. Offline inside the
# package: a sign-in or a table fetch must not block on the site; the daily
# refresh happens when bricklayer_services() is called for its own sake.
.rmbl_services_llm <- function() bricklayer_services(offline = TRUE)$llm
.rmbl_services_data <- function() bricklayer_services(offline = TRUE)$data


# The signature sits beside the document: "x.json" -> "x.sig"; a mirror
# without the suffix gets ".sig" appended (0.5.8 fetched the document as its
# own signature and failed closed, silently).
.rmbl_services_sig_url <- function(url) {
  if (grepl("[.]json$", url)) sub("[.]json$", ".sig", url) else paste0(url, ".sig")
}

# The copy shipped with the package (one seam, so a test can stand in a bundled document).
.rmbl_services_bundled_path <- function() {
  system.file("services", "morie-services.json", package = "rmoriebricklayer")
}
