///|
fn utf8_scalar_width(first_byte : Byte) -> Int {
  let first_byte = first_byte.to_int()
  if first_byte < 0x80 {
    1
  } else if first_byte < 0xe0 {
    2
  } else if first_byte < 0xf0 {
    3
  } else {
    4
  }
}

///|
fn coverage_point(character : String, count : Int64) -> Html {
  let count_text = count.to_string()
  let (state, title) = if count > 0L {
    ("hit", "Visited \{count_text} times")
  } else {
    ("miss", "Never visited")
  }
  Element(
    "span",
    [
      Attribute("class", "coverage-point is-\{state}"),
      Attribute("data-count", count_text),
      Attribute("title", title),
    ],
    [Text(character)],
  )
}

///|
fn source_line_content(
  tab_size : Int,
  line : BytesView,
  offset~ : Int64,
  points~ : ArrayView[(Int64, Int64)],
) -> Array[Html] raise {
  let _ = @utf8.decode(line)
  let content : Array[Html] = []
  let plain = @buffer.Buffer(size_hint=line.length())
  let mut point_index = 0
  let mut byte_offset = offset
  for byte_index = 0; byte_index < line.length(); {
    let byte = line[byte_index]
    let width = utf8_scalar_width(byte)
    let scalar = line[byte_index:byte_index + width]
    let has_point = point_index < points.length() &&
      points[point_index].0 == byte_offset
    if has_point {
      if !plain.is_empty() {
        content.push(Text(@utf8.decode(plain.to_bytes())))
        plain.reset()
      }
      let character = if byte == b'\t' {
        String::make(tab_size, ' ')
      } else {
        @utf8.decode(scalar)
      }
      content.push(coverage_point(character, points[point_index].1))
      point_index += 1
    } else if byte == b'\t' {
      plain.write_string_utf8(String::make(tab_size, ' '))
    } else {
      plain.write_bytes(scalar)
    }
    byte_offset += width.to_int64()
    continue byte_index + width
  }
  if !plain.is_empty() {
    content.push(Text(@utf8.decode(plain.to_bytes())))
  }
  content
}

///|
priv enum LineState {
  Neutral
  Covered
  Mixed
  Uncovered
} derive(Eq)

///|
priv struct SourceLine {
  number : Int
  content : Array[Html]
  state : LineState
}

///|
fn LineState::name(self : LineState) -> String {
  match self {
    Neutral => "neutral"
    Covered => "covered"
    Mixed => "mixed"
    Uncovered => "uncovered"
  }
}

///|
fn LineState::gutter(self : LineState) -> (String, HtmlAttribute) {
  match self {
    Neutral => ("", Attribute("aria-hidden", "true"))
    Covered => ("●", Attribute("aria-label", "covered"))
    Mixed => ("◐", Attribute("aria-label", "partially covered"))
    Uncovered => ("○", Attribute("aria-label", "uncovered"))
  }
}

///|
fn state_of_points(points : ArrayView[(Int64, Int64)]) -> LineState {
  let mut visited = false
  let mut unvisited = false
  for point in points {
    if point.1 > 0L {
      visited = true
    } else if point.1 == 0L {
      unvisited = true
    }
  }
  match (visited, unvisited) {
    (false, false) => Neutral
    (true, false) => Covered
    (true, true) => Mixed
    (false, true) => Uncovered
  }
}

///|
fn source_lines(
  tab_size : Int,
  source : BytesView,
  points : ArrayView[Int64],
  counts : ArrayView[Int64],
) -> (Array[SourceLine], (Int, Int)) raise {
  let indexed_points = points.mapi((index, offset) => {
    (offset, index, counts.get(index).unwrap_or(0L))
  })
  indexed_points.sort_by((left, right) => {
    let offset_order = left.0.compare(right.0)
    if offset_order != 0 {
      offset_order
    } else {
      left.1.compare(right.1)
    }
  })
  let point_counts = indexed_points.map(point => (point.0, point.2))
  let visited = point_counts.fold(init=0, (visited, point) => {
    if point.1 > 0L {
      visited + 1
    } else {
      visited
    }
  })
  let line_ends = []
  for index, byte in source {
    if byte == b'\n' {
      line_ends.push(index + 1)
    }
  }
  if !source.is_empty() && source[source.length() - 1] != b'\n' {
    line_ends.push(source.length())
  }
  let lines = []
  let mut line_start = 0
  let mut point_index = 0
  for line_number, line_end in line_ends {
    let point_start = point_index
    while point_index < point_counts.length() &&
          point_counts[point_index].0 < line_end.to_int64() {
      point_index += 1
    }
    let points_on_line = point_counts[point_start:point_index]
    let content_end = if source[line_end - 1] == b'\n' {
      line_end - 1
    } else {
      line_end
    }
    lines.push({
      number: line_number + 1,
      content: source_line_content(
        tab_size,
        source[line_start:content_end],
        offset=line_start.to_int64(),
        points=points_on_line,
      ),
      state: state_of_points(points_on_line),
    })
    line_start = line_end
  }
  (lines, (visited, point_counts.length()))
}

///|
fn breadcrumb_nodes(
  title : String,
  filename : String,
  report_path : String,
  report_root : String,
) -> Array[Html] {
  let nodes : Array[Html] = [
    Element(
      "a",
      [
        Attribute("class", "home-link"),
        Attribute("href", "\{report_root}index.html"),
      ],
      [Text(title)],
    ),
  ]
  for directory in ancestor_directories(report_path) {
    let path = directory.to_string()
    nodes.push(Element("span", [Attribute("aria-hidden", "true")], [Text("/")]))
    nodes.push(
      Element(
        "a",
        [Attribute("href", "\{report_root}index.html#\{package_id(path)}")],
        [Text(directory.basename().to_owned())],
      ),
    )
  }
  nodes.push(Element("span", [Attribute("aria-hidden", "true")], [Text("/")]))
  nodes.push(
    Element("span", [Attribute("aria-current", "page")], [
      Text(@path.Path(filename).basename().to_owned()),
    ]),
  )
  nodes
}

///|
fn source_line_node(line : SourceLine) -> Html {
  let line_id = "L\{line.number}"
  let (gutter, gutter_accessibility) = line.state.gutter()
  Element(
    "li",
    [
      Attribute("class", "source-line"),
      Attribute("id", line_id),
      Attribute("data-coverage", line.state.name()),
    ],
    [
      Element(
        "a",
        [
          Attribute("class", "line-number"),
          Attribute("href", "#\{line_id}"),
          Attribute("aria-label", "Line \{line.number}"),
        ],
        [Text(line.number.to_string())],
      ),
      Element(
        "span",
        [Attribute("class", "coverage-gutter"), gutter_accessibility],
        [Text(gutter)],
      ),
      Element("code", [Attribute("class", "source-code")], line.content),
    ],
  )
}

///|
fn source_outline(
  title : String,
  report_root : String,
  lines : ArrayView[SourceLine],
) -> Html {
  let blocks : Array[Html] = [
    Element("div", [Attribute("class", "outline-block")], [
      Element("h2", [], [Text("Coverage tree")]),
      Element("ul", [], [
        Element("li", [], [
          Element(
            "a",
            [
              Attribute("class", "outline-link"),
              Attribute("href", "\{report_root}index.html#coverage"),
            ],
            [
              Element("span", [Attribute("aria-hidden", "true")], [Text("■")]),
              Text(" \{title}"),
            ],
          ),
        ]),
      ]),
    ]),
  ]
  let uncovered = lines.filter(line => {
    line.state == Mixed || line.state == Uncovered
  })
  if !uncovered.is_empty() {
    blocks.push(
      Element("div", [Attribute("class", "outline-block line-outline")], [
        Element("h2", [], [Text("Uncovered lines")]),
        Element(
          "ul",
          [],
          uncovered.map(line => {
            Element("li", [], [
              Element("a", [Attribute("href", "#L\{line.number}")], [
                Text("Line \{line.number}"),
              ]),
            ])
          }),
        ),
      ]),
    )
  }
  blocks.push(
    Element(
      "div",
      [
        Attribute("class", "outline-block legend"),
        Attribute("aria-label", "Coverage legend"),
      ],
      [
        Element("h2", [], [Text("Line state")]),
        Element("p", [], [
          Element(
            "span",
            [
              Attribute("class", "legend-mark covered"),
              Attribute("aria-hidden", "true"),
            ],
            [],
          ),
          Text(" Covered point"),
        ]),
        Element("p", [], [
          Element(
            "span",
            [
              Attribute("class", "legend-mark mixed"),
              Attribute("aria-hidden", "true"),
            ],
            [],
          ),
          Text(" Mixed points"),
        ]),
        Element("p", [], [
          Element(
            "span",
            [
              Attribute("class", "legend-mark uncovered"),
              Attribute("aria-hidden", "true"),
            ],
            [],
          ),
          Text(" Uncovered point"),
        ]),
      ],
    ),
  )
  Element(
    "nav",
    [
      Attribute("class", "project-outline"),
      Attribute("aria-label", "Coverage tree outline"),
    ],
    blocks,
  )
}

///|
fn render_source_page(
  title~ : String,
  theme~ : Theme,
  tab_size~ : Int,
  report_path~ : String,
  source~ : BytesView,
  file~ : @common.InstrumentedFile,
) -> (String, (Int, Int)) raise {
  let (lines, stats) = source_lines(tab_size, source, file.points, file.counts)
  let (visited, total) = stats
  let filename = file.filename
  let basename = @path.Path(filename).basename()
  let report_root = path_to_report_root(report_path)
  let document = Fragment([
    Doctype,
    Element("html", html_document_attributes(theme), [
      Element("head", [], [
        VoidElement("meta", [Attribute("charset", "utf-8")]),
        VoidElement("meta", [
          Attribute("name", "viewport"),
          Attribute("content", "width=device-width, initial-scale=1"),
        ]),
        VoidElement("meta", [
          Attribute("name", "description"),
          Attribute("content", "Point coverage for \{filename}."),
        ]),
        Element("title", [], [Text("\{basename} — \{title} coverage")]),
        VoidElement("link", [
          Attribute("rel", "stylesheet"),
          Attribute("href", "\{report_root}coverage.css"),
        ]),
      ]),
      Element("body", [Attribute("data-page", "source")], [
        Element("header", [Attribute("class", "site-header")], [
          Element(
            "nav",
            [
              Attribute("class", "breadcrumbs"),
              Attribute("aria-label", "Report navigation"),
            ],
            breadcrumb_nodes(title, filename, report_path, report_root),
          ),
          Element("p", [Attribute("class", "site-note")], [
            Text("Generated by moon_cove · point coverage"),
          ]),
        ]),
        Element("main", [Attribute("class", "layout")], [
          Element("article", [Attribute("class", "source-report")], [
            Element("header", [Attribute("class", "source-header")], [
              Element("h1", [], [Text(filename)]),
              Element(
                "span",
                [
                  Attribute("class", "coverage-summary"),
                  Attribute("aria-label", "File coverage statistics"),
                ],
                [
                  Element("strong", [], [Text(percentage(visited, total))]),
                  Text(
                    " · \{visited} / \{total} points · \{lines.length()} lines",
                  ),
                ],
              ),
            ]),
            Element("p", [Attribute("class", "source-intro")], [
              Text(
                "Background color reports the state of each line. Underlined characters mark exact instrumented byte offsets; hover them to inspect the visit count.",
              ),
            ]),
            Element(
              "section",
              [
                Attribute("class", "source-frame"),
                Attribute("aria-label", "Source coverage for \{filename}"),
              ],
              [
                Element(
                  "ol",
                  [Attribute("class", "source-lines")],
                  lines.map(source_line_node),
                ),
              ],
            ),
          ]),
          source_outline(title, report_root, lines),
        ]),
      ]),
    ]),
  ])
  (Show::to_string(document), stats)
}
