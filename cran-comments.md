# cran-comments.md: rmoriebricklayer 0.3.7

NOTE: the text below the marker is what gets pasted into the CRAN form's
comment field. Keep each paragraph on ONE line. The form re-wraps at its
own width, and pre-wrapped text comes out mangled (seen on the 0.3.5
submission).

<!-- SUBMISSION COMMENT START -->
Resubmission. The previous manual inspection flagged a possibly-invalid file URI: README.md linked CODE_OF_CONDUCT.md, which is .Rbuildignore'd and so absent from the tarball. That link is now an absolute URL, and 'Wayback Machine' is quoted in DESCRIPTION as flagged by the incoming pretest spell check.

The earlier reviewer round (K. Lauseker) is addressed: CKAN is spelled out as Comprehensive Knowledge Archive Network and SHA-256 as Secure Hash Algorithm 256 in DESCRIPTION, with the web services linked in angle brackets; \dontrun replaced by \donttest; no setwd(), install.packages() or installed.packages() calls anywhere in the package; informational output uses message() so it can be suppressed; RNG state is saved and restored around the one internal set.seed().

0.3.7 differs from 0.3.6 only in tests: two mocked-binding tests now skip cleanly when run outside a loaded package namespace. No user-facing or code change.
<!-- SUBMISSION COMMENT END -->

