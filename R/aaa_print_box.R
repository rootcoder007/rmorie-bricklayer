# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The print() method of every result whose box comes wholly from its
# format() method. It is defined once, here, early in the collation order,
# and each such class's print method is this same function.

#' Prints a result's box, as its format() method builds it.
#' @param x The result.
#' @param ... Passed to format().
#' @return `x`, invisibly.
#' @noRd
.rmbl_print_box <- function(x, ...) {
  .rmbl_cat(format(x, ...), x)
  invisible(x)
}
