# rmorie-bricklayer: a reproducible R environment with the bundling kit
# baked in, and the base of the rmbl GitHub Action.
#
# Built on Wolfi (Chainguard), a distribution made to carry as few known
# vulnerabilities as possible: its packages are rebuilt soon after each
# upstream fix. R comes from Wolfi; the R packages are built from CRAN
# source, since no binaries exist for Wolfi.
#
# Kept current: every build upgrades the Wolfi packages and installs the
# latest R packages, and the image is rebuilt every week
# (docker-publish.yml), which also scans it and refuses to push it with a
# vulnerability that has a fix. The compilers and the development headers
# are removed at the end; the shared libraries the R packages load are
# kept. To install further R packages that need compiling, add the
# toolchain back first:
#   apk add build-base gfortran R-dev
# Pinned by digest; Dependabot moves the pin weekly, and apk upgrade below
# takes the newest packages on every build.
FROM cgr.dev/chainguard/wolfi-base@sha256:0b179206ab162b12a43bacea1b525a4023e0272005c92d08555c61b1beaedc40

# Wolfi sets no locale, so R would run in C; C.UTF-8 is built into glibc
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# R, the tools the kit uses, and what the R packages need to build
RUN apk update && apk upgrade --no-cache && apk add --no-cache \
      R R-dev bash zip unzip git curl ca-certificates-bundle libuv \
      build-base gfortran cmake pkgconf \
      curl-dev openssl-dev libxml2-dev fontconfig-dev freetype-dev \
      libpng-dev harfbuzz-dev fribidi-dev libuv-dev

# The otis-mrp example's full dependency set, from CRAN source
RUN Rscript -e 'options(repos = c(CRAN = "https://cloud.r-project.org"), \
      Ncpus = parallel::detectCores()); \
    p <- c("data.table", "MatchIt", "glmmTMB", "lme4", "DHARMa", "Hmisc", \
      "jsonlite", "digest"); \
    install.packages(p); \
    m <- setdiff(p, rownames(installed.packages())); \
    if (length(m)) stop("not installed: ", toString(m))'

WORKDIR /bricklayer
COPY . /bricklayer

# The package itself, so `library(rmoriebricklayer)` and `rmbl` work in
# the image and in the rmbl GitHub Action built on it.
RUN R CMD INSTALL --no-multiarch /bricklayer \
    && bin=$(Rscript -e \
      'cat(system.file("bin", "rmbl", package = "rmoriebricklayer"))') \
    && ln -s "$bin" /usr/local/bin/rmbl \
    && rmbl version

# Remove the build-only toolchain and headers. The checks after it prove
# the image still loads every package (tcltk aside: the image has no Tk)
# and runs rmbl.
RUN apk del --no-cache build-base gfortran cmake pkgconf \
      curl-dev openssl-dev libxml2-dev fontconfig-dev freetype-dev \
      libpng-dev harfbuzz-dev fribidi-dev libuv-dev R-dev \
    && Rscript -e 'ip <- setdiff(rownames(installed.packages()), "tcltk"); \
      for (p in ip) loadNamespace(p); \
      cat(length(ip), "packages load\n")' \
    && rmbl version

# Default to an interactive shell with the kit and R ready.
# Build a bundle with:  ./make_bundle.sh otis-mrp --version <v>
CMD ["bash"]
