# Generate the map of 0.5.x names: every 0.5.13 export that 1.0.0 renamed, with the
# old and new argument names and renamed values, which the rmbl command line uses (R/cli_compat.R).
# Run inside a clone: Rscript dev/gen_aliases.R
# (writes R/compat_names.R and inst/compat/compat_names_map.tsv)
old_ref <- "v0.5.13"; ren_commit <- "fa7da780"
git <- function(...) system2("git", c(...), stdout = TRUE)

# 1. old exports absent today (minus the 11 wrappers already in R/compat_0_5.R)
old_ns <- git("show", paste0(old_ref, ":NAMESPACE"))
new_ns <- git("show", "HEAD:NAMESPACE")  # the committed exports, never this file's own
ex <- function(x) sub("^export\\((.*)\\)$", "\\1", grep("^export\\(", x, value = TRUE))
old_exports <- ex(old_ns); new_exports <- ex(new_ns)
# names the compat files define are aliases, not 1.0.0 functions (HEAD and working tree)
compat_files <- c("R/compat_names.R", "R/compat_0_5.R", "R/compat_s3.R")
compat_defs <- character()
for (f in compat_files) {
  for (txt in list(suppressWarnings(system2("git", c("show", paste0("HEAD:", f)), stdout = TRUE, stderr = FALSE)),
                   if (file.exists(f)) readLines(f) else character())) {
    if (!length(txt)) next
    for (e in parse(text = txt, keep.source = FALSE)) {
      if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]])) {
        compat_defs <- c(compat_defs, as.character(e[[2]]))
      }
    }
  }
}
new_exports <- setdiff(new_exports, compat_defs)
gone <- setdiff(old_exports, new_exports)
# the four 0.5.13 S3 generics are written by hand in R/compat_s3.R
manual <- c("rate", "rate_change", "share", "yoy_summary")
already <- c(manual, "capsule_sign", "capsule_verify", "pqc_keygen", "signing_public_key", "core_sha256",
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
        out[[as.character(e[[2]])]] <- list(file = f, formals = e[[3]][[2]], body = e[[3]][[3]])
      }
    }
  }
  out
}
old_defs <- defs_at(old_ref); new_defs <- defs_at("HEAD")
new_defs <- new_defs[setdiff(names(new_defs), compat_defs)]
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
  rows[[o]] <- list(old = o, new = n, old_formals = fo, old_names = no, new_names = nn,
                    new_formals = fn, vals = list())
}

# 4b. old defaults that differ from the new ones: a character default is a choice vector (or one
# value); old value i becomes new value i. Anything else is reported and left alone.
dep <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = " ")
lit <- function(x) {
  # `x` is a one-element list holding a formal's default (possibly the empty symbol)
  if (is.name(x[[1]])) return(NULL)
  v <- tryCatch(eval(x[[1]], baseenv()), error = function(e) NULL)
  if (is.character(v) && !anyNA(v)) v else NULL
}
ndiff <- 0L
for (o in names(rows)) {
  r <- rows[[o]]
  for (i in seq_along(r$old_names)) {
    a <- r$old_names[i]; b <- r$new_names[i]
    if (a == "..." || !(b %in% names(r$new_formals))) next
    od <- unname(as.list(r$old_formals)[i]); nd <- unname(as.list(r$new_formals)[b])
    if (identical(dep(od), dep(nd))) next
    ndiff <- ndiff + 1L
    ov <- lit(od); nv <- lit(nd)
    if (is.null(ov) || is.null(nv)) {
      cat(sprintf("default differs, not a value rename: %s(%s = %s) -> %s(%s = %s)\n",
                  o, a, dep(od[[1]]), r$new, b, dep(nd[[1]])))
      next
    }
    if (grepl("col", a)) {
      # a column name is the user's data, not an allowed value: the old default is kept
      cat(sprintf("default differs, column name kept: %s(%s = %s)\n", o, a, dep(od[[1]])))
      next
    }
    if (length(ov) != length(nv)) stop(sprintf("%s: %s has %d old and %d new choices", o, a, length(ov), length(nv)))
    k <- ov != nv
    rows[[o]]$vals[[a]] <- stats::setNames(nv[k], ov[k])
  }
}
# renamed allowed values no default shows (the NO2 outcomes: crf_pm25 has no asthma function)
extra_vals <- list(outcome = c(childhood_asthma = "chiast"))
for (o in c("crf_no2", "pollution_burden", "pollution_burden_by_area", "verify_pollution")) {
  for (a in names(extra_vals)) rows[[o]]$vals[[a]] <- c(rows[[o]]$vals[[a]], extra_vals[[a]])
}
cat("old -> new default differences:", ndiff, "\n")
cat("value translations (alias, argument: old value -> new value):\n")
for (r in rows) for (a in names(r$vals)) {
  v <- r$vals[[a]]
  cat(sprintf("  %-28s %-14s %s\n", r$old, a, paste(names(v), v, sep = " -> ", collapse = ", ")))
}

# 4c. argument names inside `...`: the old body handed `...` to other 0.5.13 functions; their
# renamed arguments are renamed on the way through (and only theirs)
dots_callees <- function(e) {
  if (!is.call(e)) return(character())
  here <- if (is.name(e[[1]]) && any(vapply(as.list(e)[-1], identical, NA, as.name("...")))) as.character(e[[1]])
  c(here, unlist(lapply(as.list(e)[-1], function(a) if (is.call(a)) dots_callees(a))))
}
for (o in names(rows)) {
  r <- rows[[o]]
  if (!("..." %in% r$old_names)) next
  cal <- intersect(unique(dots_callees(old_defs[[o]]$body)), names(rows))
  m <- character()
  for (f in cal) {
    k <- rows[[f]]$old_names != rows[[f]]$new_names & rows[[f]]$old_names != "..."
    m[rows[[f]]$old_names[k]] <- rows[[f]]$new_names[k]
  }
  # an argument of the alias itself is matched before `...`
  m <- m[setdiff(names(m), r$old_names)]
  rows[[o]]$dots <- m
  if (length(m)) cat(sprintf("  ... of %s (via %s): %s\n", o, paste(cal, collapse = ", "),
                             paste(names(m), m, sep = " -> ", collapse = ", ")))
}

# 5. write the wrappers
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
# 6. renamed result columns and fields: the \\code{} names of each 0.5.13 \\value section that
# today's page no longer has, paired in order with the names today's page added (equal counts),
# else by dropping the underscores. Read the printed table by eye after a change.
rd_index <- function(ref) {
  fs <- if (ref == "WT") list.files("man", pattern = "\\.Rd$", full.names = TRUE) else
    grep("^man/.*\\.Rd$", git("ls-tree", "-r", "--name-only", ref), value = TRUE)
  idx <- character()
  for (f in fs) {
    l <- if (ref == "WT") readLines(f) else git("show", paste0(ref, ":", f))
    idx[sub("^\\\\alias\\{(.*)\\}$", "\\1", grep("^\\\\alias\\{", l, value = TRUE))] <- f
  }
  idx
}
value_codes <- function(lines) {
  v <- paste(lines, collapse = "\n")
  i <- regexpr("\\\\value\\{", v)
  if (i < 0) return(character())
  ch <- strsplit(substring(v, i + 7L), "")[[1]]; d <- 1L
  for (j in seq_along(ch)) {
    d <- d + (ch[j] == "{") - (ch[j] == "}")
    if (!d) break
  }
  v <- paste(ch[seq_len(j)], collapse = "")
  # a name, or a quoted one (an attribute: attr(x, "case_flow"))
  t <- regmatches(v, gregexpr("\\\\code\\{\"?[A-Za-z_][A-Za-z0-9_.]*\"?\\}", v))[[1]]
  unique(gsub("\"", "", sub("^\\\\code\\{(.*)\\}$", "\\1", t)))
}
oi <- rd_index(old_ref); ni <- rd_index("WT")
topics <- c(vapply(rows, `[[`, "", "new"), rate = "rtcalc", rate_change = "ratechg", share = "shrs",
            yoy_summary = "yoysmry", yoy = "yoy")
names(topics)[seq_along(rows)] <- vapply(rows, `[[`, "", "old")
cols <- list(); seen <- character()
for (o in names(topics)) {
  of <- oi[o]; nf <- ni[topics[[o]]]
  if (is.na(of) || is.na(nf) || of %in% seen) next
  seen <- c(seen, of)
  oc <- value_codes(git("show", paste0(old_ref, ":", of))); nc <- value_codes(readLines(nf))
  a <- setdiff(oc, nc); b <- setdiff(nc, oc)
  # a link to another function is not a field
  a <- a[!(a %in% c("bricklayer_data_tables", "bricklayer_fetch"))]
  if (!length(a)) next
  nw <- rep(NA_character_, length(a))
  if (length(a) == length(b)) nw <- b else {
    for (j in seq_along(a)) if (gsub("_", "", a[j]) %in% b) nw[j] <- gsub("_", "", a[j])
    la <- which(is.na(nw)); lb <- setdiff(b, nw)
    if (length(la) == length(lb)) nw[la] <- lb else for (j in la) {
      # an abbreviation: the 1.0.0 name's letters in order within the 0.5.x name (jsdiv in
      # js_divergence), the first letter shared, and only one such name on the page
      cand <- lb[vapply(lb, function(z) startsWith(gsub("_", "", a[j]), substr(z, 1L, 1L)) &&
        grepl(paste0("^", paste(strsplit(z, "")[[1]], collapse = ".*")), gsub("_", "", a[j])), NA)]
      nw[j] <- if (length(cand) == 1L) cand else "?"
    }
  }
  nw[a == "period_label"] <- "perlbl"
  k <- grepl("_", a)
  if (any(k)) cols[[o]] <- stats::setNames(nw[k], a[k])
}
# attributes the pages name outside \\value
cols$case_flow <- c(cols$case_flow, case_flow = "caseflow")
cols$life_table <- c(cols$life_table, life_table = "lifetbl")
if (any(unlist(cols) == "?")) stop("unpaired renamed field: ", paste(names(which(unlist(cols) == "?")), collapse = ", "))
cat("renamed result fields:", length(unlist(cols)), "in", length(cols), "topics\n")
for (o in names(cols)) cat(sprintf("  %-28s %s\n", o, paste(names(cols[[o]]), cols[[o]], sep = " -> ", collapse = ", ")))

# The page text above the two tables is written by hand in R/compat_names.R (the 0.5.x names are no
# longer R functions: the rmbl command line translates them, R/cli_compat.R); only the tables are
# generated.
out <- readLines("R/compat_names.R")
out <- out[seq_len(grep("^#. @section Renamed allowed values:", out)[1L] - 1L)]
vt <- unlist(lapply(rows, function(r) lapply(names(r$vals), function(a)
  wrap_lines(paste(names(r$vals[[a]]), r$vals[[a]], sep = " -> "),
             sprintf("#' %-26s %-10s", r$old, a), paste0("#' ", strrep(" ", 38L))))))
cl <- unlist(lapply(names(cols), function(o) {
  w <- wrap_lines(paste(names(cols[[o]]), cols[[o]], sep = " -> "), paste0("#' ", o, ":"), "#'   ")
  sub(":,", ":", w, fixed = TRUE)
}))
out <- c(out,
         "#' @section Renamed allowed values:",
         "#' Old name, argument, then each old value and the value it is translated to.",
         "#' \\preformatted{", vt, "#' }", "#'",
         "#' @section Renamed result columns and fields:",
         "#' The 0.5.13 page, then each old name and the name the result has now.",
         "#' \\preformatted{", cl, "#' }",
         "#' @keywords internal", "#' @name rmbl-aliases", "NULL", "")
writeLines(out[-length(out)], "R/compat_names.R")
vals <- function(r) paste(c(unlist(lapply(names(r$vals), function(a)
  paste0(a, ":", names(r$vals[[a]]), "=", r$vals[[a]]))),
  if (length(r$dots)) paste0("...:", names(r$dots), "=", r$dots)), collapse = ";")
map <- do.call(rbind, lapply(rows, function(r) data.frame(old = r$old, new = r$new,
  old_args = paste(r$old_names, collapse = ","), new_args = paste(r$new_names, collapse = ","),
  values = vals(r))))
dir.create("inst/compat", showWarnings = FALSE, recursive = TRUE)
write.table(map, "inst/compat/compat_names_map.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
# the result names: page, 0.5.x name, 1.0.0 name, and whether the 1.0.0 name is unambiguous (no
# 0.5.13 result or argument used it), so that it is renamed back on any page's result
old_vocab <- unique(c(unlist(lapply(unique(oi), function(f) value_codes(git("show", paste0(old_ref, ":", f))))),
                      unlist(lapply(old_defs, function(d) names(d$formals)))))
res <- do.call(rbind, lapply(names(cols), function(o) data.frame(topic = o, old = names(cols[[o]]),
                                                                 new = unname(cols[[o]]))))
amb <- tapply(res$old, res$new, function(v) length(unique(v)) > 1L)
res$safe <- as.integer(!(res$new %in% old_vocab) & !amb[res$new])
write.table(res, "inst/compat/compat_results_map.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
cat("result map:", nrow(res), "rows,", sum(res$safe), "unambiguous\n")
cat("wrote R/compat_names.R and the map of", length(rows), "0.5.x names\n")
