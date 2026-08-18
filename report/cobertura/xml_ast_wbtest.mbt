///|
test "xml ast escapes text and attribute values" {
  let node = Element("class", [Attribute("name", "a<&\"'")], [Text("<&>")])
  inspect(
    Show::to_string(node),
    content=(
      #|<class name="a&lt;&amp;&quot;&apos;">&lt;&amp;&gt;</class>
    ),
  )
}

///|
test "xml ast indents nested and empty elements" {
  let document = Fragment([
    Declaration,
    Element("coverage", [], [
      Element("lines", [], [
        EmptyElement("line", [Attribute("number", "2")]),
        EmptyElement("line", [Attribute("number", "5")]),
      ]),
    ]),
  ])
  inspect(
    Show::to_string(document),
    content=(
      #|<?xml version="1.0" ?>
      #|<coverage>
      #|  <lines>
      #|    <line number="2"/>
      #|    <line number="5"/>
      #|  </lines>
      #|</coverage>
    ),
  )
}

///|
test "xml ast replaces invalid characters and preserves attribute whitespace" {
  let node = Element("value", [Attribute("name", "a\u{1}\t\n\r")], [
    Text("b\u{0b}\r"),
  ])
  inspect(
    Show::to_string(node),
    content=(
      #|<value name="a&#xFFFD;&#x9;&#xA;&#xD;">b&#xFFFD;&#xD;</value>
    ),
  )
}

///|
test "xml ast does not insert whitespace into mixed content" {
  let node = Element("p", [], [
    Text("before"),
    Element("b", [], [Text("inside")]),
    Text("after"),
  ])
  inspect(Show::to_string(node), content="<p>before<b>inside</b>after</p>")
}
