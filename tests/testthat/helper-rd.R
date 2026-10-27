# The package's Rd files. An installed package reads them from its help
# database, which R CMD INSTALL builds; under pkgload::load_all() nothing is
# installed and there is no database (tools::Rd_db() then reports the help
# "corrupt"), so they are read from the source man/ directory.
rmbl_rd_db <- function() {
  db <- tryCatch(tools::Rd_db("rmoriebricklayer"), error = function(e) NULL)
  if (!is.null(db)) {
    return(db)
  }
  # tests/testthat sits two levels below the source root
  tools::Rd_db(dir = testthat::test_path("..", ".."))
}
