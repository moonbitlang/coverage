///|
priv suberror CoverageInputError {
  NoCoverageFiles
  MissingExpectedSource(String)
} derive(Debug)

///|
fn is_coverage_file(filename : String) -> Bool {
  filename.has_suffix(".coverage")
}

///|
async fn list_non_recursively(
  filename_filter : (String) -> Bool,
  directory : StringView,
) -> Array[String] {
  @fs.readdir(directory).filter(filename_filter)
}

///|
async fn list_recursively(
  filename_filter : (String) -> Bool,
  directory : StringView,
) -> Array[String] {
  let result = []
  @fs.walk(directory, max_concurrency=1, (current_directory, entries) => {
    for entry in entries {
      if filename_filter(entry) {
        let entry_path = @path.Path(current_directory)
          .join(Path(entry))
          .to_string()
        try @fs.kind(entry_path, follow_symlink=true) catch {
          _ => ()
        } noraise {
          Directory => ()
          _ => result.push(entry_path)
        }
      }
    }
  })
  result
}

///|
async fn is_directory(path : StringView) -> Bool {
  try @fs.kind(path, follow_symlink=true) catch {
    _ => false
  } noraise {
    Directory => true
    _ => false
  }
}

///|
async fn list_coverage_files(
  files_on_command_line~ : ArrayView[String],
  coverage_search_paths~ : ArrayView[String],
  current_directory? : StringView = ".",
  target_directory? : String? = @env.get_env_var("cur__target_dir"),
) -> Array[String] {
  let (individual_files, search_paths) = if files_on_command_line.is_empty() &&
    coverage_search_paths.is_empty() {
    let files = list_non_recursively(is_coverage_file, current_directory)
    let local_build = @path.Path(current_directory.to_owned())
      .join(Path("_build"))
      .to_string()
    let paths = if target_directory is Some(directory) {
      [directory, local_build]
    } else if find_dune_workspace_root(start=current_directory)
      is Some(workspace) {
      [@path.Path(workspace).join(Path("_build")).to_string()]
    } else {
      [local_build]
    }
    (files, paths)
  } else {
    (files_on_command_line.to_owned(), coverage_search_paths.to_owned())
  }
  let all_coverage_files = individual_files
  for directory in search_paths {
    if is_directory(directory) {
      all_coverage_files.append(list_recursively(is_coverage_file, directory))
    }
  }
  if all_coverage_files.is_empty() {
    raise NoCoverageFiles
  } else {
    all_coverage_files
  }
}

///|
fn strip_extensions(filename : String) -> String {
  let path = @path.Path(filename)
  let basename = path.basename()
  let stem = if basename.find(".") is Some(index) {
    basename[:index].to_owned()
  } else {
    basename.to_owned()
  }
  path.dirname().join(Path(stem)).to_string()
}

///|
fn is_source_file(filename : String) -> Bool {
  filename.has_suffix(".mbt")
}

///|
fn has_trailing_separator(path : String) -> Bool {
  @path.Path(path).normalize().to_string().has_suffix(@path.sep.to_string())
}

///|
async fn list_expected_files(paths : ArrayView[String]) -> Array[String] {
  let files = []
  for path in paths {
    if has_trailing_separator(path) {
      files.append(list_recursively(is_source_file, path))
    } else {
      files.push(path)
    }
  }
  files.sort()
  files.dedup()
  files
}

///|
async fn filtered_expected_files(
  expect~ : ArrayView[String],
  do_not_expect~ : ArrayView[String],
) -> Array[String] {
  let expected_files = list_expected_files(expect)
  let excluded_files = list_expected_files(do_not_expect)
  expected_files.filter(path => !excluded_files.contains(path))
}

///|
async fn assert_expected_sources_are_present(
  present_files : Array[String],
  expect~ : ArrayView[String],
  do_not_expect~ : ArrayView[String],
) -> Unit {
  let present_files = present_files.map(strip_extensions)
  filtered_expected_files(expect~, do_not_expect~).each(file => {
    if !present_files.contains(strip_extensions(file)) {
      raise MissingExpectedSource(file)
    }
  })
}

///|
/// Errors produced while decoding the contents of a `.coverage` file.
priv suberror CoverageReadError {
  InvalidHeader
  BadInteger(at~ : Int)
  Truncated(at~ : Int)
  InvalidFilename(at~ : Int)
} derive(Debug)

///|
priv struct Cursor {
  bytes : BytesView
  mut offset : Int
}

///|
fn Cursor::new(bytes : BytesView) -> Cursor {
  { bytes, offset: 0 }
}

///|
fn Cursor::junk(self : Cursor) -> Unit {
  if self.offset < self.bytes.length() {
    self.offset += 1
  }
}

///|
fn Cursor::read_header(self : Cursor) -> Unit raise CoverageReadError {
  let header = @utf8.encode(@common.coverage_file_identifier)
  if !self.read_exact(header.length()).equal_to_bytes(header) {
    raise InvalidHeader
  }
  self.junk()
}

///|
fn Cursor::read_int(self : Cursor) -> Int64 raise CoverageReadError {
  let at = self.offset
  let remaining = self.bytes[self.offset:]
  let length = if remaining.find(b" ") is Some(index) {
    index
  } else {
    remaining.length()
  }
  let token = @utf8.decode(self.read_exact(length)) catch {
    _ => raise BadInteger(at~)
  }
  self.junk()
  let value : Int64 = @string.from_str(token) catch {
    _ => raise BadInteger(at~)
  }

  value
}

///|
fn Cursor::read_length(self : Cursor) -> Int raise CoverageReadError {
  let length = self.read_int()
  if length < 0L || length > @int.MAX_VALUE.to_int64() {
    raise BadInteger(at=self.offset)
  }
  length.to_int()
}

///|
fn Cursor::read_exact(
  self : Cursor,
  length : Int,
) -> BytesView raise CoverageReadError {
  if self.offset > self.bytes.length() - length {
    raise Truncated(at=self.offset)
  }
  let result = self.bytes[self.offset:self.offset + length]
  self.offset += length
  result
}

///|
fn Cursor::read_string(self : Cursor) -> String raise CoverageReadError {
  let length = self.read_length()
  let at = self.offset
  let result = @utf8.decode(self.read_exact(length)) catch {
    _ => raise InvalidFilename(at~)
  }
  self.junk()
  result
}

///|
fn[A] Cursor::read_array(
  self : Cursor,
  read_element : (Cursor) -> A raise CoverageReadError,
) -> Array[A] raise CoverageReadError {
  let length = self.read_length()
  Array::makei(length, _ => read_element(self))
}

///|
/// Whether `Path::relative` had to leave the base directory. On Windows a
/// different drive or UNC root stays absolute; on the same root, as on POSIX,
/// an outside path has `..` among its ancestors.
fn relative_path_escapes_base(relative : @path.Path) -> Bool {
  if relative.is_absolute() || relative == Path("..") {
    true
  } else {
    let parent = relative.dirname()
    parent != relative &&
    parent != Path(".") &&
    relative_path_escapes_base(parent)
  }
}

///|
/// Match Bisect's policy: keep relative inputs as-is, make absolute paths
/// inside the current directory relative, and preserve outside absolute paths.
fn get_relative_path(filename : String, cwd : StringView) -> String {
  let path = @path.Path(filename)
  if !path.is_absolute() {
    filename
  } else {
    let relative = path.relative(base=Path(cwd.to_owned()))
    let relative_string = relative.to_string()
    if relative_string.is_empty() || relative_path_escapes_base(relative) {
      filename
    } else {
      relative_string
    }
  }
}

///|
fn Cursor::read_instrumented_file(
  self : Cursor,
  cwd : StringView,
) -> @common.InstrumentedFile raise CoverageReadError {
  let filename = get_relative_path(self.read_string(), cwd)
  let points = self.read_array(Cursor::read_int)
  let counts = self.read_array(Cursor::read_int)
  { filename, points, counts }
}

///|
fn Cursor::read_coverage(
  self : Cursor,
  cwd : StringView,
) -> Array[@common.InstrumentedFile] raise CoverageReadError {
  self.read_array(cursor => cursor.read_instrumented_file(cwd))
}

///|
fn decode(
  bytes : BytesView,
  cwd~ : StringView,
) -> Array[@common.InstrumentedFile] raise CoverageReadError {
  let cursor = Cursor::new(bytes)
  cursor.read_header()
  cursor.read_coverage(cwd)
}

///|
/// Read one `.coverage` file. This remains private, like `Input.read` in
/// Bisect; callers enter through `load_coverage`.
async fn read(coverage_file~ : StringView) -> Array[@common.InstrumentedFile] {
  let bytes = @fs.read_file(coverage_file).binary()
  let cwd = @fs.realpath(".")
  decode(bytes, cwd~)
}

///|
fn saturating_add(x : Int64, y : Int64) -> Int64 {
  if x > 0L && y > 0L && x > @int64.MAX_VALUE - y {
    @int64.MAX_VALUE
  } else if x < 0L && y < 0L && x < @int64.MIN_VALUE - y {
    @int64.MIN_VALUE
  } else {
    x + y
  }
}

///|
fn elementwise_saturating_add(
  xs : Array[Int64],
  ys : Array[Int64],
) -> Array[Int64] {
  let (longer, shorter) = if xs.length() >= ys.length() {
    (xs, ys)
  } else {
    (ys, xs)
  }
  longer.mapi((index, value) => {
    if shorter.get(index) is Some(other) {
      saturating_add(other, value)
    } else {
      value
    }
  })
}

///|
/// Find and read coverage files, then accumulate visit counts by source file.
pub async fn load_coverage(
  coverage_files~ : ArrayView[String],
  coverage_paths~ : ArrayView[String],
  expect~ : ArrayView[String],
  do_not_expect~ : ArrayView[String],
) -> @common.Coverage {
  let coverage : @common.Coverage = Map([])
  let coverage_files = list_coverage_files(
    files_on_command_line=coverage_files,
    coverage_search_paths=coverage_paths,
  )
  for coverage_file in coverage_files {
    read(coverage_file~).each(file => {
      let counts = if coverage.get(file.filename) is Some(previous) {
        elementwise_saturating_add(file.counts, previous.counts)
      } else {
        file.counts
      }
      coverage[file.filename] = {
        filename: file.filename,
        points: file.points,
        counts,
      }
    })
  }
  assert_expected_sources_are_present(
    coverage.keys().to_array(),
    expect~,
    do_not_expect~,
  )
  coverage
}
