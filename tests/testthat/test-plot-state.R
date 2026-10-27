# Every plot the package draws leaves the device as it found it: par() and the
# list of open devices (B1, B2). For each exported plot function and each plot()
# method the package registers, the help page's example runs on a fresh
# pdf(NULL) device, one top-level call at a time, and par() must be the same
# after each call as before it.
#
# Not compared: usr, xaxp, yaxp, xlog and ylog. plot.window() sets them for
# every base plot, plot() itself included; they are the coordinates a later
# points() or abline() draws in, so a plot must leave them.
ps_skip <- c("usr", "xaxp", "yaxp", "xlog", "ylog")

# examples that need the network, by help page, with the reason (none so far)
ps_net <- character()

ps_rd_db <- function() {
  root <- testthat::test_path("..", "..")
  src <- file.exists(file.path(root, "DESCRIPTION")) &&
    dir.exists(file.path(root, "man"))
  if (src) {
    tools::Rd_db(dir = root)
  } else {
    tools::Rd_db("rmoriebricklayer")
  }
}

ps_targets <- function() {
  ns <- asNamespace("rmoriebricklayer")
  ex <- getNamespaceExports(ns)
  fns <- ex[startsWith(ex, "plot")]
  fns <- fns[vapply(fns, function(e) is.function(get(e, ns)), NA)]
  s3 <- getNamespaceInfo(ns, "S3methods")
  s3 <- s3[s3[, 1L] == "plot", , drop = FALSE]
  cls <- as.character(unlist(s3[, 2L]))
  fun <- as.character(unlist(s3[, 3L]))
  meth <- ifelse(is.na(fun), paste0("plot.", cls), fun)
  unique(as.character(c(fns, meth)))
}

ps_aliases <- function(rd) {
  tags <- vapply(rd, attr, "", "Rd_tag")
  unlist(lapply(rd[tags == "\\alias"], as.character))
}

# the example's top-level calls, the body of `if (...) withAutoprint({...})`
# (an \examplesIf block) taken out as calls of its own
ps_calls <- function(file) {
  out <- list()
  for (e in parse(file, keep.source = FALSE)) {
    w <- if (is.call(e) && identical(e[[1L]], as.name("if"))) e[[3L]]
    if (is.call(w) && identical(w[[1L]], as.name("withAutoprint"))) {
      out <- c(out, as.list(w[[2L]])[-1L])
    } else {
      out <- c(out, list(e))
    }
  }
  out
}

ps_par_diff <- function(p0, p1) {
  nm <- setdiff(names(p0), ps_skip)
  nm[!vapply(nm, function(k) identical(p0[[k]], p1[[k]]), NA)]
}

ps_run_topic <- function(rd, topic) {
  f <- tempfile(fileext = ".R")
  on.exit(unlink(f), add = TRUE)
  tools::Rd2ex(rd, f, commentDontrun = TRUE, commentDonttest = FALSE)
  if (!file.exists(f)) {
    return(invisible(NULL))
  }
  grDevices::pdf(NULL)
  dev <- grDevices::dev.cur()
  on.exit(
    if (dev %in% grDevices::dev.list()) grDevices::dev.off(dev),
    add = TRUE
  )
  devs <- grDevices::dev.list()
  env <- new.env(parent = globalenv())
  for (e in ps_calls(f)) {
    what <- substr(paste(deparse(e), collapse = " "), 1L, 70L)
    p0 <- graphics::par(no.readonly = TRUE)
    err <- tryCatch(
      {
        utils::capture.output(suppressMessages(suppressWarnings(eval(e, env))))
        NULL
      },
      error = function(cnd) conditionMessage(cnd)
    )
    expect_null(err, info = paste(topic, what))
    expect_identical(
      ps_par_diff(p0, graphics::par(no.readonly = TRUE)),
      character(0),
      info = paste(topic, what)
    )
    expect_identical(grDevices::dev.list(), devs, info = paste(topic, what))
  }
  invisible(NULL)
}

test_that("no plot leaves par() or the open devices changed", {
  skip_if_not_installed("tools")
  # the examples set options of their own (plotopt()): all come back
  op <- options()
  on.exit(options(op), add = TRUE)
  withr::local_options(
    rmbl.examples = TRUE,
    rmoriebricklayer.plot = getOption("rmoriebricklayer.plot")
  )
  withr::local_seed(1)
  old <- grDevices::dev.list()
  db <- ps_rd_db()
  al <- lapply(db, ps_aliases)
  targets <- ps_targets()
  expect_gt(length(targets), 10L)
  # every plot function has a help page whose example draws it
  expect_identical(setdiff(targets, unlist(al)), character(0))
  topics <- names(db)[vapply(al, function(a) any(a %in% targets), NA)]
  for (tp in setdiff(topics, names(ps_net))) {
    ps_run_topic(db[[tp]], tp)
  }
  expect_identical(grDevices::dev.list(), old)
})
