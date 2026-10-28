# srr G5.2a: a refusal several functions share names the function that refused.
# One call per such refusal, matched on its full new text.

err <- function(expr, msg) expect_error(expr, msg, fixed = TRUE)

test_that(
  paste0(
    "the shared input guards name the ",
    "exported function that called them"
  ),
  {
    err(cspr("a", 1), "cspr: `x` must be numeric, got character")
    err(
      drftchisq(c(a = -1, b = 2), c(a = 1, b = 1)),
      "drftchisq: `obs` must be finite, non-negative counts"
    )
    err(briggs(100, 3, -2, 10, 300, 285), "briggs: `diam` must be positive")
    err(adp(numeric(0)), "adp: `days` must not be empty")
    err(attrfrac(0, 0.5), "attrfrac: `rr` must be positive")
    err(crfpm25(10, refconc = -1), "crfpm25: `refconc` must be non-negative")
    err(
      chwkfit(c(2, 1), 5),
      "chwkfit: `times` must be sorted in increasing order"
    )
    err(
      chwkfit(c(1, 2), -1),
      "chwkfit: `hor` must be a single positive finite number"
    )
    err(chnvrf(list()), "chnvrf: `chain` must come from chnnew()")
    err(
      yoycsv(1, tempfile()),
      "yoycsv: `x` must be an rmbl_yoy object from yoy()"
    )
    # S3 methods are named by their generic, and do.call() is followed to the
    # function it calls
    err(do.call(cspr, list("a", 1)), "cspr: `x` must be numeric, got character")
    # called on its own, a guard has no exported caller to name
    expect_error(.rmbl_num("a", "x"), "^`x` must be numeric")
  }
)

test_that("a statistic that returns no finite number is refused by cpsfals()", {
  d <- data.frame(a = 1:6, b = c(2, 1, 4, 3, 6, 5))
  err(
    cpsfals(d, function(x) NA_real_, n = 9L),
    "cpsfals: the statistic must return one finite number"
  )
})

test_that("a damaged credentials file is named", {
  dir <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = dir)
  dir.create(file.path(dir, "morie"))
  writeLines("[1]", file.path(dir, "morie", "credentials.json"))
  expect_error(
    .bl_read_credentials(),
    "is not a JSON object; fix or remove it"
  )
})

test_that(
  paste0(
    "an interval that does not contain its estimate warns, naming the ",
    "function"
  ),
  {
    d <- data.frame(
      g = c("a", "b", "c"),
      e = c(5, 5, 6),
      lo = c(1, 1, 1),
      hi = c(2, 9, 9),
      stringsAsFactors = FALSE
    )
    expect_warning(
      dstntst(d, "g", "e", "lo", "hi"),
      "dstntst: the interval does not contain the estimate",
      fixed = TRUE
    )
  }
)

test_that("literal copies in function bodies start with the function name", {
  df <- data.frame(a = 1:3, b = c("x", "y", "z"), stringsAsFactors = FALSE)
  err(
    anltab(data.frame(v = 1, p = 1), value = "zz", prd = "p"),
    "anltab: column `zz` not found in `data`"
  )
  err(expcnts(1, 0, 1), "expcnts: `pop` must be positive")
  err(stdinc(1:2, 1:3), "stdinc: `obs` and `expd` must be the same length")
  err(stdinc(1, 0), "stdinc: `expd` must be positive")
  err(ebrates(1:2, 1:3), "ebrates: `obs` and `expd` must be the same length")
  err(ebrates(1, 0), "ebrates: `expd` must be positive")
  err(fnllim(0), "fnllim: `expd` must be positive")
  err(cpsatst(1, NULL), "cpsatst: `man` must be a manifest from mkmnf()")
  err(chnapp(1, "e"), "chnapp: `chain` must come from chnnew()")
  err(chnhead(1), "chnhead: `chain` must come from chnnew()")
  err(
    chwknll(c(1, NA), 5, par = c(1, 0.5, 1)),
    "chwknll: `times` must not contain NA"
  )
  err(
    chwknll(c(2, 1), 5, par = c(1, 0.5, 1)),
    "chwknll: `times` must be sorted in increasing order"
  )
  err(
    chwknll(c(1, 2), -1, par = c(1, 0.5, 1)),
    "chwknll: `hor` must be a single positive finite number"
  )
  err(cspr(1:2, 1:3), "cspr: `x` and `y` must have the same length")
  err(
    cblake2b("a", key = c("a", "b")),
    "cblake2b: `key` must be a length-1 character vector or a raw vector"
  )
  err(
    cpsdrft(df, df, alpha = 2),
    "cpsdrft: `alpha` must be a single value strictly inside (0, 1)"
  )
  err(
    freqtbl(df, "b", maxlvl = 0),
    "freqtbl: `maxlvl` must be a single positive integer"
  )
  err(cortbl(df), "cortbl: need at least two numeric columns to correlate")
  err(drpempty(1), "drpempty: `data` must be a data frame")
  err(drpconst(1), "drpconst: `data` must be a data frame")
  err(mahaoutl(1), "mahaoutl: `data` must be a data frame or a numeric matrix")
  err(
    mahaoutl(data.frame(x = rnorm(10), y = rnorm(10)), alpha = 2),
    "mahaoutl: `alpha` must be a single value strictly inside (0, 1)"
  )
  err(missruns(1), "missruns: `data` must be a data frame")
  err(missruns(data.frame()), "missruns: `data` has no columns")
  err(missgrid(1), "missgrid: `data` must be a data frame")
  err(missgrid(data.frame()), "missgrid: `data` has no columns")
  err(
    cpsfals(df[1:2, ], mean),
    "cpsfals: `data` must be a data frame with at least 4 rows"
  )
  err(
    cpsfals(data.frame(a = 1:5), function(x) 1, trt = "zz"),
    "cpsfals: `trt` is not a column of `data`"
  )
  err(hqcpubkey(1), "hqcpubkey: `key` must come from hqckg()")
  err(hqccmpkey(1), "hqccmpkey: `key` must come from hqckg()")
  err(
    hqcdecap(hqcpubkey(hqckg(128)), raw(10)),
    "hqcdecap: decapsulation needs a key with its secret half"
  )
  err(mcartst(1), "mcartst: `data` must be a data frame or a numeric matrix")
  d <- data.frame(
    y = rnorm(20),
    t = rep(0:1, 10),
    x = rnorm(20),
    u = rep(1:10, 2),
    tm = rep(1:2, each = 10)
  )
  err(
    aipwcf(d, "y", "t", "x", des = 1),
    "aipwcf: `des` must come from svydes()"
  )
  err(
    plndml(d, "u", "tm", "y", "t", NULL),
    "plndml: `covs` must name one column at least"
  )
  err(plrcf(d, "y", "t", "zz"), "plrcf: data is missing columns: zz")
  err(expconcidx(d, "y", "zz"), "expconcidx: data is missing columns: zz")
  err(profcols(1), "profcols: `data` must be a data frame")
  err(topcors(1), "topcors: `data` must be a data frame")
  err(topcors(df), "topcors: need at least two numeric columns to correlate")
  err(misspat(1), "misspat: `data` must be a data frame")
  err(misspat(data.frame()), "misspat: `data` has no columns")
  err(yoybnd(1), "yoybnd: `y` must come from yoy()")
  err(cpsrpt(1), "cpsrpt: `data` must be a data frame")
  err(mnfrecseed(1), "mnfrecseed: `man` must be a manifest from mkmnf()")
  err(duprows(1), "duprows: `data` must be a data frame")
  err(misssmry(1), "misssmry: `data` must be a data frame")
  err(misssmry(data.frame()), "misssmry: `data` has no columns")
  err(valrules(1, list()), "valrules: `data` must be a data frame")
  err(infsch(1), "infsch: `data` must be a data frame")
  err(
    infsch(df, maxlvl = 0),
    "infsch: `maxlvl` must be a single positive integer"
  )
  err(smryupd(1, 1), "smryupd: `acc` must come from onlsmry()")
  err(smrystat(1), "smrystat: `acc` must come from onlsmry()")
  err(svyest(1, df, "a"), "svyest: `des` must come from svydes()")
  err(svydes(1, "w"), "svydes: `data` must be a data frame")
  sd <- data.frame(w = c(1, 2, 3), y = 1:3)
  err(
    svydes(sd, "w", reps = matrix(1, 2, 2)),
    "svydes: `reps` must have one row per row of `data` (3)"
  )
  err(
    svydes(sd, "w", reps = matrix(c(1, NA, 1), 3, 1)),
    "svydes: replicate weights must be finite and not missing"
  )
  out <- withr::local_tempfile()
  writeLines("x", out)
  err(wbrtry(out, incgone = NA), "wbrtry: `incgone` must be TRUE or FALSE")
  err(yoyjs(1, tempfile()), "yoyjs: `x` must be an rmbl_yoy object from yoy()")
  err(yoymd(1, tempfile()), "yoymd: `x` must be an rmbl_yoy object from yoy()")
})

test_that("the signing refusals name their function", {
  key <- pqckg(height = 2)
  sig <- cpssign("m", key)
  err(
    cpsvrf(c("a", "b"), sig, signpubkey(key)),
    "cpsvrf: `msg` must be a length-1 character vector or a raw vector"
  )
  sk <- fipskg("SLH-DSA-SHAKE-128f")
  err(fipsmu(sk, "m"), "fipsmu: external mu is an ML-DSA interface; ")
  err(
    fipssignmu(sk, raw(64)),
    "fipssignmu: external mu is an ML-DSA interface; "
  )
})
