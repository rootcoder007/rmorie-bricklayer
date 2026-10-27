# .rmbl_print_box(): the print() method of every boxed result

test_that("a result prints its format() box and is returned invisibly", {
  x <- structure(list(), class = "rmbl_test_box")
  registerS3method("format", "rmbl_test_box",
                   function(x, ...) c("line one", "line two"))
  out <- capture.output(res <- withVisible(.rmbl_print_box(x)))
  expect_identical(out, c("line one", "line two"))
  expect_false(res$visible)
  expect_identical(res$value, x)
  # every class that uses it is the very same function
  ns <- asNamespace("rmoriebricklayer")
  expect_identical(ns$print.rmbl_fipsmod, ns$.rmbl_print_box)
  expect_identical(ns$print.rmbl_plant, ns$.rmbl_print_box)
})
