# cran-comments.md — rmoriebricklayer 0.3.6

NOTE: the text below the marker is what gets pasted into the CRAN form's
comment field. Keep each paragraph on ONE line — the form re-wraps at its
own width, and pre-wrapped text comes out mangled (seen on the 0.3.5
submission).

<!-- SUBMISSION COMMENT START -->
Resubmission. The 0.3.5 manual inspection flagged a possibly-invalid file URI: README.md linked CODE_OF_CONDUCT.md, which is .Rbuildignore'd and so absent from the tarball. 0.3.6 makes that link an absolute URL (and quotes 'Wayback Machine' in DESCRIPTION, flagged by the incoming pretest spell check). No code changes.

Earlier reviewer round (K. Lauseker, 0.3.0) was addressed in 0.3.4: CKAN and SHA-256 spelled out and web services linked in DESCRIPTION; \dontrun -> \donttest; no setwd()/install.packages() calls; informational output uses message() so it can be suppressed; RNG state saved and restored around the one internal set.seed().
<!-- SUBMISSION COMMENT END -->

