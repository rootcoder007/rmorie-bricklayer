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
#' How it is built. Each file is hashed with SHA-256
#' ([sha256_file()]); the
#' payload is the list of `path`, `sha256` and `size_bytes`, the
#' manifest's
#' [manifest_digest()] and the UTC time;
#' [capsule_attest()] signs a manifest
#' whose `meta` is that payload, and the bundle (payload plus attestation) is
#' written as pretty JSON with doubles at 17 digits. With `files = NULL` every
#' regular file under `dir` is hashed, recursively and including dot-files
#' (a `.Rprofile` dropped into a capsule runs code), except the bundle file
#' itself. A progress bar is shown when `options(morie.progress)` allows it.
#'
#' How it is checked. `capsule_bundle_verify()` re-hashes every listed file
#' (a path that is absolute or climbs out of `dir` fails its row), reports
#' every file on disk the bundle does not list (the bundle's own file
#' excepted), checks the attestation with
#' [capsule_check_attestation()]
#' (signature, digest, and `key_expected` when given), and, when `manifest`
#' is given, compares its digest with the bundled one. Every check is a row of
#' `checks`; `ok` is `TRUE` only when all pass. A failed check is a row,
#' not
#' an error.
#'
#' Errors: `dir` missing or not a directory; no files to bundle, or a named
#' file not in `dir`; a key [capsule_attest()] cannot
#' sign with;
#' `capsule_bundle_read()` given a file that is not a bundle;
#' `capsule_bundle_verify()` given something other than a bundle or a path.
#' Reading a bundle whose signature records a stateful key's state warns (see
#' [capsule_attest()]).
#'
#' @param dir Character scalar, the directory the capsule lives in. For
#' `capsule_bundle_verify()`, the directory to check the files in.
#' @param manifest A manifest, as from [make_manifest()].
#'   Required by
#' `capsule_bundle()`; optional for `capsule_bundle_verify()`, where it adds
#' a check that the manifest still has the bundled digest.
#' @param key A signing key from
#' [fips_keygen()] or
#' [pqc_keygen()].
#' @param files Character vector of paths relative to `dir`. Defaults to
#' every regular file in `dir` (recursively, dot-files included), excluding
#' the bundle itself.
#' @param context,prehash,note As in
#' [capsule_attest()].
#' @param path Character scalar. For `capsule_bundle()`, where to write the
#' bundle; defaults to `capsule_bundle.json` inside `dir` (an existing file
#' is overwritten). For `capsule_bundle_read()`, the bundle file to read.
#' @param bundle A bundle read back with
#' `capsule_bundle_read()`, or the path to one.
#' @param key_expected Optional public key hex the
#' bundle's attestation must carry. Supply it when you know which key
#' should have signed: without it the check confirms the bundle is
#' internally consistent, which any key's holder could arrange.
#' @return `capsule_bundle()`: the bundle, invisibly, a list of class
#' `bricklayer_bundle` with `files` (a list of `path`, `sha256`,
#' `size_bytes`), `manifest_digest`, `bundled_utc` and `attestation`
#' (from
#' [capsule_attest()]), and the path it was written to as
#' attribute
#' `"path"`. `capsule_bundle_read()`: the same structure read from the file.
#' `capsule_bundle_verify()`: a list of class `bricklayer_bundle_check` with
#' `ok` (logical) and `checks` (a data frame of `check`, logical `ok`
#' and
#' `detail`: one `file:PATH` row per listed file, `no_unlisted_files`, the
#' `attestation:` rows and, with a manifest, `manifest_digest`).
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
#' res <- capsule_bundle_verify(attr(b, "path"), dir, manifest = m)
#' res$ok
#' res$checks[!res$checks$ok, c("check", "detail")]
#'
#' # read back, and checked against the key you expected to have signed
#' b2 <- capsule_bundle_read(attr(b, "path"))
#' b2
#' capsule_bundle_verify(b2, dir, key_expected = "00ff")$ok
#'
#' # a file added beside the bundle is reported too
#' writeLines("x", file.path(dir, "extra.txt"))
#' capsule_bundle_verify(b2, dir)$checks[, c("check", "ok")]
#'
#' # a directory that does not exist
#' try(capsule_bundle(file.path(tempdir(), "no-such-capsule"), m, key))
#' unlink(dir, recursive = TRUE)
#' @export
capsule_bundle <- function(dir, manifest, key, files = NULL,
                           context = NULL, prehash = "none", note = NULL,
                           path = NULL) {
  dir <- .rmbl_string1(dir, "dir")
  if (!dir.exists(dir)) {
    stop("`dir` does not exist: ", dir, call. = FALSE)
  }
  path <- path %||% file.path(dir, "capsule_bundle.json")
  if (is.null(files)) {
    # dotfiles too: a .Rprofile dropped into a capsule directory runs when
    # a session starts there, and a bundle that claims "every regular file"
    # must have hashed it
    all_files <- list.files(dir, recursive = TRUE, all.files = TRUE,
                            full.names = FALSE, no.. = TRUE)
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
  pg <- bricklayer_progress("bundling", length(files))
  on.exit(pg$done(), add = TRUE)
  entries <- lapply(seq_along(files), function(i) {
    f <- files[[i]]
    pg$update(i - 1L, sprintf("hashing %s", basename(f)))
    p <- file.path(dir, f)
    list(path = f, sha256 = sha256_file(p), size_bytes = file.size(p))
  })
  pg$update(length(files), "signing")
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
  path <- .rmbl_file1(path, "path")
  b <- .rmbl_json_text(paste(readLines(path, warn = FALSE), collapse = "\n"),
                       simplifyVector = FALSE)
  if (!is.list(b) || is.null(b$attestation) || is.null(b$files)) {
    stop("`path` is not a capsule bundle", call. = FALSE)
  }
  class(b$attestation) <- c("bricklayer_attestation", "list")
  class(b$attestation$signature) <- c("bricklayer_signature", "list")
  if (!is.null(b$attestation$signature$key_state)) warning(.rmbl_key_state_warning(), call. = FALSE)
  class(b) <- c("bricklayer_bundle", "list")
  attr(b, "path") <- normalizePath(path, winslash = "/", mustWork = FALSE)
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
  pg <- bricklayer_progress("verifying bundle", length(bundle$files))
  on.exit(pg$done(), add = TRUE)
  for (e in bundle$files) {
    f <- as.character(e$path)[1L]
    pg$tick(1, sprintf("hashing %s", basename(f)))
    p <- .rmbl_safe_rel(f, dir)
    if (is.null(p)) {
      note_row(paste0("file:", f), FALSE,
               "not a plain relative path inside the directory")
      next
    }
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
  on_disk <- list.files(dir, recursive = TRUE, full.names = FALSE,
                        all.files = TRUE, no.. = TRUE)
  on_disk <- on_disk[!dir.exists(file.path(dir, on_disk))]
  # only the bundle's OWN file is exempt from the listing, not every file
  # whose name ends in bundle.json
  own <- attr(bundle, "path")
  d <- sub("/+$", "", normalizePath(dir, winslash = "/", mustWork = FALSE))
  own_rel <- if (!is.null(own) && startsWith(own, paste0(d, "/")))
    substring(own, nchar(d) + 2L) else "capsule_bundle.json"
  extra <- setdiff(on_disk, c(named, own_rel))
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
  if (is.list(x$attestation) && is.list(x$attestation$signature) && !is.null(x$attestation$signature$key_state)) {
    warning(.rmbl_key_state_warning(), call. = FALSE)
  }
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
