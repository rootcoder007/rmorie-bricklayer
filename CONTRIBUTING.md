# Contributing to rmoriebricklayer

Thanks for considering a contribution. This package lives or dies by
being **boring and reliable**: a reviewer should never wonder why
something is the way it is.

## Reporting bugs and asking for features

Open an issue at
<https://github.com/rootcoder007/rmorie-bricklayer/issues>. Include the
output of [`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html),
the smallest code that shows the problem, and what you expected. Issues
and pull requests are public and searchable; reports are welcome in
English.

Security problems go through the private route in
[SECURITY.md](https://rootcoder007.github.io/rmorie-bricklayer/SECURITY.md),
never a public issue.

## Scope

In scope:

- Cross-platform fixes (Linux, macOS, Windows, non-UTF-8 locales)
- New data-source resolvers (Dataverse, Zenodo, plain HTTPS); see
  [docs/data_sources.md](https://rootcoder007.github.io/rmorie-bricklayer/docs/data_sources.md)
- New synthetic-column types in `R/lib_synthetic.R`
- Clearer error messages, especially first-run failures
- Documentation, examples and vignettes

Out of scope (politely declined):

- New hard dependencies outside base R (the package imports only base R)
- Required cloud services, sign-ins, telemetry or analytics
- Docker or any other container as a required step

## How a change gets in

1.  Fork the repository and branch from `main`.
2.  Make the change, with tests (below).
3.  Run the checks in the next section.
4.  Open a pull request that says what changed and why, and paste the
    check output. CI runs on every pull request; it must be green before
    merge.
5.  The maintainer reviews every pull request. `main` keeps a linear
    history, so changes are rebased, not merged.

## Requirements for an acceptable change

- **Tests.** Every new function, argument or behaviour comes with
  testthat tests in `tests/testthat/`, and every bug fix with a test
  that fails before the fix. Coverage of changed lines is checked on
  each pull request.
- **Documentation.** Exported functions have roxygen2 documentation with
  `@param`, `@return` and a runnable `@examples` block; run
  [`roxygen2::roxygenise()`](https://roxygen2.r-lib.org/reference/roxygenize.html)
  and commit the `man/` changes. User-visible changes get a bullet in
  `NEWS.md`.
- **Style.** Base R, lines of at most 80 characters, ASCII-only R
  sources (use `\u` escapes). `lintr::lint_package()` must report
  nothing (the rules are in `.lintr`), and `goodpractice::gp()` must
  stay clean.
- **C and C++.** No new compiler warnings in `R CMD check --as-cran`;
  the sanitizer and constant-time workflows must stay green. Changes
  under `src/` also need the fuzz targets to build
  (`inst/fuzz/build.sh`).
- **Cryptography.** Only published, standardised algorithms (FIPS
  202-205, RFC 8391, SP 800-90A, RFC 3161). Changes to these files need
  the matching known-answer vectors to pass
  (`tests/testthat/test-vectors-*.R`).

## Checks to run before a pull request

``` sh
R CMD build .
R CMD check --as-cran rmoriebricklayer_*.tar.gz
Rscript -e 'lintr::lint_package()'
```

`R CMD check` runs the full test suite. For a quicker loop while
working:

``` r

devtools::test()
```

If the change touches `R/lib_synthetic.R` or the synthesis recipe
schema, also run the end-to-end bundle test:

``` sh
./dev/test_build_otis.sh
./dev/test_build_otis.sh --with-data /path/to/a01_RC.csv
```

## Code of conduct

This project is released with a [Contributor Code of
Conduct](https://rootcoder007.github.io/rmorie-bricklayer/CODE_OF_CONDUCT.md);
by taking part you agree to abide by its terms. In short: be kind. The
audience is graduate students and reviewers. If an error message is
unclear, fix the error message.

## Licence

By contributing, you agree your contribution is licensed under
AGPL-3.0-or-later, the same as the rest of the project.
