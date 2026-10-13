# Curated datasets at data.rmorie.com (the address comes from the signed
# services document), opened by the MORIE key this package stores with
# bricklayer_llm_login(); keys are issued on request at www.rmorie.com/access/.
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
#' use; keys are personal and issued on request at
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
#' @param refresh Fetch again even when a day-old copy is cached.
#' @param key A \code{db/table} key from the manifest.
#' @return \code{bricklayer_data_manifest()}: a list;
#'   \code{bricklayer_data_tables()}: a data frame with \code{key},
#'   \code{name}, \code{rows} and \code{source} (class
#'   \code{bricklayer_data_tables}, which prints one left-aligned line per
#'   table, cut to the console width);
#'   \code{bricklayer_data_load()}: the table as a data frame.
#' @examples
#' \dontrun{
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
  if (is.null(want)) return(invisible(TRUE))
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
  # the manifest is fetched text: control characters (an ANSI escape, a carriage return)
  # must not reach the terminal
  printable <- function(x) {
    # Text first marked as the UTF-8 it is (the manifest is UTF-8, but in a C locale the parser
    # returns it unmarked) or converted, an invalid byte becoming "?": [[:cntrl:]] on unmarked
    # text in a C locale matched the bytes 0x80-0x9F inside every multi-byte character and cut
    # names into fragments (the C-locale CI leg, 02a38be review). Every removal below then works
    # on whole characters.
    x <- as.character(x)
    u <- !is.na(x) & Encoding(x) == "unknown" & validUTF8(x)
    v <- x[u]
    Encoding(v) <- "UTF-8"
    x[u] <- v
    o <- !is.na(x) & !u & Encoding(x) != "UTF-8"
    x[o] <- iconv(x[o], "", "UTF-8", sub = "?")
    # ANSI escape sequences, then the C0 and C1 controls and DEL, the bidirectional and
    # zero-width format characters (U+200B-U+200F, U+202A-U+202E, U+2066-U+2069), and the rest of
    # Unicode's default-ignorable code points, which print as nothing and hide text in a table
    # name (U+00AD, U+034F, U+115F, U+3164, U+180E, U+FEFF, U+FFF9-FFFB, the tag characters
    # U+E0000-E007F; review of 02a38be)
    x <- gsub("(*UTF)\033\\[[0-9;?]*[ -/]*[@-~]", "", x, perl = TRUE)
    gsub(paste0("(*UTF)[\\x{00}-\\x{1f}\\x{7f}-\\x{9f}\\x{00ad}\\x{034f}\\x{061c}\\x{115f}\\x{1160}",
                "\\x{17b4}\\x{17b5}\\x{180b}-\\x{180f}\\x{200b}-\\x{200f}\\x{2028}-\\x{202e}",
                "\\x{2060}-\\x{206f}\\x{3164}\\x{fe00}-\\x{fe0f}\\x{feff}\\x{ffa0}\\x{fff0}-\\x{fffb}",
                "\\x{e0000}-\\x{e0fff}]"), "", x, perl = TRUE)
  }
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
  if (length(known) && !key %in% known) {
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
  utils::read.csv(gzfile(dest), stringsAsFactors = FALSE, skipNul = TRUE)  # some sources carry NUL bytes
}
