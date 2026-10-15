# Lines the 0.5.13 patch added that no other test reached (codecov patch on PR #58).

ns <- asNamespace("rmoriebricklayer")

test_that("RStudio outside its console: a terminal tab, a build or render pane, or a subprocess", {
  withr::local_envvar(RSTUDIO = "1", RSTUDIO_SESSION_PID = "1", ASCIICAST = NA, RSTUDIO_CHILD_PROCESS_PANE = NA)
  local_mocked_bindings(.bl_gui = function() "X11", .bl_stdin_tty = function() TRUE)
  expect_identical(ns$.bl_rstudio(), "terminal")
  local_mocked_bindings(.bl_stdin_tty = function() FALSE)
  withr::local_envvar(RSTUDIO_CHILD_PROCESS_PANE = "build")
  expect_identical(ns$.bl_rstudio(), "build")
  withr::local_envvar(RSTUDIO_CHILD_PROCESS_PANE = NA)
  expect_identical(ns$.bl_rstudio(), "subprocess")
  local_mocked_bindings(.bl_gui = function() "RStudio")
  expect_identical(ns$.bl_rstudio(), "console")
})

test_that("R.app and Rgui get no colour; a console under 20 columns falls back to the R width", {
  withr::local_envvar(R_CLI_NUM_COLORS = NA, NO_COLOR = NA)
  withr::local_options(rmoriebricklayer.num_colors = NULL, cli.num_colors = NULL, cli.default_num_colors = NULL)
  for (g in c("AQUA", "Rgui")) {
    local_mocked_bindings(.bl_gui = function() g)
    expect_identical(ns$.bl_num_colors(NULL, "", FALSE, FALSE, TRUE, TRUE), 1L, info = g)
  }
  withr::local_envvar(COLUMNS = "5")
  withr::local_options(rmoriebricklayer.width = NULL, cli.width = NULL, width = 77)
  expect_identical(ns$.bl_console_width(""), 77L)
  withr::local_options(width = 15)      # R's width under 20 too: the 80-column default
  expect_identical(ns$.bl_console_width(""), 80L)
  withr::local_options(rmoriebricklayer.width = 900)   # capped at 500
  expect_identical(ns$.bl_console_width(""), 500L)
})

test_that("the last line of a byte count, a count with no total, and a stopped run", {
  a <- ns$.bl_anim_new("Get", 2048, quiet = FALSE, tty = TRUE, unit = "B")
  a$unicode <- FALSE
  a$sty <- ns$.bl_styles(a$rgb, 1L)   # no colour codes in the text compared
  a$done <- 1024
  expect_match(ns$.bl_anim_final(a, 1), "Get  1.0 KB of 2.0 KB", fixed = TRUE)
  b <- ns$.bl_anim_new("Spin", 0, quiet = FALSE, tty = TRUE)
  b$unicode <- FALSE
  b$sty <- ns$.bl_styles(b$rgb, 1L)
  expect_match(ns$.bl_anim_final(b, 1), "Spin \\(1.0s\\)")
  expect_match(ns$.bl_anim_final(b, 1, ok = FALSE), "Spin  stopped \\(1.0s\\)")
  # the last stage follows the count, or stands alone when there is none
  b$info <- "fitting"
  expect_match(ns$.bl_anim_final(b, 1), "Spin  fitting \\(1.0s\\)")
  a$info <- "verified"
  expect_match(ns$.bl_anim_final(a, 1), "Get  1.0 KB of 2.0 KB  verified", fixed = TRUE)
})

test_that("a provider GET goes through the network spinner", {
  local_mocked_bindings(.bl_net = function(url, expr) paste("waited for", url))
  expect_identical(ns$.bl_http_get("https://example.org/models", 5, character()),
                   "waited for https://example.org/models")
})

test_that("two failed CRL fetches for one certificate keep both notes", {
  local_mocked_bindings(.rmbl_crl_urls = function(cert) c("http://a.example/1.crl", "http://a.example/2.crl"),
                        .rmbl_ocsp_urls = function(cert) character(0),
                        .rmbl_http_der = function(url, timeout) NULL)
  r <- ns$.rmbl_revocation_fetch(list(list(der = as.raw(1))), 5)
  expect_identical(names(r$notes), c("crl fetch [1]", "crl fetch [1] #2"))
  expect_identical(r$ok, c(FALSE, FALSE))
})
