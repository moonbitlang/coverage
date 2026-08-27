///|
priv struct SortedSummaryPoint {
  file_id : String
  filename : String
  point_index : Int
  hits : Int64
}

///|
fn position_before(
  left_line : Int,
  left_column : Int,
  right_line : Int,
  right_column : Int,
) -> Bool {
  left_line < right_line ||
  (left_line == right_line && left_column < right_column)
}

///|
fn point_full_range(ranges : ArrayView[SourceRange]) -> SourceRange? {
  guard ranges.get(0) is Some(first) else { return None }
  let mut package_name = first.package_name
  let mut filename = first.filename
  let mut start_line = first.start_line
  let mut start_column = first.start_column
  let mut end_line = first.end_line
  let mut end_column = first.end_column
  for range in ranges[1:] {
    if position_before(
        range.start_line,
        range.start_column,
        start_line,
        start_column,
      ) {
      package_name = range.package_name
      filename = range.filename
      start_line = range.start_line
      start_column = range.start_column
    }
    if position_before(end_line, end_column, range.end_line, range.end_column) {
      end_line = range.end_line
      end_column = range.end_column
    }
  }
  Some({
    package_name,
    filename,
    start_line,
    start_column,
    end_line,
    end_column,
  })
}

///|
fn logical_source_path(range : SourceRange) -> String {
  if range.package_name.is_empty() {
    range.filename
  } else {
    range.package_name + "/" + range.filename
  }
}

///|
fn summary_line_starts(source : BytesView) -> Array[Int] {
  let starts = [0]
  for index, byte in source {
    if byte == b'\n' {
      starts.push(index + 1)
    }
  }
  if !source.is_empty() && source[source.length() - 1] != b'\n' {
    starts.push(source.length())
  }
  starts
}

///|
fn write_source_lines(
  output : StringBuilder,
  source : Bytes,
  starts : ArrayView[Int],
  start_line : Int,
  end_line : Int,
  prefix : String,
) -> Unit {
  let line_count = starts.length() - 1
  let first = start_line.max(1)
  let last = end_line.min(line_count)
  guard first <= last else { return }
  for line in first..<=last {
    let start = starts[line - 1]
    let end = starts[line]
    output.write_string(prefix)
    output.write_string(try! @utf8.decode(source[start:end]))
    if end == start || source[end - 1] != b'\n' {
      output.write_char('\n')
    }
  }
}

///|
fn write_spaces(output : StringBuilder, count : Int) -> Unit {
  for _ in 0..<count.max(0) {
    output.write_char(' ')
  }
}

///|
fn write_carets(output : StringBuilder, count : Int) -> Unit {
  for _ in 0..<count.max(1) {
    output.write_char('^')
  }
  output.write_char('\n')
}

///|
fn write_point_context(
  output : StringBuilder,
  file : PreparedFile,
  range : SourceRange,
  starts : ArrayView[Int],
) -> Unit {
  let line_count = starts.length() - 1
  guard line_count > 0 else { return }
  let start_line = range.start_line.max(1).min(line_count)
  let end_line = range.end_line.max(start_line).min(line_count)
  let start_column = range.start_column.max(0)
  write_source_lines(
    output,
    file.source,
    starts,
    start_line - 3,
    start_line - 1,
    "  ",
  )
  if start_line == end_line {
    write_source_lines(output, file.source, starts, start_line, end_line, "* ")
    write_spaces(output, start_column + 2)
    write_carets(output, range.end_column.max(start_column) - start_column + 1)
  } else {
    write_source_lines(
      output,
      file.source,
      starts,
      start_line,
      start_line,
      "* ",
    )
    write_spaces(output, start_column + 2)
    output.write_string("^...\n")
    if end_line - start_line > 3 {
      write_source_lines(
        output,
        file.source,
        starts,
        start_line + 1,
        start_line + 3,
        "* ",
      )
      output.write_string("* // ...\n")
      write_source_lines(
        output,
        file.source,
        starts,
        end_line - 1,
        end_line,
        "* ",
      )
    } else {
      write_source_lines(
        output,
        file.source,
        starts,
        start_line + 1,
        end_line,
        "* ",
      )
    }
  }
  write_source_lines(
    output,
    file.source,
    starts,
    end_line + 1,
    end_line + 3,
    "  ",
  )
}

///|
/// Render the hottest coverage points with their surrounding source context.
pub fn PreparedCoverage::sorted_summary(
  self : PreparedCoverage,
  limit? : Int = 50,
) -> String {
  guard limit > 0 else { return "" }
  let selected = []
  for file_id, file in self.files {
    for point_index, point in file.points {
      let informative = match point.parent {
        None => true
        Some(parent) =>
          file.points
          .get(parent)
          .map_or(false, parent_point => point.hits > parent_point.hits)
      }
      if informative && !point.ranges.is_empty() {
        selected.push({
          file_id,
          filename: file.filename,
          point_index,
          hits: point.hits,
        })
      }
    }
  }
  // Unlike upstream's hashtable-dependent stable ties, this produces the same
  // report across runs by ordering equal-hit points by file, point, then id.
  selected.sort_by((left, right) => {
    let hits_order = right.hits.compare(left.hits)
    if hits_order != 0 {
      hits_order
    } else {
      let filename_order = left.filename.compare(right.filename)
      if filename_order != 0 {
        filename_order
      } else {
        let point_order = left.point_index.compare(right.point_index)
        if point_order != 0 {
          point_order
        } else {
          left.file_id.compare(right.file_id)
        }
      }
    }
  })
  let output = StringBuilder()
  let starts_cache : Map[String, Array[Int]] = Map([])
  let count = selected.length().min(limit)
  for index in 0..<count {
    let selected_point = selected[index]
    guard self.files.get(selected_point.file_id) is Some(file) &&
      file.points.get(selected_point.point_index) is Some(point) &&
      point_full_range(point.ranges) is Some(range) else {
      continue
    }
    output.write_string(
      "\{logical_source_path(range)}:\{range.start_line}:\{range.start_column + 1}: \{point.hits} hits\n",
    )
    let starts = match starts_cache.get(selected_point.file_id) {
      Some(starts) => starts
      None => {
        let starts = summary_line_starts(file.source)
        starts_cache[selected_point.file_id] = starts
        starts
      }
    }
    write_point_context(output, file, range, starts)
  }
  output.to_string()
}
