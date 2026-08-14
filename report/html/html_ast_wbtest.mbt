///|
test "html ast escapes text and attribute values" {
  let node = Element("p", [Attribute("title", "\"<&'")], [Text("<&>\"'")])
  inspect(
    Show::to_string(node),
    content=(
      #|<p title="&quot;&lt;&amp;&#39;">&lt;&amp;&gt;&quot;&#39;</p>
    ),
  )
}

///|
test "html ast renders document, boolean attributes, and void elements" {
  let document = Fragment([
    Doctype,
    Element("details", [BooleanAttribute("open")], [
      VoidElement("meta", [Attribute("charset", "utf-8")]),
    ]),
  ])
  inspect(
    Show::to_string(document),
    content=(
      #|<!doctype html><details open><meta charset="utf-8"></details>
    ),
  )
}
