## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")


## ----setup--------------------------------------------------------------------
library(rmoriebricklayer)


## ----provenance---------------------------------------------------------------
provjson <- '{
  "dataset": {
    "title": "Demo library statistics",
    "ckan_api_endpoint": "https://data.ontario.ca/api/3/action/package_show?id=ontario-public-library-statistics"
  },
  "resource": { "name_match_pattern": "2014" },
  "schema": {
    "expected_columns": ["year", "visits", "alert"],
    "structural_invariants": { "min_data_rows": 5 },
    "expected_value_sets": { "year": [2024, 2025] },
    "synthetic_recipe": {
      "n_rows": 25,
      "seed": 42,
      "columns": {
        "year":   { "type": "sample",    "values": [2024, 2025] },
        "visits": { "type": "poisson",   "lambda": 3, "min": 1 },
        "alert":  { "type": "bernoulli", "p": 0.2 },
        "id":     { "type": "id_pattern", "pattern": "p-{seq:05d}" }
      }
    }
  }
}'

provpath <- file.path(tempdir(), "data_provenance.json")
writeLines(provjson, provpath)

prov <- loadprov(provpath)
prov$dataset$title


## ----resolve, eval = FALSE----------------------------------------------------
# url <- rslvckan(prov)            # package_show + name match
# if (is.null(url))                        # slug-change fallback
#   url <- rslvckns(prov)
# 
# path <- file.path(tempdir(), "data.csv")
# fdl(url, path)             # plain-language failure diagnosis
#                                          # + automatic Wayback fallback


## ----synthetic----------------------------------------------------------------
datapath <- file.path(tempdir(), "data.csv")
gen <- mksyncsv(prov$schema$synthetic_recipe, datapath)
gen$rows

df <- read.csv(datapath)
head(df, 3)


## ----validate-----------------------------------------------------------------
digest <- sha256file(datapath)
substr(digest, 1, 16)

chk <- vrfsha256(datapath, digest)
chk$match

issues <- valsch(df, prov)
length(issues)   # 0 = clean against the pinned schema


## ----manifest-----------------------------------------------------------------
man <- mkmnf(
  list(project = "demo-study", author = "A. Author", synthetic = TRUE),
  env = FALSE  # TRUE also snapshots R/OS/package versions
)

man <- recrd(man, "rowsgenerated", obs = gen$rows, expd = 25)
man <- recrd(man, "meanvisits",
              obs = mean(df$visits), expd = 3,
              tol = 1, syn = TRUE)

outdir <- file.path(tempdir(), "capsule-demo")
dir.create(outdir, showWarnings = FALSE)

wrmnfjs(man, file.path(outdir, "manifest.json"))
summarypath <- wrsmrytxt(
  man, outdir,
  paths = list(input = datapath, results = outdir),
  whatwasdone = c("* generated synthetic stand-in (real source offline)",
                    "* validated schema and recorded cross-checks")
)

cat(readLines(summarypath)[7:12], sep = "\n")


## ----indigenous-capsule-------------------------------------------------------
d <- indiex("wellbeing")
f <- file.path(tempdir(), "indigenous_wellbeing.csv")
utils::write.csv(d, f, row.names = FALSE)
h <- sha256file(f)
m <- mkmnf(list(dataset = "indigenouswellbeing", rows = nrow(d), sha256 = h,
                        source = "Statistics Canada, Indigenous Peoples Survey 2022",
                        licence = "Statistics Canada Open Licence"),
                   env = FALSE)
vrfsha256(f, h)


## ----capsule-plots, fig.width = 7, fig.height = 4.5---------------------------
ci_plot <- function(t, lab, main) {
  o <- order(t$estimate)
  t <- t[o, ]
  y <- seq_len(nrow(t))
  op <- par(mar = c(4, 10, 3, 1))
  on.exit(par(op))
  plot(t$estimate, y, xlim = range(t$lower, t$upper, na.rm = TRUE), yaxt = "n", pch = 19,
       col = blpal()[1], xlab = "estimate and 95% interval", ylab = "", main = main)
  segments(t$lower, y, t$upper, y, col = blpal()[1])
  axis(2, y, lab[o], las = 1, cex.axis = 0.7)
}
t1 <- d[d$indicator == d$indicator[1], ]
ci_plot(t1, t1$group, t1$indicator[1])
v <- tapply(df$visits, df$year, sum)
barplot(v, col = blpal()[2], main = "Visits by year", xlab = "year", ylab = "visits")

