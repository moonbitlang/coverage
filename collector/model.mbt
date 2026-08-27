///|
#warnings("-unused_field")
priv struct SourceRange {
  package_name : String
  filename : String
  start_line : Int
  start_column : Int
  end_line : Int
  end_column : Int
} derive(Eq)

///|
priv struct TracePoint {
  ranges : Array[SourceRange]
  parent : Int?
} derive(Eq)

///|
priv struct TraceFile {
  filename : String
  file_id : String
  package_name : String
  points : Array[TracePoint]
} derive(Eq)

///|
priv struct RuntimeHits {
  file_id : String
  hits : Array[Int64]
}

///|
#warnings("-unused_field")
priv struct PreparedPoint {
  ranges : Array[SourceRange]
  parent : Int?
  hits : Int64
}

///|
#warnings("-unused_field")
priv struct PreparedFile {
  file_id : String
  filename : String
  package_name : String
  points : Array[PreparedPoint]
  byte_offsets : Array[Int64]
  source : Bytes
}

///|
pub struct PreparedCoverage {
  priv files : Map[String, PreparedFile]
}

///|
pub(all) struct PrepareRequest {
  trace_sources : Array[String]
  runtime_logs : Array[String]
  source_paths : Array[String]
  package_filter : String?
  file_filter : String?
  absolute_paths : Bool
  current_directory : String
}

///|
pub fn PreparedCoverage::to_bisect(self : PreparedCoverage) -> @common.Coverage {
  let coverage : @common.Coverage = Map([])
  for _, file in self.files {
    coverage[file.filename] = {
      filename: file.filename,
      points: file.byte_offsets,
      counts: file.points.map(point => point.hits),
    }
  }
  coverage
}
