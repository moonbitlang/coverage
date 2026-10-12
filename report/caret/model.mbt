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
  start_line : Int32
  end_line : Int32
} derive(Eq)

///|
priv struct SimplifiedBlock {
  range : TopLevelRange
  uncovered : Array[Int32]
}

///|
priv struct SimplifiedFile {
  filename : String
  uncovered_count : Int32
  blocks : Array[String]
}
