## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----rules--------------------------------------------------------------------
df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
                 start = c(1, 5, 3), end = c(2, 4, 9))

rules <- list(
  rul("agenonnegative", function(v) v >= 0, col = "age"),
  rul("idunique", function(v) !anyDuplicated(v), col = "id", sev = "fatal"),
  rul("datesordered", function(d) all(d$start <= d$end))
)

issues <- valrules(df, rules)
names(issues)
issues$agenonnegative$n_failed
issues$agenonnegative$rows


## ----rules-clean--------------------------------------------------------------
clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
length(valrules(clean, rules))


## ----rules-edge---------------------------------------------------------------
length(valrules(data.frame(id = 1:3), rules[1:2]))
broken <- list(rul("bad", function(v) stop("boom"), col = "age"))
valrules(clean, broken)$bad$message


## ----ready--------------------------------------------------------------------
rules2 <- list(
  rulenull("id"),
  ruleuniq("id", sev = "fatal"),
  rulebtw("age", 0, 120),
  ruleinset("grade", c("a", "b", "c")),
  rulerx("code", "^[A-Z]{2}-[0-9]{4}$"),
  rulemad("score", n = 3),
  rulecolcnt(6, sev = "fatal")
)
length(rules2)


## ----infer--------------------------------------------------------------------
set.seed(1)
df <- data.frame(
  id = 1:100,
  score = stats::runif(100, 0, 10),
  grade = sample(c("a", "b", "c"), 100, TRUE),
  note = paste0("free text ", 1:100),
  stringsAsFactors = FALSE
)
sch <- infsch(df)
sch$expected_value_sets


## ----infer-check--------------------------------------------------------------
length(valsch(df, list(schema = sch)))
length(valsch(df[, -3], list(schema = sch))) > 0
bad <- df
bad$grade[1] <- "z"
length(valsch(bad, list(schema = sch))) > 0


## ----synthetic----------------------------------------------------------------
recipe <- list(
  n_rows = 20, seed = 42,
  columns = list(
    year   = list(type = "sample", values = list(2024, 2025)),
    alert  = list(type = "bernoulli", p = 0.2),
    visits = list(type = "poisson", lambda = 3, min = 1),
    id     = list(type = "id_pattern", pattern = "p-{seq:05d}")
  )
)
out <- tempfile(fileext = ".csv")
res <- mksyncsv(recipe, out)
res$rows
res$seed

df <- utils::read.csv(out)
dim(df)
names(df)
head(df, 3)


## ----synthetic-mark-----------------------------------------------------------
mksyncsv(recipe, tempfile(fileext = ".csv"), nrows = 5)$rows


## ----indigenous-rules---------------------------------------------------------
d <- indiex("health")
rules <- list(
  ruleinset("quality", c("ok", "E", "F", "x", "..")),
  ruleinset("group", c("First Nations", "M\u00e9tis", "Inuit", "Non-Indigenous")),
  rul("estimate inside its interval",
       function(x) is.na(x$estimate) | (x$lower <= x$estimate & x$estimate <= x$upper))
)
valrules(d, rules)


## ----synthetic-plot, fig.width = 8, fig.height = 4----------------------------
op <- par(mfrow = c(1, 2))
barplot(table(df$visits), col = blpal()[1], xlab = "visits", ylab = "rows",
        main = "Synthetic visits")
al <- tapply(df$alert == "Yes", df$year, mean)
barplot(100 * al, col = blpal()[2], ylim = c(0, 100), xlab = "year", ylab = "rows with an alert (%)",
        main = "Synthetic alert flag")
abline(h = 20, lty = 2)
par(op)

