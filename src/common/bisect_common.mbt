///|
/// Data gathered for a single source file.
pub(all) struct InstrumentedFile {
  filename : String
  points : Array[Int64]
  counts : Array[Int64]
} derive(Debug, Eq)

///|
/// Coverage statistics indexed by source filename.
pub type Coverage = Map[String, InstrumentedFile]

///|
/// Identifier and version prefix written to every Bisect coverage file.
pub let coverage_file_identifier : String = "BISECT-COVERAGE-4"
