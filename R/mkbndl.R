## ----- Reproducibility bundles -----
## A bundle is one zip a reviewer unzips and double-clicks: the project's
## analysis script and data notes, the runner (setup_and_run.R) with the
## package files it sources, launchers for macOS, Windows and Linux, and
## rendered README / SECURITY / INSTRUCTIONS pages. Everything is built in
## R: no zip program, no Python, no shell, so it works the same on every
## platform R does.

#' Build a Reproducibility Bundle
#'
#' Packs a project folder into one zip that anyone can unzip and run with
#' a double-click: \file{START_HERE.command} on macOS, \file{START_HERE.bat}
#' on Windows, \file{start_here.sh} on Linux. The launchers find R, the
#' runner (\file{setup_and_run.R}) checks the packages the project lists,
#' finds or downloads the data (checking it against the pinned SHA-256), or
#' generates synthetic data from the project's recipe, runs the project's
#' analysis script and summarises its \file{manifest.json} in plain
#' language.
#'
#' @details
#' A project is a folder holding at least \file{config.json} and the
#' analysis script it names (default \file{analysis.R});
#' [mkbndlproj()]
#' writes a working starter. \file{data_provenance.json} pins the data
#' file (name, URL, SHA-256, licence) and may carry a
#' \code{schema$synthetic_recipe} for the offline synthetic route. Every
#' other file in the folder is copied into the bundle too, except hidden
#' files, \file{results_*} folders and zip files.
#'
#' Symbolic links are not followed: a link to a file inside the project is
#' packed as that file, and a link to a folder, or to anything outside the
#' project, is left out with a warning that names it. Files whose names
#' look like credentials are left out too, with a warning that lists them,
#' unless \code{secrets = TRUE}: \file{llm.json}, \file{credentials.json},
#' \file{secrets.yaml}, \file{token.txt}, \file{api_key*},
#' \file{id_rsa} and the other SSH private keys, \file{.env} and
#' \file{*.env}, \file{.netrc}, \file{.Renviron}, \file{.pgpass},
#' \file{kubeconfig} and \file{kube.config}, key stores (\file{.p12},
#' \file{.pfx}, \file{.jks}, \file{.ppk}), \file{.pem} or \file{.key}
#' files holding a private key, and any other file (not a data table such
#' as \file{.csv} or \file{.rds}, nor a document such as \file{.md},
#' \file{.html}, \file{.Rmd} or \file{.qmd}) whose name, split into words at
#' \samp{-}, \samp{_}, \samp{.} and spaces, has the word \code{key},
#' \code{keys}, \code{apikey}, \code{token}, \code{tokens}, \code{secret},
#' \code{secrets}, \code{credential}, \code{credentials}, \code{creds},
#' \code{password}, \code{passwords}, \code{passwd}, \code{pat} or
#' \code{adc} (\file{openai_key.txt},
#' \file{github_pat.txt}, \file{access_token}, \file{aws_credentials},
#' \file{gcloud_adc.json}, \file{keys.R}; not \file{keyboard.csv}).
#' Public keys (\file{.pub}) are packed.
#'
#' The runner calls the analysis script as
#' \code{Rscript analysis.R <data file> <results folder>}, with
#' \code{BRICKLAYER_SYNTHETIC=1} set on synthetic data. The script writes
#' \file{manifest.json} into the results folder:
#' [mkmnf()],
#' [recrd()] and
#' [wrmnfjs()] build it, and they are in the bundle (the script sources
#' them from its own folder, as the starter does), so the reviewer needs
#' only R and the packages listed in \code{r_packages}. To call other
#' functions of this package from the analysis, list
#' \code{"rmoriebricklayer"} in \code{r_packages}.
#'
#' Optional keys of \file{config.json}: \code{project} (\code{name},
#' \code{title}, \code{paper_title}, \code{work_type}, \code{author},
#' \code{contact}, \code{orcid}, \code{affiliation}, \code{supervisor},
#' \code{licence}), \code{analysis$r_script}, \code{r_packages},
#' \code{env_packages} (packages needed only when an environment variable
#' is set), \code{optional_stages} (opt-in stages with their own
#' packages), \code{synthetic_env} (another variable that turns on the
#' synthetic route), \code{data$default_candidates}, \code{network$endpoints},
#' \code{summary$what_was_done} and \code{expected} (\code{total_checks},
#' \code{pass_real}).
#'
#' Before zipping, every internal name the bundled R files call is checked
#' to be defined by a bundled file, and by one the runner itself sources
#' when the runner calls it: a bundle that would stop with
#' \dQuote{could not find function} on the reviewer's machine is refused
#' here instead.
#'
#' Nothing is written except the zip in \code{dest}; the staging folder is
#' a temporary directory removed on exit. The zip is written under a
#' temporary name in \code{dest} and renamed when it is complete, so an
#' interrupted build leaves no partial zip (and keeps the one it was to
#' replace). Send the SHA-256 that is printed to recipients separately, so
#' they can check the zip was not altered.
#'
#' Errors: \code{project} that is neither a folder nor a bundled example;
#' a project without \file{config.json} or without its analysis script; a
#' project file whose name a bundle file already uses; \code{dest} that is
#' not an existing folder; a zip that exists when \code{overwrite} is
#' \code{FALSE}; \code{data} that is not an existing file; a
#' \code{version}, or a \code{project$name} in \file{config.json}, that is
#' not a plain name (letters, digits, dot, dash and underscore, not
#' starting with a dot, no \code{..}, at most 64 characters); a bundle of
#' more than 65535 files and folders or over 4 GB (more than a plain zip
#' holds).
#'
#' @param project A project folder, or the name of an example shipped
#'   with the package (\code{"otis-mrp"}, the Ontario restrictive
#'   confinement analysis).
#' @param dest An existing folder to write the zip into.
#' @param data Optional path to the data file, copied into the bundle
#'   (under the file name the provenance pins) so it runs offline.
#'   \code{NULL} (default) leaves it out: the runner asks for it, offers
#'   to download it, or uses synthetic data.
#' @param version Version label in the zip's name, default \code{"1"}.
#' @param overwrite Replace a zip of the same name, default \code{FALSE}.
#' @param secrets Pack files whose names look like credentials (see
#'   Details), default \code{FALSE}: they are left out with a warning.
#' @return An object of class \code{rmbl_bundle}: a list with \code{path}
#'   (the zip), \code{sha256}, \code{bytes}, \code{files} (the paths
#'   inside the zip), \code{project} (the project name) and \code{data}
#'   (whether the data file is inside). It prints as a box.
#' @seealso [mkbndlproj()] for a starter project;
#' [mkmnf()] and
#' [recrd()]
#'   for the manifest the analysis writes.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # a starter project, bundled
#' proj <- file.path(tempdir(), "demo-project")
#' mkbndlproj(proj, title = "Demo analysis", author = "A. Researcher")
#' b <- mkbndl(proj, dest = tempdir(), overwrite = TRUE)
#' b
#' head(b$files)
#'
#' # the example shipped with the package
#' otis <- mkbndl("otis-mrp", dest = tempdir(), overwrite = TRUE)
#' otis$sha256
#'
#' # an existing zip is kept unless overwrite = TRUE
#' try(mkbndl(proj, dest = tempdir()))
#' @export
mkbndl <- function(
  project,
  dest,
  data = NULL,
  version = "1",
  overwrite = FALSE,
  secrets = FALSE
) {
  root <- .bndl_root()
  pdir <- .bndl_project(project, root)
  a <- .bndl_args(dest, data, version, overwrite)
  dest <- a$dest
  data <- a$data
  version <- a$version
  overwrite <- a$overwrite
  secrets <- .rmbl_flag1(secrets, "secrets")
  cfg <- .bndl_read(file.path(pdir, "config.json"))
  prov <- .bndl_read(file.path(pdir, "data_provenance.json"))
  name <- .bndl_zipname(cfg, pdir)
  base <- paste0(name, "_v", version, if (!is.null(data)) "_with_data")
  zip <- file.path(normalizePath(dest, winslash = "/"), paste0(base, ".zip"))
  if (file.exists(zip) && !overwrite) {
    stop(
      sprintf("%s exists: pass overwrite = TRUE to replace it", zip),
      call. = FALSE
    )
  }
  tmp <- tempfile("bndl")
  on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
  .bndl_build(file.path(tmp, base), pdir, root, cfg, prov, secrets, data)
  files <- .bndl_commit(tmp, base, zip)
  out <- list(
    path = zip,
    sha256 = sha256file(zip),
    bytes = file.size(zip),
    files = files,
    project = name,
    data = !is.null(data)
  )
  .rmbl_cls(out, "rmbl_bundle")
}

#' Start a Reproducibility Bundle Project
#'
#' Writes a starter project that [mkbndl()] packs as it is: a
#' \file{config.json} with the project's details, a
#' \file{data_provenance.json} to pin the data file and describe
#' synthetic data, and an \file{analysis.R} that reads the data, records
#' its checks with [recrd()] and writes \file{manifest.json}. Edit the
#' three files for the real project; the starter runs from the first
#' build, on synthetic data, so every step can be tried before the
#' analysis is written.
#'
#' @details
#' The starter's data is a CSV with columns \code{group} and
#' \code{value}; its one check is the row count, so the first run on
#' synthetic data shows one INFO. Set \code{resource$filename},
#' \code{resource$direct_url} and \code{resource$sha256} in
#' \file{data_provenance.json} (see
#' [sha256file()]) and the runner finds,
#' downloads and checks the real file.
#'
#' Errors: \code{dir} holding any of the three files when
#' \code{overwrite} is \code{FALSE}; a \code{name} with characters other
#' than letters, digits, dot, dash and underscore, one that starts with a
#' dot or holds \code{..}, or one longer than 64 characters.
#'
#' @param dir Folder for the project, created if needed.
#' @param name Short project name used in the zip's name, default the
#'   folder's name.
#' @param title Title shown in the bundle's pages, default \code{name}.
#' @param author,contact Who the reviewer contacts; default empty.
#' @param overwrite Replace starter files that exist, default
#'   \code{FALSE}.
#' @return An object of class \code{rmbl_bundle_project}: a list with
#'   \code{dir} and \code{files} (the files written). It prints as a box.
#' @seealso [mkbndl()] to build the bundle.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- mkbndlproj(file.path(tempdir(), "my-study"), title = "My study")
#' p
#' readLines(file.path(p$dir, "analysis.R"), n = 5)
#'
#' # files are kept unless overwrite = TRUE
#' try(mkbndlproj(p$dir))
#' @export
mkbndlproj <- function(
  dir,
  name = basename(dir),
  title = name,
  author = "",
  contact = "",
  overwrite = FALSE
) {
  dir <- .rmbl_string1(dir, "dir")
  name <- .bndl_name(.rmbl_string1(name, "name"), "`name`")
  title <- .rmbl_string1(title, "title")
  author <- .bndl_text(author, "author")
  contact <- .bndl_text(contact, "contact")
  overwrite <- .rmbl_flag1(overwrite, "overwrite")
  files <- c("config.json", "data_provenance.json", "analysis.R")
  there <- files[file.exists(file.path(dir, files))]
  if (length(there) && !overwrite) {
    stop(
      sprintf(
        "%s already holds %s: pass overwrite = TRUE to replace",
        dir,
        toString(there)
      ),
      call. = FALSE
    )
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  skel <- file.path(.bndl_root(), "skeleton")
  subs <- list(
    name = name,
    title = title,
    author = author,
    contact = contact
  )
  for (f in files) {
    txt <- .bndl_read_text(file.path(skel, paste0(f, ".tmpl")))
    esc <- if (f == "analysis.R") .bndl_r_str else .bndl_json_str
    txt <- .bndl_fill(txt, lapply(subs, esc))
    .bndl_write_text(txt, file.path(dir, f))
  }
  out <- list(
    dir = normalizePath(dir, winslash = "/"),
    files = files
  )
  .rmbl_cls(out, "rmbl_bundle_project")
}

#' @export
format.rmbl_bundle <- function(x, ...) {
  .an_block(
    "Reproducibility bundle",
    facts = list(
      Project = x$project,
      Zip = basename(x$path),
      Folder = dirname(x$path),
      Size = .bndl_size(x$bytes),
      Files = length(x$files[!endsWith(x$files, "/")]),
      `Data file` = if (isTRUE(x$data)) "inside" else "not inside",
      `SHA-256` = x$sha256
    ),
    reading = c(
      paste(
        "Recipients unzip it and double-click START_HERE.command (macOS)",
        "or START_HERE.bat (Windows), or run ./start_here.sh (Linux)."
      ),
      if (!isTRUE(x$data)) {
        paste(
          "The data file is not inside: the runner finds it, downloads",
          "it and checks its SHA-256, or runs on synthetic data."
        )
      }
    ),
    notes = paste(
      "Send the SHA-256 separately from the zip, so recipients can check",
      "the copy they received was not altered."
    )
  )
}

#' @export
format.rmbl_bundle_project <- function(x, ...) {
  .an_block(
    "Bundle project",
    facts = list(Folder = x$dir, Files = toString(x$files)),
    reading = c(
      paste(
        "Edit config.json (who and what), data_provenance.json (the data",
        "file, its URL and SHA-256) and analysis.R (the checks), then",
        "build the zip with mkbndl()."
      ),
      paste(
        "It runs as it is on synthetic data, so the bundle can be tried",
        "before the analysis is written."
      )
    )
  )
}

#' The zip's name and the folder inside it: a plain name, never a path.
#' @param cfg The parsed config.json.
#' @param pdir The project folder.
#' @return A character string.
#' @noRd
.bndl_zipname <- function(cfg, pdir) {
  name <- .bndl_get(cfg, c("project", "name"), "")
  if (nzchar(name)) {
    .bndl_name(name, "project$name in config.json")
  } else {
    .bndl_name(gsub("[^A-Za-z0-9._-]", "_", sub("^[.]+", "", basename(pdir))),
               "the project folder's name")
  }
}

#' Stage a bundle's files and pages, and refuse one that would fail.
#' @param stage The folder to fill (created here).
#' @param pdir The project folder.
#' @param root The package's bundle template folder.
#' @param cfg The parsed config.json.
#' @param prov The parsed data_provenance.json.
#' @param secrets Whether files that look like credentials go in.
#' @param data The data file, or NULL.
#' @return NULL, invisibly.
#' @noRd
.bndl_build <- function(stage, pdir, root, cfg, prov, secrets, data) {
  dir.create(stage, recursive = TRUE)
  .bndl_stage(stage, pdir, root, cfg, secrets)
  subs <- .bndl_subs(cfg, prov, paste0(basename(stage), ".zip"))
  .bndl_pages(stage, root, subs, data, prov)
  bad <- .bndl_scan(stage)
  if (length(bad)) {
    stop(
      "the bundle would fail on the reviewer's machine:\n  ",
      paste(bad, collapse = "\n  "),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Write the zip under a temporary name and rename it once complete: an
#' interrupted build (Ctrl-C) leaves no partial zip, and keeps the old one.
#' @param tmp The staging folder.
#' @param base The folder inside the zip.
#' @param zip The zip's final path.
#' @return The paths inside the zip.
#' @noRd
.bndl_commit <- function(tmp, base, zip) {
  part <- tempfile(paste0(base, "_"), tmpdir = dirname(zip), fileext = ".part")
  on.exit(unlink(part, force = TRUE), add = TRUE)
  files <- .bndl_zip(tmp, base, part)
  if (!file.rename(part, zip)) {
    unlink(zip)
    if (!file.rename(part, zip)) {
      stop(sprintf("could not write %s", zip), call. = FALSE)
    }
  }
  files
}

#' mkbndl()'s arguments, checked.
#' @param dest,data,version,overwrite As for mkbndl().
#' @return A list of the four.
#' @noRd
.bndl_args <- function(dest, data, version, overwrite) {
  dest <- .rmbl_string1(dest, "dest")
  if (!dir.exists(dest)) {
    stop(sprintf("`dest` is not an existing folder: %s", dest), call. = FALSE)
  }
  if (!is.null(data)) data <- .rmbl_file1(data, "data")
  version <- .bndl_name(.rmbl_string1(version, "version"), "`version`")
  list(
    dest = dest,
    data = data,
    version = version,
    overwrite = .rmbl_flag1(overwrite, "overwrite")
  )
}

#' A name that becomes part of a file name: letters, digits, dot, dash and
#' underscore, not starting with a dot, without "..", at most 64
#' characters. A name from config.json with a slash wrote the zip outside
#' `dest`, and its entries began with "../".
#' @param x The name.
#' @param what What it is, for the error message.
#' @return `x`.
#' @noRd
.bndl_name <- function(x, what) {
  if (!.bndl_plain(x)) {
    stop(
      sprintf(
        paste0(
          "%s may hold only letters, digits, '.', '-' and '_' (not first ",
          "a dot, no '..', at most 64 characters): %s"
        ),
        what,
        .rmbl_printable(substr(paste(as.character(x), collapse = " "),
                               1L, 80L))
      ),
      call. = FALSE
    )
  }
  x
}

#' Whether a name is plain, as .bndl_name() wants it.
#' @param x The name.
#' @return TRUE or FALSE.
#' @noRd
.bndl_plain <- function(x) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    return(FALSE)
  }
  grepl("^[A-Za-z0-9_-][A-Za-z0-9._-]*$", x) &
    !grepl("..", x, fixed = TRUE) & nchar(x) <= 64L
}

#' The folder of bundle parts installed with the package.
#' @return A path.
#' @noRd
.bndl_root <- function() {
  system.file("bundle", package = "rmoriebricklayer", mustWork = TRUE)
}

#' The folder holding the package R files a bundle ships.
#'
#' An installed package carries copies made by configure in bundle/lib; a
#' package loaded from its source folder has none, and R/ beside inst/ is
#' read instead.
#' @param root The bundle folder.
#' @return A path.
#' @noRd
.bndl_lib_dir <- function(root) {
  lib <- file.path(root, "lib")
  if (length(list.files(lib, pattern = "[.]R$"))) {
    return(lib)
  }
  src <- file.path(root, "..", "..", "R")
  if (file.exists(file.path(src, "mkbndl.R"))) {
    return(normalizePath(src, winslash = "/"))
  }
  stop(
    "this installation has no bundle library (bundle/lib): reinstall",
    " rmoriebricklayer from source so configure can copy it",
    call. = FALSE
  )
}

#' The package R files a bundle ships, from bundle/lib.txt.
#' @param root The bundle folder.
#' @return File names, in the order the runner sources them.
#' @noRd
.bndl_lib_files <- function(root) {
  x <- trimws(readLines(file.path(root, "lib.txt"), warn = FALSE))
  x[nzchar(x) & !startsWith(x, "#")]
}

#' The project folder `project` names.
#' @param project A folder, or the name of a shipped example.
#' @param root The bundle folder.
#' @return A normalised path holding config.json.
#' @noRd
.bndl_project <- function(project, root) {
  project <- .rmbl_string1(project, "project")
  shipped <- file.path(root, project)
  pdir <- if (dir.exists(project)) {
    project
  } else if (
    !grepl("[/\\\\]", project) &&
      file.exists(file.path(shipped, "config.json"))
  ) {
    shipped
  } else {
    ex <- basename(dirname(Sys.glob(file.path(root, "*", "config.json"))))
    stop(
      sprintf(
        "`project` is neither a folder nor a shipped example (%s): %s",
        toString(setdiff(ex, "skeleton")),
        project
      ),
      call. = FALSE
    )
  }
  if (!file.exists(file.path(pdir, "config.json"))) {
    stop(
      sprintf("no config.json in the project folder: %s", pdir),
      call. = FALSE
    )
  }
  normalizePath(pdir, winslash = "/")
}

#' A JSON file as a plain nested list, or an empty list when absent.
#' @param path A path.
#' @return A list.
#' @noRd
.bndl_read <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }
  x <- .rmbl_read_json(path, simplify = FALSE)
  if (is.list(x)) unclass(x) else list()
}

#' One string from a nested list, or a default.
#' @param x A nested list.
#' @param keys The path of names.
#' @param default Returned for a missing, empty or non-scalar value.
#' @return One string.
#' @noRd
.bndl_get <- function(x, keys, default = "") {
  for (k in keys) {
    x <- if (is.list(x)) x[[k]] else NULL
  }
  if (is.list(x)) x <- unlist(x)
  if (length(x) != 1L || is.na(x) || !nzchar(as.character(x))) {
    return(default)
  }
  as.character(x)
}

#' Copies the runner, its R files, the launchers and the project's files.
#' @param stage The staging folder.
#' @param pdir The project folder.
#' @param root The bundle folder.
#' @param cfg The project's config.
#' @param secrets Whether files that look like credentials are packed.
#' @return Nothing useful.
#' @noRd
.bndl_stage <- function(stage, pdir, root, cfg, secrets = FALSE) {
  lib <- .bndl_lib_dir(root)
  scripts <- system.file("scripts", package = "rmoriebricklayer")
  parts <- c(
    file.path(lib, .bndl_lib_files(root)),
    file.path(scripts, c("lib_interactive.R", "setup_and_run.R")),
    list.files(file.path(root, "launchers"), full.names = TRUE)
  )
  own <- c(basename(parts), .bndl_pages_names())
  proj <- .bndl_project_files(pdir, secrets)
  clash <- intersect(proj, own)
  if (length(clash)) {
    stop(
      sprintf(
        "project files use names the bundle needs (%s): rename them",
        toString(clash)
      ),
      call. = FALSE
    )
  }
  script <- .bndl_get(cfg, c("analysis", "r_script"), "analysis.R")
  if (!script %in% proj) {
    stop(
      sprintf("the analysis script %s is not in %s", script, pdir),
      call. = FALSE
    )
  }
  # counted before anything is copied (at least these many entries: the
  # folder, the runner's files, the project's files and their folders)
  .bndl_toomany(1L + length(parts) + length(proj) + length(.bndl_dirs(proj)))
  file.copy(parts, stage, copy.date = TRUE)
  for (f in proj) {
    to <- file.path(stage, f)
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(pdir, f), to, copy.date = TRUE)
  }
  invisible(NULL)
}

#' The project's files a bundle carries, relative to the project folder.
#'
#' Symbolic links are not followed (a link to a file inside the project is
#' kept); links out of the project or to folders, and, unless `secrets`,
#' files that look like credentials, are left out with a warning.
#' @param pdir The project folder.
#' @param secrets Whether files that look like credentials are kept.
#' @return Relative paths.
#' @noRd
.bndl_project_files <- function(pdir, secrets = FALSE) {
  # counted first, in one listing a folder: the walk below checks every
  # entry for links and credentials, which took minutes on 66,000 files
  .bndl_toomany(.bndl_count(pdir))
  w <- .bndl_walk(pdir)
  f <- w$files
  keep <- !grepl("(^|/)results_[^/]*(/|$)", f) & !grepl("[.]zip$", f)
  f <- f[keep]
  if (length(w$links)) {
    warning(
      "mkbndl: not packed, symbolic links to a folder or out of the ",
      "project: ", toString(w$links),
      call. = FALSE
    )
  }
  sec <- if (isTRUE(secrets)) {
    logical(length(f))
  } else {
    vapply(file.path(pdir, f), .bndl_secret, NA, USE.NAMES = FALSE)
  }
  if (any(sec)) {
    warning(
      "mkbndl: not packed, files that look like credentials (pass ",
      "secrets = TRUE to pack them): ", toString(f[sec]),
      call. = FALSE
    )
  }
  f[!sec]
}

#' The files under a folder, without following symbolic links.
#'
#' list.files() follows links, so a link to /etc or to a file outside the
#' project was packed. Hidden files and folders are skipped, as before.
#' @param pdir The project folder.
#' @return A list: files (relative paths, sorted) and links (the links left
#'   out: to a folder, or resolving outside the project).
#' @noRd
.bndl_walk <- function(pdir) {
  top <- normalizePath(pdir, winslash = "/")
  got <- list(file = character(), link = character(), dir = character())
  todo <- ""
  while (length(todo)) {
    rel <- todo[[1L]]
    todo <- todo[-1L]
    here <- if (nzchar(rel)) file.path(top, rel) else top
    for (nm in list.files(here, all.files = FALSE, no.. = TRUE)) {
      r <- if (nzchar(rel)) file.path(rel, nm) else nm
      k <- .bndl_kind(top, r)
      got[[k]] <- c(got[[k]], r)
      if (k == "dir") todo <- c(todo, r)
    }
  }
  list(files = sort(got$file), links = sort(got$link))
}

#' What one entry under a project is for .bndl_walk(): a file to pack, a
#' folder to walk, or a link that is left out (to a folder, or out of the
#' project). A link to a file inside the project is a file.
#' @param top The normalised project folder.
#' @param r The entry, relative to it.
#' @return "file", "dir" or "link".
#' @noRd
.bndl_kind <- function(top, r) {
  full <- file.path(top, r)
  isdir <- dir.exists(full)
  inside <- startsWith(
    normalizePath(full, winslash = "/", mustWork = FALSE),
    paste0(sub("/$", "", top), "/")
  )
  if (!nzchar(Sys.readlink(full)) && inside) {
    return(if (isdir) "dir" else "file")
  }
  if (!isdir && file.exists(full) && inside) "file" else "link"
}

#' Whether a file looks like it holds credentials: by its name, and for a
#' .pem or .key file by a private key inside.
#' @param path The file.
#' @return TRUE or FALSE.
#' @noRd
.bndl_secret <- function(path) {
  b <- tolower(basename(path))
  if (endsWith(b, ".pub")) {
    return(FALSE)
  }
  pats <- c(
    paste0(
      "^(llm|credentials?|secrets?|tokens?|passwords?|auth)([-_.][^.]*)?",
      "[.](json|ya?ml|toml|txt|ini|cfg|conf|env)$"
    ),
    "^(credentials?|secrets?)$",
    "^api[-_]?keys?([-_.].*)?$",
    "^client[-_]?secret.*$",
    "^service[-_]?account.*[.]json$",
    "^id_(rsa|dsa|ecdsa|ed25519)([-_.].*)?$",
    "^[._]?(env|netrc|pgpass|npmrc|pypirc|renviron|git-credentials)$",
    "^[._]?env[.].*$",
    "[.]env$",
    "^kube[-_.]?config([-_.].*)?$",
    "[.](p12|pfx|jks|keystore|ppk|kdbx)$"
  )
  if (any(vapply(pats, grepl, NA, b)) || .bndl_secword(b)) {
    return(TRUE)
  }
  if (grepl("[.](pem|key)$", b)) {
    txt <- tryCatch(
      rawToChar(readBin(path, "raw", 65536L)),
      error = function(e) ""
    )
    return(grepl("PRIVATE KEY", txt, fixed = TRUE, useBytes = TRUE))
  }
  FALSE
}

#' Whether a file name holds a word that names a credential: split at
#' "-", "_", "." and spaces, a word such as key, token, secret, credential,
#' password, pat or adc (openai_key.txt, github_pat.txt, aws_credentials,
#' gcloud_adc.json, keys.R). A data table (.csv, .rds, ...) or a document
#' (.md, .html, .Rmd, .qmd, ...) is not judged by its words:
#' tokens_per_doc.csv is data, credentials_policy.md a text about them.
#' @param b The file's base name, in lower case.
#' @return TRUE or FALSE.
#' @noRd
.bndl_secword <- function(b) {
  data <- "[.](csv|tsv|rds|rda|rdata|parquet|feather|xlsx?|sav|dta)$"
  docs <- "[.](md|markdown|html?|rmd|qmd|rst|adoc|tex|pdf|docx?)$"
  if (grepl(data, b) || grepl(docs, b)) {
    return(FALSE)
  }
  w <- strsplit(b, "[-_. ]+")[[1L]]
  any(w %in% c(
    "key", "keys", "apikey", "apikeys", "token", "tokens", "secret",
    "secrets", "credential", "credentials", "creds", "password",
    "passwords", "passwd", "pat", "adc"
  ))
}

#' The pages a bundle renders.
#' @return File names.
#' @noRd
.bndl_pages_names <- function() {
  c("README.md", "SECURITY.md", "INSTRUCTIONS.txt", "DATA_NOTICE.md")
}

#' The values the page templates are filled with.
#' @param cfg,prov The project's config and provenance.
#' @param zipname The zip's file name.
#' @return A named list of strings.
#' @noRd
.bndl_subs <- function(cfg, prov, zipname) {
  g <- function(...) .bndl_get(cfg, c("project", ...))
  sup <- g("supervisor")
  pk <- unlist(cfg$r_packages)
  c(list(
    project_title = g("title"),
    project_name = g("name"),
    author = g("author"),
    contact = g("contact"),
    orcid = g("orcid"),
    affiliation = g("affiliation"),
    paper_title = .bndl_get(cfg, c("project", "paper_title"), g("title")),
    work_type = .bndl_get(cfg, c("project", "work_type"), "research paper"),
    supervisor_line = if (nzchar(sup)) paste0("**Supervisor:** ", sup),
    licence = .bndl_get(cfg, c("project", "licence"), "AGPL-3.0-or-later"),
    build_date = format(Sys.Date()),
    bricklayer_version = as.character(
      utils::packageVersion("rmoriebricklayer")
    ),
    bundle_filename = zipname,
    bundle_sha256 = paste(
      "(sent separately by the publisher; mkbndl() prints it when it",
      "builds the bundle)"
    ),
    packages_line = if (length(pk)) {
      paste0(
        ", and the R packages ",
        paste0("`", pk, "`", collapse = ", ")
      )
    },
    expected_block = .bndl_expected(cfg),
    network_endpoints_table = .bndl_endpoints(cfg, prov)
  ), .bndl_subs_data(prov))
}

#' The template values that describe the data file, from the provenance.
#' @param prov The project's provenance.
#' @return A named list of strings.
#' @noRd
.bndl_subs_data <- function(prov) {
  p <- function(...) .bndl_get(prov, c(...))
  lic <- p("dataset", "licence_name")
  list(
    data_licence = lic,
    licence_name = lic,
    licence_url = p("dataset", "licence_url"),
    licence_attribution = .bndl_get(
      prov,
      c("dataset", "attribution"),
      if (nzchar(lic)) {
        sprintf("Contains information licensed under the %s.", lic)
      } else {
        "See the licence of the source."
      }
    ),
    resource_name = p("resource", "name"),
    publisher = p("dataset", "publisher"),
    catalogue_url = p("dataset", "catalogue_page"),
    direct_url = p("resource", "direct_url"),
    sha256 = p("resource", "sha256"),
    size_bytes = p("resource", "size_bytes"),
    filename = p("resource", "filename"),
    retrieved_at = p("captured_at_utc")
  )
}

#' The README's paragraph on what a clean run shows.
#' @param cfg The project's config.
#' @return One string.
#' @noRd
.bndl_expected <- function(cfg) {
  tot <- .bndl_get(cfg, c("expected", "total_checks"))
  real <- .bndl_get(cfg, c("expected", "pass_real"))
  if (!nzchar(tot) || !nzchar(real)) {
    return(paste(
      "Every run writes `manifest.json` with the observed and expected",
      "value of each check and whether it passed."
    ))
  }
  paste0(
    "Expected on a clean run:\n\n",
    "- **Real data:** ", real, " of ", tot, " PASS, 0 DIFFER\n",
    "- **Synthetic data:** 0 PASS, 0 DIFFER, ", tot,
    " INFO (synthetic mode forces INFO)"
  )
}

#' The SECURITY page's list of the addresses the runner may contact.
#' @param cfg,prov The project's config and provenance.
#' @return One string, a Markdown list.
#' @noRd
.bndl_endpoints <- function(cfg, prov) {
  u <- c(
    unlist(cfg$network$endpoints),
    .bndl_get(prov, c("resource", "direct_url"))
  )
  u <- unique(u[nzchar(u)])
  if (length(prov$wayback)) {
    u <- c(u, "https://web.archive.org/ (copy kept by the Wayback Machine)")
  }
  if (!length(u)) {
    return("- none: the scripts make no network requests.")
  }
  paste0("- ", u, collapse = "\n")
}

#' Renders the README, SECURITY and INSTRUCTIONS pages, the data notice
#' and copies the data file when it travels with the bundle.
#' @param stage The staging folder.
#' @param root The bundle folder.
#' @param subs The template values.
#' @param data The data file, or NULL.
#' @param prov The bundle's provenance record.
#' @return Nothing useful.
#' @noRd
.bndl_pages <- function(stage, root, subs, data, prov) {
  pages <- .bndl_pages_names()
  if (is.null(data)) pages <- setdiff(pages, "DATA_NOTICE.md")
  for (pg in pages) {
    tm <- file.path(root, "templates", paste0(pg, ".tmpl"))
    txt <- .bndl_fill(.bndl_read_text(tm), subs)
    .bndl_write_text(txt, file.path(stage, pg))
  }
  if (!is.null(data)) {
    fn <- basename(.bndl_get(prov, c("resource", "filename"), basename(data)))
    file.copy(data, file.path(stage, fn), copy.date = TRUE)
  }
  invisible(NULL)
}

#' A text file read as one UTF-8 string.
#' @param path A path.
#' @return One string.
#' @noRd
.bndl_read_text <- function(path) {
  paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n")
}

#' Writes one string as a UTF-8 text file ending in a newline.
#' @param txt The text to write.
#' @param path The file.
#' @return Nothing useful.
#' @noRd
.bndl_write_text <- function(txt, path) {
  con <- file(path, open = "wb")
  on.exit(close(con), add = TRUE)
  writeBin(charToRaw(enc2utf8(paste0(txt, "\n"))), con)
  invisible(NULL)
}

#' Fills `{{key}}` placeholders; a NULL value leaves an empty string.
#' @param txt The template text.
#' @param subs A named list.
#' @return The text.
#' @noRd
.bndl_fill <- function(txt, subs) {
  for (k in names(subs)) {
    v <- subs[[k]]
    txt <- gsub(
      paste0("{{", k, "}}"),
      if (is.null(v)) "" else enc2utf8(as.character(v)),
      txt,
      fixed = TRUE
    )
  }
  txt
}

#' One string, or empty, for a free-text argument.
#' @param x The argument.
#' @param what Its name, for the error message.
#' @return One string.
#' @noRd
.bndl_text <- function(x, what) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be a single string", what), call. = FALSE)
  }
  x
}

#' A string as the inside of a JSON string literal.
#' @param x One string.
#' @return One string.
#' @noRd
.bndl_json_str <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("\"", "\\\"", x, fixed = TRUE)
  x <- gsub("\n", "\\n", x, fixed = TRUE)
  gsub("\t", "\\t", x, fixed = TRUE)
}

#' A string as an R string literal, quotes included.
#' @param x One string.
#' @return One string.
#' @noRd
.bndl_r_str <- function(x) {
  encodeString(x, quote = "\"")
}

#' A size in bytes for people.
#' @param n Bytes.
#' @return One string.
#' @noRd
.bndl_size <- function(n) {
  if (n < 1024) {
    return(sprintf("%d bytes", as.integer(n)))
  }
  u <- c("KB", "MB", "GB")
  i <- min(3L, floor(log(n, 1024)))
  sprintf("%.1f %s", n / 1024^i, u[i])
}

## ----- the reviewer-machine check -----

#' Names the bundle's R files call but no bundled file defines.
#'
#' Two checks. Every internal name used by any staged R file must be
#' defined by a staged R file (or be guarded by an exists() call on it,
#' or listed on a "bundle-scan-guarded:" comment line). And the files
#' setup_and_run.R sources itself must define every such name they use,
#' because the runner calls them before anything else is sourced.
#' @param dir The staging folder.
#' @return The problems, one string each; empty when there are none.
#' @noRd
.bndl_scan <- function(dir) {
  pat <- "^(\\.rmbl_|\\.an_|\\.mf_|\\.rate_|\\.rd_|core_|bricklayer_)"
  all <- .bndl_scan_files(list.files(dir, "[.]R$", full.names = TRUE), pat)
  miss <- setdiff(all$used, c(all$defined, all$guarded))
  out <- if (length(miss)) paste("called but not in the bundle:", miss)
  sr <- file.path(dir, "setup_and_run.R")
  if (file.exists(sr)) {
    libs <- .bndl_runner_libs(sr)
    run <- .bndl_scan_files(file.path(dir, libs), pat)
    rmiss <- setdiff(run$used, c(run$defined, all$guarded))
    if (length(rmiss)) {
      out <- c(out, paste("called but not sourced by the runner:", rmiss))
    }
  }
  out
}

#' The names R files define, use and guard.
#' @param files R files.
#' @param pat The pattern internal names match.
#' @return A list of three character vectors.
#' @noRd
.bndl_scan_files <- function(files, pat) {
  defined <- character()
  used <- character()
  guarded <- character()
  for (f in files[file.exists(files)]) {
    ex <- parse(f, keep.source = FALSE, encoding = "UTF-8")
    for (e in ex) {
      if (
        is.call(e) &&
          as.character(e[[1L]])[1L] %in% c("<-", "=") &&
          is.name(e[[2L]])
      ) {
        defined <- c(defined, as.character(e[[2L]]))
      }
    }
    used <- c(used, grep(pat, all.names(ex), value = TRUE))
    txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
    g <- regmatches(txt, gregexpr("exists\\(\"([^\"]+)\"", txt))[[1L]]
    guarded <- c(guarded, sub("exists\\(\"([^\"]+)\"", "\\1", g))
    a <- regmatches(txt, gregexpr("bundle-scan-guarded:[^\n]*", txt))[[1L]]
    a <- sub("bundle-scan-guarded:", "", a, fixed = TRUE)
    guarded <- c(guarded, unlist(strsplit(a, "[[:space:]]+")))
  }
  list(defined = defined, used = unique(used), guarded = guarded)
}

#' The files setup_and_run.R sources: its `for (lib in c(...))` vector.
#' @param path The runner.
#' @return File names.
#' @noRd
.bndl_runner_libs <- function(path) {
  for (e in parse(path, keep.source = FALSE, encoding = "UTF-8")) {
    if (
      is.call(e) &&
        identical(e[[1L]], as.name("for")) &&
        identical(e[[2L]], as.name("lib"))
    ) {
      return(eval(e[[3L]], baseenv()))
    }
  }
  character()
}

## ----- zip, written in R -----
## A plain zip (deflate, no zip64): what every unzip tool, Finder and
## Windows Explorer read. The launchers carry Unix mode 0755 in the
## external attributes, so they stay executable when unzipped on macOS
## or Linux whatever platform built the zip.

#' Writes `top` (a folder in `base`) as the zip `zip`.
#' @param base The folder holding `top`.
#' @param top The folder to pack; paths in the zip start with it.
#' @param zip The zip file.
#' @param limit The largest zip a plain (not zip64) archive holds.
#' @param nmax The most entries a plain zip counts (16 bits).
#' @return The paths inside the zip.
#' @noRd
.bndl_zip <- function(base, top, zip, limit = 4294967295, nmax = 65535L) {
  ents <- .bndl_ents(base, top, nmax)
  stamp <- .bndl_dos_time(Sys.time())
  con <- file(zip, open = "wb")
  on.exit(close(con), add = TRUE)
  cdir <- list()
  off <- 0
  for (p in ents) {
    e <- .bndl_zip_entry(file.path(base, p), p, stamp)
    if (off + length(e$local) + length(e$data) >= limit) {
      stop(
        "the bundle is larger than 4 GB, more than a plain zip holds",
        call. = FALSE
      )
    }
    writeBin(e$local, con)
    writeBin(e$data, con)
    cdir[[length(cdir) + 1L]] <- c(e$central, .bndl_u32(off), e$name)
    off <- off + length(e$local) + length(e$data)
  }
  cd <- unlist(cdir, use.names = FALSE)
  writeBin(cd, con)
  writeBin(.bndl_eocd(length(ents), length(cd), off), con)
  ifelse(dir.exists(file.path(base, ents)), paste0(ents, "/"), ents)
}

#' The paths a zip of `top` holds, refusing more than a plain zip counts.
#' @param base The folder holding `top`.
#' @param top The folder to pack; paths in the zip start with it.
#' @param nmax The most entries a plain zip counts (16 bits).
#' @return The paths, `top` first.
#' @noRd
.bndl_ents <- function(base, top, nmax) {
  rel <- sort(list.files(
    file.path(base, top),
    recursive = TRUE,
    all.files = TRUE,
    include.dirs = TRUE,
    no.. = TRUE
  ))
  ents <- c(top, file.path(top, rel))
  .bndl_toomany(length(ents), nmax)
  ents
}

#' Refuses more entries than a plain zip counts: the end record counts
#' entries in 16 bits (66,000 files were written with a count of 492, and
#' unzip tools saw 492).
#' @param n The number of files and folders.
#' @param nmax The most a plain zip counts.
#' @return NULL, invisibly.
#' @noRd
.bndl_toomany <- function(n, nmax = 65535L) {
  if (n > nmax) {
    stop(
      sprintf(
        "the bundle has %d files and folders, more than a plain zip holds (%d)",
        n, as.integer(nmax)
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' How many files and folders a bundle of a project holds at least: every
#' entry .bndl_walk() would see (no hidden ones), without the results_*
#' folders and zip files mkbndl() leaves out, one listing per folder and
#' no folder link followed.
#' @param pdir The project folder.
#' @return A number.
#' @noRd
.bndl_count <- function(pdir) {
  n <- 0
  todo <- pdir
  while (length(todo)) {
    e <- list.files(todo[[1L]], full.names = TRUE, no.. = TRUE)
    todo <- todo[-1L]
    e <- e[!grepl("^results_", basename(e)) & !grepl("[.]zip$", e)]
    d <- e[dir.exists(e)]
    d <- d[!nzchar(Sys.readlink(d))]
    n <- n + length(e)
    todo <- c(todo, d)
  }
  n
}

#' The folders that hold some files, every level of them.
#' @param f Relative file paths.
#' @return Relative folder paths, each once.
#' @noRd
.bndl_dirs <- function(f) {
  d <- unique(dirname(f))
  out <- character()
  d <- setdiff(d, ".")
  while (length(d)) {
    out <- c(out, d)
    d <- setdiff(unique(dirname(d)), c(".", out))
  }
  out
}

#' The end of central directory record of a plain zip.
#' @param n The number of entries.
#' @param cdlen The central directory's length in bytes.
#' @param off The central directory's offset.
#' @return A raw vector.
#' @noRd
.bndl_eocd <- function(n, cdlen, off) {
  c(
    .bndl_u32(0x06054b50),
    .bndl_u16(0),
    .bndl_u16(0),
    .bndl_u16(n),
    .bndl_u16(n),
    .bndl_u32(cdlen),
    .bndl_u32(off),
    .bndl_u16(0)
  )
}

#' One zip entry: its local header, data and the start of its central
#' directory record.
#' @param full The file on disk.
#' @param p Its path inside the zip.
#' @param stamp DOS time and date, two integers.
#' @return A list of raw vectors.
#' @noRd
.bndl_zip_entry <- function(full, p, stamp) {
  isdir <- dir.exists(full)
  name <- charToRaw(enc2utf8(if (isdir) paste0(p, "/") else p))
  if (length(name) > 65535L) {
    stop(sprintf("a path in the bundle is too long for a zip: %s",
                 substr(p, 1L, 60L)), call. = FALSE)
  }
  bytes <- if (isdir) raw() else readBin(full, "raw", file.size(full))
  crc <- if (length(bytes)) .Call(C_rmbl_crc32, bytes) else 0
  z <- .bndl_deflate(bytes)
  data <- z$data
  method <- z$method
  attr <- .bndl_attr(isdir, p)
  common <- c(
    .bndl_u16(0x0800),
    .bndl_u16(method),
    .bndl_u16(stamp[[1L]]),
    .bndl_u16(stamp[[2L]]),
    .bndl_u32(crc),
    .bndl_u32(length(data)),
    .bndl_u32(length(bytes)),
    .bndl_u16(length(name)),
    .bndl_u16(0)
  )
  list(
    local = c(.bndl_u32(0x04034b50), .bndl_u16(20), common, name),
    data = data,
    central = c(
      .bndl_u32(0x02014b50),
      .bndl_u16(0x031e),
      .bndl_u16(20),
      common,
      .bndl_u16(0),
      .bndl_u16(0),
      .bndl_u16(0),
      .bndl_u32(attr)
    ),
    name = name
  )
}

#' A file's bytes deflated when that makes them smaller, else stored.
#' @param bytes A raw vector.
#' @return A list: `data` (raw) and `method` (8 deflate, 0 stored).
#' @noRd
.bndl_deflate <- function(bytes) {
  data <- bytes
  method <- 0L
  if (length(bytes)) {
    z <- memCompress(bytes, type = "gzip")
    d <- z[3L:(length(z) - 4L)]
    if (length(d) < length(bytes)) {
      data <- d
      method <- 8L
    }
  }
  list(data = data, method = method)
}

#' The external attributes of a zip entry: Unix mode 0755 for folders
#' and launchers, 0644 for other files.
#' @param isdir Whether the entry is a folder.
#' @param p Its path inside the zip.
#' @return A number.
#' @noRd
.bndl_attr <- function(isdir, p) {
  mode <- if (isdir) {
    16877
  } else if (grepl("[.](sh|command)$", p)) {
    33261
  } else {
    33188
  }
  mode * 65536 + if (isdir) 16 else 0
}

#' A time as the DOS time and date a zip stores.
#' @param t The file time, a POSIXct.
#' @return Two integers: time, date.
#' @noRd
.bndl_dos_time <- function(t) {
  lt <- as.POSIXlt(t)
  c(
    lt$hour * 2048 + lt$min * 32 + floor(lt$sec / 2),
    (max(lt$year, 80) - 80) * 512 + (lt$mon + 1) * 32 + lt$mday
  )
}

#' A little-endian 16-bit unsigned integer.
#' @param x A number in 0..65535.
#' @return Two raw bytes.
#' @noRd
.bndl_u16 <- function(x) {
  if (x >= 32768) x <- x - 65536
  writeBin(as.integer(x), raw(), size = 2L, endian = "little")
}

#' A little-endian 32-bit unsigned integer.
#' @param x A number in 0..2^32 - 1.
#' @return Four raw bytes.
#' @noRd
.bndl_u32 <- function(x) {
  if (x >= 2147483648) x <- x - 4294967296
  writeBin(as.integer(x), raw(), size = 4L, endian = "little")
}
