///|
fn parse_top_levels(
  source : String,
  filename : String,
) -> Array[TopLevelRange] raise {
  let lexed = @lexer.tokens_from_string(source, name=filename, comment=true)
  if !lexed.errors.is_empty() {
    let count = lexed.errors.length()
    fail(
      "cannot parse source file '\{filename}': \{count} lexical error(s); use -f caret to report coverage without parsing",
    )
  }
  let (impls, diagnostics) = @handrolled_parser.parse(lexed.tokens)
  if !diagnostics.is_empty() {
    let count = diagnostics.length()
    fail(
      "cannot parse source file '\{filename}': \{count} parser diagnostic(s); use -f caret to report coverage without parsing",
    )
  }
  impls
  .to_array()
  .map(item => {
    let location = @syntax.Impl::loc(item)
    { start_line: location.start.lnum, end_line: location.end.lnum }
  })
}

///|
fn collect_blocks(
  filename : String,
  counts : ArrayView[Int64?],
  ranges : ArrayView[TopLevelRange],
) -> (Int, Array[SimplifiedBlock]) raise {
  let blocks : Array[SimplifiedBlock] = []
  let mut uncovered_count = 0
  let mut last_uncovered = -1
  let mut range_index = 0
  for line_index, count in counts {
    if count != Some(0L) {
      continue
    }
    let line = line_index + 1
    // Counts and parser ranges are source ordered, so this cursor never rewinds.
    while range_index < ranges.length() && ranges[range_index].end_line < line {
      range_index += 1
    }
    guard ranges.get(range_index) is Some(range) &&
      range.start_line <= line &&
      line <= range.end_line else {
      fail(
        "uncovered line \{line} in '\{filename}' is not inside a top-level declaration; use -f caret to report it without parsing",
      )
    }
    let same_block = blocks.last() is Some(block) && block.range == range
    if !same_block {
      blocks.push({ range, uncovered: [line_index] })
      uncovered_count += 1
    } else if last_uncovered + 1 != line_index {
      let block = blocks[blocks.length() - 1]
      block.uncovered.push(line_index)
      uncovered_count += 1
    }
    last_uncovered = line_index
  }
  (uncovered_count, blocks)
}

///|
fn simplified_block(
  lines : ArrayView[String],
  block : SimplifiedBlock,
) -> String {
  guard !block.uncovered.is_empty() && !lines.is_empty() else { "" }
  let start = (block.range.start_line - 1).max(0)
  let end = (block.range.end_line - 1).min(lines.length() - 1)
  let width = (end + 1).to_string().length()
  let output = StringBuilder()
  let mut uncovered_index = 0
  for line_index in start..<=end {
    let is_uncovered = uncovered_index < block.uncovered.length() &&
      block.uncovered[uncovered_index] == line_index
    output.write_string(
      "\{padded(line_index + 1, width)}\t\{lines[line_index]}",
    )
    if is_uncovered {
      output.write_string("\t<-- UNCOVERED")
      uncovered_index += 1
    }
    output.write_char('\n')
  }
  let padding = " ".repeat(width)
  output.write_string("\{padding}\t…\n")
  output.to_string()
}

///|
async fn simplified_file(
  file : @common.InstrumentedFile,
  source_paths : ArrayView[String],
  ignore_missing_files : Bool,
) -> SimplifiedFile? {
  guard resolve_source(file, source_paths, ignore_missing_files) is Some(source) else {
    return None
  }
  let ranges = parse_top_levels(source.text, file.filename)
  let counts = @report.line_counts(
    source.bytes,
    points=file.points,
    counts=file.counts,
  )
  let (uncovered_count, block_specs) = collect_blocks(
    file.filename,
    counts,
    ranges,
  )
  guard uncovered_count > 0 else { None }
  Some({
    filename: file.filename,
    uncovered_count,
    blocks: block_specs.map(block => simplified_block(source.lines, block)),
  })
}

///|
async fn render_simplified(
  coverage : @common.Coverage,
  source_paths : ArrayView[String],
  ignore_missing_files : Bool,
) -> String {
  let entries : Array[SimplifiedFile] = []
  for file in sorted_files(coverage) {
    if simplified_file(file, source_paths, ignore_missing_files) is Some(entry) {
      entries.push(entry)
    }
  }
  let total = entries.fold(init=0, (sum, entry) => sum + entry.uncovered_count)
  if total == 0 {
    return "All source files are fully covered\n"
  }
  let file_count = entries.length()
  let summary = "Total: \{total} uncovered line(s) in \{file_count} file(s)\n"
  let output = StringBuilder()
  output.write_string(summary)
  output.write_char('\n')
  for entry in entries {
    output.write_string(
      "\{entry.uncovered_count} uncovered line(s) in \{entry.filename}:\n\n",
    )
    for block in entry.blocks {
      output.write_string(block)
      output.write_char('\n')
    }
  }
  output.write_string(summary)
  output.to_string()
}
