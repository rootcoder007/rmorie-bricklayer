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
#' [cpsbndlvrf()] re-hashes
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
#' ([sha256file()]); the
#' payload is the list of `path`, `sha256` and `size_bytes`, the
#' manifest's
#' [mnfdgst()] and the UTC time;
#' [cpsatst()] signs a manifest
#' whose `meta` is that payload, and the bundle (payload plus attestation) is
#' written as pretty JSON with doubles at 17 digits. With `files = NULL` every
#' regular file under `dir` is hashed, recursively and including dot-files
#' (a `.Rprofile` dropped into a capsule runs code), except the bundle file
#' itself. A progress bar is shown when `options(morie.progress)` allows it.
#'
#' How it is checked. `cpsbndlvrf()` re-hashes every listed file
#' (a path that is absolute or climbs out of `dir` fails its row), reports
#' every file on disk the bundle does not list (the bundle's own file
#' excepted), checks the attestation with
#' [cpschkatst()]
#' (signature, digest, and `keyexp` when given; an `"hmac"`
#' signature needs the shared secret as `key`), and, when `man`
#' is given, compares its digest with the bundled one. Every check is a row of
#' `checks`; `ok` is `TRUE` only when all pass. A failed check is a row,
#' not
#' an error.
#'
#' Errors: `dir` missing or not a directory; no files to bundle, or a named
#' file not in `dir`; a key [cpsatst()] cannot
#' sign with;
#' `cpsbndlrd()` given a file that is not a bundle;
#' `cpsbndlvrf()` given something other than a bundle or a path.
#' Reading a bundle whose signature records a stateful key's state warns (see
#' [cpsatst()]).
#'
#' @param dir Character scalar, the directory the capsule lives in. For
#' `cpsbndlvrf()`, the directory to check the files in.
#' @param man A manifest, as from [mkmnf()]. It is required by
#' `cpsbndl()` and optional for `cpsbndlvrf()`, where it adds a check
#' that the manifest
#' still has the bundled digest.
#' @param key For `cpsbndl()`, a signing key from [fipskg()] or
#' [pqckg()], or a shared secret (a string or raw vector) for an
#' `"hmac"` bundle such as morie writes: the attestation then records
#' the key's id, never the secret (see [cpsatst()]). For
#' `cpsbndlvrf()`, the shared secret that checks an `"hmac"` bundle's
#' signature; not used for the other schemes.
#' @param files Character vector of paths relative to `dir`. Defaults to
#' every regular file in `dir` (recursively, dot-files included), excluding
#' the bundle itself.
#' @param ctx,prehash,note As in
#' [cpsatst()].
#' @param path Character scalar. For `cpsbndlrd()`, the bundle file to read.
#' For `cpsbndl()`, where to write the bundle (an existing file is
#' overwritten).
#'
#' `capsule_bundle.json` inside `dir` is the default for `cpsbndl()`.
#' @param bundle A bundle read back with
#' `cpsbndlrd()`, or the path to one.
#' @param keyexp Optional public key hex (for `"hmac"`, the key id) the
#' bundle's attestation must carry. Supply it when you know which key
#' should have signed: without it the check confirms the bundle is
#' internally consistent, which any key's holder could arrange.
#' @param seen For `cpsbndlvrf()`, the XMSS signatures seen elsewhere, as
#' [xmssidxseen()] returns them,
#' or `NULL`. For an XMSS bundle it adds an `xmss_index` row, failed
#' (\code{"xmss index reused"}) when the same key signed
#' the bundle's index with another signature: the key's state was copied
#' or rolled back (RFC 10033, section 4).
#' @return `cpsbndl()`: the bundle, invisibly, a list of class
#' `bricklayer_bundle` with `files` (a list of `path`, `sha256`,
#' `size_bytes`), `manifest_digest`, `bundled_utc` and `attestation`
#' (from
#' [cpsatst()]), and the path it was written to as
#' attribute
#' `"path"`.
#'
#' `cpsbndlrd()`: the same structure read from the file.
#'
#' `cpsbndlvrf()`: a list of class `bricklayer_bundle_check` with
#' `ok` (logical) and `checks` (a data frame of `check`, logical `ok`
#' and
#' `detail`: one `file:PATH` row per listed file, `no_unlisted_files`, the
#' `attestation:` rows, with a manifest `manifest_digest`, and with `seen`
#' `xmss_index`). For an XMSS bundle the `attestation:signature` row's
#' detail names the signature's index and the key fingerprint.
#' @seealso
#' [cpsatst()],
#' [vrfcps()],
#' [mnfdgst()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' dir <- tempfile()
#' dir.create(dir)
#' write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
#'           row.names = FALSE)
#' m <- mkmnf(list(dataset = "demo"), env = FALSE)
#' key <- fipskg("ML-DSA-44")
#'
#' b <- cpsbndl(dir, m, key, note = "as published")
#' cpsbndlvrf(attr(b, "path"), dir, man = m)$ok
#'
#' # touch a byte of the data and the bundle no longer holds
#' write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"),
#'           row.names = FALSE)
#' res <- cpsbndlvrf(attr(b, "path"), dir, man = m)
#' res$ok
#' res$checks[!res$checks$ok, c("check", "detail")]
#'
#' # read back, and checked against the key you expected to have signed
#' b2 <- cpsbndlrd(attr(b, "path"))
#' b2
#' cpsbndlvrf(b2, dir, keyexp = "00ff")$ok
#'
#' # a file added beside the bundle is reported too
#' writeLines("x", file.path(dir, "extra.txt"))
#' cpsbndlvrf(b2, dir)$checks[, c("check", "ok")]
#'
#' # a bundle signed with a shared secret (HMAC), as morie signs
#' dir2 <- tempfile()
#' dir.create(dir2)
#' writeLines("x,y", file.path(dir2, "d.csv"))
#' h <- cpsbndl(dir2, m, "shared-secret")
#' h$attestation$public  # the key id, not the secret
#' cpsbndlvrf(attr(h, "path"), dir2, key = "shared-secret",
#'            keyexp = h$attestation$public)$ok
#' # without the secret the signature row cannot pass
#' cpsbndlvrf(attr(h, "path"), dir2)$ok
#' unlink(dir2, recursive = TRUE)
#'
#' # a directory that does not exist
#' try(cpsbndl(file.path(tempdir(), "no-such-capsule"), m, key))
#' unlink(dir, recursive = TRUE)
#' @export
#' @srrstats {G5.4b} An HMAC bundle written by morie (the Python implementation,
#'   fixed fixture tests/testthat/fixtures/morie-hmac) verifies here, and one
#'   written here verifies with morie's own `capsule verify` (test-bundle.R:7,
#'   22).
cpsbndl <- function(
  dir,
  man,
  key,
  files = NULL,
  ctx = NULL,
  prehash = "none",
  note = NULL,
  path = NULL
) {
  dir <- .rmbl_string1(dir, "dir")
  if (!dir.exists(dir)) {
    stop("`dir` does not exist: ", dir, call. = FALSE)
  }
  if (!is.null(path)) {
    path <- .rmbl_out_file(path, "path", connection = FALSE)
  }
  if (!is.null(files) && (!is.character(files) || anyNA(files))) {
    stop(
      "`files` must be file names (relative to `dir`), or NULL for every file",
      call. = FALSE
    )
  }
  path <- path %||% file.path(dir, "capsule_bundle.json")
  files <- .bl_bnd_select(dir, files, path)
  pg <- blprog("bundling", length(files))
  on.exit(pg$done(), add = TRUE)
  entries <- lapply(seq_along(files), function(i) {
    f <- files[[i]]
    pg$update(i - 1L, sprintf("hashing %s", basename(f)))
    p <- file.path(dir, f)
    list(path = f, sha256 = sha256file(p), size_bytes = file.size(p))
  })
  pg$update(length(files), "signing")
  payload <- list(
    files = entries,
    manifest_digest = mnfdgst(man),
    bundled_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  # The attestation covers the file digests because they are part of the
  # payload it is taken over -- a bundle whose signature covered only
  # the manifest would leave the file list rewritable.
  inner <- list(meta = payload, results = list())
  att <- cpsatst(inner, key, ctx = ctx, prehash = prehash, note = note)
  bundle <- c(payload, list(attestation = att))
  class(bundle) <- c("bricklayer_bundle", "list")
  .bl_bnd_write(bundle, path)
  attr(bundle, "path") <- path
  invisible(bundle)
}

#' @rdname cpsbndl
#' @export
cpsbndlrd <- function(path) {
  path <- .rmbl_file1(path, "path")
  b <- .rmbl_json_text(
    paste(readLines(path, warn = FALSE), collapse = "\n"),
    simplifyVector = FALSE
  )
  if (!is.list(b) || is.null(b$attestation) || is.null(b$files)) {
    stop("`path` is not a capsule bundle", call. = FALSE)
  }
  class(b$attestation) <- c("bricklayer_attestation", "list")
  class(b$attestation$signature) <- c("bricklayer_signature", "list")
  if (!is.null(b$attestation$signature$key_state)) {
    warning(.rmbl_key_state_warning(), call. = FALSE)
  }
  class(b) <- c("bricklayer_bundle", "list")
  attr(b, "path") <- normalizePath(path, winslash = "/", mustWork = FALSE)
  b
}

#' @rdname cpsbndl
#' @export
cpsbndlvrf <- function(
  bundle,
  dir,
  man = NULL,
  keyexp = NULL,
  key = NULL,
  seen = NULL
) {
  .bl_keyexp_arg(keyexp)
  if (is.character(bundle)) {
    bundle <- cpsbndlrd(bundle)
  }
  if (!inherits(bundle, "bricklayer_bundle")) {
    stop("`bundle` must come from cpsbndl() or ", "cpsbndlrd()", call. = FALSE)
  }
  dir <- .rmbl_string1(dir, "dir")
  acc <- new.env(parent = emptyenv())
  acc$checks <- list()
  note_row <- function(check, ok, detail = "") {
    acc$checks[[length(acc$checks) + 1L]] <- data.frame(
      check = check,
      ok = isTRUE(ok),
      detail = as.character(detail),
      stringsAsFactors = FALSE
    )
  }
  pg <- blprog("verifying bundle", length(bundle$files))
  on.exit(pg$done(), add = TRUE)
  for (e in bundle$files) {
    pg$tick(1, sprintf("hashing %s", basename(as.character(e$path)[1L])))
    .bl_bnd_file_row(e, dir, note_row)
  }
  .bl_bnd_extra_row(bundle, dir, note_row)
  .bl_bnd_att_rows(bundle, keyexp, key, note_row)
  if (!is.null(seen)) {
    .bl_bnd_xmss_row(bundle, seen, note_row)
  }
  if (!is.null(man)) {
    .bl_bnd_man_row(bundle, man, note_row)
  }
  df <- do.call(rbind, acc$checks)
  rownames(df) <- NULL
  out <- list(ok = all(df$ok), checks = df)
  class(out) <- c("bricklayer_bundle_check", "list")
  out
}

#' @export
format.bricklayer_bundle <- function(x, ...) {
  .rmbl_stat_block(
    "Capsule bundle",
    facts = list(
      Files = length(x$files),
      `Manifest digest` = as.character(x$manifest_digest)[1L],
      Bundled = as.character(x$bundled_utc)[1L],
      Scheme = x$attestation$scheme,
      Note = if (nzchar(x$attestation$note %||% "")) x$attestation$note,
      Path = attr(x, "path")
    ),
    reading = paste(
      "A signed list of the capsule's files and their digests; check the",
      "files against it with cpsbndlvrf()."
    )
  )
}

#' @rdname printmeth
#' @export
print.bricklayer_bundle <- function(x, ...) {
  if (
    is.list(x$attestation) &&
      is.list(x$attestation$signature) &&
      !is.null(x$attestation$signature$key_state)
  ) {
    warning(.rmbl_key_state_warning(), call. = FALSE)
  }
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}

#' @export
format.bricklayer_bundle_check <- function(x, ...) {
  .rmbl_stat_block(
    sprintf("Bundle check: %s", if (isTRUE(x$ok)) "OK" else "FAILED"),
    facts = list(Checks = nrow(x$checks)),
    reading = .rmbl_check_reading(
      x$ok,
      "every file is the one that was signed and the signature holds",
      "the files are not the ones that were signed, or the signature fails"
    ),
    notes = .rmbl_check_lines(x$checks)
  )
}

#' The files a bundle covers: those named, or every regular file in `dir`
#' but the bundle itself; each must exist.
#' @param dir The directory whose regular files, dotfiles too, are bundled.
#' @param files The file names given, or NULL.
#' @param path Where the bundle is written.
#' @return The sorted file names.
#' @noRd
.bl_bnd_select <- function(dir, files, path) {
  if (is.null(files)) {
    # dotfiles too: a .Rprofile dropped into a capsule directory runs when
    # a session starts there, and a bundle that claims "every regular file"
    # must have hashed it
    all_files <- list.files(
      dir,
      recursive = TRUE,
      all.files = TRUE,
      full.names = FALSE,
      no.. = TRUE
    )
    keep <- vapply(
      all_files,
      function(f) {
        p <- file.path(dir, f)
        !dir.exists(p) &&
          !identical(
            normalizePath(p, mustWork = FALSE),
            normalizePath(path, mustWork = FALSE)
          )
      },
      logical(1)
    )
    files <- sort(all_files[keep])
  } else {
    files <- sort(as.character(files))
  }
  if (!length(files)) {
    stop("no files to bundle", call. = FALSE)
  }
  missing <- files[!file.exists(file.path(dir, files))]
  if (length(missing)) {
    stop(
      "these files are not in `dir`: ",
      toString(utils::head(missing, 5L)),
      call. = FALSE
    )
  }
  files
}

#' Writes a bundle as JSON.
#' @param bundle The bundle.
#' @param path Where to write it.
#' @return `path`, invisibly.
#' @noRd
.bl_bnd_write <- function(bundle, path) {
  writeLines(
    tojs(
      unclass(bundle),
      auto_unbox = TRUE,
      pretty = TRUE,
      na = "null",
      null = "null",
      digits = I(17)
    ),
    path,
    useBytes = TRUE
  )
  invisible(path)
}

#' One bundled file, checked: inside the directory, present, and with its
#' listed SHA-256.
#' @param e The bundle's entry.
#' @param dir The bundled directory the entry's path must be inside.
#' @param note_row The function that records the file's check.
#' @noRd
.bl_bnd_file_row <- function(e, dir, note_row) {
  f <- as.character(e$path)[1L]
  p <- .rmbl_safe_rel(f, dir)
  if (is.null(p)) {
    note_row(
      paste0("file:", f),
      FALSE,
      "not a plain relative path inside the directory"
    )
    return(invisible(NULL))
  }
  if (!file.exists(p)) {
    note_row(paste0("file:", f), FALSE, "missing from the directory")
    return(invisible(NULL))
  }
  got <- sha256file(p)
  ok <- identical(got, as.character(e$sha256)[1L])
  note_row(
    paste0("file:", f),
    ok,
    if (ok) {
      got
    } else {
      sprintf("expected %s, got %s", as.character(e$sha256)[1L], got)
    }
  )
  invisible(NULL)
}

#' A bundle's XMSS index against the signatures seen: an index that made
#' another signature is reused.
#' @param bundle The bundle.
#' @param seen The XMSS signatures seen, as xmssidxseen() returns them.
#' @param note_row The function that records the XMSS index check.
#' @noRd
.bl_bnd_xmss_row <- function(bundle, seen, note_row) {
  if (
    !is.data.frame(seen) ||
      !all(c("key", "index", "sig", "where") %in% names(seen))
  ) {
    stop(
      .rmbl_fn(),
      "`seen` must be what xmssidxseen() returns, or NULL",
      call. = FALSE
    )
  }
  a <- bundle$attestation
  s <- a$signature
  if (
    identical(a$scheme, "xmss-sha256") &&
      is.character(a$public) &&
      is.numeric(s$index) &&
      is.character(s$wire)
  ) {
    k <- .rmbl_xmss_fpr(a$public)
    i <- as.integer(s$index)
    o <- seen$where[
      seen$key == k & seen$index == i & seen$sig != .rmbl_xmss_sigd(s$wire)
    ]
    note_row(
      "xmss_index",
      !length(o),
      if (length(o)) {
        sprintf(
          paste0(
            "xmss index reused: index %d of key %s also made another ",
            "signature (%s)"
          ),
          i,
          k,
          toString(utils::head(unique(o), 3L))
        )
      } else {
        sprintf(
          "index %d of key %s made one signature in what was seen",
          i,
          k
        )
      }
    )
  }
  invisible(NULL)
}

#' The row for files on disk that a bundle does not list.
#' @param bundle The bundle.
#' @param dir The bundled directory searched for files the bundle omits.
#' @param note_row The function that records the extra-files check.
#' @return NULL, invisibly.
#' @noRd
.bl_bnd_extra_row <- function(bundle, dir, note_row) {
  # Files present on disk that the bundle does not mention are reported:
  # a signed list of what SHOULD be there says nothing about what else
  # has been added beside it.
  named <- vapply(
    bundle$files,
    function(e) as.character(e$path)[1L],
    character(1)
  )
  on_disk <- list.files(
    dir,
    recursive = TRUE,
    full.names = FALSE,
    all.files = TRUE,
    no.. = TRUE
  )
  on_disk <- on_disk[!dir.exists(file.path(dir, on_disk))]
  # only the bundle's OWN file is exempt from the listing, not every file
  # whose name ends in bundle.json
  own <- attr(bundle, "path")
  d <- sub("/+$", "", normalizePath(dir, winslash = "/", mustWork = FALSE))
  own_rel <- if (!is.null(own) && startsWith(own, paste0(d, "/"))) {
    substring(own, nchar(d) + 2L)
  } else {
    "capsule_bundle.json"
  }
  extra <- setdiff(on_disk, c(named, own_rel))
  note_row(
    "no_unlisted_files",
    length(extra) == 0L,
    if (length(extra)) {
      paste(
        "not covered by the bundle:",
        toString(utils::head(extra, 5L))
      )
    } else {
      ""
    }
  )
  invisible(NULL)
}

#' The rows of a bundle's attestation check.
#' @param bundle The bundle.
#' @param keyexp,key As for cpsbndlvrf().
#' @param note_row The function that records each attestation check.
#' @return NULL, invisibly.
#' @noRd
.bl_bnd_att_rows <- function(bundle, keyexp, key, note_row) {
  inner <- list(
    meta = list(
      files = bundle$files,
      manifest_digest = bundle$manifest_digest,
      bundled_utc = bundle$bundled_utc
    ),
    results = list()
  )
  res <- cpschkatst(bundle$attestation, inner, keyexp = keyexp, key = key)
  for (i in seq_len(nrow(res$checks))) {
    note_row(
      paste0("attestation:", res$checks$check[i]),
      res$checks$ok[i],
      res$checks$detail[i]
    )
  }
  invisible(NULL)
}

#' The row that checks a bundle's manifest digest against a manifest.
#' @param bundle The bundle.
#' @param man The manifest whose digest the bundle must record.
#' @param note_row The function that records the manifest digest check.
#' @return NULL, invisibly.
#' @noRd
.bl_bnd_man_row <- function(bundle, man, note_row) {
  got <- mnfdgst(man)
  note_row(
    "manifest_digest",
    identical(got, as.character(bundle$manifest_digest)[1L]),
    if (identical(got, as.character(bundle$manifest_digest)[1L])) {
      got
    } else {
      sprintf(
        "bundle says %s, manifest is %s",
        as.character(bundle$manifest_digest)[1L],
        got
      )
    }
  )
  invisible(NULL)
}
