# inst/fuzz — libFuzzer targets

Coverage-guided fuzzing of the parsers that read bytes from outside the
process: the DER parser and the RSA big-integer arithmetic (`fuzz_der.cpp`),
the decimal-to-double conversion checked bit for bit against the C library
(`fuzz_strtod.cpp`), and the SIU report parsers (`fuzz_siu.cpp`). Built with
Clang's libFuzzer plus AddressSanitizer and UndefinedBehaviorSanitizer.

`corpus/` holds small seed inputs derived from the test fixtures by
`mkcorpus.R` (DER certificates and a timestamp token as `.bin`, the
synthetic SIU report, decimal strings). They are data for the fuzzers, not
code, and nothing in the package reads them.

The package's CI runs each target for two minutes on every change and for
ten minutes weekly (`.github/workflows/fuzz.yml`). To run them yourself:

    bash inst/fuzz/build.sh        # needs R and clang++
    FUZZ_SECONDS=60 bash inst/fuzz/run.sh
