///|
priv struct IndexFile {
  filename : String
  report_path : String
  href : String
  stats : (Int, Int)
}

///|
priv enum IndexElement {
  File(IndexFile)
  Directory(String, Array[IndexElement], (Int, Int))
}

///|
fn add_stats(left : (Int, Int), right : (Int, Int)) -> (Int, Int) {
  (left.0 + right.0, left.1 + right.1)
}

///|
fn sum_file_stats(files : ArrayView[IndexFile]) -> (Int, Int) {
  files.fold(init=(0, 0), (stats, file) => add_stats(stats, file.stats))
}

///|
fn immediate_child_directory(
  directory : @path.Path,
  filename : String,
) -> @path.Path? {
  for candidate = @path.Path(filename).normalize().dirname() {
    if candidate == directory {
      break None
    }
    let parent = candidate.dirname()
    if parent == directory {
      break Some(candidate)
    } else if parent == candidate {
      break None
    } else {
      continue parent
    }
  }
}

///|
fn collate_directory(
  directory : @path.Path,
  files : ArrayView[IndexFile],
) -> (Array[IndexElement], (Int, Int)) {
  let immediate_files = []
  let child_files : Map[String, Array[IndexFile]] = Map([])
  for file in files {
    if @path.Path(file.report_path).normalize().dirname() == directory {
      immediate_files.push(file)
    } else if immediate_child_directory(directory, file.report_path)
      is Some(child) {
      let path = child.to_string()
      if child_files.get(path) is Some(group) {
        group.push(file)
      } else {
        child_files[path] = [file]
      }
    }
  }
  immediate_files.sort_by((left, right) => {
    left.report_path.compare(right.report_path)
  })
  let elements = immediate_files.map(file => File(file))
  let children = child_files.to_array()
  children.sort_by((left, right) => left.0.compare(right.0))
  for child in children {
    let (path, child_files) = child
    let (child_elements, child_stats) = collate_directory(
      Path(path),
      child_files,
    )
    elements.push(Directory(path, child_elements, child_stats))
  }
  (elements, sum_file_stats(files))
}

///|
fn collate(files : ArrayView[IndexFile]) -> (Array[IndexElement], (Int, Int)) {
  collate_directory(Path("."), files)
}

///|
fn file_state(stats : (Int, Int)) -> String {
  if stats.1 == 0 || stats.0 == stats.1 {
    "covered"
  } else if stats.0 == 0 {
    "uncovered"
  } else {
    "mixed"
  }
}

///|
fn index_file_node(file : IndexFile) -> Html {
  let (visited, total) = file.stats
  let state = file_state(file.stats)
  Element(
    "a",
    [Attribute("class", "file-node is-\{state}"), Attribute("href", file.href)],
    [
      Element(
        "span",
        [Attribute("class", "status-mark"), Attribute("aria-hidden", "true")],
        [Text("■")],
      ),
      Element("span", [Attribute("class", "file-name")], [
        Text(@path.Path(file.filename).basename().to_owned()),
      ]),
      Element("span", [Attribute("class", "file-stats")], [
        Element("strong", [], [Text(percentage(visited, total))]),
        Text(" · \{visited} / \{total}"),
      ]),
    ],
  )
}

///|
fn file_list(elements : ArrayView[IndexElement]) -> Html {
  let files = elements.filter_map(element => {
    match element {
      File(file) => Some(file)
      Directory(_, _, _) => None
    }
  })
  if files.is_empty() {
    Fragment([])
  } else {
    Element(
      "div",
      [Attribute("class", "file-list")],
      files.map(index_file_node),
    )
  }
}

///|
fn directory_nodes(elements : ArrayView[IndexElement], level : Int) -> Html {
  let directories = elements.filter_map(element => {
    match element {
      File(_) => None
      Directory(_, _, _) as directory => Some(directory)
    }
  })
  if directories.is_empty() {
    Fragment([])
  } else {
    Element(
      "div",
      [Attribute("class", "tree-children")],
      directories.map(directory => index_directory_node(directory, level)),
    )
  }
}

///|
fn index_directory_node(element : IndexElement, level : Int) -> Html {
  match element {
    File(_) => Fragment([])
    Directory(path, elements, (visited, total)) => {
      let attributes = [
        Attribute("class", "tree-node package-node"),
        Attribute("id", package_id(path)),
      ]
      if level == 2 {
        attributes.push(BooleanAttribute("open"))
      }
      Element("section", [Attribute("class", "tree-block")], [
        Element("details", attributes, [
          Element("summary", [Attribute("class", "node-header")], [
            Element(
              "span",
              [
                Attribute("class", "node-title package-title"),
                Attribute("role", "heading"),
                Attribute("aria-level", level.to_string()),
              ],
              [Text("\{@path.Path(path).basename()}/")],
            ),
            Element("span", [Attribute("class", "coverage-summary")], [
              Element("strong", [], [Text(percentage(visited, total))]),
              Text(" · \{visited} / \{total} points"),
            ]),
          ]),
          file_list(elements),
          directory_nodes(elements, level + 1),
        ]),
      ])
    }
  }
}

///|
fn index_outline_elements(elements : ArrayView[IndexElement]) -> Html {
  if elements.is_empty() {
    Fragment([])
  } else {
    Element(
      "ul",
      [],
      elements.map(element => {
        match element {
          File(file) =>
            Element("li", [], [
              Element(
                "a",
                [
                  Attribute("class", "outline-link file-outline"),
                  Attribute("href", file.href),
                ],
                [Text(@path.Path(file.filename).basename().to_owned())],
              ),
            ])
          Directory(path, children, _) =>
            Element("li", [], [
              Element(
                "a",
                [
                  Attribute("class", "outline-link"),
                  Attribute("href", "#\{package_id(path)}"),
                ],
                [Text("\{@path.Path(path).basename()}/")],
              ),
              index_outline_elements(children),
            ])
        }
      }),
    )
  }
}

///|
fn index_outline(title : String, elements : ArrayView[IndexElement]) -> Html {
  Element(
    "nav",
    [
      Attribute("class", "project-outline"),
      Attribute("aria-label", "Coverage tree outline"),
    ],
    [
      Element("div", [Attribute("class", "outline-block")], [
        Element("h2", [], [Text("Coverage tree")]),
        Element("ul", [], [
          Element("li", [], [
            Element(
              "a",
              [
                Attribute("class", "outline-link"),
                Attribute("href", "#coverage"),
              ],
              [
                Element("span", [Attribute("aria-hidden", "true")], [
                  Text("■"),
                ]),
                Text(" \{title}"),
              ],
            ),
            index_outline_elements(elements),
          ]),
        ]),
      ]),
      Element(
        "div",
        [
          Attribute("class", "outline-block legend"),
          Attribute("aria-label", "Coverage legend"),
        ],
        [
          Element("h2", [], [Text("Legend")]),
          Element("p", [], [
            Element(
              "span",
              [
                Attribute("class", "legend-mark covered"),
                Attribute("aria-hidden", "true"),
              ],
              [],
            ),
            Text(" Covered"),
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
            Text(" Partially covered"),
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
            Text(" Uncovered"),
          ]),
        ],
      ),
    ],
  )
}

///|
fn render_index_page(
  title~ : String,
  theme~ : Theme,
  files~ : ArrayView[IndexFile],
) -> String {
  let sorted_files = files.to_owned()
  sorted_files.sort_by((left, right) => {
    left.report_path.compare(right.report_path)
  })
  let (elements, (visited, total)) = collate(sorted_files)
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
          Attribute("content", "Coverage report for \{title}."),
        ]),
        Element("title", [], [Text("\{title} coverage")]),
        VoidElement("link", [
          Attribute("rel", "stylesheet"),
          Attribute("href", "coverage.css"),
        ]),
      ]),
      Element("body", [Attribute("data-page", "index")], [
        Element("header", [Attribute("class", "site-header")], [
          Element("nav", [Attribute("aria-label", "Report navigation")], [
            Element(
              "a",
              [Attribute("class", "home-link"), Attribute("href", "index.html")],
              [Text(title)],
            ),
          ]),
          Element("p", [Attribute("class", "site-note")], [
            Text("Generated by moon_cove · point coverage"),
          ]),
        ]),
        Element("main", [Attribute("class", "layout")], [
          Element("article", [Attribute("class", "report-tree")], [
            Element("section", [Attribute("class", "tree-block root-block")], [
              Element("h1", [Attribute("class", "visually-hidden")], [
                Text("\{title} coverage report"),
              ]),
              Element(
                "details",
                [
                  Attribute("class", "tree-node root-node"),
                  Attribute("id", "coverage"),
                  BooleanAttribute("open"),
                ],
                [
                  Element("summary", [Attribute("class", "node-header")], [
                    Element(
                      "span",
                      [
                        Attribute("class", "node-title title-level-1"),
                        Attribute("role", "heading"),
                        Attribute("aria-level", "1"),
                      ],
                      [Text(title)],
                    ),
                    Element(
                      "span",
                      [
                        Attribute("class", "coverage-summary"),
                        Attribute("aria-label", "Overall coverage statistics"),
                      ],
                      [
                        Element("strong", [], [Text(percentage(visited, total))]),
                        Text(
                          " · \{visited} / \{total} points · \{files.length()} files",
                        ),
                      ],
                    ),
                  ]),
                  file_list(elements),
                  directory_nodes(elements, 2),
                ],
              ),
            ]),
          ]),
          index_outline(title, elements),
        ]),
      ]),
    ]),
  ])
  Show::to_string(document)
}
