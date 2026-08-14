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

///|
fn write_int(buffer : @buffer.Buffer, value : Int64) -> Unit {
  buffer.write_byte(b' ')
  buffer.write_bytes(@utf8.encode(value.to_string()))
}

///|
fn write_string(buffer : @buffer.Buffer, value : String) -> Unit {
  let bytes = @utf8.encode(value)
  write_int(buffer, bytes.length().to_int64())
  buffer.write_byte(b' ')
  buffer.write_bytes(bytes)
}

///|
fn[A] write_array(
  write_element : (@buffer.Buffer, A) -> Unit,
  buffer : @buffer.Buffer,
  values : ArrayView[A],
) -> Unit {
  write_int(buffer, values.length().to_int64())
  values.each(value => write_element(buffer, value))
}

///|
fn write_instrumented_file(
  buffer : @buffer.Buffer,
  file : InstrumentedFile,
) -> Unit {
  write_string(buffer, file.filename)
  write_array(write_int, buffer, file.points)
  write_array(write_int, buffer, file.counts)
}

///|
/// Serialize coverage data in Bisect's version 4 coverage format.
pub fn write_coverage(coverage : Coverage) -> Bytes {
  let buffer = @buffer.Buffer(size_hint=4096)
  buffer.write_bytes(@utf8.encode(coverage_file_identifier))
  write_int(buffer, coverage.length().to_int64())
  coverage.values().each(file => write_instrumented_file(buffer, file))
  buffer.to_bytes()
}
