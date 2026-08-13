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
  let length = match remaining.find(b" ") {
    Some(index) => index
    None => remaining.length()
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
/// Bisect; `load_coverage` will be the public reporter interface.
#warnings("-unused_value")
async fn read(coverage_file~ : StringView) -> Array[@common.InstrumentedFile] {
  let bytes = @fs.read_file(coverage_file).binary()
  let cwd = @fs.realpath(".")
  decode(bytes, cwd~)
}
