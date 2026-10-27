# mkset() boxes results from base R and other packages

ns <- asNamespace("rmoriebricklayer")

# the box of a result, as one flat string, ASCII
fbox <- function(v) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  lines <- ns$.mkset_box(v)
  expect_match(lines[1L], "^-- ")
  gsub("\\s+", " ", paste(lines, collapse = " "))
}

test_that("base R models get a box with estimates and a reading", {
  fit <- lm(mpg ~ wt + hp, data = mtcars)
  b <- fbox(fit)
  expect_match(b, "Linear model (lm)", fixed = TRUE)
  expect_match(b, "R squared 0.827", fixed = TRUE)
  expect_match(b, "Observations 32", fixed = TRUE)
  expect_match(b, "2 of 2 terms differ from zero at the 5% level", fixed = TRUE)
  expect_match(b, "wt (down)", fixed = TRUE)
  expect_match(fbox(summary(fit)), "Linear model (lm), summary", fixed = TRUE)
  lg <- glm(am ~ wt, data = mtcars, family = binomial)
  b <- fbox(lg)
  expect_match(b, "binomial, logit link", fixed = TRUE)
  expect_match(b, "OR 95% CI", fixed = TRUE)
  expect_match(b, "OR is exp(estimate)", fixed = TRUE)
  ps <- glm(carb ~ wt, data = mtcars, family = poisson)
  expect_match(fbox(ps), "RR", fixed = TRUE)
  expect_match(fbox(summary(lg)), "(glm), summary", fixed = TRUE)
  nl <- nls(mpg ~ a * exp(b * wt), data = mtcars,
            start = list(a = 40, b = -0.3))
  expect_match(fbox(nl), "Nonlinear least squares", fixed = TRUE)
  nul <- lm(mpg ~ rnorm(32), data = transform(mtcars))
  set.seed(9)
  z <- lm(y ~ x, data = data.frame(x = rnorm(30), y = rnorm(30)))
  expect_match(fbox(z), "No term differs from zero at the 5% level",
               fixed = TRUE)
  expect_type(fbox(nul), "character")
  # a model with no coefficient table falls back to its printout
  expect_match(fbox(lm(mpg ~ 0, data = mtcars)), "-- lm", fixed = TRUE)
})

test_that("tests, anova, Tukey, PCA and clusters get their own boxes", {
  b <- fbox(t.test(mpg ~ am, data = mtcars))
  expect_match(b, "Welch Two Sample t-test", fixed = TRUE)
  expect_match(b, "not consistent with the null hypothesis", fixed = TRUE)
  expect_match(b, "95% CI", fixed = TRUE)
  b <- fbox(chisq.test(matrix(c(10, 10, 10, 11), 2)))
  expect_match(b, "do not reject", fixed = TRUE)
  b <- fbox(cor.test(mtcars$mpg, mtcars$wt))
  expect_match(b, "Estimate cor", fixed = TRUE)
  b <- fbox(shapiro.test(mtcars$mpg))
  expect_match(b, "Shapiro-Wilk", fixed = TRUE)
  fit <- lm(mpg ~ wt + factor(cyl), data = mtcars)
  b <- fbox(anova(fit))
  expect_match(b, "Analysis of variance", fixed = TRUE)
  expect_match(b, "Terms that matter at the 5% level: wt", fixed = TRUE)
  a <- aov(mpg ~ factor(gear), data = mtcars)
  expect_match(fbox(a), "Analysis of variance", fixed = TRUE)
  expect_match(fbox(summary(a)), "Analysis of variance", fixed = TRUE)
  noise <- aov(y ~ g, data = data.frame(y = c(1, 3, 2, 2, 3, 1),
                                        g = rep(c("a", "b"), 3),
                                        stringsAsFactors = FALSE))
  expect_match(fbox(noise), "No term matters", fixed = TRUE)
  b <- fbox(TukeyHSD(a))
  expect_match(b, "Tukey honest significant differences", fixed = TRUE)
  bare <- structure(data.frame(Df = 1, `Sum Sq` = 2, check.names = FALSE),
                    class = c("anova", "data.frame"))
  expect_match(fbox(bare), "No term matters", fixed = TRUE)
  expect_match(b, "comparisons differ at the 5% level", fixed = TRUE)
  b <- fbox(prcomp(mtcars[1:4], scale. = TRUE))
  expect_match(b, "Principal components", fixed = TRUE)
  expect_match(b, "The first two components hold", fixed = TRUE)
  set.seed(1)
  b <- fbox(kmeans(mtcars[c("mpg", "wt")], 3))
  expect_match(b, "k-means clustering", fixed = TRUE)
  expect_match(b, "Clusters 3", fixed = TRUE)
})

test_that("tables, matrices and data frames are boxed, long ones cut", {
  expect_match(fbox(table(mtcars$cyl, mtcars$gear)), "Rows 3 Columns 4",
               fixed = TRUE)
  expect_match(fbox(table(mtcars$cyl)), "Table", fixed = TRUE)
  expect_match(fbox(matrix(1:4, 2)), "Columns 3", fixed = TRUE)
  b <- fbox(mtcars)
  expect_match(b, "Rows 32 Columns 11", fixed = TRUE)
  expect_match(b, "and 2 more rows", fixed = TRUE)
})

test_that("anything else is its own printout inside a box", {
  b <- fbox(1:3)
  expect_match(b, "-- integer", fixed = TRUE)
  expect_match(b, "[1] 1 2 3", fixed = TRUE)
  long <- fbox(seq_len(2000))
  expect_match(long, "more lines", fixed = TRUE)
  expect_match(fbox(list(a = 1)), "-- list", fixed = TRUE)
  # a model whose summary has no coefficient table falls back too
  odd <- structure(list(), class = "oddmodel")
  expect_match(fbox(odd), "-- oddmodel", fixed = TRUE)
  expect_identical(ns$.fb_p(NA), "not available")
  expect_identical(ns$.fb_p(numeric()), "not available")
  expect_match(ns$.fb_kind(structure(list(), class = "foo")), "Model (foo)",
               fixed = TRUE)
})

test_that("survival, MASS and survey models get boxes", {
  skip_if_not_installed("survival")
  cx <- survival::coxph(survival::Surv(time, status) ~ age + sex,
                        data = survival::lung)
  b <- fbox(cx)
  expect_match(b, "Cox proportional hazards", fixed = TRUE)
  expect_match(b, "Events 165", fixed = TRUE)
  expect_match(b, "HR 95% CI", fixed = TRUE)
  b <- fbox(survival::survfit(survival::Surv(time, status) ~ sex,
                              data = survival::lung))
  expect_match(b, "Survival curves", fixed = TRUE)
  expect_match(b, "the time by which half had the event", fixed = TRUE)
  one <- survival::survfit(survival::Surv(time, status) ~ 1,
                           data = survival::lung)
  expect_match(fbox(one), "Groups 1", fixed = TRUE)
  few <- survival::survfit(survival::Surv(c(5, 6, 7), c(1, 0, 0)) ~ 1)
  expect_match(fbox(few), "fewer than half", fixed = TRUE)
  sr <- survival::survreg(survival::Surv(time, status) ~ age,
                          data = survival::lung)
  expect_match(fbox(sr), "Parametric survival model", fixed = TRUE)
  skip_if_not_installed("MASS")
  nb <- MASS::glm.nb(carb ~ wt, data = mtcars)
  expect_match(fbox(nb), "Negative binomial model", fixed = TRUE)
  po <- MASS::polr(factor(gear) ~ wt, data = mtcars, Hess = TRUE)
  b <- fbox(po)
  expect_match(b, "Ordinal logistic model", fixed = TRUE)
  skip_if_not_installed("survey")
  des <- survey::svydesign(ids = ~1, weights = ~1, data = mtcars)
  sv <- survey::svyglm(mpg ~ wt, design = des)
  expect_match(fbox(sv), "Survey-weighted", fixed = TRUE)
})

test_that("nlme, mgcv, nnet, lme4 and fixest models get boxes", {
  skip_if_not_installed("nlme")
  lm1 <- nlme::lme(distance ~ age, random = ~ 1 | Subject,
                   data = nlme::Orthodont)
  expect_match(fbox(lm1), "Mixed model (nlme::lme)", fixed = TRUE)
  skip_if_not_installed("mgcv")
  g <- mgcv::gam(mpg ~ s(wt) + hp, data = mtcars)
  expect_match(fbox(g), "Generalised additive model", fixed = TRUE)
  skip_if_not_installed("nnet")
  mn <- nnet::multinom(factor(gear) ~ wt, data = mtcars, trace = FALSE)
  b <- fbox(mn)
  expect_match(b, "Multinomial logit", fixed = TRUE)
  expect_match(b, "compares an outcome with the first", fixed = TRUE)
  skip_if_not_installed("lme4")
  mm <- lme4::lmer(Reaction ~ Days + (Days | Subject),
                   data = lme4::sleepstudy)
  b <- fbox(mm)
  expect_match(b, "Mixed model (lme4)", fixed = TRUE)
  expect_match(b, "reports no p-values", fixed = TRUE)
  expect_match(b, "by its 95% interval", fixed = TRUE)
  skip_if_not_installed("fixest")
  fe <- fixest::feols(mpg ~ wt | cyl, data = mtcars)
  expect_match(fbox(fe), "Fixed-effects model (fixest)", fixed = TRUE)
})

test_that("a set mixes this package's boxes and other packages' boxes", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  fit <- lm(mpg ~ wt, data = mtcars)
  s <- mkset(fit, "Gini" = ginicoef(c(3, 1, 4, 1, 5, 9)), 1:3)
  expect_identical(names(s$items)[c(1L, 3L)],
                   c("Linear model (lm)", "Result 3 (integer)"))
  out <- utils::capture.output(print(s))
  expect_true(any(grepl("^\\+-- Linear model \\(lm\\)", out)))
  expect_true(any(grepl("^\\+-- Gini coefficient", out)))
  expect_true(any(grepl("^\\+-- integer", out)))
  d <- withr::local_tempdir()
  mkset(fit, file = file.path(d, "f.md"))
  md <- readLines(file.path(d, "f.md"))
  expect_true(any(grepl("Linear model (lm)", md, fixed = TRUE)))
  expect_true(ns$.mkset_own(ginicoef(1:3)))
  expect_false(ns$.mkset_own(fit))
})
