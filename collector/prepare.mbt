///|
priv suberror PrepareError {
  NoTraceSources
  NoRuntimeLogs
  NoMatchingRuntimeData
  InvalidTraceSource(String, String)
  InvalidRuntimeLog(String, String)
  DuplicateFileId(String)
  MissingSource(String)
  CountMismatch(String, Int, Int)
  InvalidParent(String, Int, Int)
  InvalidRange(String)
} derive(Debug)

///|
impl Show for PrepareError with fn output(self, logger) {
  logger.write_string(
    match self {
      NoTraceSources =>
        "no coverage source data; run `moon test --enable-coverage` first"
      NoRuntimeLogs =>
        "no coverage runtime data; run `moon test --enable-coverage` first"
      NoMatchingRuntimeData =>
        "coverage runtime data does not match the selected source files"
      InvalidTraceSource(path, reason) =>
        "cannot decode trace source '\{path}': \{reason}"
      InvalidRuntimeLog(path, reason) =>
        "cannot decode runtime log '\{path}': \{reason}"
      DuplicateFileId(file_id) =>
        "conflicting trace metadata for file id '\{file_id}'"
      MissingSource(path) => "cannot find source file '\{path}'"
      CountMismatch(file_id, expected, actual) =>
        "counter length mismatch for '\{file_id}': expected \{expected}, got \{actual}; remove stale coverage outputs"
      InvalidParent(file_id, point, parent) =>
        "invalid parent for '\{file_id}' point \{point}: \{parent}"
      InvalidRange(path) => "invalid source range in '\{path}'"
    },
  )
}

///|
fn line_starts(source : BytesView) -> Array[Int] {
  let starts = [0]
  for index, byte in source {
    if byte == b'\n' {
      starts.push(index + 1)
    }
  }
  starts
}

///|
fn suffix_match(value : String, pattern : String) -> Bool {
  value == pattern || value.has_suffix("/" + pattern)
}

///|
fn byte_offset(
  starts : ArrayView[Int],
  range : SourceRange,
  filename : String,
) -> Int64 raise PrepareError {
  guard range.start_line > 0 &&
    range.start_line <= starts.length() &&
    range.start_column >= 0 else {
    raise InvalidRange(filename)
  }
  (starts[range.start_line - 1] + range.start_column).to_int64()
}

///|
fn prepare_data(
  traces : ArrayView[TraceFile],
  runtime : ArrayView[RuntimeHits],
  sources : Map[String, Bytes],
) -> PreparedCoverage raise PrepareError {
  let counts : Map[String, Array[Int64]] = Map([])
  let unique : Map[String, TraceFile] = Map([])
  for trace in traces {
    match unique.get(trace.file_id) {
      Some(previous) if previous == trace => ()
      Some(_) => raise DuplicateFileId(trace.file_id)
      None => {
        unique[trace.file_id] = trace
        counts[trace.file_id] = Array::make(trace.points.length(), 0L)
      }
    }
  }
  let mut matched_runtime = false
  for output in runtime {
    guard counts.get(output.file_id) is Some(current) else { continue }
    matched_runtime = true
    guard current.length() == output.hits.length() else {
      raise CountMismatch(
        output.file_id,
        current.length(),
        output.hits.length(),
      )
    }
    for index, hit in output.hits {
      current[index] += hit
    }
  }
  guard matched_runtime else { raise NoMatchingRuntimeData }
  let files = Map([])
  for _, trace in unique {
    guard sources.get(trace.filename) is Some(source) else {
      raise MissingSource(trace.filename)
    }
    let starts = line_starts(source)
    let offsets = []
    let points = []
    let hits = counts[trace.file_id]
    for index, point in trace.points {
      if point.parent is Some(parent) && (parent < 0 || parent >= index) {
        raise InvalidParent(trace.file_id, index, parent)
      }
      guard point.ranges.get(0) is Some(first) else {
        raise InvalidRange(trace.filename)
      }
      offsets.push(byte_offset(starts, first, trace.filename))
      points.push({
        ranges: point.ranges,
        parent: point.parent,
        hits: hits[index],
      })
    }
    files[trace.file_id] = {
      file_id: trace.file_id,
      filename: trace.filename,
      package_name: trace.package_name,
      points,
      byte_offsets: offsets,
      source,
    }
  }
  { files, }
}

///|
async fn discover(
  directory : StringView,
  predicate : (String) -> Bool,
) -> Array[String] {
  let files = []
  @fs.walk(directory, max_concurrency=1, (current, entries) => {
    for entry in entries {
      if predicate(entry) {
        let path = @path.Path(current).join(Path(entry)).to_string()
        try @fs.kind(path, follow_symlink=true) catch {
          _ => ()
        } noraise {
          Directory => ()
          _ => files.push(path)
        }
      }
    }
  })
  files
}

///|
async fn resolve_source(filename : String, roots : ArrayView[String]) -> String {
  if @fs.exists(filename) {
    return @fs.realpath(filename)
  }
  let separator = @path.sep.to_string()
  let parts = @path.Path(filename)
    .normalize()
    .to_string()
    .split(separator)
    .filter(part => !part.is_empty())
    .map(part => part.to_owned())
    .to_array()
  for start in 0..<parts.length() {
    let suffix = parts[start:].join(separator)
    for root in roots {
      let candidate = @path.Path(root).join(Path(suffix)).to_string()
      if @fs.exists(candidate) {
        return @fs.realpath(candidate)
      }
    }
  }
  raise MissingSource(filename)
}

///|
fn display_path(filename : String, base : String, absolute : Bool) -> String {
  guard !absolute else { filename }
  let relative = @path.Path(filename).relative(base=Path(base))
  let text = relative.to_string()
  if relative.is_absolute() ||
    text == ".." ||
    text.has_prefix("../") ||
    text.has_prefix("..\\") {
    filename
  } else if text.is_empty() {
    "."
  } else {
    text
  }
}

///|
async fn prepare_rich(request : PrepareRequest) -> PreparedCoverage {
  let trace_sources = if request.trace_sources.is_empty() {
    discover(request.current_directory, name => name.has_suffix(".trace.source"))
  } else {
    request.trace_sources
  }
  guard !trace_sources.is_empty() else { raise NoTraceSources }
  let runtime_logs = if request.runtime_logs.is_empty() {
    discover(request.current_directory, name => {
      name.has_prefix("moonbit_coverage_")
    })
  } else {
    request.runtime_logs
  }
  guard !runtime_logs.is_empty() else { raise NoRuntimeLogs }
  let traces = []
  for path in trace_sources {
    let decoded = decode_trace_source(@fs.read_file(path).binary()) catch {
      error => raise InvalidTraceSource(path, "\{error}")
    }
    traces.append(decoded)
  }
  let traces = traces.filter(trace => {
    request.package_filter.map_or(true, pattern => {
      suffix_match(trace.package_name, pattern)
    }) &&
    request.file_filter.map_or(true, pattern => {
      suffix_match(trace.filename, pattern)
    })
  })
  guard !traces.is_empty() else { raise NoTraceSources }
  let runtime = []
  for path in runtime_logs {
    let decoded = parse_runtime_log(@fs.read_file(path).text()) catch {
      error => raise InvalidRuntimeLog(path, "\{error}")
    }
    runtime.append(decoded)
  }
  guard !runtime.is_empty() else { raise NoRuntimeLogs }
  let sources = Map([])
  let normalized = []
  let base = @fs.realpath(request.current_directory)
  for trace in traces {
    let source_path = resolve_source(trace.filename, request.source_paths)
    let shown = display_path(source_path, base, request.absolute_paths)
    sources[shown] = @fs.read_file(source_path).binary()
    normalized.push({ ..trace, filename: shown })
  }
  prepare_data(normalized, runtime, sources)
}

///|
pub async fn prepare(request : PrepareRequest) -> PreparedCoverage {
  prepare_rich(request)
}
