///|
/// Selects the compiler-compatible caret report layout.
pub(all) enum Style {
  Detailed
  Simplified
}

///|
priv struct ResolvedSource {
  bytes : Bytes
  text : String
  lines : Array[String]
}

///|
priv struct TopLevelRange {
  start_line : Int
  end_line : Int
} derive(Eq)

///|
priv struct SimplifiedBlock {
  range : TopLevelRange
  uncovered : Array[Int]
}

///|
priv struct SimplifiedFile {
  filename : String
  uncovered_count : Int
  blocks : Array[String]
}
