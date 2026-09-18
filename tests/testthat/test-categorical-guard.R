test_that("guard_recode maps by name, refuses unmapped, records the mapping", {
  r <- guard_recode(c("W", "B", "O", "W"),
                    c(W = "White", B = "Black", O = "Other"))
  expect_equal(as.character(r), c("White", "Black", "Other", "White"))
  expect_equal(nchar(attr(r, "recode_audit")$checksum), 64)
  expect_error(guard_recode(c("W", "X"), c(W = "White")),
               "values with NO mapping")
  expect_equal(
    as.character(guard_recode(c("W", "X", NA), c(W = "White"), keep = "X")),
    c("White", "X", NA)
  )
})

test_that("decode_codes turns codes into labels and refuses unlabelled codes", {
  d <- decode_codes(c(1, 2, 2, 3),
                    c("1" = "White", "2" = "Black", "3" = "Indigenous"))
  expect_equal(as.character(d), c("White", "Black", "Black", "Indigenous"))
  expect_error(decode_codes(c(1, 4), c("1" = "White")), "NO mapping")
})

test_that("guard_levels declares levels and the reference", {
  f <- guard_levels(c("White", "Black", "White"), c("White", "Black"), "White")
  expect_equal(as.integer(f), c(1L, 2L, 1L))
  expect_error(guard_levels(c("White", "Other"), c("White", "Black")),
               "outside the declared levels")
  expect_error(guard_levels("White", c("White", "Black"), "Black"),
               "is not levels")
})

test_that("audit_categories flags codes, case variants and unused levels", {
  a <- audit_categories(data.frame(
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

test_that("verify_recode proves a recode and names a swap", {
  expect_silent(verify_recode(c("W", "B", "W"), c("White", "Black", "White"),
                              c(W = "White", B = "Black")))
  expect_error(
    verify_recode(c("W", "B"), c("Black", "White"),
                  c(W = "White", B = "Black")),
    "THIS is how groups get swapped"
  )
  expect_error(verify_recode(c("W", "B"), "White", c(W = "White")),
               "rows were lost")
})

test_that("verify_marginals accepts matching counts and names a permutation", {
  x <- c("White", "White", "Black", "Indigenous", "White", "Black")
  expect_true(verify_marginals(x, c(White = 3, Black = 2, Indigenous = 1))$ok)
  expect_error(verify_marginals(x, c(White = 2, Black = 3, Indigenous = 1)),
               "White -> Black")
})

test_that("odds_ratio_check recovers a label swap behind an inflated OR", {
  tab <- matrix(c(900, 100, 700, 300, 400, 600),
    ncol = 2, byrow = TRUE,
    dimnames = list(c("A", "B", "C"), c("no", "yes"))
  )
  ok <- odds_ratio_check(tab, "A", c(B = 300 / 700 / (100 / 900),
                                     C = 600 / 400 / (100 / 900)))
  expect_true(ok$consistent)
  sw <- odds_ratio_check(tab, "A", c(B = 13.5, C = 3.857))
  expect_false(sw$consistent)
  expect_equal(sw$matches$relabelling[1], "B -> C, C -> B")
  expect_match(sw$verdict, "mislabelled")
  expect_equal(nrow(odds_ratio_check(tab, "A", c(B = 36, C = 4))$matches), 0)
})

test_that("guard_binary refuses categorical treatment columns", {
  expect_true(guard_binary(c(0, 1, 1, 0), "d"))
  expect_error(guard_binary(c("treated", "control"), "d"), "level INDICES")
  expect_error(guard_binary(c(0, 2), "d"), "must be binary")
})

test_that("a recode manifest records, signs, writes and verifies the chain", {
  x <- c("W", "B", "W", "I", NA)
  y <- guard_recode(x, c(W = "White", B = "Black", I = "Indigenous"))
  key <- pqc_keygen(height = 2)
  m <- recode_manifest(x, y, c(W = "White", B = "Black", I = "Indigenous"),
    published = c(White = 2, Black = 1, Indigenous = 1),
    key = key, context = "unit test"
  )
  expect_s3_class(m, "bricklayer_recode_manifest")
  expect_true(m$checks$matches_published)
  expect_equal(m$n_missing, 1)
  p <- write_recode_manifest(m, tempfile(fileext = ".json"))
  v <- verify_recode_manifest(p, x, y)
  expect_true(v$ok)
  expect_true(v$signature_ok)
  # tamper: swap two labels in the recoded data
  y2 <- as.character(y)
  y2[y2 == "Black"] <- "Indigenous"
  v2 <- verify_recode_manifest(p, x, y2)
  expect_false(v2$ok)
  expect_true(any(grepl("groups get swapped|differ from the manifest",
                        v2$reasons)))
  # tamper: edit the file
  txt <- readLines(p)
  txt <- sub("unit test", "edited", txt)
  writeLines(txt, p)
  expect_false(verify_recode_manifest(p, x, y)$ok)
  expect_error(
    recode_manifest(x, y, c(W = "White", B = "Black", I = "Indigenous"),
                    published = c(White = 1, Black = 2, Indigenous = 1)),
    "permuted"
  )
})

test_that("odds_ratio_check names the OHRC 2023 four-way rotation", {
  # White coded as Black, Black as Other, Other as Unknown, Unknown as White
  # (OHRC, Correction to "A Disparate Impact", 26 January 2023; Jung 2022).
  tab <- matrix(c(9000, 120, 2000, 220, 1500, 60, 4000, 1),
    ncol = 2, byrow = TRUE,
    dimnames = list(c("White", "Black", "Other", "Unknown"), c("no", "yes"))
  )
  ref <- 120 / 9000
  correct <- odds_ratio_check(tab, "White", c(Black = 220 / 2000 / ref,
                                              Other = 60 / 1500 / ref,
                                              Unknown = 1 / 4000 / ref))
  expect_true(correct$consistent)
  rotated <- tab[c("Unknown", "White", "Black", "Other"), ]
  rownames(rotated) <- c("White", "Black", "Other", "Unknown")
  rref <- rotated["White", 2] / rotated["White", 1]
  reported <- c(
    Black = rotated["Black", 2] / rotated["Black", 1] / rref,
    Other = rotated["Other", 2] / rotated["Other", 1] / rref,
    Unknown = rotated["Unknown", 2] / rotated["Unknown", 1] / rref
  )
  r <- odds_ratio_check(tab, "White", reported)
  expect_false(r$consistent)
  expect_true(any(grepl("Unknown -> White", r$matches$relabelling)))
  expect_gt(unname(reported["Black"]) / unname(correct$computed["Black"]), 5)
  expect_match(r$verdict, "mislabelled")
})

test_that("relabel refuses positional labels and maps by name", {
  f <- factor(c("W", "B", "O", "W"))
  expect_error(relabel(f, c("Black", "Other", "White")), "POSITION")
  g <- relabel(f, c(W = "White", B = "Black", O = "Other"))
  expect_equal(as.character(g), c("White", "Black", "Other", "White"))
  expect_equal(levels(g), c("White", "Black", "Other"))
  expect_error(relabel(f, c(W = "White")), "NO mapping")
})

test_that("decode_labelled decodes by code, levels in code order", {
  x <- structure(c(1, 2, 2, 4),
                 labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
  f <- decode_labelled(x)
  expect_equal(as.character(f), c("White", "Black", "Black", "Unknown"))
  expect_equal(levels(f), c("White", "Black", "Other", "Unknown"))
  expect_error(decode_labelled(c(1, 5), c("1" = "White")), "NO mapping")
  expect_error(decode_labelled(c(1, 2)), "NOT the categories")
})

test_that("relabel_forensics: OHRC rotation is an alphabetical relabel", {
  vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
  obs <- c(White = "Black", Black = "Other", Other = "Unknown",
           Unknown = "White")
  r <- relabel_forensics(vl, obs)
  alpha <- "labels sorted alphabetically, assigned by code position"
  expect_true(r$matches[r$mechanism == alpha])
  expect_match(attr(r, "verdict"), "reproduced EXACTLY")
  expect_output(print(r), "alphabetically")
  # what the relabel idiom actually does to those codes
  f <- factor(c(1, 2, 3, 4, 1))
  levels(f) <- sort(unname(vl))
  expect_equal(as.character(f),
               c("Black", "Other", "Unknown", "White", "Black"))
  none <- relabel_forensics(vl, c(White = "Other", Black = "White",
                                  Other = "Black", Unknown = "Unknown"))
  expect_false(any(none$matches))
  expect_match(attr(none, "verdict"), "No positional")
  expect_error(relabel_forensics(vl, c(White = "Black")), "permutation")
  fr <- relabel_forensics(vl, c(White = "White", Black = "Black",
                                Other = "Other", Unknown = "Unknown"),
    counts = c(White = 9000, Black = 2000, Other = 1500, Unknown = 60)
  )
  dec <- "labels ordered by decreasing frequency, assigned by code position"
  expect_true(fr$matches[fr$mechanism == dec])
})

test_that("audit flags code-prefixed labels", {
  a <- audit_categories(data.frame(race = c("1. White", "2. Black", "1. White"),
                                   stringsAsFactors = FALSE))
  expect_match(a$hazards[1], "code prefixes")
})

test_that("transfer_verify accepts a faithful import, names a rotated one", {
  x <- structure(c(1, 1, 2, 4, 1),
                 labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
  ok <- transfer_verify(x, c(White = 3, Black = 1, Unknown = 1),
    code_book = c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
  )
  expect_true(ok$ok)
  expect_true(ok$code_book_ok)
  expect_equal(levels(ok$decoded), c("White", "Black", "Other", "Unknown"))
  rotated <- structure(c(1, 1, 2, 4, 1),
                       labels = c(Black = 1, Other = 2, Unknown = 3, White = 4))
  expect_error(
    transfer_verify(rotated, c(White = 3, Black = 1, Unknown = 1),
      code_book = c("1" = "White", "2" = "Black", "3" = "Other",
                    "4" = "Unknown")
    ),
    "disagree with the source code book"
  )
  expect_error(
    transfer_verify(c("Black", "Black", "Other", "White", "Black"),
                    c(White = 3, Black = 1, Unknown = 1)),
    "do not match|permuted|not in the published"
  )
})

test_that("decode_codes keeps or drops NA codes as asked", {
  d <- decode_codes(c(1, NA, 2), c("1" = "White", "2" = "Black"))
  expect_equal(as.character(d), c("White", NA, "Black"))
  expect_error(decode_codes(c(1, 2), c("White", "Black")), "named character")
})

test_that("guard_recode refuses an unnamed mapping and factor input works", {
  expect_error(guard_recode(c("W", "B"), c("White", "Black")),
               "named character vector")
  r <- guard_recode(factor(c("W", "B")), c(W = "White", B = "Black"))
  expect_equal(as.character(r), c("White", "Black"))
})

test_that("audit_categories covers labelled columns, empty frames and cols", {
  lab <- structure(c(1, 2, 2), labels = c(White = 1, Black = 2),
                   class = c("haven_labelled", "vctrs_vctr", "double"))
  a <- audit_categories(data.frame(race = I(lab), n = 1:3))
  expect_match(a$hazards[a$column == "race"], "foreign value labels")
  wide <- data.frame(id = as.character(seq_len(60)), stringsAsFactors = FALSE)
  expect_match(audit_categories(wide)$hazards[1], "identifier mistaken")
  e <- audit_categories(data.frame(n = 1:3))
  expect_equal(nrow(e), 0L)
  expect_true(attr(e, "clean"))
  expect_output(print(e), "no hazards")
  only <- audit_categories(data.frame(a = c("x", "y"), b = c("1", "2"),
                                      stringsAsFactors = FALSE), cols = "a")
  expect_equal(only$column, "a")
  expect_output(print(only), "a")
})

test_that("verify_recode reports fan-out and missingness leaks", {
  expect_error(verify_recode(c("W", "W"), c("White", "Black"), c(W = "White")),
               "MULTIPLE|fan")
  expect_error(verify_recode(c("W", "B"), c("White", NA),
                             c(W = "White", B = "Black")),
               "missing")
})

test_that("verify_marginals honours a tolerance, reports mismatches", {
  x <- c("White", "White", "Black")
  expect_true(verify_marginals(x, c(White = 3, Black = 1), tolerance = 1)$ok)
  expect_error(verify_marginals(x, c(White = 5, Black = 9)), "do not match")
  expect_error(verify_marginals(x, c(3, 1)), "named numeric")
})

test_that("odds_ratio_check finds swapped outcome columns, checks input", {
  tab <- matrix(c(900, 100, 700, 300), ncol = 2, byrow = TRUE,
                dimnames = list(c("A", "B"), c("no", "yes")))
  swapped <- odds_ratio_check(tab, "A", c(B = (700 / 300) / (900 / 100)))
  expect_false(swapped$consistent)
  expect_true(any(swapped$matches$outcome_columns_swapped))
  expect_error(odds_ratio_check(tab, "Z", c(B = 1)), "not a row")
  expect_error(odds_ratio_check(tab, "A", c(C = 1)), "named by every")
  expect_error(odds_ratio_check(tab[, 1, drop = FALSE], "A", c(B = 1)),
               "k-by-2")
})

test_that("guard_binary accepts NA, refuses factors and non-binary numbers", {
  expect_true(guard_binary(c(0, 1, NA), "d"))
  expect_error(guard_binary(factor(c("a", "b")), "d"), "level INDICES")
  expect_error(guard_binary(c(0.5, 1), "d"), "binary")
})

test_that("an unsigned manifest verifies its body and reports no signature", {
  x <- c("W", "B", "W")
  y <- guard_recode(x, c(W = "White", B = "Black"))
  m <- recode_manifest(x, y, c(W = "White", B = "Black"))
  expect_null(m$signature)
  p <- write_recode_manifest(m, tempfile(fileext = ".json"))
  v <- verify_recode_manifest(p, x, y)
  expect_true(v$ok)
  expect_true(is.na(v$signature_ok))
  expect_error(write_recode_manifest(list(), tempfile()), "recode_manifest")
  expect_output(print(m), "recode")
})

test_that("a FIPS-signed manifest verifies through the fips key branch", {
  skip_if_not(exists("fips_keygen"), "no fips_keygen in this build")
  key <- tryCatch(fips_keygen(), error = function(e) NULL)
  skip_if(is.null(key), "fips backend unavailable")
  x <- c("W", "B")
  y <- guard_recode(x, c(W = "White", B = "Black"))
  m <- recode_manifest(x, y, c(W = "White", B = "Black"), key = key)
  p <- write_recode_manifest(m, tempfile(fileext = ".json"))
  expect_true(verify_recode_manifest(p, x, y)$signature_ok)
})

test_that("relabel keeps pass-through levels and refuses unmapped ones", {
  f <- factor(c("W", "B", "X"))
  g <- relabel(f, c(W = "White", B = "Black"), keep = "X")
  expect_equal(as.character(g), c("White", "Black", "X"))
  expect_true("X" %in% levels(g))
  expect_error(relabel(c("W", "Q"), c(W = "White")), "NO mapping")
})

test_that("decode_labelled takes explicit labels, refuses bad attributes", {
  d <- decode_labelled(c(2, 1), value_labels = c("1" = "White", "2" = "Black"))
  expect_equal(as.character(d), c("Black", "White"))
  expect_equal(levels(d), c("White", "Black"))
  bad <- structure(c(1, 2), labels = c(1, 2))
  expect_error(decode_labelled(bad), "no names")
  s <- decode_labelled(c("b", "a"), value_labels = c(a = "Alpha", b = "Beta"))
  expect_equal(levels(s), c("Alpha", "Beta"))
})

test_that("relabel_forensics names reversed and case-insensitive mechanisms", {
  vl <- c("1" = "b", "2" = "A", "3" = "c")
  rev_obs <- c(b = "c", A = "A", c = "b")
  r <- relabel_forensics(vl, rev_obs)
  expect_true(r$matches[r$mechanism == "labels reversed"])
  ci <- relabel_forensics(vl, c(b = "A", A = "b", c = "c"))
  ci_name <- "labels sorted case-insensitively, assigned by code position"
  expect_true(ci$matches[ci$mechanism == ci_name])
  expect_output(print(ci), "case-insensitively")
  none <- relabel_forensics(c("1" = "x", "2" = "y", "3" = "z", "4" = "w"),
                            c(x = "z", y = "x", z = "w", w = "y"))
  expect_output(print(none), "No mechanism")
  expect_error(relabel_forensics(c("x", "y"), c(x = "y", y = "x")), "named")
})

test_that("transfer_verify decodes plain codes with a code book, tolerance", {
  cb <- c("1" = "White", "2" = "Black")
  r <- transfer_verify(c(1, 1, 2), c(White = 2, Black = 1), code_book = cb)
  expect_true(r$ok)
  expect_true(is.na(r$code_book_ok))
  expect_equal(levels(r$decoded), c("White", "Black"))
  lab <- structure(c(1, 1, 2), labels = c(White = 1, Black = 2))
  t2 <- transfer_verify(lab, c(White = 3, Black = 1), tolerance = 1)
  expect_true(t2$ok)
  expect_error(transfer_verify(c("White", "Other"), c(White = 1, Black = 1)),
               "not in the published")
})

test_that("last guard branches: NA codes, non-frame, edited mapping", {
  expect_error(decode_codes(c(1, NA), c("1" = "White"), keep_na = FALSE),
               "missing codes")
  expect_error(audit_categories(list(a = 1)), "data frame")
  x <- c("W", "B")
  y <- guard_recode(x, c(W = "White", B = "Black"))
  m <- recode_manifest(x, y, c(W = "White", B = "Black"))
  p <- write_recode_manifest(m, tempfile(fileext = ".json"))
  txt <- gsub("White", "Whyte", readLines(p))
  writeLines(txt, p)
  v <- verify_recode_manifest(p, x, y)
  expect_false(v$ok)
  expect_true(any(grepl("mapping checksum", v$reasons)))
})
