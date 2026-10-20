# Generate R/compat_names.R: every 0.5.13 export that 1.0.0 renamed becomes a wrapper with the
# OLD formals that forwards to the new function with the NEW argument names.
# Run inside a clone: Rscript gen_aliases.R  (writes R/compat_names.R, dev/compat_names_map.tsv)
old_ref <- "v0.5.13"; ren_commit <- "fa7da780"
git <- function(...) system2("git", c(...), stdout = TRUE)

# 1. old exports absent today (minus the 11 wrappers already in R/compat_0_5.R)
old_ns <- git("show", paste0(old_ref, ":NAMESPACE"))
new_ns <- git("show", "HEAD:NAMESPACE")  # the committed exports, never this file's own
ex <- function(x) sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", x, value = TRUE))
old_exports <- ex(old_ns); new_exports <- ex(new_ns)
gone <- setdiff(old_exports, new_exports)
already <- c("capsule_sign", "capsule_verify", "pqc_keygen", "signing_public_key", "core_sha256",
             "core_mean", "sha256_file", "bricklayer_json_to_json", "bricklayer_json_from_json",
             "bricklayer_fetch", "wayback_snapshot_url")
gone <- setdiff(gone, already)
cat("old exports gone:", length(gone), "\n")

# 2. function definitions: name -> (file, formals) at a ref (parse every R file)
defs_at <- function(ref) {
  files <- git("ls-tree", "-r", "--name-only", ref, "--", "R")
  files <- files[grepl("\\.R$", files)]
  out <- list()
  for (f in files) {
    txt <- git("show", paste0(ref, ":", f))
    ex <- tryCatch(parse(text = txt, keep.source = FALSE), error = function(e) NULL)
    if (is.null(ex)) next
    for (e in ex) {
      if (is.call(e) && (identical(e[[1]], as.name("<-")) || identical(e[[1]], as.name("="))) &&
          is.name(e[[2]]) && is.call(e[[3]]) && identical(e[[3]][[1]], as.name("function"))) {
        out[[as.character(e[[2]])]] <- list(file = f, formals = e[[3]][[2]])
      }
    }
  }
  out
}
old_defs <- defs_at(old_ref); new_defs <- defs_at("HEAD")
cat("defs old", length(old_defs), "new", length(new_defs), "\n")

# 3. name pairing through the Rd renames of the rename commit: old alias i -> new alias i
rd_ren <- git("diff-tree", "-M", "-r", "--name-status", paste0(ren_commit, "^"), ren_commit, "--", "man")
rd_ren <- strsplit(grep("^R", rd_ren, value = TRUE), "\t")
aliases <- function(ref, path) {
  l <- tryCatch(git("show", paste0(ref, ":", path)), error = function(e) character())
  sub("^\\\\alias\\{(.*)\\}$", "\\1", grep("^\\\\alias\\{", l, value = TRUE))
}
# a page renamed again later: follow the new path to today's name
current_path <- function(p) {
  if (file.exists(p)) return(p)
  h <- git("log", "--follow", "--format=", "--name-only", "--", p)
  h <- h[nzchar(h)]
  for (q in h) if (file.exists(q)) return(q)
  NA_character_
}
pair <- character()
for (r in rd_ren) {
  a_old <- aliases(paste0(ren_commit, "^"), r[2])
  cp <- current_path(r[3])
  if (is.na(cp)) next
  a_new <- sub("^\\\\alias\\{(.*)\\}$", "\\1", grep("^\\\\alias\\{", readLines(cp), value = TRUE))
  if (length(a_old) == length(a_new)) pair[a_old] <- a_new
  else for (i in seq_along(a_old)) {
    # unequal alias counts: match by order among function aliases only
    if (i <= length(a_new)) pair[a_old[i]] <- a_new[i]
  }
}
# 4. resolve every gone export (pages merged or renamed twice: paired by hand)
override <- c(capsule_attest = "cpsatst", capsule_bundle_verify = "cpsbndlvrf",
  capsule_check_attestation = "cpschkatst", crc32_file = "crc32file", gini = "ginicoef",
  lorenz = "lorenzc", pollution_burden = "polbrdn", rule_between = "rulebtw",
  rule_col_count = "rulecolcnt", rule_complete_rows = "rulecmpl", rule_distinct_rows = "ruledstn",
  rule_in_set = "ruleinset", rule_increasing = "ruleincr", rule_not_null = "rulenull",
  rule_regex = "rulerx", rule_unique = "ruleuniq", rule_within_n_mads = "rulemad",
  sha512_file = "sha512file", top_share = "topshr", bricklayer_llm_login = "dlogin")
rows <- list(); unmatched <- character()
for (o in gone) {
  n <- if (o %in% names(override)) unname(override[o]) else unname(pair[o])
  if (is.na(n) || !(n %in% new_exports) || is.null(new_defs[[n]]) || is.null(old_defs[[o]])) {
    unmatched <- c(unmatched, o); next
  }
  fo <- old_defs[[o]]$formals; fn <- new_defs[[n]]$formals
  no <- names(fo); nn <- names(fn)
  if (length(no) < length(nn) && !("..." %in% no)) {
    # the new function grew arguments (all with defaults): the old ones map by position
    nn <- nn[seq_along(no)]
  } else if (length(no) != length(nn)) { unmatched <- c(unmatched, paste0(o, " (", length(no), " vs ", length(nn), " formals)")); next }
  rows[[o]] <- list(old = o, new = n, old_formals = fo, old_names = no, new_names = nn)
}
cat("paired:", length(rows), " unmatched:", length(unmatched), "\n")
if (length(unmatched)) cat(unmatched, sep = "\n")

# 5. write the wrappers
dep <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")
fmt_formals <- function(fo) {
  parts <- vapply(seq_along(fo), function(i) {
    if (is.symbol(fo[[i]]) && !nzchar(as.character(fo[[i]]))) names(fo)[i] else paste0(names(fo)[i], " = ", dep(fo[[i]]))
  }, character(1))
  parts
}
wrap_lines <- function(parts, head, indent, tail = "") {
  # join "a, b, c" into source lines of at most 90 characters; `tail` closes the last line
  if (!length(parts)) return(paste0(head, tail))
  lines <- character(); cur <- head
  for (i in seq_along(parts)) {
    piece <- paste0(parts[i], if (i < length(parts)) "," else tail)
    sep <- if (endsWith(cur, "(")) "" else " "
    if (nchar(cur) + nchar(sep) + nchar(piece) > 90 && !endsWith(cur, "(")) {
      lines <- c(lines, cur); cur <- paste0(indent, piece)
    } else cur <- paste0(cur, sep, piece)
  }
  c(lines, cur)
}
out <- c(
  "# Generated by dev/gen_aliases.R from the 0.5.13 exports: do not edit by hand.",
  "",
  "#' The 0.5.x names, kept as aliases",
  "#'",
  "#' Every function rmoriebricklayer 0.5.13 exported that 1.0.0 renamed is still callable",
  "#' by its old name, with its old argument names: each alias forwards to the new",
  "#' function. The reference documentation lives on the new name; this page only lists",
  "#' the aliases.",
  "#'",
  "#' @section The map:",
  "#' Old name, then the new one.",
  "#' \\preformatted{")
map_lines <- vapply(rows, function(r) sprintf("#' %-42s %s", r$old, r$new), character(1))
out <- c(out, unname(map_lines), "#' }", "#' @keywords internal", "#' @name rmbl-aliases", "NULL", "")
for (r in rows) {
  args <- character()
  for (i in seq_along(r$old_names)) {
    if (r$old_names[i] == "...") args <- c(args, "...")
    else args <- c(args, paste0(r$new_names[i], " = ", r$old_names[i]))
  }
  sig <- wrap_lines(fmt_formals(r$old_formals), paste0(r$old, " <- function("),
                    strrep(" ", nchar(r$old) + 14L), ") {")
  body <- wrap_lines(args, paste0("  ", r$new, "("), strrep(" ", nchar(r$new) + 3L), ")")
  out <- c(out, "#' @rdname rmbl-aliases", "#' @usage NULL", "#' @export", sig, body, "}", "")
}
writeLines(out[-length(out)], "R/compat_names.R")
map <- do.call(rbind, lapply(rows, function(r) data.frame(old = r$old, new = r$new,
  old_args = paste(r$old_names, collapse = ","), new_args = paste(r$new_names, collapse = ","))))
dir.create("dev", showWarnings = FALSE)
write.table(map, "dev/compat_names_map.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
cat("wrote R/compat_names.R with", length(rows), "aliases\n")
