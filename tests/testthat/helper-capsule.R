# The capsule fixture, shared by test-capsule.R and test-coverage-0_5_9.R.

make_test_capsule <- function() {
  dir <- file.path(tempdir(), paste0("capsule-", as.integer(stats::runif(1, 1, 1e8))))
  dir.create(dir, showWarnings = FALSE)
  df <- data.frame(id = 1:6, year = rep(2024:2025, 3), value = 1:6 / 2)
  utils::write.csv(df, file.path(dir, "data.csv"), row.names = FALSE)
  prov <- list(
    captured_at_utc = "2026-06-23T04:41:40Z",
    dataset = list(
      package_slug = "test-capsule",
      publisher = "Test Publisher",
      licence_short = "OGL-Ontario"
    ),
    resource = list(
      name = "Test Detailed Dataset",
      filename = "data.csv",
      direct_url = "https://example.org/data.csv",
      sha256 = sha256_file(file.path(dir, "data.csv")),
      size_bytes = file.size(file.path(dir, "data.csv")),
      row_count_data_rows = 6
    ),
    schema = list(
      expected_columns = c("id", "year", "value"),
      structural_invariants = list(min_data_rows = 3)
    )
  )
  jsonlite::write_json(prov, file.path(dir, "data_provenance.json"),
                       auto_unbox = TRUE, digits = NA)
  m <- make_manifest(list(study = "test"), environment = FALSE)
  capture.output({
    m <- record(m, "mean_value", observed = mean(df$value), expected = 1.75)
  })
  write_manifest_json(m, file.path(dir, "manifest.json"))
  dir
}
