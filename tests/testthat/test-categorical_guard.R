test_that("grdrcd maps by name, refuses unmapped, records the mapping", {
  r <- grdrcd(c("W", "B", "O", "W"), c(W = "White", B = "Black", O = "Other"))
  expect_identical(as.character(r), c("White", "Black", "Other", "White"))
  expect_identical(nchar(attr(r, "recode_audit")$checksum), 64L)
  expect_error(grdrcd(c("W", "X"), c(W = "White")), "values with NO mapping")
  expect_identical(
    as.character(grdrcd(c("W", "X", NA), c(W = "White"), keep = "X")),
    c("White", "X", NA)
  )
})

test_that("deccodes turns codes into labels and refuses unlabelled codes", {
  d <- deccodes(
    c(1, 2, 2, 3),
    c("1" = "White", "2" = "Black", "3" = "Indigenous")
  )
  expect_identical(as.character(d), c("White", "Black", "Black", "Indigenous"))
  expect_error(deccodes(c(1, 4), c("1" = "White")), "NO mapping")
})

test_that("grdlvls declares levels and the reference", {
  f <- grdlvls(c("White", "Black", "White"), c("White", "Black"), "White")
  expect_identical(as.integer(f), c(1L, 2L, 1L))
  expect_error(
    grdlvls(c("White", "Other"), c("White", "Black")),
    "outside the declared levels"
  )
  expect_error(grdlvls("White", c("White", "Black"), "Black"), "is not levels")
})

test_that("audcats flags codes, case variants and unused levels", {
  a <- audcats(data.frame(
    race = factor(c("1", "2", "2", "3"), levels = c("1", "2", "3", "4")),
    city = c("Toronto", "toronto", "Ottawa", "Ottawa"),
    stringsAsFactors = FALSE
  ))
  expect_match(a$hazards[1], "imported CODES")
  expect_match(a$hazards[1], "unused levels")
  expect_match(a$hazards[2], "case-variant")
  expect_false(attr(a, "clean"))
  expect_output(print(a), "HAZARD")
})

test_that("vrfrcd proves a recode and names a swap", {
  expect_silent(vrfrcd(
    c("W", "B", "W"),
    c("White", "Black", "White"),
    c(W = "White", B = "Black")
  ))
  expect_error(
    vrfrcd(c("W", "B"), c("Black", "White"), c(W = "White", B = "Black")),
    "THIS is how groups get swapped"
  )
  expect_error(vrfrcd(c("W", "B"), "White", c(W = "White")), "rows were lost")
})

test_that("vrfmrg accepts matching counts and names a permutation", {
  x <- c("White", "White", "Black", "Indigenous", "White", "Black")
  expect_true(vrfmrg(x, c(White = 3, Black = 2, Indigenous = 1))$ok)
  expect_error(
    vrfmrg(x, c(White = 2, Black = 3, Indigenous = 1)),
    "White -> Black"
  )
})

test_that("orchk recovers a label swap behind an inflated OR", {
  tab <- matrix(
    c(900, 100, 700, 300, 400, 600),
    ncol = 2,
    byrow = TRUE,
    dimnames = list(c("A", "B", "C"), c("no", "yes"))
  )
  ok <- orchk(
    tab,
    "A",
    c(B = 300 / 700 / (100 / 900), C = 600 / 400 / (100 / 900))
  )
  expect_true(ok$consistent)
  sw <- orchk(tab, "A", c(B = 13.5, C = 3.857))
  expect_false(sw$consistent)
  expect_identical(sw$matches$relabelling[1], "B -> C, C -> B")
  expect_match(sw$verdict, "mislabelled")
  expect_identical(nrow(orchk(tab, "A", c(B = 36, C = 4))$matches), 0L)
})

test_that("grdbin refuses categorical treatment columns", {
  expect_true(grdbin(c(0, 1, 1, 0), "d"))
  expect_error(grdbin(c("treated", "control"), "d"), "level INDICES")
  expect_error(grdbin(c(0, 2), "d"), "must be binary")
})

test_that("a recode manifest records, signs, writes and verifies the chain", {
  x <- c("W", "B", "W", "I", NA)
  y <- grdrcd(x, c(W = "White", B = "Black", I = "Indigenous"))
  key <- pqckg(height = 2)
  m <- rcdmnf(
    x,
    y,
    c(W = "White", B = "Black", I = "Indigenous"),
    pub = c(White = 2, Black = 1, Indigenous = 1),
    key = key,
    ctx = "unit test"
  )
  expect_s3_class(m, "bricklayer_recode_manifest")
  expect_true(m$checks$matches_published)
  expect_identical(m$n_missing, 1L)
  p <- wrrcdmnf(m, tempfile(fileext = ".json"))
  v <- vrfrcdmnf(p, x, y)
  expect_true(v$ok)
  expect_true(v$signature_ok)
  # tamper: swap two labels in the recoded data
  y2 <- as.character(y)
  y2[y2 == "Black"] <- "Indigenous"
  v2 <- vrfrcdmnf(p, x, y2)
  expect_false(v2$ok)
  expect_true(any(grepl(
    "groups get swapped|differ from the manifest",
    v2$reasons
  )))
  # tamper: edit the file
  txt <- readLines(p)
  txt <- sub("unit test", "edited", txt, fixed = TRUE)
  writeLines(txt, p)
  expect_false(vrfrcdmnf(p, x, y)$ok)
  expect_error(
    rcdmnf(
      x,
      y,
      c(W = "White", B = "Black", I = "Indigenous"),
      pub = c(White = 1, Black = 2, Indigenous = 1)
    ),
    "permuted"
  )
})

test_that("orchk names the OHRC 2023 four-way rotation", {
  # White coded as Black, Black as Other, Other as Unknown, Unknown as White
  # (OHRC, Correction to "A Disparate Impact", 26 January 2023; Jung 2022).
  tab <- matrix(
    c(9000, 120, 2000, 220, 1500, 60, 4000, 1),
    ncol = 2,
    byrow = TRUE,
    dimnames = list(c("White", "Black", "Other", "Unknown"), c("no", "yes"))
  )
  ref <- 120 / 9000
  correct <- orchk(
    tab,
    "White",
    c(
      Black = 220 / 2000 / ref,
      Other = 60 / 1500 / ref,
      Unknown = 1 / 4000 / ref
    )
  )
  expect_true(correct$consistent)
  rotated <- tab[c("Unknown", "White", "Black", "Other"), ]
  rownames(rotated) <- c("White", "Black", "Other", "Unknown")
  rref <- rotated["White", 2] / rotated["White", 1]
  reported <- c(
    Black = rotated["Black", 2] / rotated["Black", 1] / rref,
    Other = rotated["Other", 2] / rotated["Other", 1] / rref,
    Unknown = rotated["Unknown", 2] / rotated["Unknown", 1] / rref
  )
  r <- orchk(tab, "White", reported)
  expect_false(r$consistent)
  expect_true(any(grepl(
    "Unknown -> White",
    r$matches$relabelling,
    fixed = TRUE
  )))
  expect_gt(unname(reported["Black"]) / unname(correct$computed["Black"]), 5)
  expect_match(r$verdict, "mislabelled")
})

test_that("relabel refuses positional labels and maps by name", {
  f <- factor(c("W", "B", "O", "W"))
  expect_error(relbl(f, c("Black", "Other", "White")), "POSITION")
  g <- relbl(f, c(W = "White", B = "Black", O = "Other"))
  expect_identical(as.character(g), c("White", "Black", "Other", "White"))
  expect_identical(levels(g), c("White", "Black", "Other"))
  expect_error(relbl(f, c(W = "White")), "NO mapping")
})

test_that("declbld decodes by code, levels in code order", {
  x <- structure(
    c(1, 2, 2, 4),
    labels = c(White = 1, Black = 2, Other = 3, Unknown = 4)
  )
  f <- declbld(x)
  expect_identical(as.character(f), c("White", "Black", "Black", "Unknown"))
  expect_identical(levels(f), c("White", "Black", "Other", "Unknown"))
  expect_error(declbld(c(1, 5), c("1" = "White")), "NO mapping")
  expect_error(declbld(c(1, 2)), "NOT the categories")
})

test_that("rlblfrns: OHRC rotation is an alphabetical relabel", {
  vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
  obs <- c(
    White = "Black",
    Black = "Other",
    Other = "Unknown",
    Unknown = "White"
  )
  r <- rlblfrns(vl, obs)
  alpha <- "labels sorted alphabetically, assigned by code position"
  expect_true(r$matches[r$mechanism == alpha])
  expect_match(attr(r, "verdict"), "reproduced EXACTLY")
  expect_output(print(r), "alphabetically")
  # what the relabel idiom actually does to those codes
  f <- factor(c(1, 2, 3, 4, 1))
  levels(f) <- sort(unname(vl))
  expect_identical(
    as.character(f),
    c("Black", "Other", "Unknown", "White", "Black")
  )
  none <- rlblfrns(
    vl,
    c(White = "Other", Black = "White", Other = "Black", Unknown = "Unknown")
  )
  expect_false(any(none$matches))
  expect_match(attr(none, "verdict"), "No positional")
  expect_error(rlblfrns(vl, c(White = "Black")), "permutation")
  # decreasing frequency: Black, Unknown, White, Other assigned to codes 1..4
  seen <- c(
    White = "Black",
    Black = "Unknown",
    Other = "White",
    Unknown = "Other"
  )
  cnt <- c(White = 100, Black = 9000, Other = 50, Unknown = 500)
  fr <- rlblfrns(vl, seen, cnts = cnt)
  dec <- "labels ordered by decreasing frequency, assigned by code position"
  expect_true(fr$matches[fr$mechanism == dec])
})

test_that("audit flags code-prefixed labels", {
  a <- audcats(data.frame(
    race = c("1. White", "2. Black", "1. White"),
    stringsAsFactors = FALSE
  ))
  expect_match(a$hazards[1], "code prefixes")
})

test_that("xfrvrf accepts a faithful import, names a rotated one", {
  x <- structure(
    c(1, 1, 2, 4, 1),
    labels = c(White = 1, Black = 2, Other = 3, Unknown = 4)
  )
  ok <- xfrvrf(
    x,
    c(White = 3, Black = 1, Unknown = 1),
    codebook = c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
  )
  expect_true(ok$ok)
  expect_true(ok$code_book_ok)
  expect_identical(levels(ok$decoded), c("White", "Black", "Other", "Unknown"))
  rotated <- structure(
    c(1, 1, 2, 4, 1),
    labels = c(Black = 1, Other = 2, Unknown = 3, White = 4)
  )
  expect_error(
    xfrvrf(
      rotated,
      c(White = 3, Black = 1, Unknown = 1),
      codebook = c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
    ),
    "disagree with the source code book"
  )
  expect_error(
    xfrvrf(
      c("Black", "Black", "Other", "White", "Black"),
      c(White = 3, Black = 1, Unknown = 1)
    ),
    "do not match|permuted|not in the published"
  )
})

test_that("deccodes keeps or drops NA codes as asked", {
  d <- deccodes(c(1, NA, 2), c("1" = "White", "2" = "Black"))
  expect_identical(as.character(d), c("White", NA, "Black"))
  expect_error(deccodes(c(1, 2), c("White", "Black")), "named character")
})

test_that("grdrcd refuses an unnamed mapping and factor input works", {
  expect_error(
    grdrcd(c("W", "B"), c("White", "Black")),
    "named character vector"
  )
  r <- grdrcd(factor(c("W", "B")), c(W = "White", B = "Black"))
  expect_identical(as.character(r), c("White", "Black"))
})

test_that("audcats covers labelled columns, empty frames and cols", {
  lab <- structure(
    c(1, 2, 2),
    labels = c(White = 1, Black = 2),
    class = c("haven_labelled", "vctrs_vctr", "double")
  )
  a <- audcats(data.frame(race = I(lab), n = 1:3))
  expect_match(a$hazards[a$column == "race"], "foreign value labels")
  wide <- data.frame(id = as.character(seq_len(60)), stringsAsFactors = FALSE)
  expect_match(audcats(wide)$hazards[1], "identifier mistaken")
  e <- audcats(data.frame(n = 1:3))
  expect_identical(nrow(e), 0L)
  expect_true(attr(e, "clean"))
  expect_output(print(e), "no hazards")
  only <- audcats(
    data.frame(a = c("x", "y"), b = c("1", "2"), stringsAsFactors = FALSE),
    cols = "a"
  )
  expect_identical(only$column, "a")
  expect_output(print(only), "a")
})

test_that("vrfrcd reports fan-out and missingness leaks", {
  expect_error(
    vrfrcd(c("W", "W"), c("White", "Black"), c(W = "White")),
    "MULTIPLE|fan"
  )
  expect_error(
    vrfrcd(c("W", "B"), c("White", NA), c(W = "White", B = "Black")),
    "missing"
  )
})

test_that("vrfmrg honours a tolerance, reports mismatches", {
  x <- c("White", "White", "Black")
  expect_true(vrfmrg(x, c(White = 3, Black = 1), tol = 1)$ok)
  expect_error(vrfmrg(x, c(White = 5, Black = 9)), "do not match")
  expect_error(vrfmrg(x, c(3, 1)), "named numeric")
  # nothing published compares nothing: all() of no categories is not a pass
  empty <- stats::setNames(numeric(), character())
  expect_error(vrfmrg(rep(NA, 3), empty, strict = FALSE), "named numeric")
  expect_error(vrfmrg(x, c(White = NA, Black = 1)), "named numeric")
})

test_that("orchk finds swapped outcome columns, checks input", {
  tab <- matrix(
    c(900, 100, 700, 300),
    ncol = 2,
    byrow = TRUE,
    dimnames = list(c("A", "B"), c("no", "yes"))
  )
  swapped <- orchk(tab, "A", c(B = (700 / 300) / (900 / 100)))
  expect_false(swapped$consistent)
  expect_true(any(swapped$matches$outcome_columns_swapped))
  expect_error(orchk(tab, "Z", c(B = 1)), "not a row")
  expect_error(orchk(tab, "A", c(C = 1)), "named by every")
  expect_error(orchk(tab[, 1, drop = FALSE], "A", c(B = 1)), "k-by-2")
})

test_that("grdbin accepts NA, refuses factors and non-binary numbers", {
  expect_true(grdbin(c(0, 1, NA), "d"))
  expect_error(grdbin(factor(c("a", "b")), "d"), "level INDICES")
  expect_error(grdbin(c(0.5, 1), "d"), "binary")
})

test_that("an unsigned manifest verifies its body and reports no signature", {
  x <- c("W", "B", "W")
  y <- grdrcd(x, c(W = "White", B = "Black"))
  m <- rcdmnf(x, y, c(W = "White", B = "Black"))
  expect_null(m$signature)
  p <- wrrcdmnf(m, tempfile(fileext = ".json"))
  v <- vrfrcdmnf(p, x, y)
  expect_true(v$ok)
  expect_true(is.na(v$signature_ok))
  expect_error(wrrcdmnf(list(), tempfile()), "rcdmnf")
  expect_output(print(m), "recode")
})

test_that("a FIPS-signed manifest verifies through the fips key branch", {
  skip_if_not(exists("fipskg"), "no fipskg in this build")
  key <- tryCatch(fipskg(), error = function(e) NULL)
  skip_if(is.null(key), "fips backend unavailable")
  x <- c("W", "B")
  y <- grdrcd(x, c(W = "White", B = "Black"))
  m <- rcdmnf(x, y, c(W = "White", B = "Black"), key = key)
  p <- wrrcdmnf(m, tempfile(fileext = ".json"))
  expect_true(vrfrcdmnf(p, x, y)$signature_ok)
})

test_that("relabel keeps pass-through levels and refuses unmapped ones", {
  f <- factor(c("W", "B", "X"))
  g <- relbl(f, c(W = "White", B = "Black"), keep = "X")
  expect_identical(as.character(g), c("White", "Black", "X"))
  expect_true("X" %in% levels(g))
  expect_error(relbl(c("W", "Q"), c(W = "White")), "NO mapping")
})

test_that("declbld takes explicit labels, refuses bad attributes", {
  d <- declbld(c(2, 1), vlabs = c("1" = "White", "2" = "Black"))
  expect_identical(as.character(d), c("Black", "White"))
  expect_identical(levels(d), c("White", "Black"))
  bad <- structure(c(1, 2), labels = c(1, 2))
  expect_error(declbld(bad), "no names")
  s <- declbld(c("b", "a"), vlabs = c(a = "Alpha", b = "Beta"))
  expect_identical(levels(s), c("Alpha", "Beta"))
})

test_that("rlblfrns names reversed and case-insensitive mechanisms", {
  vl <- c("1" = "b", "2" = "A", "3" = "c")
  rev_obs <- c(b = "c", A = "A", c = "b")
  r <- rlblfrns(vl, rev_obs)
  expect_true(r$matches[r$mechanism == "labels reversed"])
  ci <- rlblfrns(vl, c(b = "A", A = "b", c = "c"))
  ci_name <- "labels sorted case-insensitively, assigned by code position"
  expect_true(ci$matches[ci$mechanism == ci_name])
  expect_output(print(ci), "case-insensitively")
  none <- rlblfrns(
    c("1" = "x", "2" = "y", "3" = "z", "4" = "w"),
    c(x = "z", y = "x", z = "w", w = "y")
  )
  expect_output(print(none), "No mechanism")
  expect_error(rlblfrns(c("x", "y"), c(x = "y", y = "x")), "named")
})

test_that("xfrvrf decodes plain codes with a code book, tolerance", {
  cb <- c("1" = "White", "2" = "Black")
  r <- xfrvrf(c(1, 1, 2), c(White = 2, Black = 1), codebook = cb)
  expect_true(r$ok)
  expect_true(is.na(r$code_book_ok))
  expect_identical(levels(r$decoded), c("White", "Black"))
  lab <- structure(c(1, 1, 2), labels = c(White = 1, Black = 2))
  t2 <- xfrvrf(lab, c(White = 3, Black = 1), tol = 1)
  expect_true(t2$ok)
  expect_error(
    xfrvrf(c("White", "Other"), c(White = 1, Black = 1)),
    "not in the published"
  )
})

test_that("last guard branches: NA codes, non-frame, edited mapping", {
  expect_error(
    deccodes(c(1, NA), c("1" = "White"), keepna = FALSE),
    "missing codes"
  )
  expect_error(audcats(list(a = 1)), "data frame")
  x <- c("W", "B")
  y <- grdrcd(x, c(W = "White", B = "Black"))
  m <- rcdmnf(x, y, c(W = "White", B = "Black"))
  p <- wrrcdmnf(m, tempfile(fileext = ".json"))
  txt <- gsub("White", "Whyte", readLines(p), fixed = TRUE)
  writeLines(txt, p)
  v <- vrfrcdmnf(p, x, y)
  expect_false(v$ok)
  expect_true(any(grepl("mapping checksum", v$reasons, fixed = TRUE)))
})

test_that("audit flags whitespace, empty and sentinel labels (round 3)", {
  df <- data.frame(
    trailing = c("White ", "White", "Black", "Black"),
    leading = c(" White", "White", "Black", "Black"),
    na_string = c("White", "NA", "Black", "Black"),
    empty_str = c("", "White", "Black", "Black"),
    unicode_ws = c("White ", "White", "Black", "Black"),
    stringsAsFactors = FALSE
  )
  a <- audcats(df)
  expect_false(attr(a, "clean"))
  h <- stats::setNames(a$hazards, a$column)
  expect_match(h[["trailing"]], "trailing whitespace")
  expect_match(h[["trailing"]], "whitespace-variant duplicate")
  expect_match(h[["leading"]], "REFERENCE level")
  expect_match(h[["na_string"]], "sentinel")
  expect_match(h[["empty_str"]], "empty-string")
  expect_match(h[["empty_str"]], "REFERENCE level")
  expect_match(h[["unicode_ws"]], "non-breaking")
  expect_output(print(a), "REFERENCE level")
})

test_that("vrfmrg and xfrvrf return ok = FALSE when asked", {
  x <- c("White", "White", "Black", "Indigenous", "White", "Black")
  r <- vrfmrg(x, c(White = 2, Black = 3, Indigenous = 1), strict = FALSE)
  expect_false(r$ok)
  expect_identical(unname(r$permutation[["White"]]), "Black")
  expect_match(r$message, "permuted")
  r2 <- vrfmrg(
    c(x, "Other"),
    c(White = 3, Black = 2, Indigenous = 1),
    strict = FALSE
  )
  expect_false(r2$ok)
  expect_match(r2$message, "not in the published")
  cb <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
  rotated <- structure(
    c(1, 1, 2, 4, 1),
    labels = c(Black = 1, Other = 2, Unknown = 3, White = 4)
  )
  t <- xfrvrf(
    rotated,
    c(White = 3, Black = 1, Unknown = 1),
    codebook = cb,
    strict = FALSE
  )
  expect_false(t$ok)
  expect_false(t$code_book_ok)
  expect_true(any(grepl("code book", t$reasons, fixed = TRUE)))
  # the forensics input is reachable from the public path now
  t2 <- xfrvrf(
    c("Black", "White", "White", "Black", "Black"),
    c(White = 3, Black = 2),
    strict = FALSE
  )
  expect_false(t2$ok)
  expect_identical(unname(t2$marginals$permutation[["White"]]), "Black")
  expect_error(
    xfrvrf(
      c("Black", "White", "White", "Black", "Black"),
      c(White = 3, Black = 2)
    ),
    "do not match"
  )
})

test_that("rlblfrns reports identity as no permutation", {
  vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
  r <- rlblfrns(
    vl,
    c(White = "White", Black = "Black", Other = "Other", Unknown = "Unknown")
  )
  expect_false(any(r$matches))
  expect_match(attr(r, "verdict"), "no permutation")
  expect_output(print(r), "No mechanism")
})

test_that("categorical guard errors name the arguments as written", {
  f <- function() 1
  expect_error(grdlvls("a", "a", ref = f), "grdlvls: `ref` must be data")
  expect_error(rlblfrns(f, NULL, NULL), "rlblfrns: `vlabs` must be data")
  expect_error(rlblfrns(NULL, f, NULL), "rlblfrns: `obs` must be data")
  expect_error(rlblfrns(NULL, NULL, f), "rlblfrns: `cnts` must be data")
  expect_error(vrfrcdmnf("p", NULL, f), "vrfrcdmnf: `recd` must be data")
  expect_error(xfrvrf(NULL, NULL, f), "xfrvrf: `codebook` must be data")
  expect_error(
    rcdmnf(NULL, NULL, NULL, NULL, NULL, ctx = f),
    "rcdmnf: `ctx` must be data"
  )
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("the categorical guards' results print as boxes", {
  a <- audcats(data.frame(g = factor(c("b", "a", "b"))))
  o1_expect_box(o1_box(a), a, "Categorical audit", c("1 column(s)", "g"))
  x <- c("W", "B", "W")
  y <- grdrcd(x, c(W = "White", B = "Black"))
  m <- rcdmnf(x, y, c(W = "White", B = "Black"))
  b <- o1_box(m)
  o1_expect_box(
    b,
    m,
    "Recode manifest",
    c("unsigned", "White", "3 (0 missing)")
  )
  expect_true(any(grepl("crosstab is function", b$out, fixed = TRUE)))
  expect_true(any(grepl("(not checked)", b$out, fixed = TRUE)))
  p <- wrrcdmnf(m, tempfile(fileext = ".json"))
  v <- vrfrcdmnf(p, x, y)
  expect_s3_class(v, "rmbl_recode_manifest_check")
  o1_expect_box(o1_box(v), v, "Recode manifest check", "VERIFIED")
  v$ok <- FALSE
  v$reasons <- "counts changed"
  expect_true(any(grepl("counts changed", o1_box(v)$out, fixed = TRUE)))
  mc <- vrfmrg(c("a", "b", "b"), c(a = 1, b = 2))
  expect_s3_class(mc, "rmbl_margin_check")
  o1_expect_box(o1_box(mc), mc, "Published counts check", "the counts match")
  sw <- vrfmrg(c("a", "b", "b"), c(a = 2, b = 1), strict = FALSE)
  expect_true(any(grepl("NOT VERIFIED", o1_box(sw)$out, fixed = TRUE)))
  ex <- vrfmrg(c("a", "z"), c(a = 1), strict = FALSE)
  expect_s3_class(ex, "rmbl_margin_check")
  tab <- matrix(c(900, 100, 700, 300, 400, 600), ncol = 2, byrow = TRUE,
    dimnames = list(c("A", "B", "C"), c("no", "yes")))
  oc <- orchk(tab, "A", c(B = 13.5, C = 3.857))
  expect_s3_class(oc, "rmbl_or_check")
  b2 <- o1_box(oc)
  o1_expect_box(b2, oc, "Reported odds ratios check", "NOT consistent")
  expect_true(any(grepl("fits under", b2$out, fixed = TRUE)))
  xf <- xfrvrf(c("a", "b", "b"), c(a = 1, b = 2))
  expect_s3_class(xf, "rmbl_transfer_check")
  o1_expect_box(o1_box(xf), xf, "Transferred variable check", "VERIFIED")
  vl <- c("1" = "a", "2" = "b")
  r <- rlblfrns(vl, c(a = "b", b = "a"))
  o1_expect_box(o1_box(r), r, "Relabelling forensics", "Mechanisms tried")
})

test_that("the categorical checks without their columns print plainly", {
  expect_plain_df("bricklayer_category_audit")
  expect_plain_df("bricklayer_relabel_forensics")
})

test_that("the categorical check boxes say what agrees and what does not", {
  orc <- structure(
    list(
      matches = NULL, consistent = TRUE, computed = c(a = 1.5),
      reported = c(a = 1.5), verdict = "The reported values fit."
    ),
    class = c("rmbl_or_check", "list")
  )
  expect_match(box_text(orc), "consistent with the table as labelled",
    fixed = TRUE)
  mnf <- structure(
    list(
      checks = list(rows_kept = TRUE, codes_known = NA, all_mapped = FALSE),
      context = "",
      created = "2026-01-01", n = 3L, n_missing = 0L,
      mapping = list(`1` = "a"), mapping_sha256 = "ab", body_sha256 = "cd"
    ),
    class = c("bricklayer_recode_manifest", "list")
  )
  txt <- box_text(mnf)
  expect_match(txt, "ok rows kept", fixed = TRUE)
  expect_match(txt, "-- codes known (not checked)", fixed = TRUE)
  expect_match(txt, "FAIL all mapped", fixed = TRUE)
  chk <- function(sig) {
    structure(
      list(ok = TRUE, signature_ok = sig, manifest = list(created = "d")),
      class = c("rmbl_recode_manifest_check", "list")
    )
  }
  expect_match(box_text(chk(TRUE)), "Signature verified", fixed = TRUE)
  expect_match(box_text(chk(FALSE)), "Signature does not verify",
    fixed = TRUE)
  tr <- function(cb) {
    structure(
      list(ok = FALSE, code_book_ok = cb, decoded = 1:3, marginals = NULL),
      class = c("rmbl_transfer_check", "list")
    )
  }
  t1 <- box_text(tr(TRUE))
  expect_match(t1, "Code book agrees", fixed = TRUE)
  expect_match(t1, "do not reproduce what the source program reported",
    fixed = TRUE)
  expect_match(box_text(tr(FALSE)), "Code book disagrees", fixed = TRUE)
})

test_that("reports and messages stay readable where Unicode is not shown", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  d <- withr::local_tempdir()
  md <- format(cpschk(d, "drift", fp = FALSE), fmt = "md")
  expect_true(all(charToRaw(md) < as.raw(128)))
  expect_match(md, "OK No manifests found", fixed = TRUE)
  expect_true(endsWith(md, "\n"))
  e <- tryCatch(grdrcd(c("W", "X"), c(W = "White")), error = conditionMessage)
  expect_false(grepl("‘|<U\\+", e))
  expect_identical(.rmbl_squote("a"), "'a'")
  expect_identical(.rmbl_sym("✔ pass · χ² ≥ 1\nMétis"),
                   "OK pass - chi2 >= 1\nMetis")
  withr::local_envvar(RMBL_ASCII_ONLY = "")
  if (isTRUE(l10n_info()[["UTF-8"]])) {
    expect_identical(.rmbl_squote("a"), "‘a’")
  }
})
