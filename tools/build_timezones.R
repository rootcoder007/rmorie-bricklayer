# Build inst/extdata/timezone_countries.csv from the IANA tz database:
#   Rscript tools/build_timezones.R TZDIR      (zone.tab, zone1970.tab, backward)
# zone.tab lists every canonical zone under exactly one country; `backward`
# links each old or alias name to a canonical zone, and inherits its country;
# zone1970.tab fills any zone the other two miss (its first country).
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
for (i in seq_len(nrow(z70))) {
  if (is.na(map[z70[i, 3L]])) map[z70[i, 3L]] <- sub(",.*$", "", z70[i, 1L])
}
bw <- rd("backward")
bw <- bw[grepl("^Link\\s", bw)]
bw <- do.call(rbind, lapply(strsplit(sub("\\s+#.*$", "", bw), "\\s+"), function(x) x[2:3]))
for (i in seq_len(nrow(bw))) {
  target <- bw[i, 1L]
  alias <- bw[i, 2L]
  if (is.na(map[alias]) && !is.na(map[target])) map[alias] <- map[[target]]
}
# UTC, GMT, Etc/*, Factory and the posix/right trees name no country
map <- map[!is.na(map) & nzchar(map) & !grepl("^(Etc/|Factory|GMT|UTC|UCT|Zulu|Universal|Greenwich)", names(map))]
out <- data.frame(tz = names(map), location = unname(map), stringsAsFactors = FALSE)
out <- out[order(out$tz), ]
utils::write.csv(out, "inst/extdata/timezone_countries.csv", row.names = FALSE, quote = FALSE)
cat(nrow(out), "zones written\n")
