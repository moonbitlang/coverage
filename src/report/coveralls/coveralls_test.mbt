///|
async fn render_report(
  coverage_data : Bytes,
  source_filenames : ArrayView[String],
  service_name~ : String,
  service_number~ : String,
  service_job_id~ : String,
  service_pull_request~ : String,
  repo_token~ : String,
  parallel~ : Bool,
  ignore_missing_files? : Bool = false,
) -> Json {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cov-coveralls-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let coverage_file = @path.Path(root)
      .join(Path("sample.coverage"))
      .to_string()
    for source_filename in source_filenames {
      let source_file = @path.Path(root).join(Path(source_filename)).to_string()
      @fs.write_file(source_file, b"abc", create_mode=CreateOrTruncate)
    }
    @fs.write_file(coverage_file, coverage_data, create_mode=CreateOrTruncate)
    let reader = @io.MemoryReader() <| writer => {
      @coveralls.output(
        writer~,
        service_name~,
        service_number~,
        service_job_id~,
        service_pull_request~,
        repo_token~,
        parallel~,
        coverage_files=[coverage_file],
        coverage_paths=[],
        source_paths=[root],
        ignore_missing_files~,
        expect=[],
        do_not_expect=[],
      )
    }
    defer reader.close()
    @json.parse(reader.read_all().text())
  })
}

///|
async fn render_one_source_report(
  service_name~ : String,
  service_number~ : String,
  service_job_id~ : String,
  service_pull_request~ : String,
  repo_token~ : String,
  parallel~ : Bool,
) -> Json {
  render_report(
    b"BISECT-COVERAGE-4 1 10 sample.mbt 1 0 1 1",
    ["sample.mbt"],
    service_name~,
    service_number~,
    service_job_id~,
    service_pull_request~,
    repo_token~,
    parallel~,
  )
}

///|
async test "output emits Coveralls data for one source file" {
  let actual = render_one_source_report(
    service_name="",
    service_number="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
    parallel=false,
  )
  json_inspect(actual, content={
    "source_files": [
      {
        "name": "sample.mbt",
        "source_digest": "900150983cd24fb0d6963f7d28e17f72",
        "coverage": [1],
      },
    ],
  })
}

///|
async test "output trims metadata and omits blank values" {
  let actual = render_one_source_report(
    service_name=" build\"bot ",
    service_number=" 42 ",
    service_job_id=" \t ",
    service_pull_request=" 7 ",
    repo_token=" token ",
    parallel=false,
  )
  json_inspect(actual, content={
    "service_name": "build\"bot",
    "service_number": "42",
    "service_pull_request": "7",
    "repo_token": "token",
    "source_files": [
      {
        "name": "sample.mbt",
        "source_digest": "900150983cd24fb0d6963f7d28e17f72",
        "coverage": [1],
      },
    ],
  })
}

///|
async test "output marks reports that belong to a parallel build" {
  let actual = render_one_source_report(
    service_name="",
    service_number="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
    parallel=true,
  )
  json_inspect(actual, content={
    "parallel": true,
    "source_files": [
      {
        "name": "sample.mbt",
        "source_digest": "900150983cd24fb0d6963f7d28e17f72",
        "coverage": [1],
      },
    ],
  })
}

///|
async test "output orders source files by coverage filename" {
  let actual = render_report(
    b"BISECT-COVERAGE-4 2 5 b.mbt 1 0 1 1 5 a.mbt 1 0 1 1",
    ["b.mbt", "a.mbt"],
    service_name="",
    service_number="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
    parallel=false,
  )
  json_inspect(actual, content={
    "source_files": [
      {
        "name": "a.mbt",
        "source_digest": "900150983cd24fb0d6963f7d28e17f72",
        "coverage": [1],
      },
      {
        "name": "b.mbt",
        "source_digest": "900150983cd24fb0d6963f7d28e17f72",
        "coverage": [1],
      },
    ],
  })
}

///|
async test "output skips unresolved source files when requested" {
  let actual = render_report(
    b"BISECT-COVERAGE-4 1 11 missing.mbt 1 0 1 1",
    [],
    service_name="",
    service_number="",
    service_job_id="",
    service_pull_request="",
    repo_token="",
    parallel=false,
    ignore_missing_files=true,
  )
  json_inspect(actual, content={ "source_files": [] })
}
