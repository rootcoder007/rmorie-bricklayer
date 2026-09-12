# SPDX-License-Identifier: AGPL-3.0-or-later
#
# One signed artifact for a whole capsule.
#
# The pieces existed separately: per-file digests, a manifest, an
# attestation over its digest. What was missing is a single file that
# ties them together, so "verify this capsule" is one call rather than a
# procedure a recipient has to be talked through -- and so that the
# per-file digests are inside the signature rather than beside it.

#' Bundle a capsule into one signed artifact
#'
#' Records a digest of every file named, the manifest's canonical digest,
#' and an attestation covering both, as a single JSON file.
#' [capsule_bundle_verify()] re-hashes
#' the files on disk and checks everything against it.
#'
#' The file digests are inside the signed payload, not alongside it. That
#' is the whole point: a list of hashes that is not itself signed can be
#' rewritten to match whatever the files now say, and a recipient who
#' re-hashes the files and compares them to that list learns only that the
#' list is consistent with itself.
#'
#' What it establishes: the named files have not changed since signing, the
#' manifest has not changed, and both were signed together by the holder of
#' that key. What it does not: that the key belongs to anyone in
#' particular, or that the manifest's claims are true.
#'
#' @param dir Directory the capsule lives in.
#' @param manifest A manifest, as from
#' [make_manifest()].
#' @param key A signing key from
#' [fips_keygen()] or
#' [pqc_keygen()].
#' @param files Paths relative to `dir`. Defaults to
#' every regular file in `dir`, excluding the bundle itself.
#' @param context,prehash,note As in
#' [capsule_attest()].
#' @param path Where to write the bundle. Defaults to
#' `capsule_bundle.json` inside `dir`.
#' @param bundle A bundle read back with
#' `capsule_bundle_read()`, or the path to one.
#' @param key_expected Optional public key hex the
#' bundle's attestation must carry. Supply it when you know which key
#' should have signed: without it the check confirms the bundle is
#' internally consistent, which any key's holder could arrange.
#' @return `capsule_bundle()` the bundle, invisibly, with the path it
#' was written to as an attribute; `capsule_bundle_read()` the bundle;
#' `capsule_bundle_verify()` a list with `ok` and a `checks`
#' data frame.
#' @seealso
#' [capsule_attest()],
#' [verify_capsule()],
#' [manifest_digest()].
#' @examples
#' dir <- tempfile()
#' dir.create(dir)
#' write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
#'           row.names = FALSE)
#' m <- make_manifest(list(dataset = "demo"), environment = FALSE)
#' key <- fips_keygen("ML-DSA-44")
#'
#' b <- capsule_bundle(dir, m, key, note = "as published")
#' capsule_bundle_verify(attr(b, "path"), dir, manifest = m)$ok
#'
#' # touch a byte of the data and the bundle no longer holds
#' write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"),
#'           row.names = FALSE)
#' capsule_bundle_verify(attr(b, "path"), dir, manifest = m)$ok
#' unlink(dir, recursive = TRUE)
#' @export
capsule_bundle <- function(dir, manifest, key, files = NULL,
                           context = NULL, prehash = "none", note = NULL,
                           path = NULL) {
  if (!dir.exists(dir)) {
    stop("`dir` does not exist: ", dir, call. = FALSE)
  }
  path <- path %||% file.path(dir, "capsule_bundle.json")
  if (is.null(files)) {
    all_files <- list.files(dir, recursive = TRUE, all.files = FALSE,
                            full.names = FALSE)
    keep <- vapply(all_files, function(f) {
      p <- file.path(dir, f)
      !dir.exists(p) && !identical(normalizePath(p, mustWork = FALSE),
                                   normalizePath(path, mustWork = FALSE))
    }, logical(1))
    files <- sort(all_files[keep])
  } else {
    files <- sort(as.character(files))
  }
  if (!length(files)) {
    stop("no files to bundle", call. = FALSE)
  }
  missing <- files[!file.exists(file.path(dir, files))]
  if (length(missing)) {
    stop("these files are not in `dir`: ",
         paste(utils::head(missing, 5L), collapse = ", "), call. = FALSE)
  }
  entries <- lapply(files, function(f) {
    p <- file.path(dir, f)
    list(path = f, sha256 = sha256_file(p), size_bytes = file.size(p))
  })
  payload <- list(
    files = entries,
    manifest_digest = manifest_digest(manifest),
    bundled_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  # The attestation covers the file digests because they are part of the
  # payload it is taken over -- a bundle whose signature covered only
  # the manifest would leave the file list rewritable.
  inner <- list(meta = payload, results = list())
  att <- capsule_attest(inner, key, context = context, prehash = prehash,
                        note = note)
  bundle <- c(payload, list(attestation = att))
  class(bundle) <- c("bricklayer_bundle", "list")
  writeLines(bricklayer_json_to_json(unclass(bundle), auto_unbox = TRUE,
                                     pretty = TRUE, na = "null",
                                     null = "null", digits = I(17)),
             path, useBytes = TRUE)
  attr(bundle, "path") <- path
  invisible(bundle)
}

#' @rdname capsule_bundle
#' @export
capsule_bundle_read <- function(path) {
  b <- bricklayer_json_from_json(paste(readLines(path, warn = FALSE),
                                       collapse = "\n"),
                                 simplifyVector = FALSE)
  if (!is.list(b) || is.null(b$attestation) || is.null(b$files)) {
    stop("`path` is not a capsule bundle", call. = FALSE)
  }
  class(b$attestation) <- c("bricklayer_attestation", "list")
  class(b$attestation$signature) <- c("bricklayer_signature", "list")
  class(b) <- c("bricklayer_bundle", "list")
  b
}

#' @rdname capsule_bundle
#' @export
capsule_bundle_verify <- function(bundle, dir, manifest = NULL,
                                  key_expected = NULL) {
  if (is.character(bundle)) bundle <- capsule_bundle_read(bundle)
  if (!inherits(bundle, "bricklayer_bundle")) {
    stop("`bundle` must come from capsule_bundle() or ",
         "capsule_bundle_read()", call. = FALSE)
  }
  checks <- list()
  note_row <- function(check, ok, detail = "") {
    checks[[length(checks) + 1L]] <<- data.frame(
      check = check, ok = isTRUE(ok), detail = as.character(detail),
      stringsAsFactors = FALSE)
  }
  for (e in bundle$files) {
    f <- as.character(e$path)[1L]
    p <- file.path(dir, f)
    if (!file.exists(p)) {
      note_row(paste0("file:", f), FALSE, "missing from the directory")
      next
    }
    got <- sha256_file(p)
    ok <- identical(got, as.character(e$sha256)[1L])
    note_row(paste0("file:", f), ok,
             if (ok) got else sprintf("expected %s, got %s",
                                      as.character(e$sha256)[1L], got))
  }
  # Files present on disk that the bundle does not mention are reported:
  # a signed list of what SHOULD be there says nothing about what else
  # has been added beside it.
  named <- vapply(bundle$files, function(e) as.character(e$path)[1L],
                  character(1))
  on_disk <- list.files(dir, recursive = TRUE, full.names = FALSE)
  on_disk <- on_disk[!dir.exists(file.path(dir, on_disk))]
  extra <- setdiff(on_disk, c(named, basename(
    c("capsule_bundle.json", on_disk[grepl("bundle\\.json$", on_disk)]))))
  note_row("no_unlisted_files", length(extra) == 0L,
           if (length(extra))
             paste("not covered by the bundle:",
                   paste(utils::head(extra, 5L), collapse = ", ")) else "")

  inner <- list(meta = list(files = bundle$files,
                            manifest_digest = bundle$manifest_digest,
                            bundled_utc = bundle$bundled_utc),
                results = list())
  res <- capsule_check_attestation(bundle$attestation, inner,
                                   key_expected = key_expected)
  for (i in seq_len(nrow(res$checks))) {
    note_row(paste0("attestation:", res$checks$check[i]),
             res$checks$ok[i], res$checks$detail[i])
  }
  if (!is.null(manifest)) {
    got <- manifest_digest(manifest)
    note_row("manifest_digest",
             identical(got, as.character(bundle$manifest_digest)[1L]),
             if (identical(got, as.character(bundle$manifest_digest)[1L]))
               got else
                 sprintf("bundle says %s, manifest is %s",
                         as.character(bundle$manifest_digest)[1L], got))
  }
  df <- do.call(rbind, checks)
  rownames(df) <- NULL
  out <- list(ok = all(df$ok), checks = df)
  class(out) <- c("bricklayer_bundle_check", "list")
  out
}

#' @export
format.bricklayer_bundle <- function(x, ...) {
  c(.rmbl_rule("Capsule bundle"),
    .rmbl_kv(list(files = length(x$files),
                  "manifest digest" = as.character(x$manifest_digest)[1L],
                  bundled = as.character(x$bundled_utc)[1L],
                  scheme = x$attestation$scheme)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_bundle <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_bundle_check <- function(x, ...) {
  c(.rmbl_rule(sprintf("Bundle check: %s", if (x$ok) "OK" else "FAILED")),
    sprintf("  %-30s %-5s %s", substring(x$checks$check, 1L, 30L),
            ifelse(x$checks$ok, "ok", "FAIL"),
            substring(x$checks$detail, 1L, 36L)),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_bundle_check <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
