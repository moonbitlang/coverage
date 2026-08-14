///|
test "html command parses Bisect-compatible options" {
  let matches = command().parse(
    argv=[
      "html", "first.coverage", "second.coverage", "-o", "report", "--source-path",
      "src", "--source-path", "generated", "--theme", "dark", "--tab-size", "4",
      "--ignore-missing-files",
    ],
    env={},
  )
  guard matches.subcommand is Some(("html", html)) else { fail("html") }
  json_inspect(values(html, "coverage-files"), content=[
    "first.coverage", "second.coverage",
  ])
  json_inspect(values(html, "source-path"), content=["src", "generated"])
  inspect(value(html, "output"), content="report")
  assert_true(flag(html, "ignore-missing-files"))
  assert_eq(parse_tab_size(value(html, "tab-size")), 4)
  assert_true(parse_theme(value(html, "theme")) == @html.Dark)
}

///|
test "html command keeps Bisect defaults" {
  let matches = command().parse(argv=["html"], env={})
  guard matches.subcommand is Some(("html", html)) else { fail("html") }
  inspect(value(html, "output"), content="./_coverage")
  inspect(value(html, "title"), content="Coverage report")
  json_inspect(values(html, "source-path"), content=["."])
  json_inspect(values(html, "coverage-files"), content=[])
}
