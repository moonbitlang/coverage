///|
priv suberror RuntimeLogError {
  UnterminatedBlock
  InvalidBlock
  InvalidCount
} derive(Debug)

///|
impl Show for RuntimeLogError with fn output(self, logger) {
  logger.write_string(
    match self {
      UnterminatedBlock => "unterminated MoonBit coverage block"
      InvalidBlock => "invalid MoonBit coverage JSON block"
      InvalidCount => "coverage counter is not an Int64"
    },
  )
}

///|
let coverage_begin = "----- BEGIN MOONBIT COVERAGE -----"

///|
let coverage_end = "----- END MOONBIT COVERAGE -----"

///|
fn json_count(value : Json) -> Int64 raise RuntimeLogError {
  guard value is Number(number, repr~) else { raise InvalidCount }
  match repr {
    Some(text) => @string.from_str(text) catch { _ => raise InvalidCount }
    None => {
      let count = number.to_int64()
      guard count.to_double() == number else { raise InvalidCount }
      count
    }
  }
}

///|
fn decode_runtime_block(
  block : StringView,
) -> Array[RuntimeHits] raise RuntimeLogError {
  let json = @json.parse(block.trim()) catch { _ => raise InvalidBlock }
  guard json is Object(files) else { raise InvalidBlock }
  let result = []
  for file_id, value in files {
    guard value is Array(values) else { raise InvalidBlock }
    let hits = []
    for value in values {
      hits.push(json_count(value))
    }
    result.push({ file_id, hits })
  }
  result
}

///|
fn parse_runtime_log(
  log : StringView,
) -> Array[RuntimeHits] raise RuntimeLogError {
  let result = []
  for rest = log {
    guard rest.find(coverage_begin) is Some(begin_at) else { break }
    let after_begin = rest[begin_at + coverage_begin.length():]
    guard after_begin.find("\n") is Some(line_end) else {
      raise UnterminatedBlock
    }
    let body = after_begin[line_end + 1:]
    guard body.find(coverage_end) is Some(end_at) else {
      raise UnterminatedBlock
    }
    result.append(decode_runtime_block(body[:end_at]))
    continue body[end_at + coverage_end.length():]
  }
  result
}
