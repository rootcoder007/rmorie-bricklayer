# Curated datasets at data.rmorie.com (the address comes from the signed
# services document), opened by the MORIE key this package stores with
# bricklayer_llm_login() (GitHub or an emailed code), or one asked for at www.rmorie.com/access/.
# The same tables rmorie and morie pull;
# a manifest lists every table with its rows, columns, SHA-256 and the
# BigQuery public dataset it was built from.

# a TRUE/FALSE argument, said plainly when it is not one
.bl_check_flag <- function(x, name) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be TRUE or FALSE", name), call. = FALSE)
  }
  invisible(x)
}

.bl_data_url <- function() {
  env <- sub("/+$", "", trimws(Sys.getenv("MORIE_DATA_URL", unset = "")))
  if (nzchar(env)) {
    # the bearer key goes to this host: https and a public address, or no key
    return(.rmbl_check_public_url(env, "MORIE_DATA_URL"))
  }
  svc <- .rmbl_services_data()
  if (!identical(svc$mode, "key") || !nzchar(svc$base_url %||% "")) {
    notice <- bricklayer_services(offline = TRUE)$notice %||% ""
    stop("the curated-data service is not available right now",
         if (nzchar(notice)) paste0(": ", notice) else "",
         sprintf(" (see %s)", svc$request_access %||% "https://www.rmorie.com/access/"), call. = FALSE)
  }
  svc$base_url
}

# The tables whose source licence asks more than attribution (ICPSR studies, the NCVS 38604
# extract, the a2aj case law): data.rmorie.com opens them once the terms at /terms are accepted.
.bl_data_restricted <- function(key) grepl("^(icpsr_|ncvs_38604|a2aj_)", sub("^(db|files)/", "", key))

# The hosted key for the data service: to the address the signed services document names, never
# to an address set in MORIE_DATA_URL (a key that belongs to one service does not follow a URL).
.bl_data_key <- function() {
  key <- .bl_hosted_key()
  if (is.null(key)) return(NULL)
  env <- sub("/+$", "", trimws(Sys.getenv("MORIE_DATA_URL", unset = "")))
  if (!nzchar(env)) return(key)
  doc <- sub("/+$", "", .rmbl_services_data()$base_url %||% "")
  if (nzchar(doc) && identical(env, doc)) return(key)
  message(sprintf(paste("MORIE_DATA_URL=%s is not the curated-data address of the services document;",
                        "the stored key is not sent to it"), env))
  NULL
}

.bl_data_cache_dir <- function() {
  d <- getOption("rmoriebricklayer.data_cache", NULL)
  if (is.null(d) || !nzchar(d)) {
    d <- file.path(tempdir(), "rmoriebricklayer-data")
  }
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

.bl_data_get <- function(path, dest, timeout = 600) {
  key <- .bl_data_key()
  if (is.null(key)) {
    env <- trimws(Sys.getenv("MORIE_DATA_URL", unset = ""))
    if (nzchar(env) && !is.null(.bl_hosted_key())) {
      stop(sprintf(paste("MORIE_DATA_URL=%s is not the curated-data address of the signed services document,",
                         "so the stored key is not sent to it: unset MORIE_DATA_URL (the address comes from the",
                         "document)"), env), call. = FALSE)
    }
    stop("the curated tables need your MORIE key: run ",
         sprintf("bricklayer_llm_login() (or `%s login`) once; %s.", .bl_prog(), .bl_access_hint()),
         call. = FALSE)
  }
  old <- options(timeout = max(getOption("timeout", 60), timeout))
  on.exit(options(old), add = TRUE)
  hdr <- c(Authorization = paste("Bearer", key),
           "User-Agent" = "rmoriebricklayer/1 (+https://www.rmorie.com)")
  label <- sub("^/", "", path)
  size <- NULL
  if (grepl("\\.csv\\.gz$", path)) {
    label <- sub("\\.csv\\.gz$", "", label)
    m <- tryCatch(bricklayer_data_manifest(), error = function(e) NULL)
    for (d in m$datasets %||% list()) {
      if (identical(d$key, label)) {
        size <- d$bytes_gz
        break
      }
    }
  }
  rc <- tryCatch(
    bricklayer_download(paste0(.bl_data_url(), path), dest, headers = hdr,
                        label = label, size = size, timeout = timeout),
    error = function(e) e, warning = function(w) w
  )
  if (inherits(rc, "condition")) {
    msg <- conditionMessage(rc)
    if (grepl("403|Forbidden", msg) && .bl_data_restricted(label)) {
      stop(sprintf(paste("%s is a restricted table (its source asks more than a citation): read and accept",
                         "the terms at https://data.rmorie.com/terms, signed in with your key, then ask again"),
                   label), call. = FALSE)
    }
    if (grepl("401|403|Unauthorized|Forbidden", msg)) {
      stop("the curated-data service rejected the stored key; ",
           sprintf("run bricklayer_llm_login() again (or `%s login --token` and paste the key).", .bl_prog()),
           call. = FALSE)
    }
    stop("data.rmorie.com: ", msg, call. = FALSE)
  }
  invisible(dest)
}

#' Curated datasets at data.rmorie.com
#'
#' The MORIE project keeps databases materialised from Google BigQuery
#' public datasets (Chicago crime, EPA air quality, US census, FEC, FDA,
#' NOAA, NHTSA, Hacker News, Ethereum, World Bank, ...) and serves their
#' tables from the edge, under the data access terms at
#' \url{https://www.rmorie.com/data-license/}. They open with the key
#' \code{\link{bricklayer_llm_login}} stores, the same key rmorie and morie
#' use; keys are personal: sign in with GitHub or an emailed code, or ask at
#' \url{https://www.rmorie.com/access/}. The service address comes from
#' \code{\link{bricklayer_services}}.
#' \code{bricklayer_data_manifest()} returns the gateway's manifest
#' (every table with rows, columns, size, SHA-256 and its BigQuery source),
#' kept for a day; \code{bricklayer_data_tables()} the same as a data frame;
#' \code{bricklayer_data_load("db/table")} one table as a data frame, cached
#' under \code{tempdir()} (or the directory in
#' \code{options(rmoriebricklayer.data_cache = )}) so later calls are
#' local.
#' From the shell: \code{rmoriebricklayer data list} and
#' \code{rmoriebricklayer data pull db/table [--out FILE.csv]}.
#'
#' @details
#' The manifest is cached as \code{manifest.json} in the cache folder and
#' fetched again when it is more than a day old or \code{refresh = TRUE}. A
#' reply that is not a manifest (not a JSON object with a list of datasets
#' each carrying a \code{key}), or one that lists no tables while the cached
#' copy lists some, is refused and the cached copy kept.
#'
#' \code{bricklayer_data_load()} downloads \code{db/table.csv.gz} once into the
#' cache folder (as \code{db__table.csv.gz}) and checks its SHA-256 against the
#' manifest before every use, cached or not: a file that does not match is
#' deleted and refused (after one refresh of the manifest, since a table
#' rebuilt upstream has a new digest). When the manifest cannot be fetched,
#' the last copy on disk, however old, supplies the digest; with none, a fresh
#' download is not kept and a cached file is kept but not used. The CSV is
#' read in compiled code with the same result as
#' \code{read.csv(gzfile(f), stringsAsFactors = FALSE)}; tables that inflate
#' past 512 MiB are read by \code{read.csv()} itself, a piece at a time. A
#' table that decompresses to more than the option
#' \code{rmoriebricklayer.max_csv_bytes} (1 GiB by default) is refused.
#'
#' The key is sent only to the address of the signed services document. With
#' \code{MORIE_DATA_URL} set to another address the key is not sent and the
#' download fails with a message saying so. Some tables (ICPSR studies, the
#' NCVS 38604 extract, the A2AJ case law) open only after their terms are
#' accepted at \url{https://data.rmorie.com/terms}. Downloads draw a progress
#' bar when \code{options(morie.progress)} allows it.
#'
#' Errors: \code{refresh} not \code{TRUE} or \code{FALSE}; no key stored (the
#' message says how to sign in); the service unavailable, or the key rejected;
#' a \code{key} that is not of the form \code{db/table}, or not listed in the
#' manifest; a digest mismatch; a restricted table whose terms were not
#' accepted.
#'
#' @param refresh Logical scalar, default \code{FALSE}: fetch again even when a
#'   day-old copy (of the manifest, or for \code{bricklayer_data_load()} of the
#'   table) is cached.
#' @param key Character scalar, a \code{db/table} key from the manifest (the
#'   \code{key} column of \code{bricklayer_data_tables()}).
#' @return \code{bricklayer_data_manifest()}: the manifest as a list (element
#'   \code{datasets}, one list per table with at least \code{key}, and as the
#'   service provides them \code{rows}, \code{columns}, sizes, the SHA-256 of
#'   the compressed file and the BigQuery \code{source});
#'   \code{bricklayer_data_tables()}: a data frame with \code{key},
#'   \code{name} (the description, else the source, else the key), integer
#'   \code{rows} and \code{source} (class
#'   \code{bricklayer_data_tables}, which prints one left-aligned line per
#'   table, cut to the console width);
#'   \code{bricklayer_data_load()}: the table as a data frame.
#' @seealso \code{\link{bricklayer_llm_login}}, \code{\link{bricklayer_services}}.
#' @examples
#' # Offline, against a cache folder holding a manifest and one table made
#' # here (no key is stored and nothing is fetched).
#' old_env <- Sys.getenv(c("XDG_CONFIG_HOME", "MORIE_HOSTED_KEY"), unset = NA)
#' Sys.setenv(XDG_CONFIG_HOME = tempfile())
#' Sys.unsetenv("MORIE_HOSTED_KEY")
#' cache <- file.path(tempdir(), "data-hub-example")
#' dir.create(cache)
#' old <- options(rmoriebricklayer.data_cache = cache)
#' f <- file.path(cache, "demo__counts.csv.gz")
#' con <- gzfile(f, "w")
#' write.csv(data.frame(region = c("a", "b"), n = c(3L, 5L)), con, row.names = FALSE)
#' close(con)
#' m <- list(datasets = list(list(key = "demo/counts", rows = 2, source = "an example",
#'                                meta = list(description = "Counts by region"),
#'                                sha256_gz = core_sha256(readBin(f, "raw", file.size(f))))))
#' writeLines(bricklayer_json_to_json(m, auto_unbox = TRUE),
#'            file.path(cache, "manifest.json"))
#'
#' bricklayer_data_tables()
#' bricklayer_data_load("demo/counts")
#'
#' # keys are checked against the manifest
#' try(bricklayer_data_load("counts"))
#' try(bricklayer_data_load("demo/other"))
#'
#' # a cached file that no longer matches its digest is deleted and refused
#' writeBin(as.raw(1:10), f)
#' try(bricklayer_data_load("demo/counts"))
#' file.exists(f)
#'
#' options(old)
#' unlink(cache, recursive = TRUE)
#' for (v in names(old_env)) {
#'   if (is.na(old_env[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old_env[v]))
#' }
#' \dontrun{
#' # the real service: needs a key and the network
#' bricklayer_llm_login(token = "sk-...")  # a key issued at www.rmorie.com/access/
#' head(bricklayer_data_tables())
#' df <- bricklayer_data_load("chicago_crime/incidents")
#' }
#' @export
bricklayer_data_manifest <- function(refresh = FALSE) {
  .bl_check_flag(refresh, "refresh")
  p <- file.path(.bl_data_cache_dir(), "manifest.json")
  age <- if (file.exists(p)) {
    as.numeric(difftime(Sys.time(), file.mtime(p), units = "secs"))
  } else {
    Inf
  }
  fresh <- age < 86400
  if (refresh || !fresh) {
    # fetched beside the cached copy and moved over it only once it is a manifest: a refresh that
    # fails leaves the last good one in place, and the digest check falls back on it. The temporary
    # name is this process's own: one shared `manifest.json.part` let parallel refreshes delete each
    # other's file (11 of 12 workers failed; review of 02a38be, C8).
    dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
    tmp <- tempfile(pattern = "manifest-", tmpdir = dirname(p), fileext = ".part")
    on.exit(unlink(tmp), add = TRUE)
    .bl_data_get("/manifest.json", tmp, timeout = 60)
    m <- .rmbl_json_text(paste(readLines(tmp, warn = FALSE), collapse = "\n"), simplifyVector = FALSE)
    if (!is.list(m) || (length(m) && is.null(names(m)))) {
      stop("the manifest fetched from data.rmorie.com is not a JSON object", call. = FALSE)
    }
    # `{}` or `{"error": ...}` from a gateway is not a manifest: it replaced the good copy, and the
    # digests with it (C9). A manifest is an object whose `datasets` is an array of objects with a key.
    ds <- m$datasets
    if (!is.list(ds) || !is.null(names(ds)) ||
          !all(vapply(ds, function(d) is.list(d) && is.character(d$key) && length(d$key) == 1L, NA))) {
      stop("the reply from data.rmorie.com is not a manifest (no list of datasets): the cached copy is kept",
           call. = FALSE)
    }
    # an empty list does not replace a manifest that lists tables: `{"datasets": []}` took the place
    # of the good copy and, with no digest left, a tampered cached table loaded (review of e57fed5, E10)
    if (!length(ds) && file.exists(p)) {
      old <- tryCatch(.rmbl_json_text(paste(readLines(p, warn = FALSE), collapse = "\n"), simplifyVector = FALSE),
                      error = function(e) NULL)
      if (is.list(old) && is.list(old$datasets) && length(old$datasets)) {
        stop("the manifest from data.rmorie.com lists no tables: the cached copy, which does, is kept",
             call. = FALSE)
      }
    }
    if (!isTRUE(file.rename(tmp, p))) stop(sprintf("could not store the manifest in %s", p), call. = FALSE)
    return(m)
  }
  .rmbl_json_text(paste(readLines(p, warn = FALSE), collapse = "\n"),
                            simplifyVector = FALSE)
}

# the description, else the source, else the key: the first that is set and not blank (the otis
# tables carry "" for both, which printed as an empty name)
.bl_data_name <- function(d) {
  for (v in list(d$meta$description, d$source, d$key)) {
    if (length(v) && nzchar(trimws(v[[1L]]))) return(v[[1L]])
  }
  ""
}

#' @rdname bricklayer_data_manifest
#' @export
bricklayer_data_tables <- function(refresh = FALSE) {
  ds <- bricklayer_data_manifest(refresh = refresh)$datasets
  if (!length(ds)) {
    return(.bl_data_tables_df(character(), character(), integer(), character()))
  }
  keys <- vapply(ds, function(d) d$key, "")
  names <- vapply(ds, .bl_data_name, "")
  rows <- vapply(ds, function(d) as.integer(d$rows %||% NA), 1L)
  sources <- vapply(ds, function(d) (d$source %||% "")[[1L]], "")
  .bl_data_tables_df(keys, names, rows, sources)
}

# The manifest's SHA-256 for a table, when it lists one (the field may be named sha256 or
# sha256_gz, of the compressed file as served). NULL when the manifest lists none; a digest
# field that is not a digest is an error of class bl_bad_digest.
.bl_manifest_digest <- function(ds, key) {
  for (d in ds) {
    if (identical(d$key, key)) {
      for (f in c("sha256_gz", "sha256", "sha")) {
        v <- d[[f]]
        if (is.null(v)) next
        # one digest, not a list whose first element happens to be one
        one <- length(v) == 1L && (is.character(v) || is.na(v))
        v <- if (one) sub("^sha256:", "", as.character(v)) else NA_character_
        if (length(v) == 1L && !is.na(v) && grepl("^[0-9a-fA-F]{64}$", v)) return(tolower(v))
        # a digest field that is not a digest is not "no digest": the file cannot be trusted
        stop(structure(class = c("bl_bad_digest", "error", "condition"),
                       list(message = sprintf("the manifest's %s for %s is not a SHA-256 hex digest (%s)", f, key,
                                              as.character(v)[1L]), call = NULL)))
      }
    }
  }
  NULL
}

# The digest from the manifest as bricklayer_data_manifest() returns it (re-fetched when the
# cached copy is over a day old). A manifest that cannot be had is an error here, never "no
# digest" (review of 52a8883, B1).
.bl_data_manifest_sha <- function(key, refresh = FALSE) {
  .bl_manifest_digest(bricklayer_data_manifest(refresh = refresh)$datasets, key)
}

# The digest from the manifest copy on disk, however old: NA when there is no usable copy or it
# does not list the table, NULL when it lists the table without a digest (as the live manifest
# with no digest is: the table loads), the digest otherwise.
.bl_data_cached_digest <- function(key) {
  p <- file.path(.bl_data_cache_dir(), "manifest.json")
  if (!file.exists(p)) return(NA)
  m <- tryCatch(.rmbl_json_text(paste(readLines(p, warn = FALSE), collapse = "\n"), simplifyVector = FALSE),
                error = function(e) NULL)
  ds <- if (is.list(m)) m$datasets else NULL
  if (!is.list(ds) || !is.null(names(ds))) return(NA)
  listed <- any(vapply(ds, function(d) is.list(d) && identical(d$key, key), NA))
  if (!listed) return(NA)
  .bl_manifest_digest(ds, key)
}

# A cached or freshly downloaded file that does not match the manifest's SHA-256 is deleted and
# refused: a tampered cache, a truncated download or a table rebuilt upstream all look the same.
# When the manifest cannot be fetched, the last copy on disk (however old) still holds the digest
# the table had and is used; with no copy at all the file cannot be verified and is not kept. A
# mismatch triggers one refresh of the manifest (a table rebuilt upstream has a new digest), and
# a refresh that fails changes nothing.
# Only a file that fails a known digest is deleted. One that cannot be checked now (no manifest
# from the service and no copy that lists the table) is refused but, when it was already in the
# cache, kept: it is checked again before every use, and deleting it threw away a genuine table
# whenever the service was unreachable (review of 02a38be, C9). A file just downloaded and not
# verifiable is not kept.
.bl_data_check_sha <- function(key, dest, cached = FALSE) {
  refuse <- function(msg, delete = TRUE) {
    if (delete) unlink(dest)
    stop(msg, call. = FALSE)
  }
  want <- tryCatch(.bl_data_manifest_sha(key), error = function(e) e)
  if (inherits(want, "bl_bad_digest")) refuse(conditionMessage(want))
  if (inherits(want, "error")) {
    want <- tryCatch(.bl_data_cached_digest(key), error = function(e) e)
    if (inherits(want, "error")) refuse(conditionMessage(want))
    if (identical(want, NA)) {
      refuse(sprintf(paste("%s cannot be verified: the manifest could not be fetched from data.rmorie.com",
                           "(offline or an error) and no earlier copy lists the table; %s run again when",
                           "the service answers"), key,
                     if (cached) "the cached file is kept unused until then;" else "the download was not kept;"),
             delete = !cached)
    }
  }
  # no digest: loaded only when the manifest lists the table (without a digest, as some tables are);
  # a manifest that does not list it at all says nothing about the file, which is refused
  if (is.null(want)) {
    listed <- tryCatch(any(vapply(bricklayer_data_manifest()$datasets,
                                  function(d) is.list(d) && identical(d$key, key), NA)),
                       error = function(e) !identical(.bl_data_cached_digest(key), NA))
    if (!isTRUE(listed)) {
      refuse(sprintf("%s is not listed in the manifest of data.rmorie.com, so the file cannot be verified", key),
             delete = !cached)
    }
    return(invisible(TRUE))
  }
  have <- tolower(core_sha256(readBin(dest, "raw", file.size(dest))))
  if (!identical(have, want)) {
    # a table rebuilt upstream has a new digest in a new manifest: fetch the manifest again
    # before calling the file bad, so a stale cached manifest does not refuse every call
    fresh <- tryCatch(.bl_data_manifest_sha(key, refresh = TRUE), error = function(e) NULL)
    if (is.character(fresh) && length(fresh) == 1L && !is.na(fresh)) want <- fresh
    if (!identical(have, want)) {
      refuse(sprintf(paste("%s does not match the manifest's SHA-256 (%s... vs %s...): the cached file was deleted;",
                           "run again to download it, and if it still fails the file was tampered with in transit"),
                     key, substr(have, 1L, 12L), substr(want, 1L, 12L)))
    }
  }
  invisible(TRUE)
}

.bl_data_tables_df <- function(key, name, rows, source) {
  df <- data.frame(key = key, name = name, rows = rows, source = source,
                   stringsAsFactors = FALSE)
  class(df) <- c("bricklayer_data_tables", "data.frame")
  df
}

# One line per table, key and row count first and the name after, all left-aligned and cut to
# the width (print.data.frame right-aligned the names and, once a line was wider than the
# console, put each column in a block of its own). Shared by print() and `rmbl data list`.
.bl_format_data_tables <- function(tables, width = NULL,
                                   hint = "bricklayer_data_load(\"KEY\") loads one") {
  if (!nrow(tables)) {
    return("no curated tables are listed at data.rmorie.com right now\n")
  }
  if (is.null(width)) {
    width <- suppressWarnings(as.integer(Sys.getenv("COLUMNS", "")))
    if (is.na(width) || width < 40L) width <- max(80L, as.integer(getOption("width", 80L)))
  }
  rows <- ifelse(is.na(tables$rows), "-", formatC(tables$rows, format = "d", big.mark = ","))
  # the manifest is fetched text: what would not print as itself is removed (.rmbl_printable)
  printable <- .rmbl_printable
  tables$key <- printable(tables$key)
  name <- gsub("[[:space:]]+", " ", trimws(printable(tables$name)))
  name[!nzchar(name) | name == tables$key] <- "-"
  kw <- max(nchar("key"), nchar(tables$key))
  rw <- max(nchar("rows"), nchar(rows))
  room <- max(20L, width - kw - rw - 4L)
  cut <- nchar(name) > room
  name[cut] <- paste0(trimws(substr(name[cut], 1L, room - 3L)), "...")
  line <- function(k, r, n) {
    sprintf("%s  %s  %s", formatC(k, width = -kw), formatC(r, width = rw), n)
  }
  paste0(
    line("key", "rows", "name"), "\n",
    paste(line(tables$key, rows, name), collapse = "\n"), "\n\n",
    sprintf("%d tables; %s\n", nrow(tables), hint)
  )
}

#' @export
print.bricklayer_data_tables <- function(x, ...) {
  if (!all(c("key", "name", "rows") %in% names(x))) {
    return(NextMethod())
  }
  cat(.bl_format_data_tables(x))
  invisible(x)
}

#' @rdname bricklayer_data_manifest
#' @export
bricklayer_data_load <- function(key, refresh = FALSE) {
  ok <- is.character(key) && length(key) == 1L &&
    grepl("/", key, fixed = TRUE) &&
    !startsWith(key, "/") && !endsWith(key, "/")
  if (!ok) {
    stop("key must be db/table (see bricklayer_data_tables())", call. = FALSE)
  }
  .bl_check_flag(refresh, "refresh")
  known <- tryCatch(vapply(bricklayer_data_manifest()$datasets, function(d) d$key, ""), error = function(e) NULL)
  # an empty list is an answer too: no table is listed, so none is loaded
  if (!is.null(known) && !key %in% known) {
    stop(sprintf("no table %s at data.rmorie.com (`%s data list` shows them)", key, .bl_prog()), call. = FALSE)
  }
  parts <- strsplit(key, "/", fixed = TRUE)[[1L]]
  dest <- file.path(.bl_data_cache_dir(),
                    paste0(gsub("/", "__", key, fixed = TRUE), ".csv.gz"))
  cached <- !refresh && file.exists(dest)
  if (!cached) {
    rest <- paste(parts[-1L], collapse = "/")
    .bl_data_get(sprintf("/%s/%s.csv.gz", parts[[1L]], rest), dest)
  }
  .bl_data_check_sha(key, dest, cached = cached)
  .bl_read_csv_gz(dest)
}

# A gzip-compressed CSV as utils::read.csv(gzfile(f), stringsAsFactors = FALSE, skipNul = TRUE)
# reads it (the same columns, types, names and row names), in a fraction of the time: the file is
# decompressed by the checked reader, split into columns in C (rmbl_csv.c) and typed by
# type.convert(), which is what read.csv() does after scan(). read.csv() took 20 to 28 s on a 75 MB
# table (review of 29a55d8 and after, CSV speed).
# The fast way holds the whole decompressed table in memory, so it is taken up to `in_memory` bytes
# (the gzip reader measures the output before it allocates any of it). Past that the table is read
# as read.csv(gzfile()) reads it, a piece at a time: a 2.6 MB file that inflated to 2.5 GiB of blank
# lines got the process killed for memory (network stress test of 5e1dce5). A file that is not gzip
# data at all, though its name ends in .gz, is read as the plain CSV it is, as gzfile() did.
# Either way the table may decompress to at most the option rmoriebricklayer.max_csv_bytes (1 GiB by
# default), as the pollution readers' tables may: it was not applied here, and a 612 KB gzip asked
# for 2 GB (CRAN stress test of b617a3f, #6).
.bl_read_csv_gz <- function(path, in_memory = 512 * 2^20) {
  lim <- .rmbl_max_csv_bytes()
  too_big <- function() {
    stop(sprintf(paste("%s decompresses to more than %s bytes (option rmoriebricklayer.max_csv_bytes);",
                       "raise the option to read it"),
                 basename(path), format(lim, big.mark = ",", scientific = FALSE)), call. = FALSE)
  }
  in_memory <- min(in_memory, lim)
  head <- readBin(path, "raw", 2L)
  if (length(head) < 2L || head[[1L]] != as.raw(0x1f) || head[[2L]] != as.raw(0x8b)) {
    if (file.size(path) > lim) too_big()
    if (file.size(path) > in_memory) return(.bl_read_csv_streamed(path))
    return(.bl_csv_from_bytes(readBin(path, "raw", file.size(path))))
  }
  bytes <- tryCatch(.Call(C_rmbl_gunzip_checked, readBin(path, "raw", file.size(path)), in_memory),
                    error = function(e) {
                      if (grepl("more than the size limit", conditionMessage(e), fixed = TRUE)) NULL else stop(e)
                    })
  if (!is.null(bytes)) return(.bl_csv_from_bytes(bytes))
  if (in_memory >= lim) too_big()
  # past what is held in memory: the decompressed size is counted a piece at a time, holding 4 MiB,
  # before read.csv() reads it
  con <- gzfile(path, "rb")
  total <- 0
  tryCatch(repeat {
    b <- readBin(con, "raw", 4194304L)
    if (!length(b)) break
    total <- total + length(b)
    if (total > lim) too_big()
  }, finally = close(con))
  .bl_read_csv_streamed(path)
}

# The large-table path: read.csv() itself, on a gzfile() connection (it reads plain files too).
.bl_read_csv_streamed <- function(path) {
  con <- gzfile(path, "rt")
  on.exit(close(con), add = TRUE)
  utils::read.csv(con, stringsAsFactors = FALSE, skipNul = TRUE)
}

.bl_csv_from_bytes <- function(bytes, skip_nul = TRUE) {
  parts <- .Call(C_rmbl_csv_split, bytes, skip_nul)
  # the bytes decided the plain integer, decimal and logical columns; the rest is text for R to judge
  cols <- lapply(parts$columns, function(v) {
    if (is.character(v)) utils::type.convert(v, as.is = TRUE, na.strings = character()) else v
  })
  # no columns (a header of "" alone): the rows read.csv() counts below it, from the reader
  n <- if (length(cols)) length(cols[[1L]]) else as.integer(attr(parts, "nrow") %||% 0)
  names(cols) <- make.names(parts$names, unique = TRUE)
  # with no columns read.csv() names the rows "1", "2", ...
  structure(cols, class = "data.frame", row.names = if (length(cols)) c(NA_integer_, -n) else as.character(seq_len(n)))
}
