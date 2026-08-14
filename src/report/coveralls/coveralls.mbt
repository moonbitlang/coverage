///|
fn coverage_count_json(count : Int64?) -> Json {
  if count is Some(value) {
    Json::number(value.to_double(), repr=value.to_string())
  } else {
    Json::null()
  }
}

///|
/// Read and aggregate Bisect coverage files, resolve their source files, and
/// write a Coveralls-compatible JSON report.
pub async fn[W : @io.Writer] output(
  writer~ : W,
  service_name~ : String,
  service_number~ : String,
  service_job_id~ : String,
  service_pull_request~ : String,
  repo_token~ : String,
  parallel~ : Bool,
  coverage_files~ : ArrayView[String],
  coverage_paths~ : ArrayView[String],
  source_paths~ : ArrayView[String],
  ignore_missing_files~ : Bool,
  expect~ : ArrayView[String],
  do_not_expect~ : ArrayView[String],
) -> Unit {
  let coverage = @report.load_coverage(
    coverage_files~,
    coverage_paths~,
    expect~,
    do_not_expect~,
  )
  let source_files : Array[Json] = []
  let files = coverage.values().to_array()
  files.sort_by((left, right) => left.filename.compare(right.filename))
  for file in files {
    if @report.find_source_file(
        source_roots=source_paths,
        ignore_missing_files~,
        filename=file.filename,
      )
      is Some(resolved_file) {
      let source = @fs.read_file(resolved_file).binary()
      let source_digest = @crypto.bytes_to_hex_string(@crypto.md5(source))
      let coverage = @report.line_counts(
        source,
        points=file.points,
        counts=file.counts,
      ).map(coverage_count_json)
      source_files.push(
        Json::object(
          Map([
            ("name", Json::string(file.filename)),
            ("source_digest", Json::string(source_digest)),
            ("coverage", Json::array(coverage)),
          ]),
        ),
      )
    }
  }
  let metadata = [
    ("service_name", service_name),
    ("service_number", service_number),
    ("service_job_id", service_job_id),
    ("service_pull_request", service_pull_request),
    ("repo_token", repo_token),
  ].filter_map(entry => {
    let value = entry.1.trim()
    if value.is_empty() {
      None
    } else {
      Some((entry.0, Json::string(value.to_owned())))
    }
  })
  let report_fields = Map(metadata)
  if parallel {
    report_fields["parallel"] = Json::boolean(true)
  }
  report_fields["source_files"] = Json::array(source_files)
  let report = Json::object(report_fields)
  writer.write(report.stringify(indent=2) + "\n")
}
