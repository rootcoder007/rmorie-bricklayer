# Child R processes started by the tests make their session folders inside
# this session's own, which R removes when it ends: a child that is killed
# (the interrupt and timeout tests) left its Rtmp folder in TMPDIR.
if (.Platform$OS.type != "windows") {
  rmbl_kids <- file.path(tempdir(), "kids")
  dir.create(rmbl_kids, showWarnings = FALSE)
  withr::local_envvar(
    TMPDIR = rmbl_kids,
    .local_envir = testthat::teardown_env()
  )
}
