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
  assert_true(parse_theme(value(html, "theme")) == Dark)
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

///|
test "summary command parses Bisect-compatible options" {
  let matches = command().parse(
    argv=[
      "summary", "first.coverage", "second.coverage", "--coverage-path", "coverage",
      "--per-file", "--expect", "src/a.mbt", "--do-not-expect", "src/generated.mbt",
    ],
    env={},
  )
  guard matches.subcommand is Some(("summary", summary)) else {
    fail("summary")
  }
  json_inspect(values(summary, "coverage-files"), content=[
    "first.coverage", "second.coverage",
  ])
  json_inspect(values(summary, "coverage-path"), content=["coverage"])
  json_inspect(values(summary, "expect"), content=["src/a.mbt"])
  json_inspect(values(summary, "do-not-expect"), content=["src/generated.mbt"])
  assert_true(flag(summary, "per-file"))
}

///|
async test "summary command writes text through its writer" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-summary-cli-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let coverage_file = @path.Path(root)
      .join(Path("summary.coverage"))
      .to_string()
    @fs.write_file(
      coverage_file,
      b"BISECT-COVERAGE-4 1 5 a.mbt 2 0 1 2 1 0",
      create_mode=CreateOrTruncate,
    )
    let matches = command().parse(argv=["summary", coverage_file], env={})
    guard matches.subcommand is Some(("summary", summary)) else {
      fail("summary")
    }
    let reader = @io.MemoryReader() <| writer => {
      run_summary(summary, writer~)
    }
    defer reader.close()
    inspect(reader.read_all().text(), content="Coverage: 1/2 (50.00%)\n")
  })
}

///|
test "cobertura command parses output and coverage files" {
  let matches = command().parse(
    argv=[
      "cobertura", "coverage.xml", "first.coverage", "second.coverage", "--coverage-path",
      "coverage", "--source-path", "src", "--source-path", "generated", "--ignore-missing-files",
      "--expect", "src/a.mbt", "--do-not-expect", "src/generated.mbt",
    ],
    env={},
  )
  guard matches.subcommand is Some(("cobertura", cobertura)) else {
    fail("cobertura")
  }
  inspect(value(cobertura, "output"), content="coverage.xml")
  json_inspect(values(cobertura, "coverage-files"), content=[
    "first.coverage", "second.coverage",
  ])
  json_inspect(values(cobertura, "coverage-path"), content=["coverage"])
  json_inspect(values(cobertura, "source-path"), content=["src", "generated"])
  json_inspect(values(cobertura, "expect"), content=["src/a.mbt"])
  json_inspect(values(cobertura, "do-not-expect"), content=["src/generated.mbt"])
  assert_true(flag(cobertura, "ignore-missing-files"))
}

///|
async test "cobertura command writes its output file" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-cobertura-cli-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let coverage_file = @path.Path(root)
      .join(Path("sample.coverage"))
      .to_string()
    let source_file = @path.Path(root).join(Path("a.mbt")).to_string()
    let output_file = @path.Path(root)
      .join(Path("reports/coverage.xml"))
      .to_string()
    @fs.write_file(source_file, b"a\n", create_mode=CreateOrTruncate)
    @fs.write_file(
      coverage_file,
      b"BISECT-COVERAGE-4 1 5 a.mbt 1 0 1 1",
      create_mode=CreateOrTruncate,
    )
    let matches = command().parse(
      argv=["cobertura", output_file, coverage_file, "--source-path", root],
      env={},
    )
    guard matches.subcommand is Some(("cobertura", cobertura)) else {
      fail("cobertura")
    }
    run_cobertura(cobertura)
    inspect(
      @fs.read_file(output_file).text(),
      content=(
        #|<?xml version="1.0" ?>
        #|<coverage lines-valid="1" lines-covered="1" line-rate="1.000000">
        #|  <sources>
        #|    <source>.</source>
        #|  </sources>
        #|  <packages>
        #|    <package name="." line-rate="1.000000">
        #|      <classes>
        #|        <class name="a.mbt" filename="a.mbt" line-rate="1.000000">
        #|          <lines>
        #|            <line number="1" hits="1"/>
        #|          </lines>
        #|        </class>
        #|      </classes>
        #|    </package>
        #|  </packages>
        #|</coverage>
      ),
    )
  })
}

///|
async test "cobertura command preserves output when report generation fails" {
  @async.with_task_group(group => {
    let root = @fs.tmpdir(prefix="moon-cove-cobertura-failure-")
    group.add_defer(() => @fs.rmdir(root, recursive=true))
    let coverage_file = @path.Path(root)
      .join(Path("missing.coverage"))
      .to_string()
    let output_file = @path.Path(root).join(Path("coverage.xml")).to_string()
    @fs.write_file(
      coverage_file,
      b"BISECT-COVERAGE-4 1 11 missing.mbt 1 0 1 1",
      create_mode=CreateOrTruncate,
    )
    @fs.write_file(output_file, b"existing", create_mode=CreateOrTruncate)
    let matches = command().parse(
      argv=["cobertura", output_file, coverage_file, "--source-path", root],
      env={},
    )
    guard matches.subcommand is Some(("cobertura", cobertura)) else {
      fail("cobertura")
    }
    try run_cobertura(cobertura) catch {
      _ => ()
    } noraise {
      _ => fail("expected report generation to fail")
    }
    inspect(@fs.read_file(output_file).text(), content="existing")
  })
}
