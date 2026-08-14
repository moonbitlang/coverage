///|
/// Color preference for generated coverage pages.
pub(all) enum Theme {
  Auto
  Light
  Dark
} derive(Debug, Eq)

///|
fn percentage(visited : Int, total : Int) -> String {
  guard total != 0 else { "100%" }
  let total = total.to_int64()
  let scaled = visited.to_int64() * 1000L
  let quotient = scaled / total
  let rounded = if scaled % total * 2L >= total {
    quotient + 1L
  } else {
    quotient
  }
  let whole = rounded / 10L
  let fractional = rounded % 10L
  if fractional == 0L {
    "\{whole}%"
  } else {
    "\{whole}.\{fractional}%"
  }
}

///|
fn package_id(path : StringView) -> String {
  let output = StringBuilder()
  output.write_string("package-")
  for byte in @utf8.encode(path) {
    output.write_string(byte.to_int().to_string(radix=16).pad_start(2, '0'))
  }
  output.to_string()
}

///|
fn path_is_within(base : @path.Path, candidate : @path.Path) -> Bool {
  for current = candidate {
    if current == base {
      break true
    }
    let parent = current.dirname()
    if parent == current {
      break false
    } else {
      continue parent
    }
  }
}

///|
fn safe_report_path(filename : String) -> String {
  let base = @path.Path("__moon_cove_report_root__")
  let candidate = base.join(Path(filename))
  if path_is_within(base, candidate) {
    candidate.relative(base~).to_string()
  } else {
    let basename = @path.Path(filename).basename()
    let basename = if basename.is_empty() || basename == "." || basename == ".." {
      "source"
    } else {
      basename.to_owned()
    }
    base
    .join(Path("external"))
    .join(Path(package_id(filename)))
    .join(Path(basename))
    .relative(base~)
    .to_string()
  }
}

///|
fn write_hex_byte(output : @buffer.Buffer, byte : Byte) -> Unit {
  let write_nibble : (Int) -> Unit = nibble => {
    let ascii = if nibble < 10 {
      b'0'.to_int() + nibble
    } else {
      b'A'.to_int() + nibble - 10
    }
    output.write_byte(ascii.to_byte())
  }
  let value = byte.to_int()
  write_nibble(value >> 4)
  write_nibble(value & 0x0f)
}

///|
fn report_href(report_path : String) -> String {
  let output = @buffer.Buffer(size_hint=report_path.length())
  for byte in @utf8.encode(report_path) {
    let value = byte.to_int()
    let is_unreserved = (value >= b'a'.to_int() && value <= b'z'.to_int()) ||
      (value >= b'A'.to_int() && value <= b'Z'.to_int()) ||
      (value >= b'0'.to_int() && value <= b'9'.to_int()) ||
      byte == b'-' ||
      byte == b'.' ||
      byte == b'_' ||
      byte == b'~'
    if byte == b'/' || byte == b'\\' {
      output.write_byte(b'/')
    } else if is_unreserved {
      output.write_byte(byte)
    } else {
      output.write_byte(b'%')
      write_hex_byte(output, byte)
    }
  }
  @utf8.decode_lossy(output.to_bytes())
}

///|
fn ancestor_directories(filename : String) -> Array[@path.Path] {
  let directories = []
  for directory = @path.Path(filename).normalize().dirname() {
    let rendered = directory.to_string()
    guard !rendered.is_empty() && rendered != "." else { break }
    directories.push(directory)
    let parent = directory.dirname()
    if parent == directory {
      break
    } else {
      continue parent
    }
  }
  directories.rev()
}

///|
fn path_to_report_root(filename : String) -> String {
  Array::make(ancestor_directories(filename).length(), "../").join("")
}
