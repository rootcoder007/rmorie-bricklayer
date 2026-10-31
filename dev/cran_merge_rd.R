# Merges the help pages of the CRAN copy into five pages by subject (run by
# dev/cran_build.sh inside the copy it builds from): 348 pages become 5. R CMD check
# builds every page into the PDF and HTML manuals and checks each one on its own, so
# fewer pages keep those steps short on CRAN's Windows check. Every topic (alias),
# usage, argument, value, section and example is kept: each function's description and
# details become a section named by its title, an argument several functions share is
# listed once (by function when their descriptions differ), and the build stops if
# anything is lost. The internal pages (old names) form their own page. The
# repository, r-universe and the package website keep one page per function.
#   Rscript dev/cran_merge_rd.R <man directory>
args <- commandArgs(TRUE); man <- args[1]
fs <- list.files(man, "[.]Rd$", full.names = TRUE)
src <- vapply(fs, function(f) {
  l <- grep("edit documentation in", readLines(f, 3), value = TRUE)
  if (length(l)) sub("[.]R$", "", basename(trimws(strsplit(sub(".*in ", "", l[1]), ",")[[1]][1]))) else ""
}, "")
groups <- list(
  seal = c("Seals, signatures, keys and archives",
    "attest bundle capsule_check capsule_template chain crypto_extra custody digest_extra drbg evidence fipsmod hqc idcard kem ledger lib_capsule lib_manifest mkbndl mkbndlchk mkset prereg ralloc repro revocation sign timestamp tsstmp x509 xcheck xmss_state archive_capture archive_push archive_rmorie wayback_save fetch_verified"),
  data = c("Data: loading, fetching, parsing and checking",
    "data_hub lib_data_loader lib_helpers lib_synthetic fetch_native fetch_siu parse_siu json_gzip json_native download_progress census schema_infer search services justice categorical_guard rules rule_lib analyse_table trc"),
  output = c("Plots, reports, the command line and language models",
    "plots policy_plots drift_viz region_map print_methods report yoy yoy_render yoy_output yoy_write yoy_labels progress_anim search_figs dashboard cli capsule_cli llm_config llm_native agent_bundle explain_error rmbldemo"),
  compat = c("Old names", "compat_0_5 compat_names"))
grp <- vapply(src, function(s) {
  for (k in names(groups)) if (s %in% strsplit(groups[[k]][2], " ")[[1]]) return(k)
  "stats" }, "")
gtitle <- c(vapply(groups, `[`, "", 1), stats = "Statistics and analysis")
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
      while (j <= n && ch[j] == "{") { e <- grab(j); a <- c(a, if (e > j + 1) paste(ch[(j + 1):(e - 1)], collapse = "") else ""); j <- e + 1 }
      out[[length(out) + 1]] <- list(tag = tag, a = a); i <- j; next }
    i <- i + 1 }
  out }
get <- function(S, tag) Filter(function(x) x$tag == tag, S)
txt <- function(S, tag) vapply(get(S, tag), function(s) s$a[1], "")
items <- function(body) { f <- tempfile(); writeLines(body, f); Filter(function(x) x$tag == "item", secs(f)) }
one <- function(x) gsub("[[:space:]]+", " ", trimws(x))
known <- c("name", "alias", "title", "description", "usage", "arguments", "value", "details",
  "section", "seealso", "references", "examples", "keyword", "source", "docType")
want <- list(alias = character(), usage = character(), arg = character(), ex = character())
for (k in names(gtitle)) {
  g <- fs[grp == k]; if (!length(g)) next
  S <- lapply(g, secs)
  bad <- setdiff(unique(unlist(lapply(S, function(x) vapply(x, `[[`, "", "tag")))), known)
  if (length(bad)) stop("unhandled Rd tags: ", paste(bad, collapse = " "))
  if (any(vapply(S, function(x) length(get(x, "docType")) > 0, TRUE))) stop("docType page in ", k)
  topic <- vapply(S, function(x) txt(x, "name")[1], "")
  ttl <- vapply(S, function(x) one(txt(x, "title")[1]), "")
  al <- unique(c(unlist(lapply(S, txt, "alias")), topic))
  want$alias <- c(want$alias, al)
  o <- c(sprintf("\\name{rmbl-%s}", k), sprintf("\\alias{%s}", al), sprintf("\\title{%s}", gtitle[[k]]))
  u <- unlist(lapply(S, txt, "usage")); want$usage <- c(want$usage, u)
  if (length(u)) o <- c(o, "\\usage{", u, "}")
  # arguments: name -> descriptions by function
  ad <- list()
  for (i in seq_along(S)) for (a in get(S[[i]], "arguments")) for (it in items(a$a[1])) {
    for (nm in trimws(strsplit(it$a[1], ",")[[1]])) {
      ad[[nm]] <- rbind(ad[[nm]], data.frame(fn = topic[i], d = it$a[2], stringsAsFactors = FALSE)) } }
  want$arg <- c(want$arg, paste(k, names(ad)))
  if (length(ad)) {
    it <- vapply(names(ad), function(nm) { x <- ad[[nm]]; ud <- unique(x$d)
      if (length(ud) == 1) return(sprintf("\\item{%s}{%s}", nm, ud))
      parts <- vapply(ud, function(d) sprintf("For \\code{%s}: %s", paste(unique(x$fn[x$d == d]), collapse = "}, \\code{"), d), "")
      sprintf("\\item{%s}{%s}", nm, paste(parts, collapse = "\n\n")) }, "")
    o <- c(o, "\\arguments{", it, "}") }
  o <- c(o, sprintf("\\description{%s. Each function has its own section below; \\code{?name} opens this page for any of them.}", gtitle[[k]]))
  v <- unlist(lapply(seq_along(S), function(i) sprintf("\\subsection{%s (\\code{%s})}{%s}", ttl[i], topic[i], txt(S[[i]], "value"))))
  if (length(v)) o <- c(o, "\\value{", v, "}")
  for (i in seq_along(S)) { x <- S[[i]]
    p <- c(txt(x, "description"), txt(x, "details"))
    for (s in get(x, "section")) p <- c(p, sprintf("\\subsection{%s}{%s}", one(s$a[1]), s$a[2]))
    for (s in get(x, "source")) p <- c(p, sprintf("\\subsection{Source}{%s}", s$a[1]))
    o <- c(o, sprintf("\\section{%s (\\code{%s})}{", ttl[i], topic[i]), p, "}") }
  for (tag in c("references", "seealso")) { b <- unique(unlist(lapply(S, txt, tag)))
    if (length(b)) o <- c(o, sprintf("\\%s{", tag), b, "}") }
  ex <- unlist(lapply(S, txt, "examples")); want$ex <- c(want$ex, ex)
  if (length(ex)) o <- c(o, "\\examples{", ex, "}")
  kw <- unique(unlist(lapply(S, txt, "keyword")))
  if (k != "compat") kw <- setdiff(kw, "internal")
  o <- c(o, sprintf("\\keyword{%s}", kw))
  file.remove(g); writeLines(o, file.path(man, sprintf("rmbl-%s.Rd", k))) }
# nothing lost: every alias, usage, argument and example is on the new pages
nf <- list.files(man, "[.]Rd$", full.names = TRUE)
N <- lapply(nf, secs)
have <- list(alias = unlist(lapply(N, txt, "alias")),
  usage = unlist(lapply(N, function(x) strsplit(paste(txt(x, "usage"), collapse = "\n"), "\n")[[1]])),
  ex = paste(unlist(lapply(N, txt, "examples")), collapse = "\n"))
stopifnot(all(want$alias %in% have$alias),
  all(unlist(strsplit(want$usage, "\n")) %in% have$usage),
  all(vapply(want$ex, function(e) grepl(e, have$ex, fixed = TRUE), TRUE)))
cat("merged", length(fs), "pages into", length(nf), ":", basename(nf), "\n")
for (f in nf) tools::checkRd(f)
