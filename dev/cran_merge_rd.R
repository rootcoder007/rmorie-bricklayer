# Merges the help pages of the CRAN copy by the R file roxygen made them from (run by
# dev/cran_build.sh inside the copy it builds from): 348 pages become 114. R CMD check
# runs each page's examples in its own setup and builds every page into the PDF and HTML
# manuals, so fewer pages keep those steps short on CRAN's Windows check. Every topic
# (alias), argument, value, section and example is kept: a merged page's first function
# names it, the others' descriptions and details become sections, and an argument two
# pages share is listed once. Data and package pages stay as they are. The repository,
# r-universe and the package website keep one page per function.
#   Rscript dev/cran_merge_rd.R <man directory>
args <- commandArgs(TRUE); man <- args[1]
fs <- list.files(man, "[.]Rd$", full.names = TRUE)
src <- vapply(fs, function(f) {
  l <- grep("edit documentation in", readLines(f, 3), value = TRUE)
  if (length(l)) sub(".*in ", "", l[1]) else f
}, "")
# split an Rd file into top-level sections: list of (tag, args = list of brace bodies)
secs <- function(f) {
  s <- paste(readLines(f), collapse = "\n"); ch <- strsplit(s, "")[[1]]; n <- length(ch)
  out <- list(); i <- 1
  grab <- function(i) { # ch[i] == "{"; return end index of matching brace
    d <- 0; j <- i
    while (j <= n) { c <- ch[j]
      if (c == "\\") { j <- j + 2; next }
      if (c == "%") { while (j <= n && ch[j] != "\n") j <- j + 1; next }
      if (c == "{") d <- d + 1 else if (c == "}") { d <- d - 1; if (d == 0) return(j) }
      j <- j + 1 }
    stop("unbalanced ", f) }
  while (i <= n) {
    c <- ch[i]
    if (c == "%") { while (i <= n && ch[i] != "\n") i <- i + 1; next }
    if (c == "\\") { j <- i + 1; while (j <= n && grepl("[a-zA-Z]", ch[j])) j <- j + 1
      tag <- paste(ch[(i + 1):(j - 1)], collapse = ""); a <- character()
      while (j <= n && ch[j] == "{") { e <- grab(j); a <- c(a, paste(ch[(j + 1):(e - 1)], collapse = "")[e > j + 1] %||% ""); if (e == j + 1) a[length(a)] <- ""; j <- e + 1 }
      out[[length(out) + 1]] <- list(tag = tag, a = a); i <- j; next }
    i <- i + 1 }
  out }
`%||%` <- function(x, y) if (length(x)) x else y
get <- function(S, tag) Filter(function(x) x$tag == tag, S)
items <- function(body) { # \item{name}{desc} entries in an \arguments body
  S <- secs2(body); Filter(function(x) x$tag == "item", S) }
secs2 <- function(txt) { f <- tempfile(); writeLines(txt, f); secs(f) }
nm <- 0
for (g in split(fs, src)) {
  if (length(g) < 2) next
  S <- lapply(g, secs)
  keep <- vapply(S, function(x) !length(get(x, "docType")), TRUE)
  g <- g[keep]; S <- S[keep]; if (length(g) < 2) next
  ttl <- vapply(S, function(x) get(x, "title")[[1]]$a[1], "")
  o <- sprintf("\\name{%s}", get(S[[1]], "name")[[1]]$a[1])
  for (x in S) for (a in get(x, "alias")) o <- c(o, sprintf("\\alias{%s}", a$a[1]))
  o <- c(o, sprintf("\\title{%s}", ttl[1]))
  u <- unlist(lapply(S, function(x) vapply(get(x, "usage"), function(s) s$a[1], "")))
  if (length(u)) o <- c(o, "\\usage{", u, "}")
  seen <- character(); it <- character()
  for (x in S) for (a in get(x, "arguments")) for (k in items(a$a[1])) {
    ks <- trimws(strsplit(k$a[1], ",")[[1]]); nw <- ks[!ks %in% seen]
    if (length(nw)) { seen <- c(seen, nw); it <- c(it, sprintf("\\item{%s}{%s}", paste(nw, collapse = ", "), k$a[2])) } }
  if (length(it)) o <- c(o, "\\arguments{", it, "}")
  d1 <- get(S[[1]], "description"); o <- c(o, sprintf("\\description{%s}", if (length(d1)) d1[[1]]$a[1] else ttl[1]))
  v <- unlist(lapply(seq_along(S), function(i) vapply(get(S[[i]], "value"), function(s) sprintf("\\subsection{%s}{%s}", ttl[i], s$a[1]), "")))
  if (length(v)) o <- c(o, "\\value{", v, "}")
  for (i in seq_along(S)) { x <- S[[i]]
    p <- c(if (i > 1) vapply(get(x, "description"), function(s) s$a[1], ""), vapply(get(x, "details"), function(s) s$a[1], ""))
    for (s in get(x, "section")) p <- c(p, sprintf("\\subsection{%s}{%s}", s$a[1], s$a[2]))
    if (length(p)) o <- c(o, sprintf("\\section{%s}{", ttl[i]), p, "}") }
  for (tag in c("references", "seealso")) { b <- unique(unlist(lapply(S, function(x) vapply(get(x, tag), function(s) s$a[1], ""))))
    if (length(b)) o <- c(o, sprintf("\\%s{", tag), b, "}") }
  ex <- unlist(lapply(S, function(x) vapply(get(x, "examples"), function(s) s$a[1], "")))
  if (length(ex)) o <- c(o, "\\examples{", ex, "}")
  o <- c(o, unique(unlist(lapply(S, function(x) vapply(get(x, "keyword"), function(s) sprintf("\\keyword{%s}", s$a[1]), "")))))
  file.remove(g); writeLines(o, g[1]); nm <- nm + length(g) - 1 }
cat("removed", nm, "pages; now", length(list.files(man, "[.]Rd$")), "\n")
# a page that does not parse stops the build
for (f in list.files(man, "[.]Rd$", full.names = TRUE)) tools::parse_Rd(f)
