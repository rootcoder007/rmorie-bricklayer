#!/usr/bin/env bash
# Build the CRAN submission tarball of this package: a copy of the tree in which the package
# pages point at CRAN rather than r-universe, and (rmoriebricklayer) the large test-vector
# files are left out so the tarball stays under CRAN's 5 MB; the tests that read them skip.
#   dev/cran_build.sh [output directory, default /tmp/cran]
set -eu
src=$(cd "$(dirname "$0")/.." && pwd)
pkg=$(sed -n 's/^Package: //p' "$src/DESCRIPTION")
out=${1:-/tmp/cran}
rm -rf "$out/$pkg"
mkdir -p "$out"
rsync -a --exclude .git --exclude '.Rd2pdf*' --exclude 'src/*.o' --exclude 'src/*.so' \
  --exclude '*.gcno' --exclude '*.gcda' --exclude '*.gcov' "$src/" "$out/$pkg/"
cd "$out/$pkg"
for p in rmoriebricklayer rmoriedata rmorie; do
  for f in README.md inst/CITATION CITATION.cff; do
    # the citation and the install pointer go to the CRAN page; the r-universe badge keeps its own link
    [ -f "$f" ] && sed -i "/badges\//! s|https://rootcoder007.r-universe.dev/$p\b|https://CRAN.R-project.org/package=$p|g" "$f"
  done
done
# the CRAN copy cites the CRAN page: inst/CITATION whatever the copy is
# installed from, and the citations in CITATION.cff and the README
PKG="$pkg" python3 - <<'PY'
import os, re
pkg = os.environ["PKG"]
cran = "https://CRAN.R-project.org/package=" + pkg
gh = re.compile(r"https://github\.com/rootcoder007/[A-Za-z0-9._-]+")
ru = re.compile(r"https://rootcoder007\.r-universe\.dev/" + re.escape(pkg) + r"\b")
def cite(s):
    return ru.sub(cran, gh.sub(cran, s))
if os.path.exists("inst/CITATION"):
    s = open("inst/CITATION", encoding="utf-8").read()
    open("inst/CITATION", "w", encoding="utf-8").write(cite(s))
if os.path.exists("CITATION.cff"):
    s = open("CITATION.cff", encoding="utf-8").read()
    s = re.sub(r'^(\s*)url: "[^"]*"', lambda m: m.group(1) + 'url: "' + cran + '"', s, flags=re.M)
    open("CITATION.cff", "w", encoding="utf-8").write(s)
if os.path.exists("README.md"):
    s = open("README.md", encoding="utf-8").read()
    i = s.find("## Citation")
    if i >= 0:
        j = s.find("\n## ", i + 3)
        j = len(s) if j < 0 else j
        s = s[:i] + cite(s[i:j]) + s[j:]
        open("README.md", "w", encoding="utf-8").write(s)
PY
# CRAN does not know the Remotes field (its sibling pins are for r-universe and GitHub installs)
python3 - <<'PY'
import re
s = open("DESCRIPTION", encoding="utf-8").read()
s = re.sub(r"^Remotes:.*?(?=^[A-Z][A-Za-z/]*:|\Z)", "", s, flags=re.S | re.M)
open("DESCRIPTION", "w", encoding="utf-8").write(s)
PY
# the 33 vignettes as five in the CRAN copy (dev/cran_merge_vignettes.py)
python3 "$src/dev/cran_merge_vignettes.py"
# every web address as plain text in the CRAN copy (dev/cran_plain_urls.py)
python3 "$src/dev/cran_plain_urls.py"
# the help pages merged by source file in the CRAN copy (dev/cran_merge_rd.R)
Rscript "$src/dev/cran_merge_rd.R" man
if [ "$pkg" = rmoriebricklayer ]; then
  # the CRAN copy runs no tests (tests/testthat.R stops on CRAN) and is not byte-compiled:
  # CRAN's Windows check is measured without the install, and both keep it inside its ten
  # minutes (win-builder R-devel, 30 Oct: 585 s); CI and r-universe run the full suite on
  # the byte-compiled package
  printf '^tests/testthat/vectors$\n^tests/testthat/wycheproof-.*\\.txt$\n' >> .Rbuildignore
  sed -i '/^ByteCompile:/d' DESCRIPTION
  printf 'ByteCompile: no\n' >> DESCRIPTION
fi
cd "$out"
NOT_CRAN=true R CMD build "$pkg" > "$out/build_$pkg.log" 2>&1
# a build artifact (an object file, a covr gcov file) is never submitted
if tar tzf "$out"/${pkg}_*.tar.gz | grep -E '[.](o|so|dll|gcno|gcda|gcov)$'; then
  echo "cran_build.sh: build artifacts in the tarball (above)" >&2
  exit 1
fi
ls -la "$out"/${pkg}_*.tar.gz | awk '{printf "%s %.2f MiB\n", $9, $5/1048576}'
grep -c "r-universe.dev/$pkg" "$out/$pkg/README.md" || true
