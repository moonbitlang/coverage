///|
let trace_magic = b"MOONCOVE00000004"

///|
fn expect_block(
  value : MarshalValue,
  size : Int,
) -> Array[MarshalValue] raise MarshalError {
  guard value is Block(0, fields) && fields.length() == size else {
    raise InvalidShape("block")
  }
  fields
}

///|
fn expect_string(value : MarshalValue) -> String raise MarshalError {
  guard value is String(value) else { raise InvalidShape("string") }
  value
}

///|
fn expect_int(value : MarshalValue) -> Int raise MarshalError {
  guard value is Int(value) && value >= 0L && value <= @int.MAX_VALUE.to_int64() else {
    raise InvalidShape("int")
  }
  value.to_int()
}

///|
fn[A] decode_list(
  value : MarshalValue,
  decode : (MarshalValue) -> A raise MarshalError,
) -> Array[A] raise MarshalError {
  let result = []
  for value = value {
    match value {
      Int(0L) => break
      Block(0, [head, tail]) => {
        result.push(decode(head))
        continue tail
      }
      _ => raise InvalidShape("list")
    }
  }
  result
}

///|
fn decode_position(value : MarshalValue) -> (Int, Int) raise MarshalError {
  guard expect_block(value, 3) is [_, line, column] else {
    raise InvalidShape("position")
  }
  (expect_int(line), expect_int(column))
}

///|
fn decode_range(value : MarshalValue) -> SourceRange raise MarshalError {
  guard expect_block(value, 3) is [_, start, end] else {
    raise InvalidShape("range")
  }
  let (start_line, start_column) = decode_position(start)
  let (end_line, end_column) = decode_position(end)
  { start_line, start_column, end_line, end_column }
}

///|
fn decode_parent(value : MarshalValue) -> Int? raise MarshalError {
  match value {
    Int(0L) => None
    Block(0, [index]) => Some(expect_int(index))
    _ => raise InvalidShape("parent")
  }
}

///|
fn decode_point(value : MarshalValue) -> TracePoint raise MarshalError {
  guard expect_block(value, 2) is [ranges, parent] else {
    raise InvalidShape("point")
  }
  { ranges: decode_list(ranges, decode_range), parent: decode_parent(parent) }
}

///|
fn decode_file(value : MarshalValue) -> TraceFile raise MarshalError {
  guard expect_block(value, 4) is [filename, file_id, package_name, points] else {
    raise InvalidShape("file")
  }
  guard points is Block(0, points) else { raise InvalidShape("points") }
  {
    filename: expect_string(filename),
    file_id: expect_string(file_id),
    package_name: expect_string(package_name),
    points: points.map(decode_point),
  }
}

///|
fn decode_trace_source(
  bytes : BytesView,
) -> Array[TraceFile] raise MarshalError {
  guard bytes.length() >= trace_magic.length() &&
    bytes[:trace_magic.length()] == trace_magic else {
    raise InvalidHeader
  }
  decode_list(decode_marshaled(bytes[trace_magic.length():]), decode_file)
}
