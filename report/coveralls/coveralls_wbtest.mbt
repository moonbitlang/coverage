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
    git: None,
    source_files: [],
  }
  let expected : Json = { "source_files": [] }
  assert_eq(ToJson::to_json(report), expected)
}

///|
async test "output safely encodes optional Git metadata" {
  let git = GitInfo::{
    head: {
      id: "deadbeef",
      author_name: "A \"quoted\" author",
      author_email: "author@example.test",
      committer_name: "Committer\\Name",
      committer_email: "committer@example.test",
      message: "subject\nsecond line",
    },
    branch: "feature/json\"encoding",
  }
  let reader = @io.MemoryReader() <| writer => {
    output(
      writer~,
      coverage={},
      service_name="",
      service_number="",
      service_job_id="",
      service_pull_request="",
      repo_token="",
      parallel=false,
      git~,
      source_paths=[],
      ignore_missing_files=true,
    )
  }
  defer reader.close()
  json_inspect(@json.parse(reader.read_all().text()), content={
    "git": {
      "head": {
        "id": "deadbeef",
        "author_name": "A \"quoted\" author",
        "author_email": "author@example.test",
        "committer_name": "Committer\\Name",
        "committer_email": "committer@example.test",
        "message": "subject\nsecond line",
      },
      "branch": "feature/json\"encoding",
      "remotes": [],
    },
    "source_files": [],
  })
}
