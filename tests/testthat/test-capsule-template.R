# Provenance JSON delivers the digest as a length-1 list; verification must
# still recognise it, as the verify_capsule() example does.
test_that("a capsule whose provenance came through JSON verifies", {
  dir <- tempfile("capsule-json-")
  dir.create(dir)
  write.csv(data.frame(id = 1:3), file.path(dir, "d.csv"), row.names = FALSE)
  prov <- list(resource = list(filename = "d.csv",
                               sha256 = sha256_file(file.path(dir, "d.csv"))))
  # no auto_unbox: every scalar arrives back as a length-1 list
  writeLines(bricklayer_json_to_json(prov),
             file.path(dir, "data_provenance.json"))
  expect_true(is.list(load_provenance(
    file.path(dir, "data_provenance.json"))$resource$sha256))
  out <- verify_capsule(dir)
  expect_true(out$ok)
  ck <- out$checks
  expect_true(ck$ok[ck$check == "data_sha256"])
})
