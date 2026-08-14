///|
test "source file JSON encodes coverage as exact numbers or null" {
  let source_file = CoverallsSourceFile::{
    name: "src/main.mbt",
    source_digest: "digest",
    coverage: [None, Some(@int64.MAX_VALUE)],
  }
  let expected =
    #|{"name":"src/main.mbt","source_digest":"digest","coverage":[null,9223372036854775807]}
  assert_eq(ToJson::to_json(source_file).stringify(), expected)
}

///|
test "report JSON omits absent optional metadata" {
  let report = CoverallsReport::{
    service_name: None,
    service_number: None,
    service_job_id: None,
    service_pull_request: None,
    repo_token: None,
    parallel: None,
    source_files: [],
  }
  let expected : Json = { "source_files": [] }
  assert_eq(ToJson::to_json(report), expected)
}
