## ----include = FALSE----------------------------------------------------------
# the one-time index record of this vignette stays out of the reader's configuration directory
options(rmoriebricklayer.xmssidxfile = tempfile())
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----providers----------------------------------------------------------------
llmprvd()[, c("id", "label", "key_env")]


## ----status-------------------------------------------------------------------
old <- Sys.getenv("OLLAMA_HOST", unset = NA)
Sys.setenv(OLLAMA_HOST = "off")
llmstat()
if (is.na(old)) Sys.unsetenv("OLLAMA_HOST") else Sys.setenv(OLLAMA_HOST = old)


## ----ask, eval = FALSE--------------------------------------------------------
# llmask("How do I estimate a weighted proportion with bootstrap replicate weights?")
# llmask(paste(c("Summarise this table:", capture.output(print(head(mtcars)))),
#                          collapse = "\n"),
#                    syspro = "Answer in two sentences.", docs = FALSE)


## ----services-----------------------------------------------------------------
s <- svcs(offline = TRUE)
s$data$mode
attr(s, "source")


## ----login, eval = FALSE------------------------------------------------------
# dlogin(token = "<key issued at https://www.rmorie.com/access/>")
# dlogin()          # or: GitHub device flow / emailed code
# dlogout()         # forget the key


## ----indigenous-llm, eval = FALSE---------------------------------------------
# llmask(paste("How do I compare perceived mental health of First Nations,",
#                          "Metis and Inuit adults with non-Indigenous adults, using",
#                          "indiex('health_indicators')?"))


## ----providers-plot, fig.width = 6, fig.height = 4----------------------------
pv <- llmprvd()
barplot(table(pv$api), col = blpal()[1], ylab = "providers", main = "Providers by request shape")

