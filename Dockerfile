# rmorie-bricklayer — a reproducible R environment with the bundling kit
# baked in. Uses Posit Public Package Manager binaries (jammy) so the image
# builds fast and deterministically rather than compiling from source.
FROM rocker/r-ver:4.4.1

# System libraries the analysis packages link against at runtime.
RUN apt-get update && apt-get install -y --no-install-recommends \
      zip unzip git ca-certificates curl \
      libcurl4-openssl-dev libssl-dev libxml2-dev \
      libfontconfig1-dev libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

# Binary R packages (the otis-mrp example's full dependency set).
RUN R -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')); \
          install.packages(c('data.table','MatchIt','glmmTMB','lme4','DHARMa','Hmisc','jsonlite','digest'))"

WORKDIR /bricklayer
COPY . /bricklayer

# Default to an interactive shell with the kit + R toolchain ready.
# Build a bundle with:  ./make_bundle.sh otis-mrp --version <v>
CMD ["bash"]
