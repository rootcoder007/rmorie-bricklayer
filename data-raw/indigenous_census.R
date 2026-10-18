# Builds inst/extdata/indigenous_census_population.csv and indigenous_census_households.csv: excerpts
# of the 2021 Census Indigenous Population Profile (Statistics Canada 98-510-X2021001, population, and
# 98-510-X2021016, households and dwellings; Statistics Canada Open Licence), Canada, the provinces and
# the territories, total of genders, as published (columns and values unaltered). Read from the
# data service mirror (census2021_ipp/x2021001_pop, census2021_ipp/x2021016_dwelling).
dir <- Sys.getenv("RMBL_CENSUS_DIR", "/mnt/nvme/work/census2021_ipp/out/csv")
out <- Sys.getenv("RMBL_EXTDATA", "inst/extdata")
rd <- function(f) utils::read.csv(gzfile(file.path(dir, f)), check.names = FALSE, stringsAsFactors = FALSE,
                                  colClasses = "character", encoding = "UTF-8")
p <- rd("x2021001_pop.csv.gz")
p <- p[p$GENDER_ID == "1", ]
cid <- as.integer(p$CHARACTERISTIC_ID)
# characteristics and the age groups each is kept for (the age structure at every age group)
keep <- list(
  list(ids = 1L, ages = unique(p$AGE_GROUP)),
  list(ids = c(13L, 20L, 37L, 38L), ages = c("Total - Age groups", "0 to 14 years")),
  list(ids = c(398L, 402L, 403L), ages = c("Total - Age groups", "0 to 14 years", "15 to 24 years")),
  list(ids = 545:549, ages = "25 years and over"),
  list(ids = 555L, ages = "25 years and over"),
  list(ids = 624:631, ages = c("Total - Age groups", "25 to 64 years")),
  list(ids = c(806L, 807L, 809L), ages = "Total - Age groups"),
  list(ids = c(918L, 923L, 928L), ages = c("Total - Age groups", "0 to 14 years")))
sel <- Reduce(`|`, lapply(keep, function(k) cid %in% k$ids & p$AGE_GROUP %in% k$ages))
p <- p[sel, ]
utils::write.csv(p, file.path(out, "indigenous_census_population.csv"), row.names = FALSE, fileEncoding = "UTF-8")
h <- rd("x2021016_dwelling.csv.gz")
h <- h[as.integer(h$CHARACTERISTIC_ID) %in% c(1L, 37:42, 52:54, 72L, 73L, 81:84), ]
utils::write.csv(h, file.path(out, "indigenous_census_households.csv"), row.names = FALSE, fileEncoding = "UTF-8")
