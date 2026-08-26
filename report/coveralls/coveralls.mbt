///|
priv struct CoverallsSourceFile {
  name : String
  source_digest : String
  coverage : Array[Int64?]
}

///|
fn count_to_json(count : Int64?) -> Json {
  if count is Some(value) {
    Json::number(value.to_double(), repr=value.to_string())
  } else {
    Json::null()
  }
}

///|
impl ToJson for CoverallsSourceFile with fn to_json(self) {
  Json::object(
    Map([
      ("name", Json::string(self.name)),
      ("source_digest", Json::string(self.source_digest)),
      ("coverage", Json::array(self.coverage.map(count_to_json))),
    ]),
  )
}

///|
priv struct CoverallsReport {
  service_name : String?
  service_number : String?
  service_job_id : String?
  service_pull_request : String?
  repo_token : String?
  parallel : Bool?
  source_files : Array[CoverallsSourceFile]
} derive(ToJson)

///|
/// Write a Coveralls-compatible JSON report from prepared coverage.
pub async fn[W : @io.Writer] output(
  writer~ : W,
  coverage~ : @common.Coverage,
  service_name~ : String,
  service_number~ : String,
  service_job_id~ : String,
  service_pull_request~ : String,
  repo_token~ : String,
  parallel~ : Bool,
  source_paths~ : ArrayView[String],
  ignore_missing_files~ : Bool,
) -> Unit {
  let source_files : Array[CoverallsSourceFile] = []
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
      )
      source_files.push({ name: file.filename, source_digest, coverage })
    }
  }
  let optional_metadata : (String) -> String? = value => {
    let value = value.trim()
    if value.is_empty() {
      None
    } else {
      Some(value.to_owned())
    }
  }
  let report = CoverallsReport::{
    service_name: optional_metadata(service_name),
    service_number: optional_metadata(service_number),
    service_job_id: optional_metadata(service_job_id),
    service_pull_request: optional_metadata(service_pull_request),
    repo_token: optional_metadata(repo_token),
    parallel: if parallel {
      Some(true)
    } else {
      None
    },
    source_files,
  }
  writer.write(ToJson::to_json(report).stringify(indent=2) + "\n")
}
