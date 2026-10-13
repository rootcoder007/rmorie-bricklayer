# data-raw/tps_break_enter_d14_2024.R: inst/extdata/tps_break_enter_d14_2024.csv from the Toronto
# Police Service's Break and Enter open data (Public Safety Data Portal, https://data.tps.ca/,
# dataset "Break and Enter Open Data", retrieved 2026-10-13; Open Government Licence - Toronto
# Police Service). One row per occurrence (EVENT_UNIQUE_ID): the Service publishes one row per
# offence record, so an occurrence with two records appeared twice, identical in every column
# kept here (review of e57fed5, E5); `offence_records` keeps the count. Run from the package root:
#   Rscript data-raw/tps_break_enter_d14_2024.R path/to/Break_and_Enter_Open_Data_*.csv
args <- commandArgs(TRUE)
raw <- utils::read.csv(args[1], stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM")
# which(): a logical index with NA (an occurrence with no year) makes an all-NA row, which is
# where the bundled file before 0.5.12 got its row 515 of nothing
x <- raw[which(raw$OCC_YEAR == 2024 & raw$DIVISION == "D14"), ]
month <- match(trimws(x$OCC_MONTH), month.name)
x$occ_date <- sprintf("%04d-%02d-%02d", x$OCC_YEAR, month, x$OCC_DAY)
records <- table(x$EVENT_UNIQUE_ID)
first <- x[!duplicated(x$EVENT_UNIQUE_ID), ]
# the records of one occurrence agree on everything kept here; a disagreement would stop the build
keep <- c("EVENT_UNIQUE_ID", "occ_date", "PREMISES_TYPE", "LONG_WGS84", "LAT_WGS84")
chk <- unique(x[keep])
stopifnot(!anyDuplicated(chk$EVENT_UNIQUE_ID))
out <- data.frame(event_id = first$EVENT_UNIQUE_ID, occ_date = first$occ_date, premises = first$PREMISES_TYPE,
                  lon = first$LONG_WGS84, lat = first$LAT_WGS84,
                  offence_records = as.integer(records[first$EVENT_UNIQUE_ID]), stringsAsFactors = FALSE)
out <- out[order(out$occ_date, out$event_id), ]
stopifnot(all(is.finite(out$lon) & is.finite(out$lat)), !anyNA(out))
utils::write.csv(out, "inst/extdata/tps_break_enter_d14_2024.csv", row.names = FALSE)
cat(nrow(x), "records,", nrow(out), "occurrences\n")
