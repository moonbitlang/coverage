///|
priv suberror MarshalError {
  Truncated
  InvalidHeader
  UnsupportedCode(Int)
  InvalidSharedReference(Int)
  InvalidShape(String)
} derive(Debug)

///|
impl Show for MarshalError with fn output(self, logger) {
  logger.write_string(
    match self {
      Truncated => "truncated OCaml Marshal payload"
      InvalidHeader => "invalid OCaml Marshal header or object table"
      UnsupportedCode(code) => "unsupported OCaml Marshal code \{code}"
      InvalidSharedReference(distance) =>
        "invalid OCaml Marshal shared reference \{distance}"
      InvalidShape(shape) => "invalid v4 trace shape: expected \{shape}"
    },
  )
}

///|
priv enum MarshalValue {
  Int(Int64)
  String(String)
  Block(Int, Array[MarshalValue])
} derive(Debug)

///|
priv struct MarshalReader {
  bytes : BytesView
  mut offset : Int
  mut limit : Int
  objects : Array[MarshalValue?]
}

///|
fn MarshalReader::new(bytes : BytesView) -> MarshalReader {
  { bytes, offset: 0, limit: bytes.length(), objects: [] }
}

///|
fn MarshalReader::read_byte(self : MarshalReader) -> Int raise MarshalError {
  guard self.offset < self.limit else { raise Truncated }
  let byte = self.bytes[self.offset].to_int()
  self.offset += 1
  byte
}

///|
fn MarshalReader::read_uint(
  self : MarshalReader,
  width : Int,
) -> UInt64 raise MarshalError {
  let mut value = 0UL
  for _ in 0..<width {
    value = (value << 8) | self.read_byte().to_uint64()
  }
  value
}

///|
fn MarshalReader::read_length(
  self : MarshalReader,
  width : Int,
) -> Int raise MarshalError {
  let value = self.read_uint(width)
  guard value <= @int.MAX_VALUE.to_uint64() else { raise InvalidHeader }
  value.to_int()
}

///|
fn MarshalReader::read_signed(
  self : MarshalReader,
  width : Int,
) -> Int64 raise MarshalError {
  let value = self.read_uint(width)
  if width == 8 {
    value.reinterpret_as_int64()
  } else {
    let sign = 1UL << (width * 8 - 1)
    if (value & sign) == 0UL {
      value.reinterpret_as_int64()
    } else {
      value.reinterpret_as_int64() - (1L << (width * 8))
    }
  }
}

///|
fn MarshalReader::read_bytes(
  self : MarshalReader,
  length : Int,
) -> BytesView raise MarshalError {
  guard length >= 0 && self.offset <= self.limit - length else {
    raise Truncated
  }
  let value = self.bytes[self.offset:self.offset + length]
  self.offset += length
  value
}

///|
fn MarshalReader::remember(
  self : MarshalReader,
  value : MarshalValue,
) -> MarshalValue {
  self.objects.push(Some(value))
  value
}

///|
fn MarshalReader::read_string(
  self : MarshalReader,
  length : Int,
) -> MarshalValue raise MarshalError {
  let value = @utf8.decode(self.read_bytes(length)) catch {
    _ => raise InvalidShape("utf8")
  }
  self.remember(String(value))
}

///|
fn MarshalReader::read_block(
  self : MarshalReader,
  size : Int,
  tag : Int,
) -> MarshalValue raise MarshalError {
  guard size > 0 else { return Block(tag, []) }
  let slot = self.objects.length()
  self.objects.push(None)
  let fields = Array::makei(size, _ => self.read_value())
  let value = Block(tag, fields)
  self.objects[slot] = Some(value)
  value
}

///|
fn MarshalReader::read_shared(
  self : MarshalReader,
  width : Int,
) -> MarshalValue raise MarshalError {
  let distance = self.read_length(width)
  let index = self.objects.length() - distance
  guard distance > 0 && index >= 0 else {
    raise InvalidSharedReference(distance)
  }
  guard self.objects[index] is Some(value) else {
    raise InvalidSharedReference(distance)
  }
  value
}

///|
fn MarshalReader::read_value(
  self : MarshalReader,
) -> MarshalValue raise MarshalError {
  let code = self.read_byte()
  if code >= 0x80 {
    self.read_block((code >> 4) & 0x7, code & 0xF)
  } else if code >= 0x40 {
    Int((code & 0x3F).to_int64())
  } else if code >= 0x20 {
    self.read_string(code & 0x1F)
  } else {
    match code {
      0x00 => Int(self.read_signed(1))
      0x01 => Int(self.read_signed(2))
      0x02 => Int(self.read_signed(4))
      0x03 => Int(self.read_signed(8))
      0x04 => self.read_shared(1)
      0x05 => self.read_shared(2)
      0x06 => self.read_shared(4)
      0x08 => {
        let header = self.read_uint(4)
        self.read_block((header >> 10).to_int(), (header & 0xFFUL).to_int())
      }
      0x09 => self.read_string(self.read_length(1))
      0x0A => self.read_string(self.read_length(4))
      0x13 => {
        let header = self.read_uint(8)
        guard header >> 10 <= @int.MAX_VALUE.to_uint64() else {
          raise InvalidHeader
        }
        self.read_block((header >> 10).to_int(), (header & 0xFFUL).to_int())
      }
      0x14 => self.read_shared(8)
      0x15 => self.read_string(self.read_length(8))
      _ => raise UnsupportedCode(code)
    }
  }
}

///|
fn decode_marshaled(bytes : BytesView) -> MarshalValue raise MarshalError {
  let reader = MarshalReader::new(bytes)
  guard reader.read_uint(4) == 0x8495A6BEUL else { raise InvalidHeader }
  let payload_length = reader.read_length(4)
  let object_count = reader.read_length(4)
  ignore(reader.read_uint(4))
  ignore(reader.read_uint(4))
  reader.limit = reader.offset + payload_length
  guard reader.limit == bytes.length() else { raise InvalidHeader }
  let value = reader.read_value()
  guard reader.offset == reader.limit && reader.objects.length() == object_count else {
    raise InvalidHeader
  }
  value
}
