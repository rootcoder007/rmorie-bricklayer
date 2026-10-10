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

.bl_data_cache_dir <- function() {
  d <- getOption("rmoriebricklayer.data_cache", NULL)
  if (is.null(d) || !nzchar(d)) {
    d <- file.path(tempdir(), "rmoriebricklayer-data")
  }
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

.bl_data_get <- function(path, dest, timeout = 600) {
  key <- .bl_hosted_key()
  if (is.null(key)) {
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
           sprintf("run bricklayer_llm_login() again (or `%s login --token KEY`).", .bl_prog()), call. = FALSE)
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
  if (refresh || !fresh) .bl_data_get("/manifest.json", p, timeout = 60)
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
  name <- gsub("[[:space:]]+", " ", trimws(tables$name))
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
  if (refresh || !file.exists(dest)) {
    rest <- paste(parts[-1L], collapse = "/")
    .bl_data_get(sprintf("/%s/%s.csv.gz", parts[[1L]], rest), dest)
  }
  utils::read.csv(gzfile(dest), stringsAsFactors = FALSE, skipNul = TRUE)  # some sources carry NUL bytes
}
