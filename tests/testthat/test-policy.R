# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The certificate-policy state machine (RFC 5280 section 6.1), called on
# certificate lists built by hand.

anyp <- "2.5.29.32.0"
pcert <- function(...) {
  utils::modifyList(
    list(
      policies = character(0),
      policy_mappings = NULL,
      require_explicit_policy = NA_integer_,
      inhibit_policy_mapping = NA_integer_,
      inhibit_any_policy = NA_integer_
    ),
    list(...)
  )
}

test_that("the tree starts from the any-policy with no counter set", {
  st <- .rmbl_pt_start()
  expect_identical(st$valid, anyp)
  expect_false(st$explicit_required)
  expect_true(is.na(st$explicit_after))
})

test_that("a path keeps the policy every certificate carries", {
  anchor <- pcert()
  r <- .rmbl_policy_tree(list(pcert(policies = "1.2.3"), anchor), "1.2.3")
  expect_identical(r$valid, "1.2.3")
  expect_identical(r$authorities_constrained_to, "1.2.3")
  expect_true(r$ok)
  # any policy accepted: the valid set is what is reported
  r2 <- .rmbl_policy_tree(list(pcert(policies = "1.2.3"), anchor))
  expect_identical(r2$authorities_constrained_to, r2$valid)
  expect_true(r2$ok)
})

test_that("an explicit-policy requirement with nothing acceptable fails", {
  r <- .rmbl_policy_tree(
    list(pcert(), pcert(require_explicit_policy = 0L)),
    initial = "1.2.3"
  )
  expect_true(r$explicit_required)
  expect_false(r$ok)
  expect_identical(.rmbl_na_int(NULL), NA_integer_)
  expect_identical(.rmbl_na_int("4"), 4L)
  expect_identical(.rmbl_chr0(NULL), character(0))
})
