# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("a /proc scan leaves no connection behind", {
  # reading another user's /proc/<pid>/environ warns before file() lets go of
  # its connection; a warning handler that left there leaked one connection a
  # process, and R has 128 (1.0.4: the test suite ran out on R 4.1)
  skip_if_not(
    identical(Sys.info()[["sysname"]], "Linux") && dir.exists("/proc")
  )
  slots <- function() nrow(showConnections(all = TRUE))
  before <- slots()
  for (i in 1:5) {
    .bndlchk_left("rmbl-no-such-tag")
    .bndlchk_procs()
    .rmbl_xmss_writer()
  }
  expect_identical(slots(), before)
  # a file that cannot be opened reads as nothing, with no connection kept
  skip_on_os("windows")
  f <- withr::local_tempfile()
  writeLines("secret", f)
  Sys.chmod(f, "000")
  skip_if(file.access(f, 4L) == 0L, "running as root: the file stays readable")
  before <- slots()
  for (i in 1:5) {
    b <- tryCatch(
      suppressWarnings(readBin(f, "raw", 10L)),
      error = function(e) raw()
    )
    expect_identical(b, raw())
  }
  expect_identical(slots(), before)
})
