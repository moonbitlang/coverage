///|
fn detailed_block(
  lines : ArrayView[String],
  line : Int,
  around : Int,
) -> String {
  let length = lines.length()
  let left_limit = line - around
  let right_limit = line + around + 1
  let window = 2 * around + 1
  let (start, end) = match (left_limit < 0, right_limit > length) {
    (true, true) => (0, length)
    (true, false) => (0, window.min(length))
    (false, true) => ((length - window).max(0), length)
    (false, false) => (left_limit, right_limit)
  }
  let width = end.to_string().length()
  let output = StringBuilder()
  for index in start..<end {
    let source = lines[index]
    output.write_string("\{padded(index + 1, width)}\t\{source}\n")
    if index == line {
      let padding = " ".repeat(width)
      output.write_string("\{padding}\t\{caret_marker(source)}\n")
    }
  }
  output.to_string()
}

///|
async fn render_detailed(
  coverage : @common.Coverage,
  source_paths : ArrayView[String],
  ignore_missing_files : Bool,
) -> String {
  let output = StringBuilder()
  for file in sorted_files(coverage) {
    guard resolve_source(file, source_paths, ignore_missing_files)
      is Some(source) else {
      continue
    }
    let counts = @report.line_counts(
      source.bytes,
      points=file.points,
      counts=file.counts,
    )
    for line, count in counts {
      if count == Some(0L) {
        output.write_string("warning: this line has no test coverage\n")
        output.write_string(" --> \{file.filename}:\{line + 1}\n")
        output.write_string(detailed_block(source.lines, line, 2))
        output.write_string("\n\n")
      }
    }
  }
  output.to_string()
}
