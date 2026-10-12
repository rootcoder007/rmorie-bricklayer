# Build inst/extdata/timezone_countries.csv from the IANA tz database:
#   Rscript tools/build_timezones.R TZDIR      (zone.tab, zone1970.tab, backward)
# Every zone of zone.tab is listed under its one country. An alias or old name of the
# `backward` file is listed under its OWN country, which is not always the country of the
# zone it links to (Iceland links to Africa/Abidjan; Atlantic/Jan_Mayen to Europe/Berlin):
#   1. an alias that zone.tab itself lists (Atlantic/Reykjavik) keeps zone.tab's country;
#   2. the `#=` annotation of `backward` names the zone the alias stood for before the
#      database merged it (`Link Africa/Abidjan Iceland #= Atlantic/Reykjavik`): that zone's
#      country;
#   3. a link whose target serves exactly one country in zone1970.tab (Asia/Kolkata for
#      Asia/Calcutta, America/New_York for US/Eastern) takes that country;
#   4. tools/timezone_alias_countries.csv, a reviewed list, covers the cross-border links the
#      database does not annotate (America/Coral_Harbour is Canada, not Panama);
#   5. anything else is left out: the generic CET, EET, MET, WET, EST, HST, MST and the
#      EST5EDT-style names name no country, and an unresolved alias falls through to the
#      locale rather than to a wrong grid.
# The script prints the aliases it could not place so the reviewed list can be kept current.
args <- commandArgs(trailingOnly = TRUE)
tzdir <- if (length(args)) args[[1]] else "."
rd <- function(f) readLines(file.path(tzdir, f), warn = FALSE)
tab <- function(lines) {
  lines <- lines[!startsWith(lines, "#") & nzchar(lines)]
  do.call(rbind, lapply(strsplit(lines, "\t", fixed = TRUE), function(x) x[1:3]))
}
z <- tab(rd("zone.tab"))
map <- stats::setNames(z[, 1L], z[, 3L])
z70 <- tab(rd("zone1970.tab"))
countries70 <- stats::setNames(strsplit(z70[, 1L], ",", fixed = TRUE), z70[, 3L])
bw <- rd("backward")
bw <- bw[grepl("^Link\\s", bw)]
fields <- lapply(bw, function(l) {
  note <- if (grepl("#=", l, fixed = TRUE)) trimws(sub("^.*#=\\s*", "", l)) else NA_character_
  f <- strsplit(sub("\\s+#.*$", "", l), "\\s+")[[1L]]
  c(target = f[2L], alias = f[3L], was = sub("\\s.*$", "", note))
})
links <- do.call(rbind, fields)
curated_path <- file.path("tools", "timezone_alias_countries.csv")
curated <- if (file.exists(curated_path)) {
  cu <- utils::read.csv(curated_path, stringsAsFactors = FALSE, colClasses = "character", comment.char = "#")
  stats::setNames(cu$location, cu$tz)
} else {
  character()
}
generic <- "^(CET|EET|MET|WET|EST|HST|MST|PST|CST|EST5EDT|CST6CDT|MST7MDT|PST8PDT|Etc/.*|Factory|GMT.*|UTC|UCT|Zulu|Universal|Greenwich)$"
unplaced <- character()
for (i in seq_len(nrow(links))) {
  alias <- links[i, "alias"]
  if (!is.na(map[alias]) || grepl(generic, alias)) next
  was <- links[i, "was"]
  target <- links[i, "target"]
  loc <- if (!is.na(was) && !is.na(map[was])) {
    map[[was]]                                    # rule 2
  } else if (!is.null(countries70[[target]]) && length(countries70[[target]]) == 1L) {
    countries70[[target]]                         # rule 3
  } else if (!is.na(curated[alias])) {
    curated[[alias]]                              # rule 4
  } else {
    NA_character_
  }
  if (is.na(loc)) unplaced <- c(unplaced, sprintf("%s -> %s (%s)", alias, target, paste(countries70[[target]], collapse = ",")))
  else map[alias] <- loc
}
map <- map[!is.na(map) & nzchar(map) & !grepl(generic, names(map))]
out <- data.frame(tz = names(map), location = unname(map), stringsAsFactors = FALSE)
out <- out[order(out$tz), ]
utils::write.csv(out, "inst/extdata/timezone_countries.csv", row.names = FALSE, quote = FALSE)
cat(nrow(out), "zones written\n")
if (length(unplaced)) cat("unplaced aliases (add to tools/timezone_alias_countries.csv or leave out):\n ", paste(unplaced, collapse = "\n  "), "\n")
