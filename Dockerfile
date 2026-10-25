# rmorie-bricklayer: a reproducible R environment with the bundling kit baked in, and the base of
# the rmbl GitHub Action. R packages are Posit Package Manager binaries for this image's own Ubuntu
# release (rocker's default repository), so the image builds fast without compiling them.
#
# Kept current: every build upgrades the Ubuntu packages and the R packages to their latest
# versions, and the image is rebuilt every week (docker-publish.yml). The compilers and the
# development headers needed only to build packages are removed at the end, kernel headers
# (linux-libc-dev) with them, which were most of the image's CVE reports; the shared libraries the
# installed R packages link against are kept. Install further R packages as binaries, which need
# no compiler.
FROM rocker/r-ver:4.6.1

ENV DEBIAN_FRONTEND=noninteractive

# System libraries the analysis packages link against, at their latest versions (libuv for
# fs, which the binary needs at run time and was missing).
RUN apt-get update && apt-get -y upgrade && apt-get install -y --no-install-recommends \
      zip unzip git ca-certificates curl \
      libuv1t64 \
      libcurl4-openssl-dev libssl-dev libxml2-dev \
      libfontconfig1-dev libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

# Binary R packages (the otis-mrp example's full dependency set), then every installed package
# brought to its latest version.
RUN R -e "install.packages(c('data.table','MatchIt','glmmTMB','lme4','DHARMa','Hmisc','jsonlite','digest')); \
          update.packages(ask = FALSE, checkBuilt = TRUE)"

WORKDIR /bricklayer
COPY . /bricklayer

# The package itself, so `library(rmoriebricklayer)` and `rmbl` work in the image and in the
# rmbl GitHub Action built on it.
RUN R CMD INSTALL --no-multiarch /bricklayer \
    && ln -s "$(Rscript -e 'cat(system.file("bin", "rmbl", package = "rmoriebricklayer"))')" /usr/local/bin/rmbl \
    && rmbl version

# Keep the packages that own a shared library some installed R package (or R itself) loads,
# then remove the build-only toolchain and headers. The checks after it prove the image still
# loads every package (tcltk aside: the image has no Tk) and runs rmbl.
RUN set -e; \
    libs=$(find /usr/local/lib/R /usr/local/lib/R/site-library -name '*.so' -print0 \
           | xargs -0 ldd 2>/dev/null | awk '/=> \// {print $3}' | sort -u); \
    pkgs=$(for l in $libs; do dpkg -S "$(readlink -f "$l")" 2>/dev/null || dpkg -S "$l" 2>/dev/null; done \
           | cut -d: -f1 | sort -u); \
    apt-mark manual $pkgs zip unzip git ca-certificates curl > /dev/null; \
    apt-get purge -y --auto-remove \
      libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libfreetype6-dev \
      linux-libc-dev libc6-dev gcc g++ gfortran make; \
    rm -rf /var/lib/apt/lists/*; \
    Rscript -e 'ip <- setdiff(rownames(installed.packages()), "tcltk"); for (p in ip) loadNamespace(p); cat(length(ip), "packages load\n")'; \
    rmbl version

# Default to an interactive shell with the kit and R ready.
# Build a bundle with:  ./make_bundle.sh otis-mrp --version <v>
CMD ["bash"]
