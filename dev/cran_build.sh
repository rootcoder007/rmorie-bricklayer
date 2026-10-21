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
rsync -a --exclude .git --exclude '.Rd2pdf*' --exclude 'src/*.o' --exclude 'src/*.so' "$src/" "$out/$pkg/"
cd "$out/$pkg"
for p in rmoriebricklayer rmoriedata rmorie; do
  for f in README.md inst/CITATION CITATION.cff; do
    # the citation and the install pointer go to the CRAN page; the r-universe badge keeps its own link
    [ -f "$f" ] && sed -i "/badges\//! s|https://rootcoder007.r-universe.dev/$p\b|https://CRAN.R-project.org/package=$p|g" "$f"
  done
done
# CRAN does not know the Remotes field (its sibling pins are for r-universe and GitHub installs)
python3 - <<'PY'
import re
s = open("DESCRIPTION", encoding="utf-8").read()
s = re.sub(r"^Remotes:.*?(?=^[A-Z][A-Za-z/]*:|\Z)", "", s, flags=re.S | re.M)
open("DESCRIPTION", "w", encoding="utf-8").write(s)
PY
if [ "$pkg" = rmoriebricklayer ]; then
  printf '^tests/testthat/vectors$\n^tests/testthat/wycheproof-.*\\.txt$\n' >> .Rbuildignore
fi
cd "$out"
NOT_CRAN=true R CMD build "$pkg" > "$out/build_$pkg.log" 2>&1
ls -la "$out"/${pkg}_*.tar.gz | awk '{printf "%s %.2f MiB\n", $9, $5/1048576}'
grep -c "r-universe.dev/$pkg" "$out/$pkg/README.md" || true
