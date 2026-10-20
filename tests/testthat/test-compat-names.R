# Every 0.5.13 name 1.0.0 renamed still works: the alias has the old formals and forwards each of
# them to the new function under the new argument name. The map is dev/compat_names_map.tsv.

.alias_map <- function() {
  p <- testthat::test_path("..", "..", "dev", "compat_names_map.tsv")
  skip_if_not(file.exists(p), "the alias map is only in the source tree")
  utils::read.delim(p, stringsAsFactors = FALSE)
}

test_that("every alias exists, is exported and keeps the old formals", {
  m <- .alias_map()
  ns <- getNamespaceExports("rmoriebricklayer")
  for (i in seq_len(nrow(m))) {
    expect_true(m$old[i] %in% ns, info = m$old[i])
    expect_true(m$new[i] %in% ns, info = m$new[i])
    expect_identical(as.character(names(formals(get(m$old[i], asNamespace("rmoriebricklayer"))))),
                     strsplit(m$old_args[i], ",", fixed = TRUE)[[1]], info = m$old[i])
  }
})

test_that("every alias forwards each old argument under the new name", {
  m <- .alias_map()
  ns <- asNamespace("rmoriebricklayer")
  for (i in seq_len(nrow(m))) {
    old <- strsplit(m$old_args[i], ",", fixed = TRUE)[[1]]
    new <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1]]
    if (!length(old)) new <- character()
    # one value per old formal (a dummy for `...`), the target replaced by a recorder that
    # reads the names it was called with and never forces a promise
    args <- stats::setNames(as.list(seq_along(old)), old)
    args[old == "..."] <- NULL
    seen <- new.env()
    rec <- function(...) {
      seen$names <- as.character(...names())
      invisible(NULL)
    }
    do.call(testthat::with_mocked_bindings,
            c(list(code = bquote(do.call(.(m$old[i]), .(args)))), stats::setNames(list(rec), m$new[i]),
              list(.package = "rmoriebricklayer")))
    want <- new[old != "..."]
    expect_identical(seen$names, want, info = m$old[i])
  }
})

test_that("an alias really reaches the new function", {
  f <- tempfile(); writeLines("abc", f)
  expect_identical(crc32_file(f), crc32file(f))
  expect_identical(gini(c(1, 2, 3, 10)), ginicoef(c(1, 2, 3, 10)))
  expect_identical(rule_not_null("x"), rulenull("x"))
})
