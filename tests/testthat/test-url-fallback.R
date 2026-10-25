# A lib_*.R file sourced on its own inside a capsule bundle has no compiled
# code: the base-R stand-in for the URL validator must refuse what the C one
# refuses.
test_that(
  paste0(
    "the bundle's base-R URL check refuses local, private and non-https ",
    "addresses"
  ),
  {
    why <- asNamespace("rmoriebricklayer")$.rmbl_url_why
    environment(why) <- new.env(parent = baseenv())
    ok <- c(
      "https://data.ontario.ca/api/3/action/package_show?id=x",
      "https://www12.statcan.gc.ca/x"
    )
    bad <- c(
      "http://data.ontario.ca/x",
      "https://127.0.0.1/x",
      "https://localhost/x",
      "https://10.0.0.5/x",
      "https://169.254.169.254/latest",
      "https://192.168.1.1/",
      "https://172.20.0.1/",
      "https://100.100.1.1/",
      "https://2130706433/",
      "https://0x7f000001/",
      "https://127.1/",
      "https://[::1]/",
      "https://[fe80::1]/",
      "https://[fd00::1]/",
      "https://intranet/x",
      "https://printer.local/x",
      "ftp://x.org/y"
    )
    for (u in ok) {
      expect_identical(why(u), "", info = u)
    }
    for (u in bad) {
      expect_true(nzchar(why(u)), info = u)
    }
    expect_identical(
      why("http://127.0.0.1:11434/api", allow_loopback = TRUE),
      ""
    )
    expect_identical(why("http://data.ontario.ca/x", allow_http = TRUE), "")
  }
)
