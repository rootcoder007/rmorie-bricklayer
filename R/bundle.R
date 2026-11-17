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
#' itself; a temporary left by a write that was cut short
#' (\code{.rmbl-*.tmp}) is refused, as the check reports it. The folder is
#' walked one level at a time: a link that stays inside is content like any
#' other file or folder, but a link to the capsule folder or a folder above
#' it, a link that leaves the folder, a folder that cannot be read and
#' links that would list one folder more than 64 times are refused, all of
#' them named at once. An empty folder holds no content: it is not bundled
#' and the check does not report it. File names are kept by their bytes: a
#' name that is UTF-8 is bundled in every locale (C and Latin-1 too). A
#' bundle lists only names that verify on every system, so a name is
#' refused, with its reason, when it is not UTF-8 (its bytes shown as
#' \code{<e9>}), starts with \code{~} or a drive letter (\code{c:}), holds
#' a backslash, a double quote, one of \code{< > : | ? *} or a control
#' character, or has
#' a part that ends in a dot or a space or that Windows reserves (CON, PRN,
#' AUX, NUL, COM1 to COM9, LPT1 to LPT9, and COM and LPT followed by a
#' superscript 1, 2 or 3, with any extension), letters compared by their
#' ASCII bytes in every locale. Names that differ only by letter case or by
#' Unicode normalisation (\code{A.txt} and \code{a.txt}, \code{sub/x} and
#' \code{SUB/x}, an accented letter written as one character and as a letter
#' with a combining accent) are one name on Windows and macOS, so they are
#' refused together, each set named: every name and every folder above one
#' is compared by Unicode's canonical caseless match (the canonical
#' decomposition of the simple case folding of the canonical decomposition,
#' Unicode 15.1, section 3.13), from the Unicode Character Database's tables
#' and never the locale's. Simple folding maps one character to one, so
#' \code{ss} and a sharp s are two names (as Windows takes them); the Turkish
#' dotted capital I folds to an i with a dot above, not to a plain i. The
#' check of a bundle does not apply these rules, so a bundle made before them
#' still verifies. A progress bar is shown when `options(morie.progress)`
#' allows it.
#'
#' Each file is read through the real path it had when it was checked,
#' below `dir`, so a link changed while the bundle is made is not followed
#' out of the folder. Before anything is signed every file is looked at
#' again: its real path, a link's target, its size and its modification and
#' status-change times must be those it had before it was read, and a file
#' of at most 1 MiB is read a second time and must give the same digest;
#' anything else stops `cpsbndl()` with the files named and nothing signed.
#' What remains unseen is a change to a file over 1 MiB that keeps its size
#' and both times: the system sets the status-change time on every write
#' and no program can set it back, so only a file system that records
#' whole seconds, written twice within one, can hide such a change.
#'
#' How it is checked. `cpsbndlvrf()` re-hashes every listed file
#' (a path that is absolute or climbs out of `dir` fails its row), reports
#' every file on disk the bundle does not list (the bundle's own file
#' excepted, when it is the file checked: a \code{capsule_bundle.json}
#' in `dir` is unlisted when another bundle file is checked) and what the
#' walk of `dir` cannot cover (the links and folders `cpsbndl()` refuses),
#' in the `no_unlisted_files` row,
#' checks the attestation with
#' [cpschkatst()]
#' (signature, digest, and `keyexp` when given; an `"hmac"`
#' signature needs the shared secret as `key`), and, when `man`
#' is given, compares its digest with the bundled one. Every check is a row of
#' `checks`; `ok` is `TRUE` only when all pass. A failed check is a row,
#' not
#' an error.
#'
#' Errors: `dir` missing or not a directory; no files to bundle, or a named
#' file not in `dir`, or a link whose target does not exist; the links,
#' folders and names above; a file changed while it was read; a file that cannot
#' be read, or a bundle file or its folder that cannot be written to (all
#' before any file is hashed); a key [cpsatst()] cannot
#' sign with;
#' `cpsbndlrd()` given a file that is not a bundle, or one over 32 MiB;
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
#' `detail`: one `file:PATH` row per listed file, `no_unlisted_files`, a
#' failed `no_unsigned_fields` row when the bundle or its attestation holds
#' fields \code{cpsbndl()} does not write (no signature covers them), the
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
  dir <- .rmbl_fspath(.rmbl_string1(dir, "dir"))
  if (!dir.exists(dir)) {
    stop("`dir` does not exist: ", .rmbl_ctl_escape(dir), call. = FALSE)
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
  prep <- .bl_bnd_prep(dir, files, path, man)
  files <- prep$files
  pg <- blprog("bundling", length(files))
  on.exit(pg$done(), add = TRUE)
  entries <- .bl_bnd_hash(dir, files, pg)
  payload <- list(
    files = entries,
    manifest_digest = prep$digest,
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
  # within the 32 MiB the package's JSON documents are held to
  path <- .rmbl_file1(path, "path", max = 32 * 2^20)
  b <- .rmbl_json_text(
    paste(.rmbl_json_file_lines(path), collapse = "\n"),
    simplifyVector = FALSE
  )
  if (
    !is.list(b) ||
      !is.list(b$attestation) ||
      !is.list(b$attestation$signature) ||
      !.bl_bnd_files_ok(b$files)
  ) {
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
  dir <- .rmbl_fspath(.rmbl_string1(dir, "dir"))
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
    # sub(), not basename(): basename() translates a name marked UTF-8 to
    # the session encoding, and stopped on an accented name in a C locale
    nm <- sub("^.*/", "", as.character(e$path)[1L], useBytes = TRUE)
    pg$tick(1, sprintf("hashing %s", .bl_names(nm)))
    .bl_bnd_file_row(e, dir, note_row)
  }
  .bl_bnd_extra_row(bundle, dir, note_row)
  .bl_bnd_fields_row(bundle, note_row)
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

#' Whether a bundle's file list is a list of records, each with one path and
#' one digest as strings.
#' @param files The `files` member of a parsed bundle.
#' @return TRUE or FALSE.
#' @noRd
.bl_bnd_files_ok <- function(files) {
  one <- function(v) is.character(v) && length(v) == 1L && !is.na(v)
  is.list(files) &&
    all(vapply(
      files,
      function(e) is.list(e) && one(e$path) && one(e$sha256),
      NA
    ))
}

#' A folder's entries, walked one folder at a time.
#'
#' list.files(recursive = TRUE) follows every link to a folder: two links
#' back to the capsule (a -> ., b -> .) made it walk some 2^40 paths, and a
#' link to "/" the whole file system, before anything could refuse them, and
#' it skipped a folder it could not read without a word. Here each folder is
#' listed by itself and the real path of each entry resolved first. A link
#' to a folder on the path walked, or to one above it, is a loop and is not
#' followed; a link that leaves `dir` is not followed; a folder that cannot
#' be read is named. A link that stays inside is content, as before, but no
#' real folder is listed more than 64 times, so the work is bounded by the
#' real entries whatever the links. An empty folder is no content: it is
#' neither bundled nor reported.
#' @param dir The folder, as .rmbl_fspath() gives it.
#' @param search TRUE to look for capsules under `dir` instead of listing
#'   one: a link to a folder inside `dir` is followed, each real folder
#'   listed once (a capsule linked in from elsewhere in the tree is found);
#'   a link to a folder on the path walked or above it (a loop) is not
#'   followed; a link to any other folder outside `dir` is not followed but
#' named in `outside` (a link to /usr walked all of it, and a folder there that
#'   could not be read failed the search; skipped without a word, a linked
#'   capsule went unchecked and the check said "ok"); .git and .rmbl-cache
#'   are not entered.
#' @return A list of paths relative to `dir`: `files` (every entry that is
#'   not a folder), `loops`, `outside` (links that leave `dir`), `unread`
#'   (folders that cannot be read; "." for `dir` itself) and `many` (folders
#'   that links would list a 65th time).
#' @noRd
.bl_walk <- function(dir, search = FALSE) {
  root <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  st <- new.env(parent = emptyenv())
  st$seen <- new.env(parent = emptyenv())
  st$out <- list()
  .bl_walk_once(st, root)
  todo <- list(list(rel = "", real = root, chain = root))
  while (length(todo)) {
    it <- todo[[length(todo)]]
    todo[[length(todo)]] <- NULL
    todo <- c(todo, .bl_walk1(dir, it, root, search, st))
  }
  keys <- c("files", "loops", "outside", "unread", "many")
  lapply(stats::setNames(keys, keys), function(k) {
    as.character(unlist(lapply(st$out, `[[`, k), use.names = FALSE))
  })
}

#' One folder of .bl_walk(): its entries sorted into the walk's lists.
#' @param dir The folder walked.
#' @param it The folder to list: `rel` (to `dir`), its `real` path and the
#'   `chain` of real paths walked to reach it.
#' @param root The real path of `dir`.
#' @param search As for .bl_walk().
#' @param st The walk's state, which collects what is found.
#' @return The folders to walk next, as `it` is.
#' @noRd
.bl_walk1 <- function(dir, it, root, search, st) {
  # joined by .rmbl_jpath(): file.path() refuses a name that is not text
  # before R 4.2
  full <- if (nzchar(it$rel)) .rmbl_jpath(dir, it$rel) else dir
  # a folder that cannot be listed or searched hides its files (Windows
  # tests no search permission)
  mode <- if (.Platform$OS.type == "windows") 4L else 5L
  if (file.access(full, mode) != 0L) {
    return(.bl_walk_put(st, unread = if (nzchar(it$rel)) it$rel else "."))
  }
  e <- list.files(full, all.files = TRUE, no.. = TRUE)
  rel <- if (nzchar(it$rel)) .rmbl_jpath(it$rel, e) else e
  p <- .rmbl_jpath(full, e)
  isd <- dir.exists(p)
  # dir.exists() says TRUE for a socket too
  isd[isd] <- vapply(p[isd], .rmbl_isdir, NA, USE.NAMES = FALSE)
  real <- normalizePath(p, winslash = "/", mustWork = FALSE)
  # a link, of either kind (a Windows junction too), by its real path: a
  # link that does not resolve is a file that is not there
  want <- .rmbl_jpath(if (identical(it$real, "/")) "" else it$real, e)
  link <- file.exists(p) & .rmbl_bytes(real) != .rmbl_bytes(want)
  out <- !search & !isd & link & !.bl_under(real, root)
  .bl_walk_put(st, files = rel[!isd & !out], outside = rel[out])
  .bl_walk_dirs(it, rel[isd], real[isd], link[isd], list(root, search, st))
}

#' The folders of one listed folder that .bl_walk() goes on into.
#' @param it The listed folder, as for .bl_walk1().
#' @param rel,real,link Its sub-folders: relative path, real path, and
#'   whether each is reached through a link.
#' @param w The walk: its root's real path, `search` and its state.
#' @return The folders to walk next.
#' @noRd
.bl_walk_dirs <- function(it, rel, real, link, w) {
  st <- w[[3L]]
  if (w[[2L]]) {
    keep <- !basename(rel) %in% c(".git", ".rmbl-cache")
    rel <- rel[keep]
    real <- real[keep]
    link <- link[keep]
  }
  loop <- link & .bl_up(real, it$chain)
  out <- link & !loop & !.bl_under(real, w[[1L]])
  if (w[[2L]]) {
    .bl_walk_put(st, outside = rel[out])
    go <- !out & !loop
    go[go] <- .bl_walk_once(st, real[go])
  } else {
    many <- !loop & !out
    many[many] <- !.bl_walk_count(st, real[many])
    .bl_walk_put(st, loops = rel[loop], outside = rel[out], many = rel[many])
    go <- !loop & !out & !many
  }
  lapply(which(go), function(i) {
    list(rel = rel[[i]], real = real[[i]], chain = c(it$chain, real[[i]]))
  })
}

#' Adds what one folder of a walk found to the walk's results.
#' @param st The walk's state.
#' @param ... Named character vectors (files, loops, ...).
#' @return An empty list: no folder to walk on from here.
#' @noRd
.bl_walk_put <- function(st, ...) {
  st$out[[length(st$out) + 1L]] <- list(...)
  list()
}

#' Marks real folders as walked, for a search that walks each one once.
#' @param st The walk's state.
#' @param real Real paths.
#' @return For each, TRUE when it had not been walked.
#' @noRd
.bl_walk_once <- function(st, real) {
  vapply(real, function(r) {
    if (exists(r, envir = st$seen, inherits = FALSE)) {
      return(FALSE)
    }
    assign(r, 1L, envir = st$seen)
    TRUE
  }, NA, USE.NAMES = FALSE)
}

#' Counts how often each real folder is listed, links included.
#'
#' Links that stay inside a capsule are content, but nested pairs of them
#' list the folders below 2^n times without any loop: a folder is listed at
#' most 64 times.
#' @param st The walk's state.
#' @param real Real paths.
#' @return For each, TRUE when it is still within the 64.
#' @noRd
.bl_walk_count <- function(st, real) {
  vapply(real, function(r) {
    n <- if (exists(r, envir = st$seen, inherits = FALSE)) {
      get(r, envir = st$seen, inherits = FALSE)
    } else {
      0L
    }
    assign(r, n + 1L, envir = st$seen)
    n < 64L
  }, NA, USE.NAMES = FALSE)
}

#' Whether real paths are a folder or inside it, by their bytes.
#' @param x Real paths.
#' @param root The folder's real path.
#' @return A logical vector.
#' @noRd
.bl_under <- function(x, root) {
  pre <- sub("/*$", "/", root, useBytes = TRUE)
  .rmbl_bytes(x) == .rmbl_bytes(root) | .rmbl_bstarts(x, pre)
}

#' Whether real paths are a folder on a walked path or above one of them: a
#' link to such a folder is a loop.
#' @param x The real paths links resolve to.
#' @param chain The real paths walked to reach the links.
#' @return A logical vector.
#' @noRd
.bl_up <- function(x, chain) {
  vapply(x, function(r) any(.bl_under(chain, r)), NA, USE.NAMES = FALSE)
}

#' What a walk found that a bundle cannot cover, one sentence for each kind.
#' @param w A walk, from .bl_walk().
#' @return Sentences; none when the walk is clean.
#' @noRd
.bl_walk_why <- function(w) {
  c(
    if (length(w$loops)) {
      paste0(
        "a link that points back into the capsule folder, or to a folder ",
        "above it, is not followed; remove it: ", .bl_names(w$loops)
      )
    },
    if (length(w$many)) {
      paste0(
        "links list these folders more than 64 times and are not followed ",
        "further; remove some of the links: ", .bl_names(w$many)
      )
    },
    if (length(w$unread)) {
      paste0(
        "a folder that cannot be read (permission denied) hides its files; ",
        "make it readable or remove it: ", .bl_names(w$unread)
      )
    },
    if (length(w$outside)) {
      paste0(
        "these entries are reached through a link that leaves the capsule ",
        "folder; copy them in or remove the link: ", .bl_names(w$outside)
      )
    }
  )
}

#' File names as a message shows them: bytes that are not UTF-8 as <e9>,
#' control characters escaped, at most `n` of them.
#' @param x Names.
#' @param n The most shown; the rest are counted.
#' @return One string.
#' @noRd
.bl_names <- function(x, n = 20L) {
  s <- utils::head(x, n)
  bad <- !validUTF8(s)
  s[bad] <- .rmbl_esc8(s[bad])
  paste0(
    toString(.rmbl_ctl_escape(s)),
    if (length(x) > n) sprintf(" and %d more", length(x) - n)
  )
}

#' The entries of a capsule folder reached through a link that leaves it.
#' @param dir The capsule folder.
#' @param files Paths relative to `dir`, all of which exist.
#' @return Those of `files` whose real path is not inside `dir`.
#' @noRd
.bl_bnd_outside <- function(dir, files) {
  real <- normalizePath(file.path(dir, files), winslash = "/",
                        mustWork = FALSE)
  files[!.bl_under(real, normalizePath(dir, winslash = "/", mustWork = FALSE))]
}

#' Every file a bundle of `dir` covers when no files are named.
#'
#' Dotfiles too: a .Rprofile dropped into a capsule runs when a session
#' starts there, and a bundle that claims "every regular file" must have
#' hashed it. What the walk cannot cover (a loop, a folder that cannot be
#' read, a link out) stops here, all of it named at once.
#' @param dir The capsule folder.
#' @param path Where the bundle is written, which is left out.
#' @return The sorted file names, relative to `dir`.
#' @noRd
.bl_bnd_every <- function(dir, path) {
  w <- .bl_walk(dir)
  why <- .bl_walk_why(w)
  if (length(why)) {
    stop(.rmbl_fn(), .bl_names(dir), ": ", paste(why, collapse = "; "),
         call. = FALSE)
  }
  # the temporary of a write cut short is no content of the capsule, and
  # the check reports it: bundled without it, the capsule failed its check
  .bl_left_stop(w$files[.rmbl_leftover(w$files)])
  f <- w$files
  own <- normalizePath(.rmbl_fspath(path), winslash = "/", mustWork = FALSE)
  real <- normalizePath(.rmbl_jpath(dir, f), winslash = "/",
                        mustWork = FALSE)
  .rmbl_bsort(f[.rmbl_bytes(real) != .rmbl_bytes(own)])
}

#' Stops when temporaries of the package's writes are left in a capsule.
#'
#' A write or a seal that was stopped or killed leaves them (a seal keeps a
#' copy of each file it replaces, and puts it back when it fails); they are
#' no content, the check reports them, and nothing needs them. Every one
#' is named, however many (a seal killed late leaves two for each capsule
#' it had sealed, and naming 20 of them left the rest unnamed), so a seal
#' can be run again once exactly those are deleted.
#' @param left Their paths.
#' @return NULL, invisibly.
#' @noRd
.bl_left_stop <- function(left) {
  if (length(left)) {
    stop(
      .rmbl_fn(), "a temporary left by a write or a seal of this package ",
      "that was cut short (stopped or killed) is not part of the capsule ",
      "and is safe to delete; delete it and run again: ",
      .bl_names(left, Inf),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The files a bundle covers: those named, or every regular file in `dir`
#' but the bundle itself; each must have a name a bundle may list, exist
#' and lie inside `dir`.
#' @param dir The directory whose regular files, dotfiles too, are bundled.
#' @param files The file names given, or NULL.
#' @param path Where the bundle is written.
#' @return The sorted file names.
#' @noRd
.bl_bnd_select <- function(dir, files, path) {
  files <- if (is.null(files)) {
    .bl_bnd_every(dir, path)
  } else {
    .rmbl_bsort(.rmbl_fspath(as.character(files)))
  }
  no <- function(...) {
    stop(.rmbl_fn(), .bl_names(dir), ": ", ..., call. = FALSE)
  }
  if (!length(files)) {
    no("no files to bundle")
  }
  .bl_bnd_names(files, .bl_bnd_selfname(dir, path))
  p <- .rmbl_jpath(dir, files)
  gone <- !file.exists(p)
  # a link whose target is missing is in the folder: it is no missing file
  lk <- Sys.readlink(p)
  dang <- gone & !is.na(lk) & nzchar(lk)
  if (any(dang)) {
    no("these links lead nowhere (their target does not exist); remove ",
       "them or restore what they point to: ", .bl_names(files[dang], Inf))
  }
  if (any(gone)) {
    no("these files are not in `dir`: ", .bl_names(files[gone], 5L))
  }
  out <- .bl_bnd_outside(dir, files)
  if (length(out)) {
    no("these entries are reached through a link that leaves the capsule ",
       "folder; copy them in or remove the link: ", .bl_names(out, 5L))
  }
  files
}

#' The bundle file's own name when it is written inside the capsule folder,
#' for the clash of names: a capsule holding CAPSULE_BUNDLE.JSON has its
#' bundle written over it where case is ignored.
#' @param dir The capsule folder.
#' @param path Where the bundle is written.
#' @return Its name relative to `dir`, or none.
#' @noRd
.bl_bnd_selfname <- function(dir, path) {
  real <- function(x) normalizePath(x, winslash = "/", mustWork = FALSE)
  pd <- real(dirname(.rmbl_fspath(path)))
  if (.rmbl_bytes(pd) == .rmbl_bytes(real(dir))) basename(path)
}

#' Hashes the files of a bundle, each read by the real path it had when it
#' was checked, so a link swapped meanwhile is not followed out of the
#' capsule, and stops when one changed before anything is signed
#' (.bl_bnd_unmoved()).
#' @param dir The capsule folder.
#' @param files The files, relative to `dir`.
#' @param pg The progress bar.
#' @return The bundle's entries: `path`, `sha256`, `size_bytes`.
#' @noRd
.bl_bnd_hash <- function(dir, files, pg) {
  st <- .bl_bnd_stat(dir, files)
  entries <- lapply(seq_along(files), function(i) {
    pg$update(i - 1L, sprintf("hashing %s", .bl_names(basename(files[[i]]))))
    list(path = files[[i]], sha256 = sha256file(st$real[[i]]),
         size_bytes = st$size[[i]])
  })
  .bl_bnd_unmoved(dir, files, st, entries)
  pg$update(length(files), "signing")
  entries
}

#' What cpsbndl() records of each file before it reads it: its real path
#' (which must lie inside the folder), the target of a link, its size and
#' its modification and status-change times.
#'
#' Base R reads no inode number; the status-change time (ctime) stands in
#' for it: the system sets it whenever a file is written, renamed onto or
#' has its mode changed, and no program can set it back.
#' @param dir The capsule folder.
#' @param files The files, relative to `dir`.
#' @return A list of vectors: `real`, `link`, `size`, `mtime`, `ctime`.
#' @noRd
.bl_bnd_stat <- function(dir, files) {
  p <- .rmbl_jpath(dir, files)
  real <- normalizePath(p, winslash = "/", mustWork = FALSE)
  root <- normalizePath(dir, winslash = "/", mustWork = FALSE)
  out <- !.bl_under(real, root)
  if (any(out)) {
    stop(.rmbl_fn(), .bl_names(dir), ": these entries were changed during ",
         "the seal to lead outside the capsule folder, and were not read: ",
         .bl_names(files[out], Inf), call. = FALSE)
  }
  # read as `dir` plus the real path below it: no link below `dir` is
  # followed, and a folder above it whose name is not UTF-8 is not spelled
  # out (sha256file() refuses such a path in a UTF-8 locale)
  n <- length(charToRaw(sub("/*$", "/", root, useBytes = TRUE)))
  below <- vapply(real, function(r) rawToChar(charToRaw(r)[-seq_len(n)]), "",
                  USE.NAMES = FALSE)
  fi <- file.info(real, extra_cols = FALSE)
  lk <- Sys.readlink(p)
  lk[is.na(lk)] <- ""
  list(real = .rmbl_jpath(dir, below), link = lk,
       size = fi$size, mtime = as.numeric(fi$mtime),
       ctime = as.numeric(fi$ctime))
}

#' Stops when a file changed while cpsbndl() read it, before anything is
#' signed.
#'
#' Every file is looked at again: its real path, link target, size and
#' times must be those recorded before it was read (.bl_bnd_stat()), and a
#' file of at most 1 MiB is read a second time and must give the same
#' digest. A change that keeps the size and both times of a larger file is
#' not seen; the system changes the status-change time on every write.
#' @param dir The capsule folder.
#' @param files The files, relative to `dir`.
#' @param st What .bl_bnd_stat() recorded before they were read.
#' @param entries The bundle's entries: each file's `sha256`.
#' @return NULL, invisibly.
#' @noRd
.bl_bnd_unmoved <- function(dir, files, st, entries) {
  now <- .bl_bnd_stat(dir, files)
  same <- function(k) {
    a <- st[[k]]
    b <- now[[k]]
    if (is.character(a)) {
      return(.rmbl_bytes(a) == .rmbl_bytes(b))
    }
    !is.na(a) & !is.na(b) & a == b
  }
  ok <- same("real") & same("link") & same("size") & same("mtime") &
    same("ctime")
  small <- which(ok & st$size <= 1048576)
  ok[small] <- vapply(small, function(i) {
    identical(sha256file(st$real[[i]]), entries[[i]]$sha256)
  }, NA)
  if (!all(ok)) {
    stop(.rmbl_fn(), .bl_names(dir), ": these files changed while the ",
         "capsule was being bundled, so nothing was signed; run it again ",
         "once nothing writes to them: ", .bl_names(files[!ok], Inf),
         call. = FALSE)
  }
  invisible(NULL)
}

#' What cpsbndl() checks before it reads a byte or signs.
#'
#' The files to bundle (walked, their names ones a bundle may list, each
#' inside `dir`), each one checked as sha256file() checks it before reading
#' it, the bundle file as the writer checks it, and the manifest's digest.
#' cpsseal()
#' runs it over every capsule before it writes the first, so its look-ahead
#' is this code and cannot miss a refusal of it.
#' @param dir,files,path,man As for cpsbndl(); `path` is set.
#' @return A list: `files` and the manifest's `digest`.
#' @noRd
.bl_bnd_prep <- function(dir, files, path, man) {
  files <- .bl_bnd_select(dir, files, path)
  for (p in file.path(dir, files)) {
    .rmbl_sha256_path(p)
    .rmbl_file1(p, "path")
  }
  # the writer's own check: a bundle that cannot be written to was found
  # only after the capsules before it were signed
  .rmbl_wtarget(path.expand(.rmbl_fspath(path)))
  list(files = files, digest = mnfdgst(man))
}

#' Writes a bundle as JSON.
#' @param bundle The bundle.
#' @param path Where to write it.
#' @return `path`, invisibly.
#' @noRd
.bl_bnd_write <- function(bundle, path) {
  .rmbl_wlines(
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

#' Stops when a file to bundle has a name a bundle may not list.
#'
#' The rule is the check's (.rmbl_relwhy()), made strict: a name the check
#' refuses ("~notes.txt", "c:raw.csv", "a\\\\b") was bundled and signed, and
#' the capsule failed its check right after; a name that is not UTF-8
#' cannot be listed in JSON by its bytes; and a name Windows cannot hold
#' would not verify there.
#' @param files The files to bundle, relative to the directory.
#' @param own The bundle file's own name in the directory, or NULL.
#' @return NULL, invisibly.
#' @noRd
.bl_bnd_names <- function(files, own = NULL) {
  why <- .rmbl_relwhy(files, strict = TRUE)
  bad <- which(nzchar(why))
  if (length(bad)) {
    each <- vapply(bad, function(i) {
      paste0(.bl_names(files[[i]]), " (", why[[i]], ")")
    }, "")
    stop(
      .rmbl_fn(), "a file whose name is not valid text (UTF-8), or would ",
      "not verify on every system, cannot be listed in a bundle; rename ",
      "it: ", toString(utils::head(each, 5L)),
      if (length(bad) > 5L) sprintf(" and %d more", length(bad) - 5L),
      call. = FALSE
    )
  }
  clash <- .rmbl_clash(c(files, own))
  if (length(clash)) {
    stop(
      .rmbl_fn(), "names that differ only by case or by Unicode ",
      "normalisation are one name on Windows and macOS, where only one of ",
      "each set can be, so the capsule would not verify there; rename all ",
      "but one of each: ", paste(clash, collapse = "; "),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' What a bundled directory holds: its files.
#'
#' Walked as cpsbndl() walks it (.bl_walk()), so the listing that is checked
#' is the listing that was signed. An empty folder is no content, as it is
#' none of a bundle: reported, it failed every capsule sealed with one.
#' @param dir The bundled directory.
#' @return Paths relative to `dir`. Attribute "why": what the walk could not
#'   cover.
#' @noRd
.bl_bnd_ondisk <- function(dir) {
  w <- .bl_walk(dir)
  out <- w$files
  attr(out, "why") <- .bl_walk_why(w)
  out
}

#' The bundle's own file, relative to the directory, when it lies inside.
#' @param bundle The bundle; its `path` attribute is the file checked.
#' @param dir The bundled directory.
#' @return A relative path, or NULL.
#' @noRd
.bl_bnd_ownrel <- function(bundle, dir) {
  # only the bundle's OWN file is exempt from the listing, when it is the
  # file checked: a bundle checked from outside the capsule exempts nothing,
  # where a capsule_bundle.json planted inside passed whatever it held
  own <- attr(bundle, "path")
  if (is.null(own)) {
    return(NULL)
  }
  own <- normalizePath(own, winslash = "/", mustWork = FALSE)
  d <- sub("/*$", "/", normalizePath(dir, winslash = "/", mustWork = FALSE),
           useBytes = TRUE)
  # by its bytes, as the walk compares
  if (.rmbl_bstarts(own, d)) {
    rawToChar(charToRaw(own)[-seq_along(charToRaw(d))])
  }
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
  disk <- .bl_bnd_ondisk(dir)
  why <- attr(disk, "why")
  # by bytes: the names read from the bundle are marked UTF-8, those read
  # from the folder are not
  keep <- c(named, .bl_bnd_ownrel(bundle, dir))
  extra <- unique(disk[!.rmbl_bytes(disk) %in% .rmbl_bytes(keep)])
  # a temporary left by a write that was cut short is said to be one: it
  # is not part of the capsule either, and is removed rather than signed
  lo <- .rmbl_leftover(extra)
  left <- extra[lo]
  extra <- extra[!lo]
  note_row(
    "no_unlisted_files",
    !length(extra) && !length(left) && !length(why),
    paste(c(
      if (length(extra)) {
        paste("not covered by the bundle:", .bl_names(extra, 5L))
      },
      if (length(left)) {
        paste(
          "left over from an interrupted write, not part of the capsule",
          "(remove it):",
          .bl_names(left, 5L)
        )
      },
      why
    ), collapse = "; ")
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

#' A failed row for fields of a bundle or its file records that cpsbndl()
#' never writes, which the signature does not cover; nothing when there are
#' none.
#' @param bundle The bundle whose fields are checked.
#' @param note_row Records the fields check as a row.
#' @return NULL, invisibly.
#' @noRd
.bl_bnd_fields_row <- function(bundle, note_row) {
  top <- setdiff(
    names(bundle),
    c("files", "manifest_digest", "bundled_utc", "attestation")
  )
  rec <- unlist(lapply(bundle$files, function(e) {
    setdiff(names(e), c("path", "sha256", "size_bytes"))
  }))
  extra <- c(top, if (length(rec)) paste0("files: ", unique(rec)))
  if (length(extra)) {
    note_row(
      "no_unsigned_fields",
      FALSE,
      paste("not covered by the signature:", toString(extra))
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
