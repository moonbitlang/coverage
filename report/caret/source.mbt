///|
fn source_lines(source : String) -> Array[String] {
  if source.is_empty() {
    return []
  }
  let lines = source.split("\n").map(line => line.to_owned()).to_array()
  if source.has_suffix("\n") {
    ignore(lines.pop())
  }
  lines
}

///|
async fn resolve_source(
  file : @common.InstrumentedFile,
  source_paths : ArrayView[String],
  ignore_missing_files : Bool,
) -> ResolvedSource? {
  guard @report.find_source_file(
      source_roots=source_paths,
      ignore_missing_files~,
      filename=file.filename,
    )
    is Some(path) else {
    return None
  }
  let data = @fs.read_file(path)
  let bytes = data.binary()
  let text = data.text()
  Some({ bytes, text, lines: source_lines(text) })
}

///|
fn padded(value : Int, width : Int) -> String {
  let value = value.to_string()
  " ".repeat(width - value.length()) + value
}

///|
fn caret_marker(line : String) -> String {
  let source = @utf8.encode(line)
  guard !source.is_empty() else { "" }
  let mut left = 0
  while left < source.length() && source[left] == b' ' {
    left += 1
  }
  let mut right = source.length() - 1
  while right >= left && source[right] == b' ' {
    right -= 1
  }
  let marker = @buffer.Buffer(size_hint=source.length())
  for index, _ in source {
    marker.write_byte(if left <= index && index <= right { b'^' } else { b' ' })
  }
  @utf8.decode_lossy(marker.to_bytes())
}

///|
fn sorted_files(coverage : @common.Coverage) -> Array[@common.InstrumentedFile] {
  let files = coverage.values().to_array()
  files.sort_by((left, right) => left.filename.compare(right.filename))
  files
}
