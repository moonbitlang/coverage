///|
test "line rate uses ties-to-even rounding like OCaml printf" {
  let node = Element(
    "coverage",
    [Attribute("line-rate", line_rate((1, 128)))],
    [],
  )
  inspect(
    Show::to_string(node),
    content=(
      #|<coverage line-rate="0.007812"></coverage>
    ),
  )
}
